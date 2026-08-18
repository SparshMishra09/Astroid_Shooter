import 'dart:math';
import 'game_mode.dart';
import '../models/enums.dart';
import '../models/boss.dart';
import '../models/game_state.dart';
import '../models/power_ups.dart';
import '../config/game_config.dart';

/// The classic endless run: waves that grow harder, full power-up suite,
/// periodic boss dreadnought. This is the original game's behavior.
///
/// Extends (not implements) the interface so uniform power-up drop
/// weights are inherited unchanged — every ability stays at 25%.
class ClassicRunMode extends GameModeConfig {
  @override
  String get displayName => 'Classic Run';

  @override
  bool get powerUpsEnabled => true;

  @override
  bool get asteroidsEnabled => true;

  @override
  bool get specialEnemiesEnabled => true;

  @override
  bool get wavesEnabled => true;

  @override
  String get waveLabel => 'Wave';

  @override
  int get bossRespawnDelay => 0;

  @override
  int get initialBossDelay => 0;

  @override
  bool get randomPowerUpsEnabled => false;

  @override
  int getPowerUpSpawnInterval(GameState state) => 1 << 30; // unused

  @override
  Boss createBoss(int bossesDefeated, double screenWidth, double bossSize) {
    return Boss.create(screenWidth, bossSize);
  }

  @override
  int getShotInterval(GameState state, Map<PowerUpType, ActivePowerUp> active) {
    final rapid = active[PowerUpType.rapidFire];
    if (rapid != null && rapid.isActive) {
      return GameConfig.shotInterval ~/ GameConfig.rapidFireDivisor;
    }
    return GameConfig.shotInterval;
  }

  @override
  int getAsteroidSpawnRate(GameState state) {
    final baseRate = GameConfig.baseAsteroidSpawnRate;
    final waveAdjustment =
        (state.currentWave * GameConfig.asteroidSpawnWaveStep).clamp(0, GameConfig.asteroidSpawnWaveCap);
    return max(GameConfig.minAsteroidSpawnRate, baseRate - waveAdjustment);
  }

  @override
  int getEnemySpawnInterval(GameState state) {
    final waveReduction = (state.currentWave - 1) * GameConfig.enemySpawnWaveReduction;
    return max(GameConfig.minEnemySpawnInterval, GameConfig.baseEnemySpawnInterval - waveReduction);
  }

  /// Cumulative probability table. Enemy ship now appears from wave 3.
  @override
  Map<EnemyType, double> getEnemyProbabilities(int wave) {
    // Wave 1: only normal asteroids.
    if (wave == 1) {
      return {
        EnemyType.smallFastAsteroid: 0.0,
        EnemyType.hugeSlowAsteroid: 0.0,
        EnemyType.enemyShip: 0.0,
      };
    }

    // Wave 2: introduce small fast asteroids.
    if (wave == 2) {
      return {
        EnemyType.smallFastAsteroid: 0.15,
        EnemyType.hugeSlowAsteroid: 0.0,
        EnemyType.enemyShip: 0.0,
      };
    }

    // Wave 3: introduce enemy fighters (small chance) early.
    if (wave == 3) {
      return {
        EnemyType.smallFastAsteroid: 0.20,
        EnemyType.hugeSlowAsteroid: 0.0,
        EnemyType.enemyShip: 0.23, // 20% small + 3% enemy ship
      };
    }

    // Wave 4-5: add huge slow asteroids.
    if (wave <= 5) {
      return {
        EnemyType.smallFastAsteroid: 0.22,
        EnemyType.hugeSlowAsteroid: 0.27, // + 5% huge
        EnemyType.enemyShip: 0.32, // + 5% enemy ship
      };
    }

    // Wave 6-8: more of everything.
    if (wave <= 8) {
      return {
        EnemyType.smallFastAsteroid: 0.25,
        EnemyType.hugeSlowAsteroid: 0.33, // + 8% huge
        EnemyType.enemyShip: 0.41, // + 8% enemy ship
      };
    }

    // Wave 9-12: high pressure.
    if (wave <= 12) {
      return {
        EnemyType.smallFastAsteroid: 0.30,
        EnemyType.hugeSlowAsteroid: 0.42, // + 12% huge
        EnemyType.enemyShip: 0.52, // + 10% enemy ship
      };
    }

    // Wave 13+: maximum chaos.
    return {
      EnemyType.smallFastAsteroid: 0.35,
      EnemyType.hugeSlowAsteroid: 0.50, // + 15% huge
      EnemyType.enemyShip: 0.63, // + 13% enemy ship
    };
  }

  @override
  int getWaveDuration(int wave) {
    final extraTime = (wave * GameConfig.waveDurationStep)
        .clamp(0, GameConfig.waveMaxDuration - GameConfig.waveMinDuration);
    return GameConfig.waveMinDuration + extraTime;
  }

  @override
  bool shouldSpawnBoss(GameState state, int destroyed) {
    return destroyed >= GameConfig.bossKillThreshold;
  }

  @override
  String waveIntroText(int wave) {
    if (wave == 1) return 'Survive the asteroid field!';
    if (wave <= 2) return 'Fast asteroids incoming!';
    if (wave == 3) return 'Enemy fighters detected!';
    if (wave <= 5) return 'Beware of huge asteroids!';
    return 'Enemy fleet closing in!';
  }

  @override
  String waveNotifyText(int wave) {
    if (wave == 1) return 'Survive!';
    if (wave == 2) return 'Fast Rocks!';
    if (wave == 3) return 'Enemy Ships!';
    if (wave <= 5) return 'Huge Asteroids!';
    return 'Fleet Attack!';
  }
}
