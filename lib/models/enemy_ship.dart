import 'dart:math';
import 'asteroids.dart';
import 'enums.dart';
import '../config/score_values.dart';

/// Enemy fighter — an evil twin of the player's ship.
///
/// Moves horizontally (bouncing off edges), slowly descends, and fires
/// downward at the player. Rendered pointing DOWN to signal hostility.
class EnemyShip extends Enemy {
  double speedX;
  int lastShotFrame;
  final int shootInterval;
  int frameCount;

  EnemyShip({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedX,
    this.shootInterval = 90, // 1.5 seconds @ 60fps
  })  : lastShotFrame = 0,
        frameCount = 0,
        super(
          type: EnemyType.enemyShip,
          x: x,
          y: y,
          width: width,
          height: height,
          health: 5,
          scoreValue: ScoreValues.enemyShip,
        );

  @override
  void update(double screenHeight, double screenWidth) {
    x += speedX;
    frameCount++;

    // Bounce off side walls
    if (x <= 0 || x >= screenWidth - width) {
      speedX *= -1;
    }

    // Drift downward
    y += 0.5;

    if (y > screenHeight) isVisible = false;
  }

  bool shouldShoot() {
    if (frameCount - lastShotFrame >= shootInterval) {
      lastShotFrame = frameCount;
      return true;
    }
    return false;
  }

  static EnemyShip random(double screenWidth, double shipSize) {
    final random = Random();
    return EnemyShip(
      x: random.nextDouble() * (screenWidth - shipSize),
      y: -shipSize,
      width: shipSize,
      height: shipSize * 0.6,
      speedX: (random.nextBool() ? 1 : -1) * (1 + random.nextDouble()),
    );
  }
}
