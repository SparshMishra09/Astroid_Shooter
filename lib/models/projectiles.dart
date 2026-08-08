import 'game_object.dart';

/// Player-fired bullet (travels upward).
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
