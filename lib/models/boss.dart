import 'dart:math';
import 'asteroids.dart';
import 'enums.dart';
import '../config/score_values.dart';

/// Boss dreadnought — a capital battleship that appears periodically.
///
/// Zigzags across the screen, fires a spread of bullets downward, and has
/// a large health pool. Rendered as an armored dreadnought pointing DOWN.
class Boss extends Enemy {
  double speedX;
  double baseY;
  int lastShotFrame;
  final int shootInterval;
  int frameCount;
  double zigzagAmplitude;

  Boss({
    required double x,
    required double y,
    required double width,
    required double height,
    this.shootInterval = 60, // 1 second @ 60fps
    this.zigzagAmplitude = 100,
  })  : speedX = 2.0,
        baseY = y,
        lastShotFrame = 0,
        frameCount = 0,
        super(
          type: EnemyType.boss,
          x: x,
          y: y,
          width: width,
          height: height,
          health: 50,
          scoreValue: ScoreValues.boss,
        );

  @override
  void update(double screenHeight, double screenWidth) {
    frameCount++;

    // Zigzag movement pattern
    x += speedX;
    y = baseY + sin(frameCount * 0.05) * 50;

    if (x <= 0 || x >= screenWidth - width) {
      speedX *= -1;
    }
  }

  bool shouldShoot() {
    if (frameCount - lastShotFrame >= shootInterval) {
      lastShotFrame = frameCount;
      return true;
    }
    return false;
  }

  static Boss create(double screenWidth, double bossSize) {
    return Boss(
      x: screenWidth / 2 - bossSize / 2,
      y: 100,
      width: bossSize,
      height: bossSize * 0.8,
    );
  }
}
