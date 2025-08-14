import 'dart:math';
import 'package:flutter/material.dart';

// Game modes (currently only Survival, future expansion ready)
enum GameMode {
  survival,
}

// Power-up types enum
enum PowerUpType {
  shield,
  rapidFire,
  tripleShot,
  laserBeam,
}

// Base class for all game objects
abstract class GameObject {
  double x;
  double y;
  double width;
  double height;
  bool isVisible;

  GameObject({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isVisible = true,
  });

  // Check if this object collides with another object
  bool collidesWith(GameObject other) {
    if (!isVisible || !other.isVisible) return false;
    
    return (x < other.x + other.width &&
        x + width > other.x &&
        y < other.y + other.height &&
        y + height > other.y);
  }

  // Get the center point of the object
  Offset get center => Offset(x + width / 2, y + height / 2);
}

// Player spaceship
class Player extends GameObject {
  int lives;
  bool isInvulnerable;
  int invulnerabilityTimer;
  
  // Combo system
  double comboMultiplier;
  int consecutiveHits;
  bool lastShotHit;
  
  Player({
    required double x,
    required double y,
    required double width,
    required double height,
    this.lives = 3,
    this.isInvulnerable = false,
    this.invulnerabilityTimer = 0,
  }) : comboMultiplier = 1.0,
       consecutiveHits = 0,
       lastShotHit = false,
       super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Move player to a new position
  void moveTo(double newX, double screenWidth) {
    // Ensure player stays within screen bounds
    if (newX >= 0 && newX <= screenWidth - width) {
      x = newX;
    }
  }
  
  // Handle player getting hit by an asteroid
  void hit() {
    if (!isInvulnerable && lives > 0) {
      lives--;
      isInvulnerable = true;
      invulnerabilityTimer = 90; // 90 frames = ~1.5 seconds at 60fps
    }
  }
  
  // Update player state each frame
  void update() {
    if (isInvulnerable) {
      invulnerabilityTimer--;
      if (invulnerabilityTimer <= 0) {
        isInvulnerable = false;
      }
    }
  }
  
  // Combo system methods
  void registerHit() {
    consecutiveHits++;
    lastShotHit = true;
    
    // Update multiplier: starts at x1, increases by 0.2 per hit, max x3
    comboMultiplier = (1.0 + (consecutiveHits * 0.2)).clamp(1.0, 3.0);
  }
  
  void registerMiss() {
    _resetCombo();
  }
  
  void resetComboOnDamage() {
    _resetCombo();
  }
  
  void _resetCombo() {
    consecutiveHits = 0;
    comboMultiplier = 1.0;
    lastShotHit = false;
  }
  
  // Get current combo state for UI
  bool get hasCombo => comboMultiplier > 1.0;
  String get comboText => 'COMBO x${comboMultiplier.toStringAsFixed(1)}';
  
  // Calculate score with combo multiplier
  int calculateScore(int baseScore) {
    return (baseScore * comboMultiplier).round();
  }
}

// Asteroid object
class Asteroid extends GameObject {
  double speedY;
  double rotationAngle;
  double rotationSpeed;
  
  Asteroid({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedY,
    this.rotationAngle = 0,
    this.rotationSpeed = 0,
  }) : super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Update asteroid position and rotation
  void update(double screenHeight) {
    y += speedY;
    rotationAngle += rotationSpeed;
    
    // If asteroid goes off screen, mark it as not visible
    if (y > screenHeight) {
      isVisible = false;
    }
  }
  
  // Factory method to create a random asteroid
  static Asteroid random(double screenWidth, double asteroidSize) {
    final random = Random();
    
    // Random x position within screen bounds
    final x = random.nextDouble() * (screenWidth - asteroidSize);
    
    // Start above the screen
    final y = -asteroidSize - random.nextDouble() * 300;
    
    // Random vertical speed
    final speedY = 1 + random.nextDouble() * 3;
    
    // Random rotation speed
    final rotationSpeed = (random.nextDouble() - 0.5) * 0.1;
    
    return Asteroid(
      x: x,
      y: y,
      width: asteroidSize,
      height: asteroidSize,
      speedY: speedY,
      rotationSpeed: rotationSpeed,
    );
  }
}

// Bullet fired by player
class Bullet extends GameObject {
  double speedY;
  double speedX;
  
