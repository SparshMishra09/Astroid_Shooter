import 'dart:math';
import 'package:flutter/material.dart' show Colors;
import '../config/game_config.dart';
import '../models/enums.dart';
import '../models/player.dart';
import '../models/asteroids.dart';
import '../models/enemy_ship.dart';
import '../models/boss.dart';
import '../models/projectiles.dart';
import '../models/power_ups.dart';
import '../models/effects.dart';
import '../models/game_state.dart';
import 'game_mode.dart';
import 'game_mode_registry.dart';

/// Callbacks the controller fires to drive audio + UI reactions
/// (screen shake, combo flash) without knowing about Flutter widgets.
abstract class GameCallbacks {
  void onShoot();
  void onExplosion();
  void onPowerUp();
  void onHit();
  void onGameOver();
  void onWaveComplete();
  void onBossIncoming();
  void onBossDefeated();
  void onShieldBreak();

  /// Trigger screen shake (intensity 0..1).
  void onShake(double intensity);

  /// Trigger a combo-level-up flash.
  void onComboFlash();
}

/// No-op callback implementation (used when audio/effects are disabled).
class NullGameCallbacks implements GameCallbacks {
  const NullGameCallbacks();
  @override
  void onShoot() {}
  @override
  void onExplosion() {}
  @override
  void onPowerUp() {}
  @override
  void onHit() {}
  @override
  void onGameOver() {}
  @override
  void onWaveComplete() {}
  @override
  void onBossIncoming() {}
  @override
  void onBossDefeated() {}
  @override
  void onShieldBreak() {}
  @override
  void onShake(double intensity) {}
  @override
  void onComboFlash() {}
}

/// Owns ALL game logic and mutable state. The screen is a thin view that
/// calls [tick] each frame and reads the public fields for rendering.
///
/// Adding a new game mode: pass a different [GameModeConfig] — no logic
/// in this class needs to change.
class GameController {
  GameController({required this.mode, this.callbacks = const NullGameCallbacks()})
      : config = gameModeConfigFor(mode);

  final GameMode mode;
  final GameModeConfig config;
  GameCallbacks callbacks;

  // --- Core entities ---
  // player is initialized with default screen dimensions so it's valid
  // before initialize() is called with real dimensions.
  Player player = Player(
    x: GameConfig.defaultScreenWidth / 2 - GameConfig.playerSize / 2,
    y: GameConfig.defaultScreenHeight - GameConfig.playerSize - GameConfig.playerBottomPadding,
    width: GameConfig.playerSize,
    height: GameConfig.playerSize,
  );
  List<Asteroid> asteroids = [];
  List<Bullet> bullets = [];
  List<Enemy> enemies = [];
  List<EnemyBullet> enemyBullets = [];
  Boss? activeBoss;
  List<PowerUp> powerUps = [];
  Map<PowerUpType, ActivePowerUp> activePowerUps = {};
  List<LaserBeam> laserBeams = [];
  List<FloatingText> floatingTexts = [];
  List<ExplosionEffect> explosionEffects = [];
  List<HitEffect> hitEffects = [];
  List<Flash> muzzleFlashes = [];

  // Buffer for entities created during collision processing (e.g. split
  // asteroids). These are flushed into their real lists AFTER all
  // iteration completes, preventing ConcurrentModificationError.
  final List<Enemy> _pendingEnemies = [];

  // --- State ---
  // gameState is eagerly initialized so it's always valid, even before
  // initialize() is called with real screen dimensions.
  GameState gameState = GameState();
  int frameCount = 0;
  int lastShotFrame = 0;
  int asteroidsDestroyed = 0;
  bool hasShield = false;
  int shieldHitsRemaining = 0;

  // --- Combo flash tracking (UI reads these) ---
  double? previousComboMultiplier;
  int comboFlashTimer = 0;

  // --- Screen dimensions (set by screen before first tick) ---
  double screenWidth = GameConfig.defaultScreenWidth;
  double screenHeight = GameConfig.defaultScreenHeight;
  double backgroundScrollOffset = 0.0;

  // Sizes (exposed for rendering)
  final double playerSize = GameConfig.playerSize;
  final double asteroidSize = GameConfig.asteroidSize;
  final double bulletWidth = GameConfig.bulletWidth;
  final double bulletHeight = GameConfig.bulletHeight;
  final double bulletSpeed = GameConfig.bulletSpeed;

