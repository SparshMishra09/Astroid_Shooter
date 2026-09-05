import '../models/enums.dart';

/// Central place for all tunable game constants.
///
/// Keeping every magic number here makes the game easy to balance and
/// tweak without hunting through the codebase.
class GameConfig {
  GameConfig._();

  // --- Player ---
  static const double playerSize = 50;

  // --- Asteroids ---
  static const double asteroidSize = 40;
  static const double smallAsteroidScale = 0.5; // 50% of normal
  static const double hugeAsteroidScale = 2.0; // 2x normal

  // --- Bullets ---
  static const double bulletWidth = 10;
  static const double bulletHeight = 20;
  static const double bulletSpeed = 10;
  static const double enemyBulletSpeed = 3;
  static const double bossBulletSpeed = 4;

  // --- Shooting ---
  static const int shotInterval = 15; // ~4 shots/sec at 60fps
  static const int rapidFireDivisor = 2; // halve interval when rapid fire active

  // --- Spawning ---
  static const int baseAsteroidSpawnRate = 45; // frames
  static const int minAsteroidSpawnRate = 18;
  static const int asteroidSpawnWaveStep = 3; // faster each wave
  static const int asteroidSpawnWaveCap = 30;

  static const int baseEnemySpawnInterval = 180; // 3 sec
  static const int enemySpawnWaveReduction = 20;
  static const int minEnemySpawnInterval = 90; // 1.5 sec

  // --- Enemy sizes ---
  static const double enemyShipSize = 60;
  static const double bossSize = 120;

  // --- Boss ---
  static const int bossKillThreshold = 150; // boss every 150 destroyed

  // --- Boss Rush mode ---
  static const int bossRushRespawnDelay = 600; // 10s between bosses
  static const int bossRushInitialDelay = 180; // 3s before first boss
  static const int bossRushPowerUpBaseInterval = 600; // 10s base
  static const int bossRushPowerUpMinInterval = 300; // 5s floor
  static const int bossRushPowerUpWaveStep = 15; // faster per boss defeated

  // --- Boss variant attack intervals (frames @ 60fps) ---
  static const int rapidFireBossShootInterval = 12; // ~5 shots/sec
  static const int pentaBeamBossShootInterval = 75; // 1.25s
  static const int marksmanBossShootInterval = 90; // 1.5s
  static const int marksmanMinionCount = 3; // escorts spawned with boss

  // --- Shielded burst boss (Bulwark Sentinel) ---
  static const int shieldedBossShieldHealth = 15; // hits to break shield
  static const int shieldedBossShootInterval = 150; // 2.5s between bursts
  static const int bossBurstBulletCount = 10; // bullets per burst line
  static const int bossBurstBulletInterval = 5; // frames between burst shots
  static const double shieldedBossSpeed = 1.6;

  // --- Laser cannon boss (Void Lancer) ---
  static const int laserBossShootInterval = 240; // 4s between laser cycles
  static const int bossLaserChargeDuration = 60; // 1s telegraph before beam
  static const int bossLaserFireDuration = 75; // 1.25s beam
  static const double bossLaserWidth = 26;
  static const double laserBossSpeed = 1.9;

  // --- Bombardier boss (Demolition Titan) ---
  static const int bombardierShootInterval = 120; // 2s between drops
  static const int bombardierBarrelsPerVolley = 2; // barrels per drop
  static const double bombardierSpeed = 1.7;
  static const double bombBarrelSpeed = 3.0;
  static const double bombBarrelWidth = 18;
  static const double bombBarrelHeight = 24;
  static const double bombExplosionRadius = 85; // blast damage radius

  // --- Serpent volley boss (Serpent Volley) ---
  static const int serpentShootInterval = 130; // ~2.2s between volleys
  static const int serpentBulletCount = 7; // bullets in the V formation
  static const double serpentBulletGap = 26; // vertical stagger per row
  static const double serpentBulletSpeed = 3.2;
  static const double serpentBossSpeed = 1.8;

  // --- Swarm Lords boss (Boss Rush) ---
  static const int swarmUnitCount = 20; // units per encounter
  static const int swarmUnitsPerRow = 5; // columns per deployment row
  static const int swarmUnitShieldHealth = 2; // shield hits per unit
  static const int swarmUnitHealth = 1; // hull hits after shield breaks
  static const double swarmUnitSize = 34;
  static const int swarmUnitShootInterval = 150; // ~2.5s, staggered per unit
  static const double swarmUnitBulletSpeed = 3.0;
  static const double swarmUnitSpeed = 1.2; // horizontal patrol
  static const double swarmHoverY = 110; // descent stops here (bob band)
  static const double swarmRowGap = 46; // vertical spacing between rows