  Bullet({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedY,
    this.speedX = 0,
  }) : super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Update bullet position
  void update([double screenWidth = 1000]) {
    y -= speedY;
    x += speedX;
    
    // If bullet goes off screen, mark it as not visible
    if (y + height < 0 || x < -width || x > screenWidth + width) {
      isVisible = false;
    }
  }
}

// Game state class to manage overall game state
class GameState {
  int score = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isPaused = false;
  
  // Wave system properties
  int currentWave = 1;
  int waveTimer = 0;
  int waveBreakTimer = 0;
  bool isWaveBreak = false;
  bool showWaveComplete = false;
  int waveCompleteTimer = 0;
  bool showWaveStart = false;
  int waveStartTimer = 0;
  
  // Wave constants (in frames at 60fps) - faster pacing
  static const int waveMinDuration = 2100; // 35 seconds
  static const int waveMaxDuration = 2700; // 45 seconds
  static const int waveBreakDuration = 180; // 3 seconds
  static const int waveCompleteDisplayTime = 120; // 2 seconds
  static const int waveStartDisplayTime = 90; // 1.5 seconds
  
  // Reset game state for a new game
  void reset() {
    score = 0;
    isGameOver = false;
    isPaused = false;
    
    // Reset wave system
    currentWave = 1;
    waveTimer = 0;
    waveBreakTimer = 0;
    isWaveBreak = false;
    showWaveComplete = false;
    waveCompleteTimer = 0;
    showWaveStart = true;
    waveStartTimer = waveStartDisplayTime;
  }
  
  // Update high score if current score is higher
  void updateHighScore() {
    if (score > highScore) {
      highScore = score;
    }
  }
  
  // Get current wave duration (45-60 seconds based on wave number)
  int getWaveDuration() {
    // Later waves last slightly longer
    final baseLength = waveMinDuration;
    final extraTime = (currentWave * 50).clamp(0, waveMaxDuration - waveMinDuration);
    return baseLength + extraTime;
  }
  
  // Start a new wave
  void startNewWave() {
    currentWave++;
    waveTimer = 0;
    isWaveBreak = false;
    showWaveComplete = false;
    waveCompleteTimer = 0;
    showWaveStart = true;
    waveStartTimer = waveStartDisplayTime;
  }
  
  // Complete current wave and start break
  void completeWave() {
    isWaveBreak = true;
    waveBreakTimer = waveBreakDuration;
    showWaveComplete = true;
    waveCompleteTimer = waveCompleteDisplayTime;
    
    // Award wave completion bonus
    final bonus = 200 * currentWave;
    score += bonus;
  }
  
  // Update wave timers
  void updateWaveSystem() {
    // Handle wave start animation
    if (showWaveStart && waveStartTimer > 0) {
      waveStartTimer--;
      if (waveStartTimer <= 0) {
        showWaveStart = false;
      }
    }
    
    if (isWaveBreak) {
      // Handle wave break
      waveBreakTimer--;
      if (waveCompleteTimer > 0) {
        waveCompleteTimer--;
        if (waveCompleteTimer <= 0) {
          showWaveComplete = false;
        }
      }
      
      if (waveBreakTimer <= 0) {
        startNewWave();
      }
    } else {
      // Handle normal wave progression
      waveTimer++;
      if (waveTimer >= getWaveDuration()) {
        completeWave();
      }
    }
  }
  
  // Get wave progress percentage (0.0 to 1.0)
  double getWaveProgress() {
    if (isWaveBreak) return 0.0;
    return (waveTimer / getWaveDuration()).clamp(0.0, 1.0);
  }
}

// Power-up object that drops from destroyed asteroids
class PowerUp extends GameObject {
  PowerUpType type;
  double speedY;
  int lifeTimer;
  final int maxLifeTime = 900; // 15 seconds at 60fps
  
  PowerUp({
    required double x,
    required double y,
    required this.type,
    double width = 30,
    double height = 30,
    this.speedY = 1.5,
  }) : lifeTimer = 900, // 15 seconds at 60fps
       super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Update power-up position and lifetime
  void update(double screenHeight) {
    y += speedY;
    lifeTimer--;
    
    // Remove if off screen or expired
    if (y > screenHeight || lifeTimer <= 0) {
      isVisible = false;
    }
  }
  