  /// Initialize / reset for a new run.
  /// Pass [preserveHighScore] to keep the loaded high score across resets
  /// (e.g. when restarting after game over).
  void initialize({bool preserveHighScore = false}) {
    final savedHighScore = preserveHighScore ? gameState.highScore : 0;
    gameState = GameState();
    gameState.highScore = savedHighScore;

    player = Player(
      x: screenWidth / 2 - playerSize / 2,
      y: screenHeight - playerSize - GameConfig.playerBottomPadding,
      width: playerSize,
      height: playerSize,
    );

    asteroids.clear();
    bullets.clear();
    enemies.clear();
    enemyBullets.clear();
    activeBoss = null;
    powerUps.clear();
    laserBeams.clear();
    floatingTexts.clear();
    activePowerUps.clear();
    explosionEffects.clear();
    hitEffects.clear();
    muzzleFlashes.clear();
    _pendingEnemies.clear();
    hasShield = false;
    shieldHitsRemaining = 0;

    frameCount = 0;
    lastShotFrame = 0;
    asteroidsDestroyed = 0;
    backgroundScrollOffset = 0;
    previousComboMultiplier = null;
    comboFlashTimer = 0;
  }

  void setScreenSize(double width, double height) {
    screenWidth = width;
    screenHeight = height;
  }

  /// Move the player toward a screen x (called from gesture handlers).
  void movePlayerTo(double globalX) {
    if (gameState.isPaused || gameState.isGameOver) return;
    player.moveTo(globalX - player.width / 2, screenWidth);
  }

  void togglePause() => gameState.isPaused = !gameState.isPaused;

  // =========================================================================
  //  MAIN LOOP
  // =========================================================================

  /// Advance one frame. Returns true if the screen should rebuild.
  void tick() {
    if (gameState.isPaused || gameState.isGameOver) return;

    frameCount++;
    backgroundScrollOffset += 2.0;
    gameState.updateWaveSystem();

    // Auto-shoot (always, even during wave breaks)
    final currentInterval = config.getShotInterval(gameState, activePowerUps);
    if (frameCount - lastShotFrame >= currentInterval) {
      fireBullet();
      lastShotFrame = frameCount;
    }

    if (!gameState.isWaveBreak) {
      // Spawn normal asteroids
      final waveSpawnRate = config.getAsteroidSpawnRate(gameState);
      if (frameCount % waveSpawnRate == 0) {
        asteroids.add(Asteroid.random(screenWidth, asteroidSize));
      }
      updatePowerUps();
      updateEnemies();
      spawnEnemies();
    } else {
      // During break: keep updating existing objects, no new spawns.
      updatePowerUps();
      updateEnemies();

      // One chance at a bonus power-up drop per break.
      if (gameState.waveBreakTimer == GameConfig.waveBreakDuration - 60) {
        _maybeDropWaveBreakBonus();
      }
    }

    player.update();

    for (var asteroid in asteroids) {
      asteroid.update(screenHeight);
    }
    for (var bullet in bullets) {
      bullet.update(screenWidth);
    }

    checkCollisions();

    // Flush any entities created during collision processing (e.g. split
    // asteroids) into their real lists. This MUST happen after all
    // for-in iteration in checkCollisions() is complete to avoid
    // ConcurrentModificationError.
    if (_pendingEnemies.isNotEmpty) {
      enemies.addAll(_pendingEnemies);
      _pendingEnemies.clear();
    }

    cleanupObjects();

    // Decay effects
    for (var fx in explosionEffects) {
      fx.update();
    }
    for (var fx in hitEffects) {
      fx.update();
    }
    for (var fx in muzzleFlashes) {
      fx.update();
    }
    explosionEffects.removeWhere((fx) => !fx.isActive);
    hitEffects.removeWhere((fx) => !fx.isActive);
    muzzleFlashes.removeWhere((fx) => !fx.isActive);

    if (comboFlashTimer > 0) comboFlashTimer--;
  }

  // =========================================================================
  //  SHOOTING
  // =========================================================================