  // --- Boss variant movement ---
  static const double triBeamBossSpeed = 2.0;
  static const double rapidFireBossSpeed = 3.0;
  static const double pentaBeamBossSpeed = 1.8;
  static const double marksmanBossSpeed = 2.2;

  // --- Boss Rush power-up weighting ---
  // Laser weight relative to 1.0 for each other ability. With the other
  // three at 1.0, 0.33 gives the laser ~10% of drops (vs 25% uniform) —
  // rare enough that it can't carry every boss fight, common enough
  // that landing one feels like a jackpot.
  static const double bossRushLaserPowerUpWeight = 0.33;

  // --- Wing drones rarity (both modes) ---
  // Two extra rapid-firing ships is the strongest ability in the game,
  // so it drops at roughly a third of the normal rate — common enough
  // to find, rare enough that runs stay challenging.
  static const double wingDronesPowerUpWeight = 0.35;

  // --- Power-up drop ---
  static const double powerUpDropChance = 0.05; // 5%
  static const double waveBreakBonusDropChance = 0.20; // 20%
  static const int bossPowerUpDropCount = 2;

  // --- Wave system (all durations in frames @ 60fps) ---
  static const int waveMinDuration = 2100; // 35 seconds
  static const int waveMaxDuration = 2700; // 45 seconds
  static const int waveBreakDuration = 180; // 3 seconds
  static const int waveCompleteDisplayTime = 120; // 2 seconds
  static const int waveStartDisplayTime = 90; // 1.5 seconds
  static const int waveDurationStep = 50; // extra frames per wave

  // --- Wave bonus ---
  static const int waveBonusBase = 200;

  // --- Player ---
  static const int playerStartLives = 3;
  static const int invulnerabilityFrames = 90; // ~1.5 seconds
  static const int blinkFrames = 10; // invulnerability blink rate

  // --- Power-up durations (frames @ 60fps) ---
  static const int shieldDuration = 600; // 10 seconds
  static const int rapidFireDuration = 480; // 8 seconds
  static const int tripleShotDuration = 360; // 6 seconds
  static const int laserBeamDuration = 240; // 4 seconds
  static const int pentaShotDuration = 420; // 7 seconds
  static const int wingDronesDuration = 540; // 9 seconds

  // --- Penta shot (Λ formation) ---
  /// Fire-cadence multiplier while penta shot is active — five bullets
  /// per volley is a big payload, so the gun fires markedly slower
  /// (~1.6 volleys/sec vs ~4 singles/sec). Rapid fire halves it back.
  static const double pentaShotRateMultiplier = 2.5;

  // --- Wing drones ---
  static const double droneOffsetX = 42; // flank distance from ship center
  static const double droneSize = 26;
  static const int droneShootInterval = 7; // ~8.5 shots/sec (rapid fire)

  // --- Power-up drop object ---
  static const double powerUpSize = 30;
  static const double powerUpFallSpeed = 1.5;
  static const int powerUpLifeTime = 900; // 15 seconds

  // --- Game loop ---
  static const Duration gameTickDuration = Duration(milliseconds: 16);

  // --- Difficulty (game speed) ---
  // The whole game runs on a fixed-step loop; shrinking the step makes
  // EVERYTHING proportionally faster — entities, bullets, spawns, boss
  // cycles, animations — without touching a single balance constant.
  static const Duration cadetTickDuration = Duration(milliseconds: 16); // 1.0x
  static const Duration veteranTickDuration = Duration(milliseconds: 12); // ~1.33x
  static const Duration aceTickDuration = Duration(milliseconds: 10); // 1.6x

  static Duration tickDurationFor(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.cadet:
        return cadetTickDuration;
      case DifficultyLevel.veteran:
        return veteranTickDuration;
      case DifficultyLevel.ace:
        return aceTickDuration;
    }
  }

  // --- Combo system ---
  static const double comboStep = 0.2;
  static const double comboMax = 3.0;

  // --- Screen defaults (updated at runtime) ---
  static const double defaultScreenWidth = 400;
  static const double defaultScreenHeight = 600;
  static const double playerBottomPadding = 80;
}
