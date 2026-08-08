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

  // --- Power-up drop object ---
  static const double powerUpSize = 30;
  static const double powerUpFallSpeed = 1.5;
  static const int powerUpLifeTime = 900; // 15 seconds

  // --- Game loop ---
  static const Duration gameTickDuration = Duration(milliseconds: 16);

  // --- Combo system ---
  static const double comboStep = 0.2;
  static const double comboMax = 3.0;

  // --- Screen defaults (updated at runtime) ---
  static const double defaultScreenWidth = 400;
  static const double defaultScreenHeight = 600;
  static const double playerBottomPadding = 80;
}
