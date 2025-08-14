import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/game_models.dart';
import '../services/score_service.dart';

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  
  const GameScreen({Key? key, this.gameMode = GameMode.survival}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game objects
  late Player player;
  List<Asteroid> asteroids = [];
  List<Bullet> bullets = [];
  
  // Game state
  late GameState gameState;
  
  // Game settings
  final double playerSize = 50;
  final double asteroidSize = 40;
  final double bulletWidth = 10;
  final double bulletHeight = 20;
  final double bulletSpeed = 10;
  
  // Auto-shooting settings
  int lastShotFrame = 0;
  final int shotInterval = 15; // Fire bullet every 15 frames (about 4 shots per second)
  
  // Game timing
  late Timer gameTimer;
  int frameCount = 0;
  int asteroidSpawnRate = 60; // New asteroid every 60 frames (about 1 second at 60fps)
  
  // Screen dimensions
  late double screenWidth;
  late double screenHeight;
  
  // Touch control
  double? touchX;
  
  // Animation controllers for visual effects
  late AnimationController _shakeController;
  late AnimationController _comboFlashController;
  
  // Power-up system (only for Survival mode) - now stackable
  List<PowerUp> powerUps = [];
  Map<PowerUpType, ActivePowerUp> activePowerUps = {};
  List<LaserBeam> laserBeams = [];
  List<FloatingText> floatingTexts = [];
  bool hasShield = false;
  int shieldHitsRemaining = 0;
  
  // Combo system
  double? _previousComboMultiplier;
  int _comboFlashTimer = 0;
  
  // New enemy system
  List<Enemy> enemies = [];
  List<EnemyBullet> enemyBullets = [];
  BossUFO? activeBoss;
  int asteroidsDestroyed = 0;
  
  // Particle and effect systems
  List<ExplosionEffect> explosionEffects = [];
  List<HitEffect> hitEffects = [];
  
  @override
  void initState() {
    super.initState();
    
    // Set preferred orientations to portrait only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Initialize shake animation controller
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Initialize combo flash animation controller
    _comboFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Initialize game state
    gameState = GameState();
    
    // Initialize screen dimensions with default values
    // These will be updated in the build method
    screenWidth = 400; // Default width
    screenHeight = 600; // Default height
    
    // Initialize player with default position
    // This will be updated in the _initializeGame method
    player = Player(
      x: 175,
      y: 530,
      width: playerSize,
      height: playerSize,
    );
    
    // Load high score and initialize game
    _loadHighScore().then((_) {
      _initializeGame();
    });
  }
  
  @override
  void dispose() {
    gameTimer.cancel();
    _shakeController.dispose();
    _comboFlashController.dispose();
    
    // Reset orientation settings
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }
  
  // Load high score from persistent storage
  Future<void> _loadHighScore() async {
    final highScore = await ScoreService.getHighScore();
    setState(() {
      gameState.highScore = highScore;
    });
  }
  
  // Initialize or reset the game
  void _initializeGame() {
    // Reset game state if needed
    if (gameState.isGameOver) {
      gameState.reset();
    }
    
    // Initialize screen dimensions - will be properly set in build method
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    
    // Initialize player at bottom center of screen with safe positioning
    // Use 80 pixels from bottom to ensure visibility on all devices
    player = Player(
      x: screenWidth / 2 - playerSize / 2,
      y: screenHeight - playerSize - 80,
      width: playerSize,
      height: playerSize,
    );
    
    // Clear game objects
    asteroids.clear();
    bullets.clear();
    
    // Clear power-up objects and enemies
    powerUps.clear();
    laserBeams.clear();
    floatingTexts.clear();
    activePowerUps.clear();
    hasShield = false;
    shieldHitsRemaining = 0;
    
    // Clear new enemy system
    enemies.clear();
    enemyBullets.clear();
    activeBoss = null;
    asteroidsDestroyed = 0;
    
    // Clear particle effects
    explosionEffects.clear();
    hitEffects.clear();
    
    // Reset frame counter
    frameCount = 0;
    asteroidSpawnRate = 60;
    
    // Start game loop
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
  }
  
  // Main game loop
  void _gameLoop(Timer timer) {
    if (gameState.isPaused || gameState.isGameOver) return;
    
    // Update frame counter
    frameCount++;
    
    // Update wave system
    gameState.updateWaveSystem();
    
    // Check if wave break is active - limit game activity during breaks
    if (!gameState.isWaveBreak) {
      // Auto-shoot bullets at regular intervals
      final currentInterval = widget.gameMode == GameMode.survival ? _getCurrentShotInterval() : shotInterval;
      if (frameCount - lastShotFrame >= currentInterval) {
        _fireBullet();
        lastShotFrame = frameCount;
      }
      
      // Spawn new asteroid at regular intervals (adjusted for wave system)
      final waveSpawnRate = _getWaveAdjustedSpawnRate();
      if (frameCount % waveSpawnRate == 0) {
        asteroids.add(Asteroid.random(screenWidth, asteroidSize));
      }
      
      // Update power-ups and enemies
      _updatePowerUps();
      _updateEnemies();
      _spawnEnemies();
    } else {
      // During wave break, still update existing objects but don't spawn new ones
      _updatePowerUps();
      _updateEnemies();
      
      // 20% chance of free power-up drop during wave break (once per break)
      if (gameState.waveBreakTimer == GameState.waveBreakDuration - 60) { // 1 second into break
        final random = Random();
        if (random.nextDouble() < 0.20) { // 20% chance
          final powerUp = PowerUp.random(
            screenWidth / 2 - 15, // Center of screen
            screenHeight / 2 - 100, // Above center
          );
          powerUps.add(powerUp);
          
          // Show bonus power-up text
          final text = FloatingText(
            text: 'Bonus Power-Up!',
            x: screenWidth / 2 - 60,
            y: screenHeight / 2 - 150,
            color: Colors.cyan,
            lifeTimer: 180,
          );
          floatingTexts.add(text);
        }
      }
    }
    
    // Update player (always active)
    player.update();
    
    // Update asteroids
    for (var asteroid in asteroids) {
      asteroid.update(screenHeight);
    }
    
    // Update bullets
    for (var bullet in bullets) {
      bullet.update(screenWidth);
    }
    
    // Check for collisions
    _checkCollisions();
    
    // Clean up invisible objects
    _cleanupObjects();
    
  // Update UI
    setState(() {});
    
    // Update combo flash timer
    if (_comboFlashTimer > 0) {
      _comboFlashTimer--;
    }
  }
  
  // Check for collisions between game objects
  void _checkCollisions() {
    // Check bullet-asteroid collisions
    for (var bullet in bullets) {
      if (!bullet.isVisible) continue;
      
      for (var asteroid in asteroids) {
        if (!asteroid.isVisible) continue;
        
        if (bullet.collidesWith(asteroid)) {
          // Mark both objects as invisible
          bullet.isVisible = false;
          asteroid.isVisible = false;
          
          // Create explosion effect
          explosionEffects.add(ExplosionEffect(
            x: asteroid.x + asteroid.width / 2,
            y: asteroid.y + asteroid.height / 2,
            particleCount: 6,
          ));
          
          // Register hit for combo system
          player.registerHit();
          
          // Calculate score with combo multiplier
          final baseScore = 10; // Normal asteroid: 10 points
          final comboScore = player.calculateScore(baseScore);
          gameState.score += comboScore;
          asteroidsDestroyed++;
          
          // Show score popup
          _showScorePopup(asteroid.x + asteroid.width / 2, asteroid.y, comboScore, player.comboMultiplier);
          
          // Try to drop power-up (5% chance)
          _tryDropPowerUp(asteroid.x + asteroid.width / 2, asteroid.y + asteroid.height / 2);
          
          // Check for combo flash animation
          _checkComboFlash();
        }
      }
      
      // Check bullet-enemy collisions
      for (var enemy in enemies) {
        if (!enemy.isVisible) continue;
        
        if (bullet.collidesWith(enemy)) {
          bullet.isVisible = false;
          
          if (enemy.takeDamage(1)) {
            // Register hit for combo system
            player.registerHit();
            
            // Calculate score with combo multiplier
            final comboScore = player.calculateScore(enemy.scoreValue);
            gameState.score += comboScore;
            asteroidsDestroyed++;
            
            // Show score popup
            _showScorePopup(enemy.x + enemy.width / 2, enemy.y, comboScore, player.comboMultiplier);
            
            // Check for combo flash animation
            _checkComboFlash();
            
            // Handle huge asteroid splitting
            if (enemy is HugeSlowAsteroid) {
              _splitHugeAsteroid(enemy);
            }
            
            // Try to drop power-up
            _tryDropPowerUp(enemy.x + enemy.width / 2, enemy.y + enemy.height / 2);
          }
        }
      }
      
      // Check bullet-boss collisions
      if (activeBoss != null && activeBoss!.isVisible) {
        if (bullet.collidesWith(activeBoss!)) {
          bullet.isVisible = false;
          activeBoss!.takeDamage(1);
          
          if (!activeBoss!.isVisible) {
            _defeatBoss();
          }
        }
      }
    }
    
    // Check laser-asteroid collisions
    for (var laser in laserBeams) {
      if (!laser.isVisible) continue;
      
      for (var asteroid in asteroids) {
        if (!asteroid.isVisible) continue;
        
        if (laser.collidesWith(asteroid)) {
          // Mark asteroid as invisible
          asteroid.isVisible = false;
          
          // Try to drop power-up
          _tryDropPowerUp(asteroid.x + asteroid.width / 2, asteroid.y + asteroid.height / 2);
          
          // Increase score and asteroids destroyed counter
          gameState.score++;
          asteroidsDestroyed++;
        }
      }
      
      // Check laser-enemy collisions
      for (var enemy in enemies) {
        if (!enemy.isVisible) continue;
        
        if (laser.collidesWith(enemy)) {
          if (enemy.takeDamage(1)) {
            // Enemy destroyed
            gameState.score += enemy.scoreValue;
            asteroidsDestroyed++;
            
            // Handle huge asteroid splitting
            if (enemy is HugeSlowAsteroid) {
              _splitHugeAsteroid(enemy);
            }
            
            // Try to drop power-up
            _tryDropPowerUp(enemy.x + enemy.width / 2, enemy.y + enemy.height / 2);
          }
        }
      }
      
      // Check laser-boss collisions
      if (activeBoss != null && activeBoss!.isVisible) {
        if (laser.collidesWith(activeBoss!)) {
          activeBoss!.takeDamage(1);
          
          if (!activeBoss!.isVisible) {
            _defeatBoss();
          }
        }
      }
    }
    
    // Check player-power-up collisions
    for (var powerUp in powerUps) {
      if (!powerUp.isVisible) continue;
      
      if (player.collidesWith(powerUp)) {
        _collectPowerUp(powerUp);
      }
    }
    
    // Check player-asteroid collisions
    for (var asteroid in asteroids) {
      if (!asteroid.isVisible) continue;
      
      if (player.collidesWith(asteroid)) {
        asteroid.isVisible = false;
        _handlePlayerHit();
      }
    }
    
    // Check player-enemy collisions
    for (var enemy in enemies) {
      if (!enemy.isVisible) continue;
      
      if (player.collidesWith(enemy)) {
        enemy.isVisible = false;
        _handlePlayerHit();
      }
    }
    
    // Check player-boss collisions
    if (activeBoss != null && activeBoss!.isVisible) {
      if (player.collidesWith(activeBoss!)) {
        _handlePlayerHit();
      }
    }
    
    // Check player-enemy bullet collisions
    for (var bullet in enemyBullets) {
      if (!bullet.isVisible) continue;
      
      if (player.collidesWith(bullet)) {
        bullet.isVisible = false;
        _handlePlayerHit();
      }
    }
  }
  
  // Clean up invisible objects
  void _cleanupObjects() {
    // Track bullets that go off screen without hitting anything (misses)
    final bulletsToRemove = <Bullet>[];
    for (var bullet in bullets) {
      if (!bullet.isVisible) {
        if (bullet.y < -bullet.height) {
          // Bullet went off top of screen - this is a miss
          player.registerMiss();
        }
        bulletsToRemove.add(bullet);
      }
    }
    
    // Remove invisible objects safely
    asteroids.removeWhere((asteroid) => !asteroid.isVisible);
    bullets.removeWhere((bullet) => !bullet.isVisible);
    
    // Clean up power-up and enemy objects
    powerUps.removeWhere((powerUp) => !powerUp.isVisible);
    enemies.removeWhere((enemy) => !enemy.isVisible);
    enemyBullets.removeWhere((bullet) => !bullet.isVisible);
    laserBeams.removeWhere((laser) => !laser.isVisible);
    floatingTexts.removeWhere((text) => !text.isVisible);
  }
  
  // Handle game over
  void _gameOver() {
    gameState.isGameOver = true;
    gameState.updateHighScore();
    ScoreService.saveHighScore(gameState.highScore);
  }
  
  // Fire a bullet from the player's position
  void _fireBullet() {
    if (gameState.isPaused || gameState.isGameOver) return;
    
    // Handle different shot types based on active power-ups
    if (widget.gameMode == GameMode.survival && 
        activePowerUps.containsKey(PowerUpType.tripleShot) && 
        activePowerUps[PowerUpType.tripleShot]!.isActive) {
      _fireTripleShot();
    } else {
      _fireSingleBullet();
    }
  }
  
  // Fire a single bullet
  void _fireSingleBullet() {
    final bullet = Bullet(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      width: bulletWidth,
      height: bulletHeight,
      speedY: bulletSpeed,
    );
    bullets.add(bullet);
  }
  
  // Fire three bullets (triple shot power-up)
  void _fireTripleShot() {
    // Center bullet
    _fireSingleBullet();
    
    // Left bullet (15 degrees left)
    final leftAngle = -15 * (pi / 180);
    final leftSpeedX = sin(leftAngle) * bulletSpeed;
    final leftSpeedY = cos(leftAngle) * bulletSpeed;
    final leftBullet = Bullet(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      width: bulletWidth,
      height: bulletHeight,
      speedY: leftSpeedY,
      speedX: leftSpeedX,
    );
    bullets.add(leftBullet);
    
    // Right bullet (15 degrees right)
    final rightAngle = 15 * (pi / 180);
    final rightSpeedX = sin(rightAngle) * bulletSpeed;
    final rightSpeedY = cos(rightAngle) * bulletSpeed;
    final rightBullet = Bullet(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      width: bulletWidth,
      height: bulletHeight,
      speedY: rightSpeedY,
      speedX: rightSpeedX,
    );
    bullets.add(rightBullet);
  }
  
  // Handle touch input for player movement
  void _handleTouchUpdate(DragUpdateDetails details) {
    if (gameState.isPaused || gameState.isGameOver) return;
    
    setState(() {
      touchX = details.globalPosition.dx;
      player.moveTo(touchX! - player.width / 2, screenWidth);
    });
  }
  
  // Handle pan start for initial touch
  void _handleTouchStart(DragStartDetails details) {
    if (gameState.isPaused || gameState.isGameOver) return;
    
    setState(() {
      touchX = details.globalPosition.dx;
      player.moveTo(touchX! - player.width / 2, screenWidth);
    });
  }
  
  // Toggle pause state
  void _togglePause() {
    setState(() {
      gameState.isPaused = !gameState.isPaused;
    });
  }
  
  // Restart the game
  void _restartGame() {
    // Cancel existing timer if running
    if (gameTimer.isActive) {
      gameTimer.cancel();
    }
    
    // Reset game state completely
    setState(() {
      gameState = GameState();
      asteroids.clear();
      bullets.clear();
      frameCount = 0;
      asteroidSpawnRate = 60;
      lastShotFrame = 0;
      touchX = null;
    });
    
    // Load high score and reinitialize game
    _loadHighScore().then((_) {
      _initializeGame();
    });
  }
  
  // Power-up system methods (Survival mode only)
  
  // Update power-ups each frame
  void _updatePowerUps() {
    // Update active power-ups
    final keysToRemove = <PowerUpType>[];
    activePowerUps.forEach((type, powerUp) {
      powerUp.update();
      if (!powerUp.isActive) {
        keysToRemove.add(type);
      }
    });
    
    // Remove inactive power-ups
    for (var key in keysToRemove) {
      _deactivatePowerUp(key);
    }
    
    // Update floating power-ups
    for (var powerUp in powerUps) {
      powerUp.update(screenHeight);
    }
    
    // Update laser beams to follow player
    if (activePowerUps.containsKey(PowerUpType.laserBeam) && 
        activePowerUps[PowerUpType.laserBeam]!.isActive) {
      // Update laser beam position to follow player
      for (var laser in laserBeams) {
        laser.x = player.x + player.width / 2 - 4;
        laser.update();
      }
    }
    
    // Update floating texts
    for (var text in floatingTexts) {
      text.update();
    }
    
    // Note: Object cleanup is handled in _cleanupObjects() to avoid duplication
  }
  
  // Check if power-up should be dropped (5% chance)
  void _tryDropPowerUp(double x, double y) {
    final random = Random();
    if (random.nextDouble() < 0.05) { // 5% chance
      final powerUp = PowerUp.random(x, y);
      powerUps.add(powerUp);
    }
  }
  
  // Collect a power-up
  void _collectPowerUp(PowerUp powerUp) {
    powerUp.isVisible = false;
    
    // Activate power-up (stackable system allows multiple active power-ups)
    _activatePowerUp(powerUp.type);
    
    // Show floating text
    final text = FloatingText(
      text: ActivePowerUp(type: powerUp.type, remainingTime: 0).displayName,
      x: powerUp.x,
      y: powerUp.y,
    );
    floatingTexts.add(text);
  }
  
  // Activate a power-up
  void _activatePowerUp(PowerUpType type) {
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
        // Rapid fire will be handled in _fireBullet
        break;
      case PowerUpType.tripleShot:
        // Triple shot will be handled in _fireBullet
        break;
      case PowerUpType.laserBeam:
        _createLaserBeam();
        break;
    }
  }
  
  // Deactivate specific power-up
  void _deactivatePowerUp(PowerUpType type) {
    if (!activePowerUps.containsKey(type)) return;
    
    switch (type) {
      case PowerUpType.shield:
        hasShield = false;
        shieldHitsRemaining = 0;
        break;
      case PowerUpType.laserBeam:
        laserBeams.clear();
        break;
      case PowerUpType.rapidFire:
      case PowerUpType.tripleShot:
        // These don't need special cleanup
        break;
    }
    
    activePowerUps.remove(type);
  }
  
  // Create laser beam
  void _createLaserBeam() {
    final laser = LaserBeam(
      x: player.x + player.width / 2 - 4,
      y: 0,
      height: player.y,
    );
    laserBeams.add(laser);
  }
  
  // Get current shot interval based on active power-ups
  int _getCurrentShotInterval() {
    if (activePowerUps.containsKey(PowerUpType.rapidFire) && 
        activePowerUps[PowerUpType.rapidFire]!.isActive) {
      return shotInterval ~/ 2; // Double fire rate
    }
    return shotInterval;
  }
  
  // Get wave-adjusted spawn rate for asteroids
  int _getWaveAdjustedSpawnRate() {
    // More aggressive spawn rate scaling for engaging gameplay
    // Base spawn rate starts at 45 frames (0.75 seconds) - faster from start
    final baseRate = 45;
    final waveAdjustment = (gameState.currentWave * 3).clamp(0, 30);
    return max(18, baseRate - waveAdjustment); // Min spawn rate is 18 frames (0.3 seconds)
  }
  
  // Enemy system methods
  void _updateEnemies() {
    // Update all enemies
    for (var enemy in enemies) {
      enemy.update(screenHeight, screenWidth);
      
      // Handle UFO shooting
      if (enemy is EnemyUFO && enemy.shouldShoot()) {
        _fireEnemyBullet(enemy);
      }
    }
    
    // Update enemy bullets
    for (var bullet in enemyBullets) {
      bullet.update(screenHeight);
    }
    
    // Update boss
    if (activeBoss != null) {
      activeBoss!.update(screenHeight, screenWidth);
      
      // Boss shooting
      if (activeBoss!.shouldShoot()) {
        _fireBossSpread();
      }
    }
    
    // Note: Enemy cleanup is handled in _cleanupObjects() to avoid duplication
  }
  
  // Fire enemy bullet from UFO
  void _fireEnemyBullet(EnemyUFO ufo) {
    final bullet = EnemyBullet(
      x: ufo.x + ufo.width / 2 - 5,
      y: ufo.y + ufo.height,
      width: 10,
      height: 15,
      speedY: 3,
    );
    enemyBullets.add(bullet);
  }
  
  // Fire boss spread bullets
  void _fireBossSpread() {
    if (activeBoss == null) return;
    
    // Fire 3 bullets in spread pattern
    for (int i = -1; i <= 1; i++) {
      final angle = i * 20 * (pi / 180); // -20, 0, +20 degrees
      final speedX = sin(angle) * 4;
      final speedY = cos(angle) * 4;
      
      final bullet = EnemyBullet(
        x: activeBoss!.x + activeBoss!.width / 2 - 5,
        y: activeBoss!.y + activeBoss!.height,
        width: 10,
        height: 15,
        speedY: speedY,
        speedX: speedX,
      );
      enemyBullets.add(bullet);
    }
  }
  
  void _spawnEnemies() {
    // Check for boss spawn every 150 asteroids destroyed
    if (asteroidsDestroyed >= 150 && activeBoss == null) {
      _spawnBoss();
      return;
    }
    
    // Skip enemy spawning if boss is active
    if (activeBoss != null) return;
    
    // Calculate wave-based enemy spawn interval and probabilities
    final waveSpawnInterval = _getWaveEnemySpawnInterval();
    
    // Spawn enemies based on wave-adjusted interval
    if (frameCount % waveSpawnInterval == 0) {
      final random = Random();
      final roll = random.nextDouble();
      
      // Get wave-based enemy probabilities
      final enemyProbabilities = _getWaveEnemyProbabilities();
      
      if (roll < enemyProbabilities['smallFast']!) {
        // Small fast asteroid - appears starting wave 2
        enemies.add(SmallFastAsteroid.random(screenWidth, asteroidSize));
      } else if (roll < enemyProbabilities['hugeSlow']!) {
        // Huge slow asteroid - appears starting wave 4
        enemies.add(HugeSlowAsteroid.random(screenWidth, asteroidSize));
      } else if (roll < enemyProbabilities['ufo']!) {
        // UFO - appears starting wave 6
        enemies.add(EnemyUFO.random(screenWidth, 60));
      }
      // If roll doesn't match any enemy type, no special enemy spawns (normal asteroids only)
    }
  }
  
  // Get wave-adjusted enemy spawn interval
  int _getWaveEnemySpawnInterval() {
    // More aggressive enemy spawn timing for engaging gameplay
    // Start with 180 frames (3 seconds) and decrease with waves
    // Min interval is 90 frames (1.5 seconds) at high waves
    final baseInterval = 180;
    final waveReduction = (gameState.currentWave - 1) * 20;
    return max(90, baseInterval - waveReduction);
  }
  
  // Get wave-based enemy spawn probabilities
  Map<String, double> _getWaveEnemyProbabilities() {
    final wave = gameState.currentWave;
    
    // Wave 1: Only normal asteroids (no special enemies)
    if (wave == 1) {
      return {
        'smallFast': 0.0,
        'hugeSlow': 0.0,
        'ufo': 0.0,
      };
    }
    
    // Wave 2-3: Introduce small fast asteroids (15% chance)
    if (wave <= 3) {
      return {
        'smallFast': 0.15,
        'hugeSlow': 0.0,
        'ufo': 0.0,
      };
    }
    
    // Wave 4-5: Add huge slow asteroids (10% for small, 5% for huge)
    if (wave <= 5) {
      return {
        'smallFast': 0.20,
        'hugeSlow': 0.25, // 20% small + 5% huge
        'ufo': 0.0,
      };
    }
    
    // Wave 6-8: Introduce UFOs (15% small, 8% huge, 3% ufo)
    if (wave <= 8) {
      return {
        'smallFast': 0.25,
        'hugeSlow': 0.33, // 25% small + 8% huge
        'ufo': 0.36, // + 3% ufo
      };
    }
    
    // Wave 9-12: Increase all enemy types (20% small, 12% huge, 5% ufo)
    if (wave <= 12) {
      return {
        'smallFast': 0.30,
        'hugeSlow': 0.42, // 30% small + 12% huge
        'ufo': 0.47, // + 5% ufo
      };
    }
    
    // Wave 13+: High difficulty (25% small, 15% huge, 8% ufo)
    return {
      'smallFast': 0.35,
      'hugeSlow': 0.50, // 35% small + 15% huge
      'ufo': 0.58, // + 8% ufo
    };
  }
  
  // Handle player getting hit
  void _handlePlayerHit() {
    // Handle shield protection
    if (hasShield && shieldHitsRemaining > 0) {
      shieldHitsRemaining--;
      if (shieldHitsRemaining <= 0) {
        hasShield = false;
        _deactivatePowerUp(PowerUpType.shield);
      }
      
      // Show floating text
      final text = FloatingText(
        text: 'Shield Hit!',
        x: player.x,
        y: player.y - 30,
        color: Colors.blue,
      );
      floatingTexts.add(text);
    } else {
      // Player takes damage
      player.hit();
      
      // Reset combo on damage
      player.resetComboOnDamage();
      
      // Shake screen effect
      _shakeController.forward(from: 0);
      
      // Check if game over
      if (player.lives <= 0) {
        _gameOver();
      }
    }
  }
  
  // Spawn boss UFO
  void _spawnBoss() {
    activeBoss = BossUFO.create(screenWidth, 120);
    
    // Show boss warning
    final text = FloatingText(
      text: 'BOSS INCOMING!',
      x: screenWidth / 2 - 60,
      y: screenHeight / 2,
      color: Colors.red,
      lifeTimer: 180,
    );
    floatingTexts.add(text);
    
    // Reset asteroid counter
    asteroidsDestroyed = 0;
  }
  
  // Defeat boss
  void _defeatBoss() {
    if (activeBoss == null) return;
    
    // Add score for boss
    gameState.score += activeBoss!.scoreValue;
    
    // Drop 2 power-ups
    for (int i = 0; i < 2; i++) {
      final powerUp = PowerUp.random(
        activeBoss!.x + activeBoss!.width / 2 + (i * 30 - 15),
        activeBoss!.y + activeBoss!.height / 2,
      );
      powerUps.add(powerUp);
    }
    
    // Show victory text
    final text = FloatingText(
      text: 'BOSS DEFEATED!',
      x: screenWidth / 2 - 70,
      y: screenHeight / 2,
      color: Colors.yellow,
      lifeTimer: 180,
    );
    floatingTexts.add(text);
    
    activeBoss = null;
  }
  
  // Split huge asteroid into 2 small ones
  void _splitHugeAsteroid(HugeSlowAsteroid hugeAsteroid) {
    // Create a list to store new enemies to add after collision processing
    List<SmallFastAsteroid> newEnemies = [];
    
    for (int i = 0; i < 2; i++) {
      final smallAsteroid = SmallFastAsteroid(
        x: hugeAsteroid.x + (i * 20),
        y: hugeAsteroid.y,
        size: asteroidSize * 0.5,
        speedY: (1 + Random().nextDouble() * 3) * 1.8,
        rotationSpeed: (Random().nextDouble() - 0.5) * 0.15,
      );
      newEnemies.add(smallAsteroid);
    }
    
    // Add new enemies in next frame to avoid concurrent modification
    Future.microtask(() {
      if (mounted && !gameState.isGameOver) {
        enemies.addAll(newEnemies);
      }
    });
  }
  
  // Show score popup with combo information
  void _showScorePopup(double x, double y, int score, double multiplier) {
    final text = FloatingText(
      text: multiplier > 1.0 ? '+$score (${multiplier.toStringAsFixed(1)}x)' : '+$score',
      x: x - 20,
      y: y - 20,
      color: multiplier > 1.0 ? Colors.yellow : Colors.white,
      lifeTimer: 90,
    );
    floatingTexts.add(text);
  }
  
  // Check if combo flash animation should play
  void _checkComboFlash() {
    if (_previousComboMultiplier == null || player.comboMultiplier > _previousComboMultiplier!) {
      _comboFlashController.forward(from: 0);
      _comboFlashTimer = 60; // Flash for 60 frames (1 second)
    }
    _previousComboMultiplier = player.comboMultiplier;
    
    if (_comboFlashTimer > 0) {
      _comboFlashTimer--;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Update screen dimensions
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            // Apply shake effect when player is hit
            final offset = _shakeController.value * 10;
            final dx = sin(_shakeController.value * 10) * offset;
            
            return Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            );
          },
          child: Stack(
            children: [
              // Game area - GestureDetector for player control
              GestureDetector(
                onPanUpdate: _handleTouchUpdate,
                onPanStart: _handleTouchStart,
                child: Container(
                  width: screenWidth,
                  height: screenHeight,
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      // Draw player
                      _buildPlayer(),
                      
                      // Draw asteroids
                      ...asteroids.map(_buildAsteroid).toList(),
                      
                      // Draw bullets
                      ...bullets.map(_buildBullet).toList(),
                      
                      // Draw power-ups (Survival mode only)
                      if (widget.gameMode == GameMode.survival) ...
                        powerUps.map(_buildPowerUp).toList(),
                      
                      // Draw laser beams (Survival mode only)
                      if (widget.gameMode == GameMode.survival) ...
                        laserBeams.map(_buildLaserBeam).toList(),
                      
                      // Draw floating texts (Survival mode only)
                      if (widget.gameMode == GameMode.survival) ...
                        floatingTexts.map(_buildFloatingText).toList(),
                      
                      // Draw enemies
                      ...enemies.map(_buildEnemy).toList(),
                      
                      // Draw enemy bullets
                      ...enemyBullets.map(_buildEnemyBullet).toList(),
                      
                      // Draw boss
                      if (activeBoss != null) _buildBoss(activeBoss!),
                    ],
                  ),
                ),
              ),
              
              // Game UI overlay
              _buildGameUI(),
              
              // Combo display
              if (player.hasCombo) _buildComboDisplay(),
              
              // Pause button
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Icon(
                    gameState.isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                  ),
                  onPressed: _togglePause,
                ),
              ),
              
              // Subtle wave notifications (non-intrusive)
              if (gameState.showWaveStart) _buildWaveNotification(),
              
              // Wave completion notification
              if (gameState.showWaveComplete) _buildWaveCompleteNotification(),
              
              // Game over overlay
              if (gameState.isGameOver) _buildGameOverOverlay(),
              
              // Pause overlay
              if (gameState.isPaused) _buildPauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build player widget
  Widget _buildPlayer() {
    // Make player blink when invulnerable
    final isVisible = !player.isInvulnerable || (frameCount % 10 < 5);
    
    if (!isVisible) return const SizedBox.shrink();
    
    return Positioned(
      left: player.x,
      top: player.y,
      width: player.width,
      height: player.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shield effect
          if (widget.gameMode == GameMode.survival && hasShield && shieldHitsRemaining > 0)
            Container(
              width: player.width + 20,
              height: player.height + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.withOpacity(0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          // Player spaceship
          SvgPicture.asset(
            'assets/images/spaceship.svg',
            width: player.width,
            height: player.height,
          ),
        ],
      ),
    );
  }
  
  // Build asteroid widget
  Widget _buildAsteroid(Asteroid asteroid) {
    if (!asteroid.isVisible) return const SizedBox.shrink();
    
    return Positioned(
      left: asteroid.x,
      top: asteroid.y,
      width: asteroid.width,
      height: asteroid.height,
      child: Transform.rotate(
        angle: asteroid.rotationAngle,
        child: SvgPicture.asset(
          'assets/images/asteroid.svg',
          width: asteroid.width,
          height: asteroid.height,
        ),
      ),
    );
  }
  
  // Build bullet widget
  Widget _buildBullet(Bullet bullet) {
    if (!bullet.isVisible) return const SizedBox.shrink();
    
    return Positioned(
      left: bullet.x,
      top: bullet.y,
      width: bullet.width,
      height: bullet.height,
      child: SvgPicture.asset(
        'assets/images/bullet.svg',
        width: bullet.width,
        height: bullet.height,
      ),
    );
  }
  
  // Build game UI (score, lives, etc.)
  Widget _buildGameUI() {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Centered Score
          Text(
            'Score: ${gameState.score}',
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 2,
                  color: Colors.black,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Lives and High Score (left side)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wave number display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.8),
                        Colors.red.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    'Wave ${gameState.currentWave}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // High Score
                Text(
                  'High Score: ${gameState.highScore}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 10),
                // Lives
                Row(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: index < player.lives
                          ? SvgPicture.asset(
                              'assets/images/heart.svg',
                              width: 20,
                              height: 20,
                            )
                          : SvgPicture.asset(
                              'assets/images/heart.svg',
                              width: 20,
                              height: 20,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                    ),
                  ),
                ),
                
                // Wave progress indicator (during wave)
                if (!gameState.isWaveBreak)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wave Progress',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 100,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: gameState.getWaveProgress(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green,
                                    Colors.yellow,
                                    Colors.red,
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Wave break countdown
                if (gameState.isWaveBreak)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Next Wave: ${(gameState.waveBreakTimer / 60).ceil()}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Power-up status (Survival mode only)
                if (widget.gameMode == GameMode.survival && activePowerUps.isNotEmpty) ...
                  activePowerUps.entries.map((entry) {
                    final powerUp = entry.value;
                    if (powerUp.isActive) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${powerUp.type.name.toUpperCase()}: ${(powerUp.remainingTime / 60).ceil()}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build combo display widget
  Widget _buildComboDisplay() {
    return AnimatedBuilder(
      animation: _comboFlashController,
      builder: (context, child) {
        final flashValue = _comboFlashController.value;
        final isFlashing = _comboFlashTimer > 0;
        
        return Positioned(
          top: 80,
          right: 20,
          child: Transform.scale(
            scale: isFlashing ? (1.0 + flashValue * 0.3) : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isFlashing 
                        ? Colors.yellow.withOpacity(0.9) 
                        : Colors.orange.withOpacity(0.8),
                    isFlashing 
                        ? Colors.orange.withOpacity(0.9) 
                        : Colors.red.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isFlashing ? Colors.yellow : Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isFlashing ? Colors.yellow : Colors.orange).withOpacity(0.6),
                    spreadRadius: isFlashing ? 4 : 2,
                    blurRadius: isFlashing ? 8 : 4,
                  ),
                ],
              ),
              child: Text(
                player.comboText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isFlashing ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 2,
                      color: Colors.black,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Build game over overlay
  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      width: screenWidth,
      height: screenHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(color: Colors.red, fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Score: ${gameState.score}',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Text(
              'High Score: ${gameState.highScore}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _restartGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'Play Again',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                // Cancel the game timer
                if (gameTimer.isActive) {
                  gameTimer.cancel();
                }
                // Navigate back to main menu
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'Main Menu',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build pause overlay
  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      width: screenWidth,
      height: screenHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _togglePause,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'Resume',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _restartGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'Restart',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build power-up widget
  Widget _buildPowerUp(PowerUp powerUp) {
    if (!powerUp.isVisible) return const SizedBox.shrink();
    
    // Create pulsing animation for power-ups
    final pulseValue = 1.0 + sin(frameCount * 0.1) * 0.2;
    
    return Positioned(
      left: powerUp.x,
      top: powerUp.y,
      width: powerUp.width,
      height: powerUp.height,
      child: Transform.scale(
        scale: pulseValue,
        child: Container(
          decoration: BoxDecoration(
            color: powerUp.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: powerUp.color.withOpacity(0.6),
                spreadRadius: 2,
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            powerUp.icon,
            color: Colors.white,
            size: powerUp.width * 0.6,
          ),
        ),
      ),
    );
  }
  
  // Build laser beam widget
  Widget _buildLaserBeam(LaserBeam laser) {
    if (!laser.isVisible) return const SizedBox.shrink();
    
    return Positioned(
      left: laser.x,
      top: laser.y,
      width: laser.width,
      height: laser.height,
      child: Stack(
        children: [
          // Outer glow
          Container(
            width: laser.width + 4,
            height: laser.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.3),
                  Colors.pink.withOpacity(0.2),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main beam
          Positioned(
            left: 2,
            child: Container(
              width: laser.width,
              height: laser.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.9),
                    Colors.pink.withOpacity(0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Inner core
          Positioned(
            left: 3,
            child: Container(
              width: laser.width - 2,
              height: laser.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.8),
                    Colors.pink.withOpacity(0.9),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build floating text widget
  Widget _buildFloatingText(FloatingText text) {
    if (!text.isVisible) return const SizedBox.shrink();
    
    return Positioned(
      left: text.x,
      top: text.y,
      child: Opacity(
        opacity: text.opacity,
        child: Text(
          text.text,
          style: TextStyle(
            color: text.color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 2,
                color: Colors.black,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build enemy widget
  Widget _buildEnemy(Enemy enemy) {
    if (!enemy.isVisible) return const SizedBox.shrink();
    
    Widget enemyWidget;
    
    switch (enemy.type) {
      case EnemyType.smallFastAsteroid:
        enemyWidget = _buildSmallFastAsteroid(enemy as SmallFastAsteroid);
        break;
      case EnemyType.hugeSowAsteroid:
        enemyWidget = _buildHugeSlowAsteroid(enemy as HugeSlowAsteroid);
        break;
      case EnemyType.ufo:
        enemyWidget = _buildAlienUFO(enemy as EnemyUFO);
        break;
      default:
        enemyWidget = Container(
          width: enemy.width,
          height: enemy.height,
          color: Colors.red,
        );
    }
    
    return Positioned(
      left: enemy.x,
      top: enemy.y,
      width: enemy.width,
      height: enemy.height,
      child: enemyWidget,
    );
  }
  
  // Build small fast asteroid with simple design to prevent visual issues
  Widget _buildSmallFastAsteroid(SmallFastAsteroid asteroid) {
    return Transform.rotate(
      angle: asteroid.rotationAngle,
      child: Container(
        width: asteroid.width,
        height: asteroid.height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.orange.withOpacity(0.8),
          border: Border.all(
            color: Colors.red.withOpacity(0.6),
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            width: asteroid.width * 0.4,
            height: asteroid.height * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
  
  // Build huge slow asteroid with rocky texture effect
  Widget _buildHugeSlowAsteroid(HugeSlowAsteroid asteroid) {
    return Transform.rotate(
      angle: asteroid.rotationAngle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: asteroid.width + 12,
            height: asteroid.height + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.brown.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Main asteroid body
          Container(
            width: asteroid.width,
            height: asteroid.height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.brown.shade800,
                  Colors.brown.shade600,
                  Colors.brown.shade400,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withOpacity(0.7),
                  spreadRadius: 3,
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          // Rocky texture spots
          ...List.generate(8, (index) {
            final angle = (index * 45) * (pi / 180);
            final distance = asteroid.width * 0.25;
            return Transform.translate(
              offset: Offset(
                cos(angle) * distance,
                sin(angle) * distance,
              ),
              child: Container(
                width: asteroid.width * 0.15,
                height: asteroid.height * 0.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            );
          }),
          // Health indicator (gets redder as health decreases)
          Container(
            width: asteroid.width * 0.3,
            height: asteroid.height * 0.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: asteroid.health == asteroid.maxHealth
                  ? Colors.brown.withOpacity(0.8)
                  : asteroid.health == 2
                      ? Colors.orange.withOpacity(0.8)
                      : Colors.red.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build alien UFO with proper alien spaceship design
  Widget _buildAlienUFO(EnemyUFO ufo) {
    final pulseValue = 1.0 + sin(frameCount * 0.1) * 0.1;
    
    return Transform.scale(
      scale: pulseValue,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // UFO outer glow
          Container(
            width: ufo.width + 15,
            height: ufo.height + 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.green.withOpacity(0.6),
                  Colors.cyan.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // UFO main body (saucer shape)
          Container(
            width: ufo.width,
            height: ufo.height * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(ufo.width / 2),
                right: Radius.circular(ufo.width / 2),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade600,
                  Colors.grey.shade800,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.7),
                  spreadRadius: 2,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          // UFO dome (cockpit)
          Positioned(
            top: 5,
            child: Container(
              width: ufo.width * 0.5,
              height: ufo.height * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyan.withOpacity(0.9),
                    Colors.blue.withOpacity(0.7),
                    Colors.green.withOpacity(0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.8),
                    spreadRadius: 1,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // UFO lights around the edge
          ...List.generate(6, (index) {
            final angle = (index * 60) * (pi / 180);
            final lightDistance = ufo.width * 0.4;
            return Transform.translate(
              offset: Offset(
                cos(angle) * lightDistance,
                sin(angle) * lightDistance * 0.3,
              ),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (frameCount + index * 10) % 60 < 30
                      ? Colors.yellow
                      : Colors.orange,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.8),
                      spreadRadius: 1,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            );
          }),
          // Tractor beam effect (optional visual)
          Positioned(
            bottom: -5,
            child: Container(
              width: ufo.width * 0.3,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build enemy bullet widget
  Widget _buildEnemyBullet(EnemyBullet bullet) {
    if (!bullet.isVisible) return const SizedBox.shrink();
    
    return Positioned(
      left: bullet.x,
      top: bullet.y,
      width: bullet.width,
      height: bullet.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
  
  // Build wave start overlay
  Widget _buildWaveStartOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      width: screenWidth,
      height: screenHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated wave start text with scaling effect
            Transform.scale(
              scale: 1.2 + sin(frameCount * 0.15) * 0.3,
              child: Text(
                'WAVE ${gameState.currentWave}',
                style: TextStyle(
                  color: Colors.cyan,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 15,
                      color: Colors.blue,
                      offset: Offset(0, 0),
                    ),
                    Shadow(
                      blurRadius: 3,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            
            // Sub text with wave guidance
            Text(
              gameState.currentWave == 1 
                  ? 'Survive the asteroid field!'
                  : gameState.currentWave <= 3
                      ? 'New enemies incoming!'
                      : gameState.currentWave <= 6
                          ? 'Beware of huge asteroids!'
                          : 'UFOs have joined the battle!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontStyle: FontStyle.italic,
                shadows: [
                  Shadow(
                    blurRadius: 2,
                    color: Colors.black,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // Countdown or ready indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(0.7),
                    Colors.blue.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Text(
                'Get Ready!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build wave complete overlay
  Widget _buildWaveCompleteOverlay() {
    final bonus = 200 * (gameState.currentWave - 1); // Previous wave bonus
    
    return Container(
      color: Colors.black.withOpacity(0.8),
      width: screenWidth,
      height: screenHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated wave complete text
            Transform.scale(
              scale: 1.0 + sin(frameCount * 0.1) * 0.1,
              child: Text(
                'Wave ${gameState.currentWave - 1} Complete!',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.orange,
                      offset: Offset(0, 0),
                    ),
                    Shadow(
                      blurRadius: 2,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            
            // Wave bonus info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.8),
                    Colors.purple.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Wave Bonus: +$bonus points',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Preparing Wave ${gameState.currentWave}...',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Countdown timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Next wave in: ${(gameState.waveBreakTimer / 60).ceil()}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Rest and prepare message
            Text(
              'Take a breath! Collect any power-ups on screen.',
              style: TextStyle(
                color: Colors.cyan.withOpacity(0.8),
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // Build subtle wave notification (non-intrusive)
  Widget _buildWaveNotification() {
    return Positioned(
      top: 140,
      right: 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.cyan.withOpacity(0.9),
              Colors.blue.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(0.6),
              spreadRadius: 2,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WAVE ${gameState.currentWave}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              gameState.currentWave == 1 
                  ? 'Survive!'
                  : gameState.currentWave <= 3
                      ? 'New Enemies!'
                      : gameState.currentWave <= 6
                          ? 'Huge Asteroids!'
                          : 'UFOs Attack!',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build subtle wave complete notification
  Widget _buildWaveCompleteNotification() {
    final bonus = 200 * (gameState.currentWave - 1);
    
    return Positioned(
      top: 140,
      right: 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.yellow.withOpacity(0.9),
              Colors.orange.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.yellow.withOpacity(0.6),
              spreadRadius: 2,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wave Complete!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (bonus > 0) ...
              [
                const SizedBox(height: 4),
                Text(
                  '+$bonus bonus',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
  
  // Build boss widget with enhanced alien mothership design
  Widget _buildBoss(BossUFO boss) {
    if (!boss.isVisible) return const SizedBox.shrink();
    
    // Create pulsing effect for boss
    final pulseValue = 1.0 + sin(frameCount * 0.05) * 0.15;
    final healthPercentage = boss.health / boss.maxHealth;
    
    return Positioned(
      left: boss.x,
      top: boss.y,
      width: boss.width,
      height: boss.height,
      child: Transform.scale(
        scale: pulseValue,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Boss outer energy field
            Container(
              width: boss.width + 25,
              height: boss.height + 25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(0.8),
                    Colors.red.withOpacity(0.5),
                    Colors.pink.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: [0.2, 0.5, 0.7, 1.0],
                ),
              ),
            ),
            // Boss main hull (larger saucer)
            Container(
              width: boss.width * 0.9,
              height: boss.height * 0.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(boss.width * 0.45),
                  right: Radius.circular(boss.width * 0.45),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade400,
                    Colors.grey.shade700,
                    Colors.black,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.9),
                    spreadRadius: 4,
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            // Boss command center (large dome)
            Positioned(
              top: 0,
              child: Container(
                width: boss.width * 0.6,
                height: boss.height * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      healthPercentage > 0.5 ? Colors.purple.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                      healthPercentage > 0.3 ? Colors.blue.withOpacity(0.7) : Colors.orange.withOpacity(0.7),
                      Colors.green.withOpacity(0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (healthPercentage > 0.5 ? Colors.purple : Colors.red).withOpacity(0.9),
                      spreadRadius: 3,
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: boss.width * 0.2,
                    height: boss.height * 0.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white,
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Boss weapon arrays (multiple lights around edges)
            ...List.generate(12, (index) {
              final angle = (index * 30) * (pi / 180);
              final lightDistance = boss.width * 0.35;
              return Transform.translate(
                offset: Offset(
                  cos(angle) * lightDistance,
                  sin(angle) * lightDistance * 0.2,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (frameCount + index * 8) % 48 < 24
                        ? (healthPercentage > 0.5 ? Colors.cyan : Colors.red)
                        : (healthPercentage > 0.5 ? Colors.purple : Colors.orange),
                    boxShadow: [
                      BoxShadow(
                        color: (healthPercentage > 0.5 ? Colors.cyan : Colors.red).withOpacity(0.8),
                        spreadRadius: 2,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Boss energy cannons (4 larger weapon ports)
            ...List.generate(4, (index) {
              final angle = (index * 90 + 45) * (pi / 180);
              final cannonDistance = boss.width * 0.25;
              return Transform.translate(
                offset: Offset(
                  cos(angle) * cannonDistance,
                  sin(angle) * cannonDistance * 0.3,
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white,
                        healthPercentage > 0.5 ? Colors.purple : Colors.red,
                        Colors.black,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (healthPercentage > 0.5 ? Colors.purple : Colors.red).withOpacity(0.9),
                        spreadRadius: 2,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Boss health indicator (central beam)
            Positioned(
              bottom: -10,
              child: Container(
                width: boss.width * 0.6 * healthPercentage,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (healthPercentage > 0.5 ? Colors.purple : Colors.red).withOpacity(0.8),
                      (healthPercentage > 0.3 ? Colors.blue : Colors.orange).withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Boss damage effects (sparks when low health)
            if (healthPercentage < 0.3) ...
              List.generate(6, (index) {
                final sparkAngle = Random().nextDouble() * 2 * pi;
                final sparkDistance = Random().nextDouble() * boss.width * 0.4;
                return Transform.translate(
                  offset: Offset(
                    cos(sparkAngle) * sparkDistance,
                    sin(sparkAngle) * sparkDistance,
                  ),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: frameCount % 20 < 10 ? Colors.orange : Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange,
                          spreadRadius: 1,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