  // Get color for power-up based on type
  Color get color {
    switch (type) {
      case PowerUpType.shield:
        return Colors.blue;
      case PowerUpType.rapidFire:
        return Colors.red;
      case PowerUpType.tripleShot:
        return Colors.green;
      case PowerUpType.laserBeam:
        return Colors.purple;
    }
  }
  
  // Get icon for power-up based on type
  IconData get icon {
    switch (type) {
      case PowerUpType.shield:
        return Icons.shield;
      case PowerUpType.rapidFire:
        return Icons.speed;
      case PowerUpType.tripleShot:
        return Icons.scatter_plot;
      case PowerUpType.laserBeam:
        return Icons.flash_on;
    }
  }
  
  // Factory method to create random power-up
  static PowerUp random(double x, double y) {
    final random = Random();
    final types = PowerUpType.values;
    final type = types[random.nextInt(types.length)];
    
    return PowerUp(
      x: x,
      y: y,
      type: type,
    );
  }
}

// Active power-up state manager
class ActivePowerUp {
  PowerUpType type;
  int remainingTime;
  bool isActive;
  
  ActivePowerUp({
    required this.type,
    required this.remainingTime,
    this.isActive = true,
  });
  
  // Update power-up timer
  void update() {
    if (isActive && remainingTime > 0) {
      remainingTime--;
      if (remainingTime <= 0) {
        isActive = false;
      }
    }
  }
  
  // Get duration for power-up type in frames (at 60fps)
  static int getDuration(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return 600; // 10 seconds
      case PowerUpType.rapidFire:
        return 480; // 8 seconds
      case PowerUpType.tripleShot:
        return 360; // 6 seconds
      case PowerUpType.laserBeam:
        return 240; // 4 seconds
    }
  }
  
  // Get display name for power-up
  String get displayName {
    switch (type) {
      case PowerUpType.shield:
        return 'Shield Activated!';
      case PowerUpType.rapidFire:
        return 'Rapid Fire!';
      case PowerUpType.tripleShot:
        return 'Triple Shot!';
      case PowerUpType.laserBeam:
        return 'Laser Beam!';
    }
  }
}

// Laser beam for laser power-up
class LaserBeam extends GameObject {
  double speedY;
  
  LaserBeam({
    required double x,
    required double y,
    double width = 8,
    required double height,
    this.speedY = 0,
  }) : super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Update laser beam (it doesn't move, just exists)
  void update() {
    // Laser beam is stationary
  }
}

// Floating text for power-up notifications
class FloatingText {
  String text;
  double x;
  double y;
  double speedY;
  int lifeTimer;
  Color color;
  
  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    this.speedY = -1,
    this.lifeTimer = 120, // 2 seconds at 60fps
    this.color = Colors.yellow,
  });
  
  // Update floating text position and lifetime
  void update() {
    y += speedY;
    lifeTimer--;
  }
  
  // Check if text is still visible
  bool get isVisible => lifeTimer > 0;
  
  // Get opacity based on remaining lifetime
  double get opacity {
    return (lifeTimer / 120.0).clamp(0.0, 1.0);
  }
}

// Particle system for explosion effects
class Particle {
  double x;
  double y;
  double speedX;
  double speedY;
  double size;
  Color color;
  int lifeTimer;
  int maxLifeTime;
  
  Particle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.color,
    this.lifeTimer = 60,
  }) : maxLifeTime = lifeTimer;
  
  // Update particle position and lifetime
  void update() {
    x += speedX;
    y += speedY;
    lifeTimer--;
    
    // Apply gravity-like effect
    speedY += 0.1;
    
    // Slight air resistance
    speedX *= 0.98;
    speedY *= 0.98;
  }
  
  // Check if particle is still alive
  bool get isAlive => lifeTimer > 0;
  
  // Get opacity based on remaining lifetime
  double get opacity {
    return (lifeTimer / maxLifeTime.toDouble()).clamp(0.0, 1.0);
  }
  
  // Get current size based on lifetime (shrinks over time)
  double get currentSize {
    final progress = 1.0 - (lifeTimer / maxLifeTime.toDouble());
    return size * (1.0 - progress * 0.5); // Shrinks to 50% of original size
  }
}