  void fireBullet() {
    if (gameState.isPaused || gameState.isGameOver) return;

    if (config.powerUpsEnabled &&
        activePowerUps.containsKey(PowerUpType.tripleShot) &&
        activePowerUps[PowerUpType.tripleShot]!.isActive) {
      fireTripleShot();
    } else {
      fireSingleBullet();
    }
  }

  void fireSingleBullet() {
    bullets.add(Bullet(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      width: bulletWidth,
      height: bulletHeight,
      speedY: bulletSpeed,
    ));
    muzzleFlashes.add(Flash(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      size: bulletWidth * 1.6,
      lifeTimer: 5,
      isUpward: true,
    ));
    callbacks.onShoot();
  }

  void fireTripleShot() {
    fireSingleBullet(); // center

    final leftAngle = -15 * (pi / 180);
    final rightAngle = 15 * (pi / 180);

    bullets.add(Bullet(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      width: bulletWidth,
      height: bulletHeight,
      speedY: cos(leftAngle) * bulletSpeed,
      speedX: sin(leftAngle) * bulletSpeed,
    ));
    bullets.add(Bullet(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      width: bulletWidth,
      height: bulletHeight,
      speedY: cos(rightAngle) * bulletSpeed,
      speedX: sin(rightAngle) * bulletSpeed,
    ));
  }

  // =========================================================================
  //  ENEMIES
  // =========================================================================

  void updateEnemies() {
    for (var enemy in enemies) {
      enemy.update(screenHeight, screenWidth);
      if (enemy is EnemyShip && enemy.shouldShoot()) {
        fireEnemyBullet(enemy);
      }
    }

    for (var bullet in enemyBullets) {
      bullet.update(screenHeight);
    }

    if (activeBoss != null) {
      activeBoss!.update(screenHeight, screenWidth);
      if (activeBoss!.shouldShoot()) {
        fireBossSpread();
      }
    }
  }

  void fireEnemyBullet(EnemyShip ship) {
    enemyBullets.add(EnemyBullet(
      x: ship.x + ship.width / 2 - 5,
      y: ship.y + ship.height,
      width: 10,
      height: 15,
      speedY: GameConfig.enemyBulletSpeed,
    ));
  }

  void fireBossSpread() {
    if (activeBoss == null) return;
    for (int i = -1; i <= 1; i++) {
      final angle = i * 20 * (pi / 180);
      enemyBullets.add(EnemyBullet(
        x: activeBoss!.x + activeBoss!.width / 2 - 5,
        y: activeBoss!.y + activeBoss!.height,
        width: 10,
        height: 15,
        speedY: cos(angle) * GameConfig.bossBulletSpeed,
        speedX: sin(angle) * GameConfig.bossBulletSpeed,
      ));
    }
  }

  void spawnEnemies() {
    // Boss spawn check
    if (config.shouldSpawnBoss(gameState, asteroidsDestroyed) && activeBoss == null) {
      spawnBoss();
      return;
    }
    if (activeBoss != null) return; // pause other enemy spawns during boss

    final waveSpawnInterval = config.getEnemySpawnInterval(gameState);
    if (frameCount % waveSpawnInterval != 0) return;

    final random = Random();
    final roll = random.nextDouble();
    final probs = config.getEnemyProbabilities(gameState.currentWave);

    if (roll < probs[EnemyType.smallFastAsteroid]!) {
      enemies.add(SmallFastAsteroid.random(screenWidth, asteroidSize));
    } else if (roll < probs[EnemyType.hugeSlowAsteroid]!) {
      enemies.add(HugeSlowAsteroid.random(screenWidth, asteroidSize));
    } else if (roll < probs[EnemyType.enemyShip]!) {
      enemies.add(EnemyShip.random(screenWidth, GameConfig.enemyShipSize));
    }
    // else: no special enemy this roll (normal asteroids only)
  }

  void spawnBoss() {
    activeBoss = Boss.create(screenWidth, GameConfig.bossSize);
    floatingTexts.add(FloatingText(
      text: 'BOSS INCOMING!',
      x: screenWidth / 2 - 60,
      y: screenHeight / 2,
      color: Colors.red,
      lifeTimer: 180,
      fontSize: 22,
    ));
    asteroidsDestroyed = 0;
    callbacks.onBossIncoming();
  }

