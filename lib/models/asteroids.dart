import 'dart:math';
import 'game_object.dart';
import 'enums.dart';
import '../config/game_config.dart';
import '../config/score_values.dart';

/// Base asteroid (uses the approved SVG asset for rendering).
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
  }) : super(x: x, y: y, width: width, height: height);

  void update(double screenHeight) {
    y += speedY;
    rotationAngle += rotationSpeed;
    if (y > screenHeight) isVisible = false;
  }

  static Asteroid random(double screenWidth, double asteroidSize) {
    final random = Random();
    return Asteroid(
      x: random.nextDouble() * (screenWidth - asteroidSize),
      y: -asteroidSize - random.nextDouble() * 300,
      width: asteroidSize,
      height: asteroidSize,
      speedY: 1 + random.nextDouble() * 3,
      rotationSpeed: (random.nextDouble() - 0.5) * 0.1,
    );
  }
}

/// Base class for asteroids that count as enemies (health, score, damage).
abstract class Enemy extends GameObject {
  final EnemyType type;
  int health;
  late final int maxHealth;
  final int scoreValue;

  Enemy({
    required this.type,
    required double x,
    required double y,
    required double width,
    required double height,
    required this.health,
    required this.scoreValue,
  })  : maxHealth = health,
        super(x: x, y: y, width: width, height: height);

  /// Apply damage. Returns true if the enemy was destroyed this hit.
  bool takeDamage(int damage) {
    health -= damage;
    if (health <= 0) {
      isVisible = false;
      return true;
    }
    return false;
  }

  void update(double screenHeight, double screenWidth);
}

/// Small, fast, low-health asteroid. Signals danger with a glowing edge.
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
          scoreValue: ScoreValues.smallFastAsteroid,
        );

  @override
  void update(double screenHeight, double screenWidth) {
    y += speedY;
    rotationAngle += rotationSpeed;
    if (y > screenHeight) isVisible = false;
  }

  static SmallFastAsteroid random(double screenWidth, double asteroidSize) {
    final random = Random();
    final size = asteroidSize * GameConfig.smallAsteroidScale;
    return SmallFastAsteroid(
      x: random.nextDouble() * (screenWidth - size),
      y: -size - random.nextDouble() * 300,
      size: size,
      speedY: (1 + random.nextDouble() * 3) * 1.8,
      rotationSpeed: (random.nextDouble() - 0.5) * 0.15,
    );
  }
}

/// Large, slow, multi-hit asteroid. Splits into small ones when destroyed.
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
          type: EnemyType.hugeSlowAsteroid,
          x: x,
          y: y,
          width: size,
          height: size,
          health: 3,
          scoreValue: ScoreValues.hugeSlowAsteroid,
        );

  @override
  void update(double screenHeight, double screenWidth) {
    y += speedY;
    rotationAngle += rotationSpeed;
    if (y > screenHeight) isVisible = false;
  }

  static HugeSlowAsteroid random(double screenWidth, double asteroidSize) {
    final random = Random();
    final size = asteroidSize * GameConfig.hugeAsteroidScale;
    return HugeSlowAsteroid(
      x: random.nextDouble() * (screenWidth - size),
      y: -size - random.nextDouble() * 300,
      size: size,
      speedY: (1 + random.nextDouble() * 3) * 0.5,
      rotationSpeed: (random.nextDouble() - 0.5) * 0.05,
    );
  }
}
