import 'dart:math' as math;
import 'game_object.dart';
import '../config/game_config.dart';

/// Player-fired bullet (travels upward).
class Bullet extends GameObject {
  double speedY;
  double speedX;

  /// True when fired by a wing drone — drone bullets hit enemies but
  /// never count as the player's shot for combo miss tracking.
  final bool fromDrone;

  Bullet({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedY,
    this.speedX = 0,
    this.fromDrone = false,
  }) : super(x: x, y: y, width: width, height: height);

  void update([double screenWidth = 1000]) {
    y -= speedY;
    x += speedX;
    if (y + height < 0 || x < -width || x > screenWidth + width) {
      isVisible = false;
    }
  }
}

/// Bullet fired by enemies/boss (travels downward).
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
  }) : super(x: x, y: y, width: width, height: height);

  void update(double screenHeight) {
    y += speedY;
    x += speedX;
    if (y > screenHeight || y < -height || x < -width || x > 1000) {
      isVisible = false;
    }
  }
}

/// Laser beam for the laser power-up. Stationary, follows the player x.
class LaserBeam extends GameObject {
  LaserBeam({
    required double x,
    required double y,
    double width = 8,
    required double height,
  }) : super(x: x, y: y, width: width, height: height);

  void update() {
    // Laser beam is stationary — position is updated by the controller.
  }
}

/// Bomb barrel dropped by the Demolition Titan boss. Falls toward the
/// player's level and detonates when it gets there (or early on player
/// contact) — the blast radius is what the player must dodge.
class BombBarrel extends GameObject {
  double speedY;
  double rotationSpeed;
  double rotationAngle;
  final double spawnY;

  /// Y coordinate at which the barrel detonates (the player's level).
  final double detonationY;

  BombBarrel({
    required double x,
    required double y,
    double width = GameConfig.bombBarrelWidth,
    double height = GameConfig.bombBarrelHeight,
    this.speedY = GameConfig.bombBarrelSpeed,
    required this.detonationY,
  })  : spawnY = y,
        rotationAngle = 0,
        rotationSpeed = math.Random().nextBool() ? 0.06 : -0.06,
        super(x: x, y: y, width: width, height: height);

  void update(double screenHeight) {
    y += speedY;
    rotationAngle += rotationSpeed;
    if (y > screenHeight) isVisible = false;
  }

  /// Detonates once the barrel reaches the player's level.
  bool get shouldExplode => y + height >= detonationY;

  /// 0 = just dropped, 1 = about to blow. Drives the warning glow.
  double get fallProgress =>
      ((y - spawnY) / (detonationY - spawnY)).clamp(0.0, 1.0);
}

/// Reusable structure for tracking a short-lived muzzle/engine flash.
class Flash {
  double x;
  double y;
  double size;
  int lifeTimer;
  final int maxLifeTime;
  final bool isUpward;

  Flash({
    required this.x,
    required this.y,
    this.size = 12,
    this.lifeTimer = 6,
    this.isUpward = true,
  }) : maxLifeTime = lifeTimer;

  void update() => lifeTimer--;

  bool get isActive => lifeTimer > 0;

  double get opacity => (lifeTimer / maxLifeTime.toDouble()).clamp(0.0, 1.0);
}
