import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/game_models.dart';
import '../services/score_service.dart';

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  
  const GameScreen({Key? key, this.gameMode = GameMode.classic}) : super(key: key);

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
  
  // Power-up system (only for Survival mode)
  List<PowerUp> powerUps = [];
  ActivePowerUp? activePowerUp;
  List<LaserBeam> laserBeams = [];
  List<FloatingText> floatingTexts = [];
  bool hasShield = false;
  int shieldHitsRemaining = 0;
  
  // New enemy system
  List<Enemy> enemies = [];
  List<EnemyBullet> enemyBullets = [];
  BossUFO? activeBoss;
  int asteroidsDestroyed = 0;
  
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
    
    // Clear power-up objects (Survival mode)
    if (widget.gameMode == GameMode.survival) {
      powerUps.clear();
      laserBeams.clear();
      floatingTexts.clear();
      activePowerUp = null;
      hasShield = false;
      shieldHitsRemaining = 0;
    }
    
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
    
    // Auto-shoot bullets at regular intervals
    final currentInterval = widget.gameMode == GameMode.survival ? _getCurrentShotInterval() : shotInterval;
    if (frameCount - lastShotFrame >= currentInterval) {
      _fireBullet();
      lastShotFrame = frameCount;
    }
    
    // Spawn new asteroid at regular intervals
    if (frameCount % asteroidSpawnRate == 0) {
      asteroids.add(Asteroid.random(screenWidth, asteroidSize));
      
      // Increase difficulty by spawning asteroids more frequently as score increases
      if (gameState.score > 0 && gameState.score % 10 == 0) {
        asteroidSpawnRate = max(20, asteroidSpawnRate - 2); // Min spawn rate is 20 frames
      }
    }
    
    // Update player
    player.update();
    
    // Update asteroids
    for (var asteroid in asteroids) {
      asteroid.update(screenHeight);
    }
    
    // Update bullets
    for (var bullet in bullets) {
      bullet.update(screenWidth);
    }
    
    // Update power-ups (Survival mode only)
    if (widget.gameMode == GameMode.survival) {
      _updatePowerUps();
    }
    
    // Check for collisions
    _checkCollisions();
    
    // Clean up invisible objects
    _cleanupObjects();
    
    // Update UI
    setState(() {});
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
          
          // Try to drop power-up in survival mode (5% chance)
          if (widget.gameMode == GameMode.survival) {
            _tryDropPowerUp(asteroid.x + asteroid.width / 2, asteroid.y + asteroid.height / 2);
          }
          
          // Increase score
          gameState.score++;
        }
      }
    }
    
    // Check laser-asteroid collisions (Survival mode only)
    if (widget.gameMode == GameMode.survival) {
      for (var laser in laserBeams) {
        if (!laser.isVisible) continue;
        
        for (var asteroid in asteroids) {
          if (!asteroid.isVisible) continue;
          
          if (laser.collidesWith(asteroid)) {
            // Mark asteroid as invisible
            asteroid.isVisible = false;
            
            // Try to drop power-up
            _tryDropPowerUp(asteroid.x + asteroid.width / 2, asteroid.y + asteroid.height / 2);
            
            // Increase score
            gameState.score++;
          }
        }
      }
    }
    
    // Check player-power-up collisions (Survival mode only)
    if (widget.gameMode == GameMode.survival) {
      for (var powerUp in powerUps) {
        if (!powerUp.isVisible) continue;
        
        if (player.collidesWith(powerUp)) {
          _collectPowerUp(powerUp);
        }
      }
    }
    
    // Check player-asteroid collisions
    for (var asteroid in asteroids) {
      if (!asteroid.isVisible) continue;
      
      if (player.collidesWith(asteroid)) {
        // Mark asteroid as invisible
        asteroid.isVisible = false;
        
        // Handle shield protection (Survival mode)
        if (widget.gameMode == GameMode.survival && hasShield && shieldHitsRemaining > 0) {
          shieldHitsRemaining--;
          if (shieldHitsRemaining <= 0) {
            hasShield = false;
            _deactivatePowerUp();
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
          
          // Shake screen effect
          _shakeController.forward(from: 0);
          
          // Check if game over
          if (player.lives <= 0) {
            _gameOver();
          }
        }
      }
    }
  }
  
  // Clean up invisible objects
  void _cleanupObjects() {
    asteroids.removeWhere((asteroid) => !asteroid.isVisible);
    bullets.removeWhere((bullet) => !bullet.isVisible);
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
        activePowerUp?.type == PowerUpType.tripleShot && 
        activePowerUp!.isActive) {
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
    // Update active power-up
    if (activePowerUp != null) {
      activePowerUp!.update();
      if (!activePowerUp!.isActive) {
        _deactivatePowerUp();
      }
    }
    
    // Update floating power-ups
    for (var powerUp in powerUps) {
      powerUp.update(screenHeight);
    }
    
    // Update laser beams to follow player
    if (activePowerUp?.type == PowerUpType.laserBeam && activePowerUp!.isActive) {
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
    
    // Clean up expired objects
    powerUps.removeWhere((powerUp) => !powerUp.isVisible);
    laserBeams.removeWhere((laser) => !laser.isVisible);
    floatingTexts.removeWhere((text) => !text.isVisible);
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
    
    // Deactivate current power-up if any
    if (activePowerUp != null) {
      _deactivatePowerUp();
    }
    
    // Activate new power-up
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
    activePowerUp = ActivePowerUp(
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
  
  // Deactivate current power-up
  void _deactivatePowerUp() {
    if (activePowerUp == null) return;
    
    switch (activePowerUp!.type) {
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
    
    activePowerUp = null;
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
    if (activePowerUp?.type == PowerUpType.rapidFire && activePowerUp!.isActive) {
      return shotInterval ~/ 2; // Double fire rate
    }
    return shotInterval;
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
                    ],
                  ),
                ),
              ),
              
              // Game UI overlay
              _buildGameUI(),
              
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
      left: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score
          Text(
            'Score: ${gameState.score}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 5),
          // High Score
          Text(
            'High Score: ${gameState.highScore}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
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
          
          // Power-up status (Survival mode only)
          if (widget.gameMode == GameMode.survival && activePowerUp != null && activePowerUp!.isActive) ...
            [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${activePowerUp!.type.name.toUpperCase()}: ${(activePowerUp!.remainingTime / 60).ceil()}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
        ],
      ),
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
}
