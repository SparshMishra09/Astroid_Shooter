import 'dart:math';
import 'game_mode.dart';
import '../models/enums.dart';
import '../models/boss.dart';
import '../models/game_state.dart';
import '../config/game_config.dart';

/// Boss Rush: no asteroids, no waves — an endless gauntlet of bosses.
///
/// Rules:
///   • Exactly one boss is on screen at a time. After each defeat there
///     is a 10-second breather before the next spawns.
///   • Boss order is RANDOM — any of the six variants (tri-beam,
///     rapid-fire, penta-beam, escort carrier, bulwark sentinel, void
///     lancer) can appear at any time, all with equal odds.
///   • The marksman (escort carrier) boss brings 3 enemy-fighter
///     minions that each fire single aimed-downward shots.
///   • The bulwark sentinel is shielded — break the dome before the
///     hull takes damage; it fires 3-bullet bursts in a straight line.
///   • The void lancer freezes to charge and fire a vertical instant-
///     kill laser (survivable only with an active shield).
///   • With no asteroids to farm, power-ups drop at random intervals so
///     the player can still use abilities.
///   • The laser beam is a RARE find here (~10% of drops instead of the
///     usual 25%): it shreds bosses so fast that letting it drop at the
///     normal rate would flatten the difficulty curve. The other three
///     abilities drop at their normal rates.
class BossRushMode extends GameModeConfig {
  @override
  String get displayName => 'Boss Rush';

  @override
  bool get powerUpsEnabled => true;

  @override
  bool get asteroidsEnabled => false;

  @override
  bool get specialEnemiesEnabled => false;

  @override
  bool get wavesEnabled => false;

  @override
  String get waveLabel => 'Boss';

  @override
  int get bossRespawnDelay => GameConfig.bossRushRespawnDelay;

  @override
  int get initialBossDelay => GameConfig.bossRushInitialDelay;

  @override
  bool get randomPowerUpsEnabled => true;

  /// Laser is rare here (boss-shredder), and wing drones — the game's
  /// strongest ability — are rare in every mode.
  @override
  Map<PowerUpType, double> get powerUpWeights => {
        PowerUpType.shield: 1,
        PowerUpType.rapidFire: 1,
        PowerUpType.tripleShot: 1,
        PowerUpType.laserBeam: GameConfig.bossRushLaserPowerUpWeight,
        PowerUpType.pentaShot: 1,
        PowerUpType.wingDrones: GameConfig.wingDronesPowerUpWeight,
      };

  @override
  int getPowerUpSpawnInterval(GameState state) {
    // Power-ups arrive a little faster as more bosses fall (harder
    // fights, more frequent ability usage).
    final interval = GameConfig.bossRushPowerUpBaseInterval -
        state.currentWave * GameConfig.bossRushPowerUpWaveStep;
    return max(GameConfig.bossRushPowerUpMinInterval, interval);
  }

  // getShotInterval: inherited shared implementation (rapid fire halves
  // the cadence, penta shot slows it, both stack).

  // Asteroids never spawn in this mode; values are safe placeholders.
  @override
  int getAsteroidSpawnRate(GameState state) => 1 << 30;

  // Probability-table enemies never spawn; the escort carrier's minions
  // are spawned directly by the controller.
  @override
  int getEnemySpawnInterval(GameState state) => 1 << 30;

  @override
  Map<EnemyType, double> getEnemyProbabilities(int wave) => {
        EnemyType.smallFastAsteroid: 0.0,
        EnemyType.hugeSlowAsteroid: 0.0,
        EnemyType.enemyShip: 0.0,
      };

  // Waves never complete (wave system disabled); boss count is the stage.
  @override
  int getWaveDuration(int wave) => 1 << 30;

  /// Always true — the controller additionally gates on "no active
  /// boss" plus the respawn cooldown after each defeat.
  @override
  bool shouldSpawnBoss(GameState state, int destroyed) => true;

  /// The variants this mode may spawn, with equal odds. Explicit list
  /// so variants exclusive to other modes never leak in.
  static const List<BossType> _bossPool = [
    BossType.triBeam,
    BossType.rapidFire,
    BossType.pentaBeam,
    BossType.marksman,
    BossType.shieldedBurst,
    BossType.laserCannon,
    BossType.bombardier,
    BossType.serpentVolley,
  ];

  /// Boss order is RANDOM: any variant can be next, regardless of what
  /// was defeated before ([bossesDefeated] is ignored on purpose).
  @override
  Boss createBoss(int bossesDefeated, double screenWidth, double bossSize) {
    final type = _bossPool[Random().nextInt(_bossPool.length)];
    return Boss.createTyped(type, screenWidth, bossSize);
  }

  @override
  String waveIntroText(int wave) {
    return 'Defeat the bosses! Grab power-ups to survive!';
  }

  @override
  String waveNotifyText(int wave) {
    if (wave == 1) return 'First Boss Incoming!';
    if (wave <= 3) return 'The gauntlet begins!';
    if (wave <= 6) return 'They keep coming!';
    return 'Endless assault!';
  }
}