// Explosion effect system
class ExplosionEffect {
  double x;
  double y;
  List<Particle> particles;
  int duration;
  
  ExplosionEffect({
    required this.x,
    required this.y,
    int particleCount = 8,
    this.duration = 60,
  }) : particles = [] {
    _createParticles(particleCount);
  }
  
  void _createParticles(int count) {
    final random = Random();
    
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi;
      final speed = 1.0 + random.nextDouble() * 3.0;
      
      particles.add(Particle(
        x: x,
        y: y,
        speedX: cos(angle) * speed,
        speedY: sin(angle) * speed,
        size: 2.0 + random.nextDouble() * 4.0,
        color: _getRandomExplosionColor(random),
        lifeTimer: 30 + random.nextInt(30), // 0.5 to 1 second
      ));
    }
  }
  
  Color _getRandomExplosionColor(Random random) {
    final colors = [
      Colors.orange,
      Colors.red,
      Colors.yellow,
      Colors.deepOrange,
      Colors.amber,
    ];
    return colors[random.nextInt(colors.length)];
  }
  
  // Update all particles in the explosion
  void update() {
    for (var particle in particles) {
      particle.update();
    }
    
    // Remove dead particles
    particles.removeWhere((particle) => !particle.isAlive);
    
    duration--;
  }
  
  // Check if explosion is still active
  bool get isActive => particles.isNotEmpty && duration > 0;
}

// Hit effect for enemies
class HitEffect {
  double x;
  double y;
  Color color;
  int lifeTimer;
  double size;
  
  HitEffect({
    required this.x,
    required this.y,
    required this.color,
    this.lifeTimer = 30,
    this.size = 20.0,
  });
  
  void update() {
    lifeTimer--;
  }
  
  bool get isActive => lifeTimer > 0;
  
  double get opacity {
    return (lifeTimer / 30.0).clamp(0.0, 1.0);
  }
  
  double get currentSize {
    final progress = 1.0 - (lifeTimer / 30.0);
    return size * (1.0 + progress * 0.5); // Grows slightly over time
  }
}

// Enemy types enum
enum EnemyType {
  normalAsteroid,
  smallFastAsteroid,
  hugeSowAsteroid,
  ufo,
  bossUfo,
}

// Base Enemy class
abstract class Enemy extends GameObject {
  EnemyType type;
  int health;
  int maxHealth;
  int scoreValue;
  
  Enemy({
    required this.type,
    required double x,
    required double y,
    required double width,
    required double height,
    required this.health,
    required this.scoreValue,
  }) : maxHealth = health,
       super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Take damage and return true if destroyed
  bool takeDamage(int damage) {
    health -= damage;
    if (health <= 0) {
      isVisible = false;
      return true;
    }
    return false;
  }
  
  // Abstract update method
  void update(double screenHeight, double screenWidth);
}

// Small Fast Asteroid
class SmallFastAsteroid extends Enemy {
  double speedY;
  double rotationAngle;
  double rotationSpeed;
  
  SmallFastAsteroid({
    required double x,
    required double y,
    required double size,
    required this.speedY,
    this.rotationAngle = 0,
    this.rotationSpeed = 0,
  }) : super(
          type: EnemyType.smallFastAsteroid,
          x: x,
          y: y,
          width: size,
          height: size,
          health: 1,
          scoreValue: 15, // Small fast asteroid: 15 points
        );
  
  @override
  void update(double screenHeight, double screenWidth) {
    y += speedY;
    rotationAngle += rotationSpeed;
    
    if (y > screenHeight) {
      isVisible = false;
    }
  }
  
  static SmallFastAsteroid random(double screenWidth, double asteroidSize) {
    final random = Random();
    final size = asteroidSize * 0.5; // 50% smaller
    
    return SmallFastAsteroid(
      x: random.nextDouble() * (screenWidth - size),
      y: -size - random.nextDouble() * 300,
      size: size,
      speedY: (1 + random.nextDouble() * 3) * 1.8, // 1.8x speed
      rotationSpeed: (random.nextDouble() - 0.5) * 0.15,
    );
  }
}

// Huge Slow Asteroid
class HugeSlowAsteroid extends Enemy {
  double speedY;
  double rotationAngle;
  double rotationSpeed;
  