  void defeatBoss() {
    if (activeBoss == null) return;

    gameState.score += activeBoss!.scoreValue;

    // Big death explosion + shake
    explosionEffects.add(ExplosionEffect(
      x: activeBoss!.x + activeBoss!.width / 2,
      y: activeBoss!.y + activeBoss!.height / 2,
      particleCount: 24,
      duration: 90,
    ));
    callbacks.onShake(1.0);

    // Drop power-ups
    for (int i = 0; i < GameConfig.bossPowerUpDropCount; i++) {
      powerUps.add(PowerUp.random(
        activeBoss!.x + activeBoss!.width / 2 + (i * 30 - 15),
        activeBoss!.y + activeBoss!.height / 2,
      ));
    }

    floatingTexts.add(FloatingText(
      text: 'BOSS DEFEATED!',
      x: screenWidth / 2 - 70,
      y: screenHeight / 2,
      color: Colors.yellow,
      lifeTimer: 180,
      fontSize: 22,
    ));

    activeBoss = null;
    callbacks.onBossDefeated();
  }

  /// Split a destroyed huge asteroid into two small fast ones.
  /// Adds to [_pendingEnemies] — flushed after collision processing to
  /// avoid ConcurrentModificationError during iteration.
  void splitHugeAsteroid(HugeSlowAsteroid huge) {
    for (int i = 0; i < 2; i++) {
      _pendingEnemies.add(SmallFastAsteroid(
        x: huge.x + (i * 20),
        y: huge.y,
        size: asteroidSize * 0.5,
        speedY: (1 + Random().nextDouble() * 3) * 1.8,
        rotationSpeed: (Random().nextDouble() - 0.5) * 0.15,
      ));
    }
  }

  // =========================================================================
  //  POWER-UPS
  // =========================================================================

  void updatePowerUps() {
    // Decay active power-ups
    final keysToRemove = <PowerUpType>[];
    activePowerUps.forEach((type, powerUp) {
      powerUp.update();
      if (!powerUp.isActive) keysToRemove.add(type);
    });
    for (var key in keysToRemove) {
      deactivatePowerUp(key);
    }

    // Fall floating power-ups
    for (var powerUp in powerUps) {
      powerUp.update(screenHeight);
    }

    // Laser follows player
    if (activePowerUps.containsKey(PowerUpType.laserBeam) &&
        activePowerUps[PowerUpType.laserBeam]!.isActive) {
      for (var laser in laserBeams) {
        laser.x = player.x + player.width / 2 - 4;
        laser.update();
      }
    }

    for (var text in floatingTexts) {
      text.update();
    }
  }

  void tryDropPowerUp(double x, double y) {
    if (!config.powerUpsEnabled) return;
    final random = Random();
    if (random.nextDouble() < GameConfig.powerUpDropChance) {
      powerUps.add(PowerUp.random(x, y));
    }
  }

  void _maybeDropWaveBreakBonus() {
    final random = Random();
    if (random.nextDouble() < GameConfig.waveBreakBonusDropChance) {
      powerUps.add(PowerUp.random(
        screenWidth / 2 - GameConfig.powerUpSize / 2,
        screenHeight / 2 - 100,
      ));
      floatingTexts.add(FloatingText(
        text: 'Bonus Power-Up!',
        x: screenWidth / 2 - 60,
        y: screenHeight / 2 - 150,
        color: Colors.cyan,
        lifeTimer: 180,
      ));
    }
  }

  void collectPowerUp(PowerUp powerUp) {
    powerUp.isVisible = false;
    activatePowerUp(powerUp.type);
    callbacks.onPowerUp();

    // Collection burst
    explosionEffects.add(ExplosionEffect(
      x: powerUp.x + powerUp.width / 2,
      y: powerUp.y + powerUp.height / 2,
      particleCount: 10,
      duration: 40,
      colors: [powerUp.color, Colors.white, powerUp.color],
    ));

    floatingTexts.add(FloatingText(
      text: ActivePowerUp(type: powerUp.type, remainingTime: 0).displayName,
      x: powerUp.x,
      y: powerUp.y,
    ));
  }

