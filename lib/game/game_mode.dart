import '../models/enums.dart';
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

  /// Wave intro sub-text shown to the player.
  String waveIntroText(int wave);

  /// Short wave notification sub-text.
  String waveNotifyText(int wave);
}

/// Look up the config for a [GameMode]. Defined in `game_mode_registry.dart`
/// to avoid circular references between the interface and its impls.
