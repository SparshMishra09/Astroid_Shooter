import 'dart:math';
import 'asteroids.dart';
import 'enums.dart';
import '../config/game_config.dart';
import '../config/score_values.dart';

/// Phases of the laser cannon boss's attack cycle.
enum BossLaserPhase {
  /// Not attacking — boss moves normally.
  idle,

  /// Telegraph: the cannon glows and a thin blinking warning line shows
  /// where the beam will fire. Boss is stationary.
  charging,

  /// The beam is live — instantly lethal on contact unless the player
  /// has an active shield. Boss is stationary.
  firing,
}

/// Boss dreadnought — a capital battleship that appears periodically.
///
/// Zigzags across the screen, fires downward, and has a large health
/// pool. Rendered as an armored dreadnought pointing DOWN.
///
/// Six variants exist (see [BossType]): they share the same hull but
/// differ in health, score, fire rate, attack pattern and extras. The
/// controller dispatches the attack pattern; this class only holds the
/// per-variant state (shield charge, burst progress, laser phase).
class Boss extends Enemy {
  final BossType bossType;
  double speedX;
  double baseY;
  int lastShotFrame;
  final int shootInterval;
  int frameCount;
  double zigzagAmplitude;

  // --- Shield (shieldedBurst variant) ---
  /// Remaining shield hits. While > 0, damage goes to the shield, not
  /// the hull. Rendered as a cracking energy dome over the boss.
  int shieldHealth;
  final int maxShieldHealth;

  bool get hasShield => shieldHealth > 0;

  // --- Burst fire state (shieldedBurst variant) ---
  /// Shots left in the current 3-bullet burst.
  int burstShotsRemaining = 0;

  /// Frame on which the next burst bullet may fire.
  int burstNextShotFrame = 0;

  /// Aim direction shared by every bullet in the current burst (locked
  /// when the burst starts so the string travels as one dodgeable line).
  double burstDirX = 0;
  double burstDirY = 1;

  // --- Laser cannon state (laserCannon variant) ---
  BossLaserPhase laserPhase = BossLaserPhase.idle;
  int laserTimer = 0;

  /// 0..1 how charged the cannon is — drives the painter's glow.
  double get laserChargeProgress {
    switch (laserPhase) {
      case BossLaserPhase.idle:
        return 0;
      case BossLaserPhase.charging:
        return (1 - laserTimer / GameConfig.bossLaserChargeDuration)
            .clamp(0.0, 1.0);
      case BossLaserPhase.firing:
        return 1;
    }
  }

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
    int shield = 0,
  })  : baseY = y,
        lastShotFrame = 0,
        frameCount = 0,
        shieldHealth = shield,
        maxShieldHealth = shield,
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

    // The laser cannon locks down while charging/firing its beam.
    if (bossType == BossType.laserCannon && laserPhase != BossLaserPhase.idle) {
      laserTimer--;
      if (laserPhase == BossLaserPhase.charging && laserTimer <= 0) {
        laserPhase = BossLaserPhase.firing;
        laserTimer = GameConfig.bossLaserFireDuration;
      } else if (laserPhase == BossLaserPhase.firing && laserTimer <= 0) {
        laserPhase = BossLaserPhase.idle;
        laserTimer = 0;
      }
      return; // stationary while the beam cycle runs
    }

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

  /// Chip the shield (shieldedBurst variant only).
  void damageShield(int damage) {
    shieldHealth = max(0, shieldHealth - damage);
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
      case BossType.shieldedBurst:
        return 'BULWARK SENTINEL';
      case BossType.laserCannon:
        return 'VOID LANCER';
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
      case BossType.shieldedBurst:
        return Boss(
          x: screenWidth / 2 - bossSize / 2,
          y: 100,
          width: bossSize,
          height: bossSize * 0.8,
          bossType: type,
          health: 45,
          scoreValue: ScoreValues.bossShieldedBurst,
          shootInterval: GameConfig.shieldedBossShootInterval,
          speedX: GameConfig.shieldedBossSpeed,
          shield: GameConfig.shieldedBossShieldHealth,
        );
      case BossType.laserCannon:
        return Boss(
          x: screenWidth / 2 - bossSize / 2,
          y: 100,
          width: bossSize,
          height: bossSize * 0.8,
          bossType: type,
          health: 55,
          scoreValue: ScoreValues.bossLaserCannon,
          shootInterval: GameConfig.laserBossShootInterval,
          speedX: GameConfig.laserBossSpeed,
        );
    }
  }
}
