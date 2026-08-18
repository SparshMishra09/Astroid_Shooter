import '../models/enums.dart';
import '../models/boss.dart';
import '../models/game_state.dart';
import '../models/power_ups.dart';

/// Strategy interface that defines how a game mode behaves.
///
/// To add a new mode:
///   1. Add an entry to [GameMode].
///   2. Create a class implementing [GameModeConfig] in `lib/game/`.
///   3. Register it in [gameModeConfigFor].
///
/// Everything that differs between modes (spawn rates, difficulty curve,
/// enemy mix, power-ups, boss rules) lives here — never in the screen.
abstract class GameModeConfig {
  /// Player-facing mode name (e.g. "Classic Run").
  String get displayName;

  /// Whether power-ups drop and activate in this mode.
  bool get powerUpsEnabled;

  /// Whether normal asteroids rain from the top. Boss Rush disables them.
  bool get asteroidsEnabled;

  /// Whether probability-table special enemies spawn (wave-based mix).
  /// Boss Rush disables them — its only minions come from the marksman
  /// boss, spawned directly by the controller.
  bool get specialEnemiesEnabled;

  /// Whether the timed wave system runs (wave progress, breaks, bonuses).
  /// Boss Rush replaces waves with a boss counter.
  bool get wavesEnabled;

  /// Player-facing label for the current stage: "Wave" or "Boss".
  String get waveLabel;

  /// Frames to wait after a boss is defeated before the next may spawn.
  int get bossRespawnDelay;

  /// Frames to wait at game start before the first boss may spawn.
  int get initialBossDelay;

  /// Whether power-ups spawn at random intervals (not only from kills).
  /// Boss Rush uses this because there are no asteroids to drop them.
  bool get randomPowerUpsEnabled;

  /// Relative drop weights per power-up type. The default is uniform,
  /// which yields the same odds for every type; modes override this to
  /// make specific abilities rarer (Boss Rush dampens the laser so it
  /// can't trivialize boss fights while keeping it a jackpot find).
  Map<PowerUpType, double> get powerUpWeights => const {
        PowerUpType.shield: 1,
        PowerUpType.rapidFire: 1,
        PowerUpType.tripleShot: 1,
        PowerUpType.laserBeam: 1,
      };

  /// Frames between random power-up spawns (when enabled).
  int getPowerUpSpawnInterval(GameState state);

  /// Frames between player shots, factoring in active power-ups.
  int getShotInterval(GameState state, Map<PowerUpType, ActivePowerUp> active);

  /// Frames between normal-asteroid spawns for the current wave.
  int getAsteroidSpawnRate(GameState state);

  /// Frames between special-enemy spawns for the current wave.
  int getEnemySpawnInterval(GameState state);

  /// Probability table (cumulative) for which special enemy spawns.
  /// Keys are enemy types; a roll < value means that type spawns.
  Map<EnemyType, double> getEnemyProbabilities(int wave);

  /// Wave duration in frames for the given wave number.
  int getWaveDuration(int wave);

  /// Whether a boss should spawn now given state and destroy count.
  bool shouldSpawnBoss(GameState state, int destroyed);

  /// Create the boss for this mode. [bossesDefeated] counts bosses killed
  /// so far this run — modes may use it to pick or cycle variants.
  Boss createBoss(int bossesDefeated, double screenWidth, double bossSize);

  /// Wave intro sub-text shown to the player.
  String waveIntroText(int wave);

  /// Short wave notification sub-text.
  String waveNotifyText(int wave);
}

/// Look up the config for a [GameMode]. Defined in `game_mode_registry.dart`
/// to avoid circular references between the interface and its impls.
