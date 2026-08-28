import 'dart:math';
import 'dart:ui' show Offset;
import 'package:flutter/material.dart' show Colors;
import '../config/game_config.dart';
import '../config/score_values.dart';
import '../models/enums.dart';
import '../models/player.dart';
import '../models/asteroids.dart';
import '../models/enemy_ship.dart';
import '../models/swarm_unit.dart';
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

  /// The laser beam power-up just activated — heavy haptic.
  void onLaserActivated();

  /// A boss was just defeated — celebratory haptic.
  void onBossDefeatedHaptic();
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
  @override
  void onLaserActivated() {}
  @override
  void onBossDefeatedHaptic() {}
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
  List<BombBarrel> bombBarrels = [];
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

  // --- Boss sequencing (Boss Rush relies on these; classic ignores) ---
  /// How many bosses have been defeated this run.
  int bossesDefeated = 0;

  /// Frames remaining before the next boss may spawn. Set after each
  /// defeat from `config.bossRespawnDelay` (10s in Boss Rush, 0 in
  /// classic where the kill threshold gates spawns instead).
  int bossRespawnCooldown = 0;

  /// The Swarm Lords encounter: instead of one boss, 10 shielded
  /// SwarmUnits deploy. This counts how many are still alive — while
  /// > 0 the encounter is "the boss" (spawning is paused, and the run's
  /// boss counter advances only when the last unit dies).
  int swarmUnitsAlive = 0;

  // --- Wing drones (wingDrones power-up) ---
  /// x-offset of each drone from the player's center. Two entries =
  /// both drones active; an empty list = none.
  ///
  /// Drones are invulnerable, don't collect anything, and fire rapid
  /// shots regardless of which other power-ups are active.
  List<double> wingDrones = [];

  /// Frame counters for each drone's next shot (parallel to
  /// [wingDrones]).
  List<int> wingDroneShotTimers = [];

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
    bombBarrels.clear();
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
    bossesDefeated = 0;
    bossRespawnCooldown = config.initialBossDelay;
    swarmUnitsAlive = 0;
    wingDrones.clear();
    wingDroneShotTimers.clear();
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

    // The timed wave system only runs in wave-based modes; Boss Rush
    // replaces waves with a boss counter (no breaks, no wave bonuses).
    if (config.wavesEnabled) {
      gameState.updateWaveSystem();
    }

    // Auto-shoot (always, even during wave breaks)
    final currentInterval = config.getShotInterval(gameState, activePowerUps);
    if (frameCount - lastShotFrame >= currentInterval) {
      fireBullet();
      lastShotFrame = frameCount;
    }

    if (!gameState.isWaveBreak) {
      // Spawn normal asteroids (disabled in Boss Rush — bosses only)
      if (config.asteroidsEnabled) {
        final waveSpawnRate = config.getAsteroidSpawnRate(gameState);
        if (frameCount % waveSpawnRate == 0) {
          asteroids.add(Asteroid.random(screenWidth, asteroidSize));
        }
      }

      // Timed random power-up drops (Boss Rush has no asteroids to
      // drop them, so abilities arrive on a random schedule instead).
      if (config.randomPowerUpsEnabled &&
          frameCount % config.getPowerUpSpawnInterval(gameState) == 0) {
        final px = Random().nextDouble() * (screenWidth - GameConfig.powerUpSize);
        powerUps.add(PowerUp.randomWeighted(px, -GameConfig.powerUpSize, config.powerUpWeights));
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

    updateWingDrones();

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
  //  WING DRONES
  // =========================================================================

  /// Drones flank the player (slightly above, offset left/right) and
  /// fire rapid shots on their own cadence. They are invulnerable,
  /// never collect power-ups, and their fire rate is fixed — no other
  /// power-up affects them.
  void updateWingDrones() {
    if (wingDrones.isEmpty) return;

    final playerCenterX = player.x + player.width / 2;

    for (int i = 0; i < wingDrones.length; i++) {
      // Smoothly track the player horizontally (a little lag so the
      // drones feel like companions, not rigid attachments).
      // wingDrones[i] holds the current offset; ease toward the target.
      final target = i == 0 ? -GameConfig.droneOffsetX : GameConfig.droneOffsetX;
      wingDrones[i] += (target - wingDrones[i]) * 0.2;

      // Fire on the drone's own rapid cadence.
      wingDroneShotTimers[i]--;
      if (wingDroneShotTimers[i] <= 0) {
        wingDroneShotTimers[i] = GameConfig.droneShootInterval;
        final dx = playerCenterX + wingDrones[i] - bulletWidth / 2;
        final dy = player.y - bulletHeight + 6; // slightly below the player's nose
        bullets.add(Bullet(
          x: dx,
          y: dy,
          width: bulletWidth,
          height: bulletHeight,
          speedY: bulletSpeed,
          fromDrone: true,
        ));
        muzzleFlashes.add(Flash(
          x: dx,
          y: dy,
          size: bulletWidth * 1.3,
          lifeTimer: 4,
          isUpward: true,
        ));
      }
    }
  }

  /// Screen positions of the active wing drones (for rendering).
  List<Offset> get wingDronePositions {
    final playerCenterX = player.x + player.width / 2;
    return [
      for (final offset in wingDrones)
        Offset(playerCenterX + offset, player.y + 6),
    ];
  }

  // =========================================================================
  //  SHOOTING
  // =========================================================================

  void fireBullet() {
    if (gameState.isPaused || gameState.isGameOver) return;

    // Penta shot wins over triple shot: whichever was collected LAST
    // stays active (activating one cancels the other in
    // activatePowerUp), so a single check suffices here.
    if (config.powerUpsEnabled &&
        activePowerUps.containsKey(PowerUpType.pentaShot) &&
        activePowerUps[PowerUpType.pentaShot]!.isActive) {
      firePentaShot();
    } else if (config.powerUpsEnabled &&
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

  /// Penta shot: 5 bullets in a "^" formation ALL traveling straight up
  /// at the same speed — the center bullet is the highest point (the
  /// tip) and two level pairs sit progressively lower beside it, like a
  /// caret pointing up. Zero horizontal velocity, so the formation
  /// stays locked together as one clustered wall all the way up.
  /// The cadence is slower (see GameModeConfig's shared
  /// getShotInterval); rapid fire stacks to speed it back up.
  void firePentaShot() {
    final centerX = player.x + player.width / 2 - bulletWidth / 2;
    final muzzleY = player.y - bulletHeight;
    const horizontalGap = 12.0; // side spacing between formation columns
    const verticalGap = 10.0; // row height of each "^" step

    // (dx, rows below the tip) per bullet: tip leads at the top, then
    // the two level pairs stagger down — the caret's shoulders.
    // Screen y grows DOWNWARD, so larger yOffset = lower on screen.
    final formation = <List<double>>[
      [0, 0], //   tip — highest, leads the cluster
      [-horizontalGap, verticalGap], // pair 1 left (one row below tip)
      [horizontalGap, verticalGap], // pair 1 right
      [-horizontalGap * 2, verticalGap * 2], // pair 2 left (two rows below)
      [horizontalGap * 2, verticalGap * 2], // pair 2 right
    ];

    for (final pos in formation) {
      bullets.add(Bullet(
        x: centerX + pos[0],
        y: muzzleY + pos[1],
        width: bulletWidth,
        height: bulletHeight,
        speedY: bulletSpeed,
        speedX: 0, // straight up — the formation never spreads
      ));
    }
    muzzleFlashes.add(Flash(
      x: centerX,
      y: muzzleY,
      size: bulletWidth * 2.4,
      lifeTimer: 6,
      isUpward: true,
    ));
    callbacks.onShoot();
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
      if (enemy is SwarmUnit && enemy.shouldShoot()) {
        _fireSwarmUnitBullet(enemy);
      }
    }

    for (var bullet in enemyBullets) {
      bullet.update(screenHeight);
    }

    // Bomb barrels (Demolition Titan): fall until they reach the
    // player's level, then detonate in a blast radius — or detonate
    // early on player contact.
    for (var barrel in bombBarrels) {
      barrel.update(screenHeight);
      if (!barrel.isVisible) continue;
      if (barrel.shouldExplode || player.collidesWith(barrel)) {
        _explodeBarrel(barrel);
      }
    }

    if (activeBoss != null) {
      activeBoss!.update(screenHeight, screenWidth);

      // Per-frame attack state for the two stateful variants.
      switch (activeBoss!.bossType) {
        case BossType.shieldedBurst:
          _tickBossBurst();
          break;
        case BossType.laserCannon:
          _tickBossLaser();
          break;
        default:
          break;
      }

      if (activeBoss!.shouldShoot()) {
        fireBossAttack();
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

  /// Swarm unit attack: one bullet aimed directly at the player.
  void _fireSwarmUnitBullet(SwarmUnit unit) {
    final mx = unit.x + unit.width / 2;
    final my = unit.y + unit.height;
    final dx = (player.x + player.width / 2) - mx;
    final dy = (player.y + player.height / 2) - my;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final speed = GameConfig.swarmUnitBulletSpeed;
    enemyBullets.add(EnemyBullet(
      x: mx - 5,
      y: my,
      width: 10,
      height: 15,
      speedY: (dy / len) * speed,
      speedX: (dx / len) * speed,
    ));
  }

  /// Bottom-center of the boss hull — where its shots originate.
  double get _bossMuzzleX => activeBoss!.x + activeBoss!.width / 2;
  double get _bossMuzzleY => activeBoss!.y + activeBoss!.height;

  /// Dispatch the active boss's attack pattern by variant.
  void fireBossAttack() {
    if (activeBoss == null) return;
    switch (activeBoss!.bossType) {
      case BossType.triBeam:
        _fireTriBeam();
        break;
      case BossType.rapidFire:
        _fireRapidShot();
        break;
      case BossType.pentaBeam:
        _firePentaBeam();
        break;
      case BossType.marksman:
        _fireAimedShot();
        break;
      case BossType.shieldedBurst:
        _startBossBurst();
        break;
      case BossType.laserCannon:
        _startBossLaserCharge();
        break;
      case BossType.bombardier:
        _fireBombBarrels();
        break;
      case BossType.serpentVolley:
        _fireSerpentVolley();
        break;
      case BossType.swarm:
        break; // units fire individually via _fireSwarmUnitBullet
    }
  }

  /// 3-way spread — the original dreadnought pattern.
  void _fireTriBeam() {
    for (int i = -1; i <= 1; i++) {
      final angle = i * 20 * (pi / 180);
      enemyBullets.add(EnemyBullet(
        x: _bossMuzzleX - 5,
        y: _bossMuzzleY,
        width: 10,
        height: 15,
        speedY: cos(angle) * GameConfig.bossBulletSpeed,
        speedX: sin(angle) * GameConfig.bossBulletSpeed,
      ));
    }
  }

  /// 5-way spread from the penta-beam variant.
  void _firePentaBeam() {
    for (int i = -2; i <= 2; i++) {
      final angle = i * 18 * (pi / 180);
      enemyBullets.add(EnemyBullet(
        x: _bossMuzzleX - 5,
        y: _bossMuzzleY,
        width: 10,
        height: 15,
        speedY: cos(angle) * GameConfig.bossBulletSpeed,
        speedX: sin(angle) * GameConfig.bossBulletSpeed,
      ));
    }
  }

  /// Single fast bullet straight down — the rapid-fire hose compensates
  /// volume with a higher speed so it can't be ignored.
  void _fireRapidShot() {
    enemyBullets.add(EnemyBullet(
      x: _bossMuzzleX - 5,
      y: _bossMuzzleY,
      width: 10,
      height: 15,
      speedY: GameConfig.bossBulletSpeed * 1.3,
    ));
  }

  /// Single shot aimed directly at the player — the escort carrier's
  /// precision attack (its minions supply the spread pressure).
  void _fireAimedShot() {
    final dx = (player.x + player.width / 2) - _bossMuzzleX;
    final dy = (player.y + player.height / 2) - _bossMuzzleY;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return; // avoid division by ~0 when overlapping
    enemyBullets.add(EnemyBullet(
      x: _bossMuzzleX - 5,
      y: _bossMuzzleY,
      width: 10,
      height: 15,
      speedY: (dy / len) * GameConfig.bossBulletSpeed,
      speedX: (dx / len) * GameConfig.bossBulletSpeed,
    ));
  }

  /// Start the Bulwark Sentinel's burst: lock the aim line at the
  /// player, then fire 10 bullets along it (one every few frames) so
  /// the stream travels as a single dodgeable line.
  void _startBossBurst() {
    final boss = activeBoss!;
    final dx = (player.x + player.width / 2) - _bossMuzzleX;
    final dy = (player.y + player.height / 2) - _bossMuzzleY;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) {
      boss.burstDirX = 0;
      boss.burstDirY = 1;
    } else {
      boss.burstDirX = dx / len;
      boss.burstDirY = dy / len;
    }
    boss.burstShotsRemaining = GameConfig.bossBurstBulletCount;
    boss.burstNextShotFrame = frameCount + 6;
  }

  /// Emit one bullet of the pending burst, all sharing the locked aim
  /// direction so the string travels as a single dodgeable line.
  void _tickBossBurst() {
    final boss = activeBoss!;
    if (boss.burstShotsRemaining <= 0 || frameCount < boss.burstNextShotFrame) {
      return;
    }
    final speed = GameConfig.bossBulletSpeed * 1.2;
    enemyBullets.add(EnemyBullet(
      x: _bossMuzzleX - 5,
      y: _bossMuzzleY,
      width: 10,
      height: 15,
      speedY: boss.burstDirY * speed,
      speedX: boss.burstDirX * speed,
    ));
    boss.burstShotsRemaining--;
    boss.burstNextShotFrame = frameCount + GameConfig.bossBurstBulletInterval;
  }

  /// Begin the Void Lancer's laser cycle: 1s charge telegraph, then the
  /// beam. The boss freezes in place for the whole sequence.
  void _startBossLaserCharge() {
    final boss = activeBoss!;
    if (boss.laserPhase != BossLaserPhase.idle) return;
    boss.laserPhase = BossLaserPhase.charging;
    boss.laserTimer = GameConfig.bossLaserChargeDuration;
    callbacks.onShake(0.3); // warning rumble
  }

  /// Detect the charge->fire transition and shake the screen when the
  /// beam goes live. Player collision is checked in [checkCollisions].
  void _tickBossLaser() {
    final boss = activeBoss!;
    if (boss.laserPhase == BossLaserPhase.firing &&
        boss.laserTimer == GameConfig.bossLaserFireDuration) {
      callbacks.onShake(0.7);
    }
  }

  /// Chip the boss's shield. On the breaking hit, a cyan flash + shake
  /// makes the shield-down moment read clearly.
  void _damageBossShield(double x, double y) {
    activeBoss!.damageShield(1);
    hitEffects.add(HitEffect(x: x, y: y, color: Colors.cyan, size: 20));
    callbacks.onHit();
    if (!activeBoss!.hasShield) {
      explosionEffects.add(ExplosionEffect(
        x: activeBoss!.x + activeBoss!.width / 2,
        y: activeBoss!.y + activeBoss!.height / 4,
        particleCount: 16,
        duration: 50,
        colors: [Colors.cyan, Colors.white, Colors.lightBlue],
      ));
      callbacks.onShake(0.8);
      floatingTexts.add(FloatingText(
        text: 'SHIELD DOWN!',
        x: screenWidth / 2 - 80,
        y: screenHeight / 3,
        color: Colors.cyan,
        lifeTimer: 120,
        fontSize: 20,
      ));
    }
  }

  /// Demolition Titan: drop 2 bomb barrels per volley — one from each
  /// wing bay. Barrels fall until they reach the player's level, then
  /// detonate there, so the blast is always a threat to dodge.
  void _fireBombBarrels() {
    final boss = activeBoss!;
    final random = Random();
    for (int i = 0; i < GameConfig.bombardierBarrelsPerVolley; i++) {
      final bayX = i == 0
          ? boss.x + boss.width * 0.28
          : boss.x + boss.width * 0.72;
      // Detonate at the player's level (with slight per-barrel jitter
      // so the two blasts don't always land at exactly the same line).
      final jitter = (random.nextDouble() - 0.5) * 40;
      final targetY = (player.y + jitter).clamp(boss.y + boss.height + 120.0, screenHeight - 40);
      bombBarrels.add(BombBarrel(
        x: bayX - GameConfig.bombBarrelWidth / 2,
        y: boss.y + boss.height,
        detonationY: targetY,
      ));
    }
  }

  /// Detonate a bomb barrel: blast visual + shake, and damage the
  /// player if they're inside the blast radius. The shield absorbs the
  /// blast; otherwise the player loses one life.
  void _explodeBarrel(BombBarrel barrel) {
    barrel.isVisible = false;

    final blastX = barrel.x + barrel.width / 2;
    final blastY = barrel.y + barrel.height / 2;
    final radius = GameConfig.bombExplosionRadius;

    // Big orange blast + shockwave ring + shake.
    explosionEffects.add(ExplosionEffect(
      x: blastX,
      y: blastY,
      particleCount: 18,
      duration: 55,
      colors: [Colors.orange, Colors.red, Colors.yellow, Colors.deepOrange],
    ));
    hitEffects.add(HitEffect(
      x: blastX,
      y: blastY,
      color: Colors.orange,
      size: radius, // expanding glow approximates the blast radius
    ));
    callbacks.onExplosion();
    callbacks.onShake(0.5);

    // Damage the player if within the blast radius.
    final px = player.x + player.width / 2;
    final py = player.y + player.height / 2;
    final dist = sqrt((px - blastX) * (px - blastX) + (py - blastY) * (py - blastY));
    if (dist <= radius) {
      handlePlayerHit();
    }
  }

  /// Serpent Volley: 7 bullets in a V formation, all moving straight
  /// down at the same speed. The center bullet is lowest (reaches the
  /// player first) and each symmetric pair above it is level with its
  /// partner — so the wall snakes toward the player instead of arriving
  /// as one flat line. Horizontal offsets spread the V across the
  /// muzzle so the bullets never stack into a single column.
  void _fireSerpentVolley() {
    final count = GameConfig.serpentBulletCount;
    final verticalGap = GameConfig.serpentBulletGap;
    const horizontalGap = 24.0;
    final speed = GameConfig.serpentBulletSpeed;

    for (int i = 0; i < count; i++) {
      // Rows above the center bullet: 3,2,1,0,1,2,3 for 7 bullets —
      // bullet 4 lowest, bullets 1/7 highest, exactly per the spec.
      final rowFromCenter = (i - count ~/ 2).abs();
      enemyBullets.add(EnemyBullet(
        x: _bossMuzzleX - 5 + (i - count ~/ 2) * horizontalGap,
        y: _bossMuzzleY - rowFromCenter * verticalGap,
        width: 10,
        height: 15,
        speedY: speed,
      ));
    }
  }

  /// The Void Lancer's beam: instantly lethal through lives AND
  /// invulnerability — only an active shield saves the player.
  void _hitPlayerWithBossLaser() {
    if (hasShield && shieldHitsRemaining > 0) {
      hasShield = false;
      shieldHitsRemaining = 0;
      deactivatePowerUp(PowerUpType.shield);
      // Grace period so the rest of the beam doesn't kill immediately.
      player.isInvulnerable = true;
      player.invulnerabilityTimer = GameConfig.invulnerabilityFrames;
      callbacks.onHit();
      callbacks.onShake(0.8);
      floatingTexts.add(FloatingText(
        text: 'SHIELD ABSORBED IT!',
        x: player.x - 40,
        y: player.y - 30,
        color: Colors.blue,
        lifeTimer: 120,
        fontSize: 16,
      ));
    } else {
      player.lives = 0;
      callbacks.onHit();
      callbacks.onShake(1.0);
      gameOver();
    }
  }

  void spawnEnemies() {
    // --- Boss spawn check (with per-mode respawn cooldown) ---
    // The Swarm Lords encounter counts as an active boss while any of
    // its units live.
    final bossEncounterActive = activeBoss != null || swarmUnitsAlive > 0;
    if (!bossEncounterActive) {
      if (bossRespawnCooldown > 0) {
        bossRespawnCooldown--;
      } else if (config.shouldSpawnBoss(gameState, asteroidsDestroyed)) {
        spawnBoss();
        return;
      }
    }
    if (bossEncounterActive) return; // pause other enemy spawns during boss

    // Probability-table enemies (disabled in Boss Rush — its only
    // minions are the escort carrier's, spawned directly in spawnBoss).
    if (!config.specialEnemiesEnabled) return;

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
    // The mode decides which boss spawns (classic: the original tri-beam
    // dreadnought; Boss Rush: a random variant).
    activeBoss = config.createBoss(bossesDefeated, screenWidth, GameConfig.bossSize);

    // In Boss Rush the boss counter replaces the wave number, so the HUD
    // badge reads "Boss Rush · Boss N".
    if (!config.wavesEnabled) {
      gameState.currentWave = bossesDefeated + 1;
    }

    // Classic keeps its original announcement; Boss Rush names the variant.
    final announce = config.wavesEnabled
        ? 'BOSS INCOMING!'
        : '${activeBoss!.displayName}!';
    floatingTexts.add(FloatingText(
      text: announce,
      x: screenWidth / 2 - 100,
      y: screenHeight / 2,
      color: Colors.red,
      lifeTimer: 180,
      fontSize: 22,
    ));

    // The escort carrier (marksman) arrives with 3 enemy-fighter
    // minions that each fire single shots — the same fighters players
    // face in Classic Run.
    if (activeBoss!.bossType == BossType.marksman) {
      for (int i = 0; i < GameConfig.marksmanMinionCount; i++) {
        enemies.add(EnemyShip.random(screenWidth, GameConfig.enemyShipSize));
      }
    }

    // The Swarm Lords: no single hull — 10 small shielded units deploy
    // in two staggered rows and the marker Boss is discarded. The run's
    // boss counter still reads "Boss N" via currentWave (set above).
    if (activeBoss!.bossType == BossType.swarm) {
      _deploySwarm();
      activeBoss = null;
    }

    asteroidsDestroyed = 0;
    callbacks.onBossIncoming();
  }

  /// Deploy the Swarm Lords: 10 small units in two offset rows (a
  /// beehive arrangement), each with its own patrol direction, bob
  /// phase, and staggered fire cadence so their shots don't sync up.
  void _deploySwarm() {
    final random = Random();
    const perRow = 5;
    final usableWidth = screenWidth - GameConfig.swarmUnitSize - 20;
    final columnGap = usableWidth / (perRow + 1);

    for (int i = 0; i < GameConfig.swarmUnitCount; i++) {
      final row = i ~/ perRow; // 0 top, 1 bottom (offset by half a column)
      final col = i % perRow;
      final x = 10 + columnGap * (col + 1 + (row == 1 ? 0.5 : 0));
      enemies.add(SwarmUnit(
        x: x.clamp(0.0, screenWidth - GameConfig.swarmUnitSize),
        y: -GameConfig.swarmUnitSize - (row == 0 ? 40 : 0), // top row enters first
        speedX: (random.nextBool() ? 1 : -1) *
            (GameConfig.swarmUnitSpeed * (0.7 + random.nextDouble() * 0.6)),
        hoverY: GameConfig.swarmHoverY + row * 55,
        shootInterval: GameConfig.swarmUnitShootInterval - random.nextInt(50),
        phase: random.nextDouble() * 2 * pi,
      ));
    }
    swarmUnitsAlive = GameConfig.swarmUnitCount;
  }

  /// Called when a swarm unit dies — awards its astrids and ends the
  /// encounter (advancing the boss counter) when the last one falls.
  void _onSwarmUnitDestroyed(SwarmUnit unit) {
    swarmUnitsAlive--;
    if (swarmUnitsAlive > 0) {
      floatingTexts.add(FloatingText(
        text: '${swarmUnitsAlive} LEFT',
        x: unit.x - 10,
        y: unit.y - 10,
        color: Colors.deepOrange,
        lifeTimer: 60,
        fontSize: 14,
      ));
      return;
    }

    // Last unit down = the "boss" is defeated.
    gameState.score += ScoreValues.bossSwarm;
    bossesDefeated++;
    bossRespawnCooldown = config.bossRespawnDelay;
    callbacks.onBossDefeatedHaptic();
    callbacks.onShake(1.0);

    // Drop power-ups from the screen center (no single hull position).
    for (int i = 0; i < GameConfig.bossPowerUpDropCount; i++) {
      powerUps.add(PowerUp.randomWeighted(
        screenWidth / 2 + (i * 40 - 20),
        screenHeight / 3,
        config.powerUpWeights,
      ));
    }

    floatingTexts.add(FloatingText(
      text: 'SWARM DEFEATED!',
      x: screenWidth / 2 - 90,
      y: screenHeight / 2,
      color: Colors.yellow,
      lifeTimer: 180,
      fontSize: 22,
    ));
  }

  void defeatBoss() {
    if (activeBoss == null) return;

    gameState.score += activeBoss!.scoreValue;
    bossesDefeated++;
    bossRespawnCooldown = config.bossRespawnDelay;
    callbacks.onBossDefeatedHaptic();

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
      powerUps.add(PowerUp.randomWeighted(
        activeBoss!.x + activeBoss!.width / 2 + (i * 30 - 15),
        activeBoss!.y + activeBoss!.height / 2,
        config.powerUpWeights,
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
      powerUps.add(PowerUp.randomWeighted(x, y, config.powerUpWeights));
    }
  }

  void _maybeDropWaveBreakBonus() {
    final random = Random();
    if (random.nextDouble() < GameConfig.waveBreakBonusDropChance) {
      powerUps.add(PowerUp.randomWeighted(
        screenWidth / 2 - GameConfig.powerUpSize / 2,
        screenHeight / 2 - 100,
        config.powerUpWeights,
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
      case PowerUpType.pentaShot:
        // Penta and triple are alternative fire modes — collecting one
        // cancels the other so the LAST equipped ability stays active.
        deactivatePowerUp(PowerUpType.tripleShot);
        break;
      case PowerUpType.tripleShot:
        deactivatePowerUp(PowerUpType.pentaShot);
        break;
      case PowerUpType.rapidFire:
        break; // handled in getShotInterval
      case PowerUpType.laserBeam:
        laserBeams.add(LaserBeam(
          x: player.x + player.width / 2 - 4,
          y: 0,
          height: player.y,
        ));
        callbacks.onLaserActivated();
        break;
      case PowerUpType.wingDrones:
        // Deploy the two companion ships (staggered entry: they fly in
        // from the player's position outward).
        wingDrones
          ..clear()
          ..addAll([0.0, 0.0]);
        wingDroneShotTimers
          ..clear()
          ..addAll([GameConfig.droneShootInterval, GameConfig.droneShootInterval ~/ 2]);
        break;
    }
  }

  void deactivatePowerUp(PowerUpType type) {
    if (type != PowerUpType.shield && !activePowerUps.containsKey(type)) return;
    switch (type) {
      case PowerUpType.shield:
        hasShield = false;
        shieldHitsRemaining = 0;
        callbacks.onShieldBreak();
        break;
      case PowerUpType.laserBeam:
        laserBeams.clear();
        break;
      case PowerUpType.wingDrones:
        wingDrones.clear();
        wingDroneShotTimers.clear();
        break;
      case PowerUpType.rapidFire:
      case PowerUpType.tripleShot:
      case PowerUpType.pentaShot:
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

          // Swarm units carry their own shields — absorb hits first.
          if (enemy is SwarmUnit && enemy.hasShield) {
            enemy.damageShield(1);
            hitEffects.add(HitEffect(
              x: bullet.x,
              y: bullet.y,
              color: Colors.cyan,
              size: 14,
            ));
            callbacks.onHit();
            break;
          }

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
            if (enemy is SwarmUnit) {
              _onSwarmUnitDestroyed(enemy);
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

      // Bullet vs boss (shielded variants absorb hits until the dome breaks)
      if (activeBoss != null && activeBoss!.isVisible && bullet.isVisible) {
        if (bullet.collidesWith(activeBoss!)) {
          bullet.isVisible = false;
          if (activeBoss!.hasShield) {
            _damageBossShield(bullet.x, bullet.y);
          } else {
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
          // Swarm shields absorb the laser too — but it melts them fast
          // (one frame per hit, so a pass strips shields then hulls).
          if (enemy is SwarmUnit && enemy.hasShield) {
            enemy.damageShield(1);
            continue;
          }
          if (enemy.takeDamage(1)) {
            gameState.score += enemy.scoreValue;
            asteroidsDestroyed++;
            if (enemy is HugeSlowAsteroid) splitHugeAsteroid(enemy);
            if (enemy is SwarmUnit) _onSwarmUnitDestroyed(enemy);
            tryDropPowerUp(enemy.center.dx, enemy.center.dy);
          }
        }
      }

      if (activeBoss != null && activeBoss!.isVisible) {
        if (laser.collidesWith(activeBoss!)) {
          if (activeBoss!.hasShield) {
            _damageBossShield(laser.x, activeBoss!.y + activeBoss!.height / 2);
          } else if (activeBoss!.takeDamage(1)) {
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

    // --- Player vs boss laser beam (Void Lancer) ---
    // A vertical instant-kill column under the boss while it fires.
    if (activeBoss != null && activeBoss!.laserPhase == BossLaserPhase.firing) {
      final beamCenter = activeBoss!.x + activeBoss!.width / 2;
      final halfBeam = GameConfig.bossLaserWidth / 2;
      final beamTop = activeBoss!.y + activeBoss!.height;
      if (player.x < beamCenter + halfBeam &&
          player.x + player.width > beamCenter - halfBeam &&
          player.y + player.height > beamTop) {
        _hitPlayerWithBossLaser();
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
    // Track misses (bullets that flew off the top without hitting).
    // Wing-drone bullets never touch the player's combo streak.
    for (var bullet in bullets) {
      if (!bullet.isVisible && bullet.y < -bullet.height && !bullet.fromDrone) {
        player.registerMiss();
      }
    }

    asteroids.removeWhere((a) => !a.isVisible);
    bullets.removeWhere((b) => !b.isVisible);
    powerUps.removeWhere((p) => !p.isVisible);
    enemies.removeWhere((e) => !e.isVisible);
    enemyBullets.removeWhere((b) => !b.isVisible);
    bombBarrels.removeWhere((b) => !b.isVisible);
    laserBeams.removeWhere((l) => !l.isVisible);
    floatingTexts.removeWhere((t) => !t.isVisible);
  }

  /// Persist the current high score (called by the screen on dispose/gameover).
  void commitHighScore() {
    gameState.updateHighScore();
  }
}