  void activatePowerUp(PowerUpType type) {
    activePowerUps[type] = ActivePowerUp(
      type: type,
      remainingTime: ActivePowerUp.getDuration(type),
    );

    switch (type) {
      case PowerUpType.shield:
        hasShield = true;
        shieldHitsRemaining = 1;
        break;
      case PowerUpType.rapidFire:
      case PowerUpType.tripleShot:
        break; // handled in getShotInterval / fireBullet
      case PowerUpType.laserBeam:
        laserBeams.add(LaserBeam(
          x: player.x + player.width / 2 - 4,
          y: 0,
          height: player.y,
        ));
        break;
    }
  }

  void deactivatePowerUp(PowerUpType type) {
    if (!activePowerUps.containsKey(type)) return;
    switch (type) {
      case PowerUpType.shield:
        hasShield = false;
        shieldHitsRemaining = 0;
        callbacks.onShieldBreak();
        break;
      case PowerUpType.laserBeam:
        laserBeams.clear();
        break;
      case PowerUpType.rapidFire:
      case PowerUpType.tripleShot:
        break;
    }
    activePowerUps.remove(type);
  }

  // =========================================================================
  //  COLLISIONS
  // =========================================================================

  void checkCollisions() {
    // --- Bullet vs asteroids/enemies/boss ---
    for (var bullet in bullets) {
      if (!bullet.isVisible) continue;

      for (var asteroid in asteroids) {
        if (!asteroid.isVisible) continue;
        if (bullet.collidesWith(asteroid)) {
          bullet.isVisible = false;
          asteroid.isVisible = false;

          explosionEffects.add(ExplosionEffect(
            x: asteroid.center.dx,
            y: asteroid.center.dy,
            particleCount: 6,
          ));
          callbacks.onExplosion();

          player.registerHit();
          final comboScore = player.calculateScore(10);
          gameState.score += comboScore;
          asteroidsDestroyed++;
          showScorePopup(asteroid.center.dx, asteroid.y, comboScore, player.comboMultiplier);
          tryDropPowerUp(asteroid.center.dx, asteroid.center.dy);
          checkComboFlash();
          break;
        }
      }

      // Bullet vs enemies
      for (var enemy in enemies) {
        if (!bullet.isVisible || !enemy.isVisible) continue;
        if (bullet.collidesWith(enemy)) {
          bullet.isVisible = false;
          final destroyed = enemy.takeDamage(1);

          if (destroyed) {
            player.registerHit();
            final comboScore = player.calculateScore(enemy.scoreValue);
            gameState.score += comboScore;
            asteroidsDestroyed++;

            explosionEffects.add(ExplosionEffect(
              x: enemy.center.dx,
              y: enemy.center.dy,
              particleCount: enemy is HugeSlowAsteroid ? 14 : 8,
            ));
            callbacks.onExplosion();

            showScorePopup(enemy.center.dx, enemy.y, comboScore, player.comboMultiplier);
            checkComboFlash();

            if (enemy is HugeSlowAsteroid) {
              splitHugeAsteroid(enemy);
            }
            tryDropPowerUp(enemy.center.dx, enemy.center.dy);
          } else {
            // Non-lethal hit: spark + small combo nudge
            hitEffects.add(HitEffect(
              x: bullet.x,
              y: bullet.y,
              color: Colors.yellow,
              size: 16,
            ));
            player.registerHit();
            checkComboFlash();
          }
          break;
        }
      }

      // Bullet vs boss
      if (activeBoss != null && activeBoss!.isVisible && bullet.isVisible) {
        if (bullet.collidesWith(activeBoss!)) {
          bullet.isVisible = false;
          final destroyed = activeBoss!.takeDamage(1);
          hitEffects.add(HitEffect(
            x: bullet.x,
            y: bullet.y,
            color: Colors.orange,
            size: 18,
          ));
          if (destroyed) {
            defeatBoss();
          }
        }
      }
    }

    // --- Laser vs asteroids/enemies/boss ---
    for (var laser in laserBeams) {
      if (!laser.isVisible) continue;

      for (var asteroid in asteroids) {
        if (!asteroid.isVisible) continue;
        if (laser.collidesWith(asteroid)) {
          asteroid.isVisible = false;
          tryDropPowerUp(asteroid.center.dx, asteroid.center.dy);
          gameState.score++;
          asteroidsDestroyed++;
        }
      }

      for (var enemy in enemies) {
        if (!enemy.isVisible) continue;
        if (laser.collidesWith(enemy)) {
          if (enemy.takeDamage(1)) {
            gameState.score += enemy.scoreValue;
            asteroidsDestroyed++;
            if (enemy is HugeSlowAsteroid) splitHugeAsteroid(enemy);
            tryDropPowerUp(enemy.center.dx, enemy.center.dy);
          }
        }
      }

      if (activeBoss != null && activeBoss!.isVisible) {
        if (laser.collidesWith(activeBoss!)) {
          if (activeBoss!.takeDamage(1)) {
            defeatBoss();
          }
        }
      }
    }

    // --- Player vs power-ups ---
    for (var powerUp in powerUps) {
      if (!powerUp.isVisible) continue;
      if (player.collidesWith(powerUp)) {
        collectPowerUp(powerUp);
      }
    }

    // --- Player vs asteroids ---
    for (var asteroid in asteroids) {
      if (!asteroid.isVisible) continue;
      if (player.collidesWith(asteroid)) {
        asteroid.isVisible = false;
        handlePlayerHit();
      }
    }

    // --- Player vs enemies ---
    for (var enemy in enemies) {
      if (!enemy.isVisible) continue;
      if (player.collidesWith(enemy)) {
        enemy.isVisible = false;
        handlePlayerHit();
      }
    }

    // --- Player vs boss ---
    if (activeBoss != null && activeBoss!.isVisible) {
      if (player.collidesWith(activeBoss!)) {
        handlePlayerHit();
      }
    }

    // --- Player vs enemy bullets ---
    for (var bullet in enemyBullets) {
      if (!bullet.isVisible) continue;
      if (player.collidesWith(bullet)) {
        bullet.isVisible = false;
        handlePlayerHit();
      }
    }
  }

