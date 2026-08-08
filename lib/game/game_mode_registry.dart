import '../models/enums.dart';
import 'game_mode.dart';
import 'classic_run_mode.dart';

/// Look up the [GameModeConfig] implementation for a [GameMode].
///
/// Kept in its own file so the interface and its impls don't reference
/// each other circularly.
GameModeConfig gameModeConfigFor(GameMode mode) {
  switch (mode) {
    case GameMode.classicRun:
      return ClassicRunMode();
  }
}
