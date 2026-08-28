import 'dart:math';
import 'asteroids.dart';
import 'enums.dart';
import '../config/game_config.dart';
import '../config/score_values.dart';

/// A single unit of the Swarm Lords boss encounter (Boss Rush).
///
/// Ten of these replace the usual single boss. Each carries a small
/// energy shield that must be shot off before the hull takes damage,
/// and each fires single aimed bullets at the player on its own
/// staggered cadence. Units patrol horizontally, descend to a hover
/// band near the top of the screen, and never leave — the encounter
/// only ends when every unit is destroyed.
class SwarmUnit extends Enemy {
  double speedX;
  int frameCount;
  int lastShotFrame;
  final int shootInterval;

  /// Vertical position where descent stops; the unit bobs around it.
  final double hoverY;

  /// Per-unit phase offset so the swarm doesn't bob in unison.
  final double phase;

  int shieldHealth;
  final int maxShieldHealth;

  bool get hasShield => shieldHealth > 0;

  void damageShield(int damage) {
    shieldHealth = max(0, shieldHealth - damage);
  }

  SwarmUnit({
    required double x,
    required double y,
    required this.speedX,
    required this.hoverY,
    required this.shootInterval,
    required this.phase,
  })  : frameCount = 0,
        lastShotFrame = shootInterval ~/ 2,
        shieldHealth = GameConfig.swarmUnitShieldHealth,
        maxShieldHealth = GameConfig.swarmUnitShieldHealth,
        super(
          type: EnemyType.enemyShip,
          x: x,
          y: y,
          width: GameConfig.swarmUnitSize,
          height: GameConfig.swarmUnitSize,
          health: GameConfig.swarmUnitHealth,
          scoreValue: ScoreValues.swarmUnit,
        );

  @override
  void update(double screenHeight, double screenWidth) {
    frameCount++;

    // Horizontal patrol, bouncing off the screen edges.
    x += speedX;
    if (x <= 0 || x >= screenWidth - width) {
      speedX *= -1;
    }

    // Descend to the hover band, then bob gently — units never leave
    // the screen, so the fight can't be outlasted.
    if (y < hoverY) {
      y += 0.6;
    } else {
      y = hoverY + sin(frameCount * 0.06 + phase) * 8;
    }
  }

  bool shouldShoot() {
    if (frameCount - lastShotFrame >= shootInterval) {
      lastShotFrame = frameCount;
      return true;
    }
    return false;
  }
}
