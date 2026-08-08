import 'game_object.dart';
import '../config/game_config.dart';

/// Player spaceship with lives, i-frames and a combo multiplier system.
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
    this.lives = GameConfig.playerStartLives,
    this.isInvulnerable = false,
    this.invulnerabilityTimer = 0,
  })  : comboMultiplier = 1.0,
        consecutiveHits = 0,
        lastShotHit = false,
        super(x: x, y: y, width: width, height: height);

  /// Move player horizontally, clamped to screen bounds.
  void moveTo(double newX, double screenWidth) {
    if (newX >= 0 && newX <= screenWidth - width) {
      x = newX;
    }
  }

  /// Take a hit unless invulnerable. Grants brief i-frames.
  void hit() {
    if (!isInvulnerable && lives > 0) {
      lives--;
      isInvulnerable = true;
      invulnerabilityTimer = GameConfig.invulnerabilityFrames;
    }
  }

  /// Per-frame player state update.
  void update() {
    if (isInvulnerable) {
      invulnerabilityTimer--;
      if (invulnerabilityTimer <= 0) {
        isInvulnerable = false;
      }
    }
  }

  // --- Combo system ---

  void registerHit() {
    consecutiveHits++;
    lastShotHit = true;
    comboMultiplier =
        (1.0 + (consecutiveHits * GameConfig.comboStep)).clamp(1.0, GameConfig.comboMax);
  }

  void registerMiss() => _resetCombo();

  void resetComboOnDamage() => _resetCombo();

  void _resetCombo() {
    consecutiveHits = 0;
    comboMultiplier = 1.0;
    lastShotHit = false;
  }

  bool get hasCombo => comboMultiplier > 1.0;
  String get comboText => 'COMBO x${comboMultiplier.toStringAsFixed(1)}';

  /// Apply the combo multiplier to a base score.
  int calculateScore(int baseScore) => (baseScore * comboMultiplier).round();
}