  void handlePlayerHit() {
    if (hasShield && shieldHitsRemaining > 0) {
      shieldHitsRemaining--;
      if (shieldHitsRemaining <= 0) {
        hasShield = false;
        deactivatePowerUp(PowerUpType.shield);
      }
      callbacks.onHit();
      floatingTexts.add(FloatingText(
        text: 'Shield Hit!',
        x: player.x,
        y: player.y - 30,
        color: Colors.blue,
      ));
    } else {
      player.hit();
      player.resetComboOnDamage();
      callbacks.onHit();
      callbacks.onShake(0.6);
      if (player.lives <= 0) {
        gameOver();
      }
    }
  }

  void gameOver() {
    gameState.isGameOver = true;
    gameState.updateHighScore();
    callbacks.onGameOver();
  }

  // =========================================================================
  //  UI HELPERS
  // =========================================================================

  void showScorePopup(double x, double y, int score, double multiplier) {
    floatingTexts.add(FloatingText(
      text: multiplier > 1.0 ? '+$score (${multiplier.toStringAsFixed(1)}x)' : '+$score',
      x: x - 20,
      y: y - 20,
      color: multiplier > 1.0 ? Colors.yellow : Colors.white,
      lifeTimer: 90,
    ));
  }

  void checkComboFlash() {
    if (previousComboMultiplier == null || player.comboMultiplier > previousComboMultiplier!) {
      callbacks.onComboFlash();
      comboFlashTimer = 60;
    }
    previousComboMultiplier = player.comboMultiplier;
  }

  // =========================================================================
  //  CLEANUP
  // =========================================================================

  void cleanupObjects() {
    // Track misses (bullets that flew off the top without hitting)
    for (var bullet in bullets) {
      if (!bullet.isVisible && bullet.y < -bullet.height) {
        player.registerMiss();
      }
    }

    asteroids.removeWhere((a) => !a.isVisible);
    bullets.removeWhere((b) => !b.isVisible);
    powerUps.removeWhere((p) => !p.isVisible);
    enemies.removeWhere((e) => !e.isVisible);
    enemyBullets.removeWhere((b) => !b.isVisible);
    laserBeams.removeWhere((l) => !l.isVisible);
    floatingTexts.removeWhere((t) => !t.isVisible);
  }

  /// Persist the current high score (called by the screen on dispose/gameover).
  void commitHighScore() {
    gameState.updateHighScore();
  }
}
