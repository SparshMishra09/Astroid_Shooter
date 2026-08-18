import 'dart:math';
import 'asteroids.dart';
import 'enums.dart';
import '../config/game_config.dart';
import '../config/score_values.dart';

/// Boss dreadnought — a capital battleship that appears periodically.
///
/// Zigzags across the screen, fires downward, and has a large health
/// pool. Rendered as an armored dreadnought pointing DOWN.
///
/// Four variants exist (see [BossType]): they share the same hull and
/// movement but differ in health, score, fire rate, attack pattern and
/// energy-core color. The controller dispatches the attack pattern.
class Boss extends Enemy {
  final BossType bossType;
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
    this.bossType = BossType.triBeam,
    int health = 50,
    int scoreValue = ScoreValues.boss,
    this.shootInterval = 60, // 1 second @ 60fps
    this.speedX = GameConfig.triBeamBossSpeed,
    this.zigzagAmplitude = 100,
  })  : baseY = y,
        lastShotFrame = 0,
        frameCount = 0,
        super(
          type: EnemyType.boss,
          x: x,
          y: y,
          width: width,
          height: height,
          health: health,
          scoreValue: scoreValue,
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

  /// Player-facing name shown in the "BOSS INCOMING!" announcement.
  String get displayName {
    switch (bossType) {
      case BossType.triBeam:
        return 'TRI-BEAM DREADNOUGHT';
      case BossType.rapidFire:
        return 'RAPID-FIRE BOSS';
      case BossType.pentaBeam:
        return 'PENTA-BEAM BOSS';
      case BossType.marksman:
        return 'ESCORT CARRIER';
    }
  }

  /// The original dreadnought: 3-way spread, purple core.
  static Boss create(double screenWidth, double bossSize) {
    return createTyped(BossType.triBeam, screenWidth, bossSize);
  }

  /// Create a boss of a specific variant, centered at the top of the
  /// screen. Per-type stats (health / score / fire rate / speed) come
  /// from the balance table in [GameConfig] and [ScoreValues].
  static Boss createTyped(BossType type, double screenWidth, double bossSize) {
    switch (type) {
      case BossType.triBeam:
        return Boss(
          x: screenWidth / 2 - bossSize / 2,
          y: 100,
          width: bossSize,
          height: bossSize * 0.8,
          bossType: type,
          health: 50,
          scoreValue: ScoreValues.bossTriBeam,
          shootInterval: 60,
          speedX: GameConfig.triBeamBossSpeed,
        );
      case BossType.rapidFire:
        return Boss(
          x: screenWidth / 2 - bossSize / 2,
          y: 100,
          width: bossSize,
          height: bossSize * 0.8,
          bossType: type,
          health: 45,
          scoreValue: ScoreValues.bossRapidFire,
          shootInterval: GameConfig.rapidFireBossShootInterval,
          speedX: GameConfig.rapidFireBossSpeed,
        );
      case BossType.pentaBeam:
        return Boss(
          x: screenWidth / 2 - bossSize / 2,
          y: 100,
          width: bossSize,
          height: bossSize * 0.8,
          bossType: type,
          health: 60,
          scoreValue: ScoreValues.bossPentaBeam,
          shootInterval: GameConfig.pentaBeamBossShootInterval,
          speedX: GameConfig.pentaBeamBossSpeed,
          zigzagAmplitude: 130,
        );
      case BossType.marksman:
        return Boss(
          x: screenWidth / 2 - bossSize / 2,
          y: 100,
          width: bossSize,
          height: bossSize * 0.8,
          bossType: type,
          health: 70,
          scoreValue: ScoreValues.bossMarksman,
          shootInterval: GameConfig.marksmanBossShootInterval,
          speedX: GameConfig.marksmanBossSpeed,
        );
    }
  }
}
