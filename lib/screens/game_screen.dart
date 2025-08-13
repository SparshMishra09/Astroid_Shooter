import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/game_models.dart';
import '../services/score_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

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
    if (frameCount - lastShotFrame >= shotInterval) {
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
      bullet.update();
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
          
          // Increase score
          gameState.score++;
        }
      }
    }
    
    // Check player-asteroid collisions
    for (var asteroid in asteroids) {
      if (!asteroid.isVisible) continue;
      
      if (player.collidesWith(asteroid)) {
        // Mark asteroid as invisible
        asteroid.isVisible = false;
        
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
    
    final bullet = Bullet(
      x: player.x + player.width / 2 - bulletWidth / 2,
      y: player.y - bulletHeight,
      width: bulletWidth,
      height: bulletHeight,
      speedY: bulletSpeed,
    );
    
    bullets.add(bullet);
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
      child: SvgPicture.asset(
        'assets/images/spaceship.svg',
        width: player.width,
        height: player.height,
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
}