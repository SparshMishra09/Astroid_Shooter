import '../config/game_config.dart';

/// Overall game state: astrids (score), high score, wave system, pause/gameover.
///
/// "Points" are called "astrids" everywhere the player sees them; the
/// internal field name `score` is unchanged so the stored high-score
/// preference key (`high_score`) needs no migration.
class GameState {
  int score = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isPaused = false;

  // Wave system
  int currentWave = 1;
  int wavesCompleted = 0; // total waves cleared this run (for progress tracking)
  int waveTimer = 0;
  int waveBreakTimer = 0;
  bool isWaveBreak = false;
  bool showWaveComplete = false;
  int waveCompleteTimer = 0;
  bool showWaveStart = false;
  int waveStartTimer = 0;

  void reset() {
    score = 0;
    isGameOver = false;
    isPaused = false;

    currentWave = 1;
    wavesCompleted = 0;
    waveTimer = 0;
    waveBreakTimer = 0;
    isWaveBreak = false;
    showWaveComplete = false;
    waveCompleteTimer = 0;
    showWaveStart = true;
    waveStartTimer = GameConfig.waveStartDisplayTime;
  }

  void updateHighScore() {
    if (score > highScore) highScore = score;
  }

  /// Wave duration in frames. Later waves last slightly longer.
  int getWaveDuration() {
    final baseLength = GameConfig.waveMinDuration;
    final extraTime =
        (currentWave * GameConfig.waveDurationStep).clamp(0, GameConfig.waveMaxDuration - GameConfig.waveMinDuration);
    return baseLength + extraTime;
  }

  void startNewWave() {
    currentWave++;
    waveTimer = 0;
    isWaveBreak = false;
    showWaveComplete = false;
    waveCompleteTimer = 0;
    showWaveStart = true;
    waveStartTimer = GameConfig.waveStartDisplayTime;
  }

  void completeWave() {
    isWaveBreak = true;
    waveBreakTimer = GameConfig.waveBreakDuration;
    showWaveComplete = true;
    waveCompleteTimer = GameConfig.waveCompleteDisplayTime;
    wavesCompleted++;
    score += GameConfig.waveBonusBase * currentWave;
  }

  void updateWaveSystem() {
    if (showWaveStart && waveStartTimer > 0) {
      waveStartTimer--;
      if (waveStartTimer <= 0) showWaveStart = false;
    }

    if (isWaveBreak) {
      waveBreakTimer--;
      if (waveCompleteTimer > 0) {
        waveCompleteTimer--;
        if (waveCompleteTimer <= 0) showWaveComplete = false;
      }
      if (waveBreakTimer <= 0) startNewWave();
    } else {
      waveTimer++;
      if (waveTimer >= getWaveDuration()) completeWave();
    }
  }

  double getWaveProgress() {
    if (isWaveBreak) return 0.0;
    return (waveTimer / getWaveDuration()).clamp(0.0, 1.0);
  }
}