  HugeSlowAsteroid({
    required double x,
    required double y,
    required double size,
    required this.speedY,
    this.rotationAngle = 0,
    this.rotationSpeed = 0,
  }) : super(
          type: EnemyType.hugeSowAsteroid,
          x: x,
          y: y,
          width: size,
          height: size,
          health: 3,
          scoreValue: 30, // Huge slow asteroid: 30 points
        );
  
  @override
  void update(double screenHeight, double screenWidth) {
    y += speedY;
    rotationAngle += rotationSpeed;
    
    if (y > screenHeight) {
      isVisible = false;
    }
  }
  
  static HugeSlowAsteroid random(double screenWidth, double asteroidSize) {
    final random = Random();
    final size = asteroidSize * 2.0; // 2x bigger
    
    return HugeSlowAsteroid(
      x: random.nextDouble() * (screenWidth - size),
      y: -size - random.nextDouble() * 300,
      size: size,
      speedY: (1 + random.nextDouble() * 3) * 0.5, // 0.5x speed
      rotationSpeed: (random.nextDouble() - 0.5) * 0.05,
    );
  }
}

// Enemy UFO
class EnemyUFO extends Enemy {
  double speedX;
  int lastShotFrame;
  final int shootInterval = 90; // 1.5 seconds at 60fps
  int frameCount;
  
  EnemyUFO({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedX,
  }) : lastShotFrame = 0,
       frameCount = 0,
       super(
          type: EnemyType.ufo,
          x: x,
          y: y,
          width: width,
          height: height,
          health: 5,
          scoreValue: 40, // UFO: 40 points
        );
  
  @override
  void update(double screenHeight, double screenWidth) {
    x += speedX;
    frameCount++;
    
    // Reverse direction at screen edges
    if (x <= 0 || x >= screenWidth - width) {
      speedX *= -1;
    }
    
    // Move down screen slowly
    y += 0.5;
    
    if (y > screenHeight) {
      isVisible = false;
    }
  }
  
  // Check if UFO should shoot
  bool shouldShoot() {
    if (frameCount - lastShotFrame >= shootInterval) {
      lastShotFrame = frameCount;
      return true;
    }
    return false;
  }
  
  static EnemyUFO random(double screenWidth, double ufoSize) {
    final random = Random();
    
    return EnemyUFO(
      x: random.nextDouble() * (screenWidth - ufoSize),
      y: -ufoSize,
      width: ufoSize,
      height: ufoSize * 0.6,
      speedX: (random.nextBool() ? 1 : -1) * (1 + random.nextDouble()),
    );
  }
}

// Boss UFO
class BossUFO extends Enemy {
  double speedX;
  double baseY;
  int lastShotFrame;
  final int shootInterval = 60; // 1 second at 60fps
  int frameCount;
  double zigzagAmplitude = 100;
  
  BossUFO({
    required double x,
    required double y,
    required double width,
    required double height,
  }) : speedX = 2.0,
       baseY = y,
       lastShotFrame = 0,
       frameCount = 0,
       super(
          type: EnemyType.bossUfo,
          x: x,
          y: y,
          width: width,
          height: height,
          health: 50,
          scoreValue: 200, // Boss UFO: 200 points
        );
  
  @override
  void update(double screenHeight, double screenWidth) {
    frameCount++;
    
    // Zigzag movement pattern
    x += speedX;
    y = baseY + sin(frameCount * 0.05) * 50;
    
    // Reverse direction at screen edges
    if (x <= 0 || x >= screenWidth - width) {
      speedX *= -1;
    }
  }
  
  // Check if Boss should shoot
  bool shouldShoot() {
    if (frameCount - lastShotFrame >= shootInterval) {
      lastShotFrame = frameCount;
      return true;
    }
    return false;
  }
  
  static BossUFO create(double screenWidth, double bossSize) {
    return BossUFO(
      x: screenWidth / 2 - bossSize / 2,
      y: 100,
      width: bossSize,
      height: bossSize * 0.8,
    );
  }
}

// Enemy bullet
class EnemyBullet extends GameObject {
  double speedY;
  double speedX;
  
  EnemyBullet({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedY,
    this.speedX = 0,
  }) : super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  void update(double screenHeight) {
    y += speedY;
    x += speedX;
    
    if (y > screenHeight || y < -height || x < -width || x > 1000) {
      isVisible = false;
    }
  }
}
