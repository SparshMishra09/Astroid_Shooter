import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/player.dart';
import '../models/power_ups.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../game/game_mode.dart';
import '../config/game_config.dart';
import '../config/palette.dart';

// ============================================================
//  HUD
// ============================================================

/// Top-left HUD: wave badge, best astrids, lives, wave progress, power-ups.
class GameHUD extends StatelessWidget {
  const GameHUD({
    super.key,
    required this.gameState,
    required this.player,
    required this.mode,
    required this.activePowerUps,
    this.difficulty = DifficultyLevel.cadet,
  });

  final GameState gameState;
  final Player player;
  final GameModeConfig mode;
  final Map<PowerUpType, ActivePowerUp> activePowerUps;
  final DifficultyLevel difficulty;

  static const _difficultyStyle = {
    DifficultyLevel.cadet: (label: 'CADET', color: Color(0xFF4ADE80)),
    DifficultyLevel.veteran: (label: 'VETERAN', color: Color(0xFFFBBF24)),
    DifficultyLevel.ace: (label: 'ACE', color: Color(0xFFF87171)),
  };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Centered Astrids count
          Text(
            'Astrids: ${gameState.score}',
            style: const TextStyle(
              color: Palette.astridText,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mode + Wave badge, with the difficulty chip beside it
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Palette.waveBadgeStart.withOpacity(0.85),
                          Palette.waveBadgeEnd.withOpacity(0.85),
                        ]),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '${mode.displayName} · ${mode.waveLabel} ${gameState.currentWave}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _difficultyStyle[difficulty]!.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _difficultyStyle[difficulty]!.color.withOpacity(0.7),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed, size: 12, color: _difficultyStyle[difficulty]!.color),
                          const SizedBox(width: 4),
                          Text(
                            _difficultyStyle[difficulty]!.label,
                            style: TextStyle(
                              color: _difficultyStyle[difficulty]!.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Best astrids
                Text(
                  'Best: ${gameState.highScore} astrids',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 10),
                // Lives
                Row(
                  children: List.generate(
                    GameConfig.playerStartLives,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: index < player.lives
                          ? SvgPicture.asset('assets/images/heart.svg', width: 20, height: 20)
                          : SvgPicture.asset('assets/images/heart.svg',
                              width: 20, height: 20, color: Colors.grey.withOpacity(0.5)),
                    ),
                  ),
                ),
                // Wave progress (meaningless in boss-counter modes like
                // Boss Rush, where the stage advances on a boss kill)
                if (mode.wavesEnabled && !gameState.isWaveBreak)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wave Progress', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 5),
                        Container(
                          width: 100,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: gameState.getWaveProgress(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.green, Colors.yellow, Colors.red],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Wave break countdown
                if (gameState.isWaveBreak)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Next Wave: ${(gameState.waveBreakTimer / 60).ceil()}s',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // Active power-ups
                if (activePowerUps.isNotEmpty)
                  ...activePowerUps.entries.map((entry) {
                    final powerUp = entry.value;
                    if (!powerUp.isActive) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${powerUp.type.name.toUpperCase()}: ${(powerUp.remainingTime / 60).ceil()}s',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  COMBO DISPLAY
// ============================================================

class ComboDisplay extends StatelessWidget {
  const ComboDisplay({
    super.key,
    required this.player,
    required this.isFlashing,
    required this.flashValue,
  });

  final Player player;
  final bool isFlashing;
  final double flashValue;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      right: 20,
      child: Transform.scale(
        scale: isFlashing ? (1.0 + flashValue * 0.3) : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              isFlashing ? Colors.yellow.withOpacity(0.9) : Colors.orange.withOpacity(0.8),
              isFlashing ? Colors.orange.withOpacity(0.9) : Colors.red.withOpacity(0.8),
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isFlashing ? Colors.yellow : Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isFlashing ? Colors.yellow : Colors.orange).withOpacity(0.6),
                spreadRadius: isFlashing ? 4 : 2,
                blurRadius: isFlashing ? 8 : 4,
              ),
            ],
          ),
          child: Text(
            player.comboText,
            style: TextStyle(
              color: Colors.white,
              fontSize: isFlashing ? 16 : 14,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  WAVE NOTIFICATIONS (subtle, non-intrusive)
// ============================================================

class WaveStartNotification extends StatelessWidget {
  const WaveStartNotification({super.key, required this.gameState, required this.mode});
  final GameState gameState;
  final GameModeConfig mode;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 140,
      right: 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Palette.waveNotifyStart.withOpacity(0.9), Palette.waveNotifyEnd.withOpacity(0.9)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: Palette.waveNotifyStart.withOpacity(0.6), spreadRadius: 2, blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${mode.waveLabel.toUpperCase()} ${gameState.currentWave}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              mode.waveNotifyText(gameState.currentWave),
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveCompleteNotification extends StatelessWidget {
  const WaveCompleteNotification({super.key, required this.gameState});
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final bonus = 200 * (gameState.currentWave - 1);
    return Positioned(
      top: 140,
      right: 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Palette.waveCompleteStart.withOpacity(0.9), Palette.waveCompleteEnd.withOpacity(0.9)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: Palette.waveCompleteStart.withOpacity(0.6), spreadRadius: 2, blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Wave Complete!',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (bonus > 0) ...[
              const SizedBox(height: 4),
              Text('+$bonus astrids',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  PAUSE BUTTON + OVERLAYS
// ============================================================

class PauseButton extends StatelessWidget {
  const PauseButton({super.key, required this.isPaused, required this.onPressed});
  final bool isPaused;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: 10,
      child: IconButton(
        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onQuitToMenu,
  });
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuitToMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.cyan.withOpacity(0.1), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pause icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyan.withOpacity(0.4), width: 2),
                  color: Colors.cyan.withOpacity(0.05),
                ),
                child: const Icon(Icons.pause_rounded, color: Colors.cyan, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  shadows: [Shadow(color: Colors.cyan, blurRadius: 15)],
                ),
              ),
              const SizedBox(height: 28),

              // Resume button
              _OverlayButton(
                label: 'RESUME',
                icon: Icons.play_arrow_rounded,
                gradient: const [Colors.cyan, Colors.blue],
                textColor: Colors.white,
                onPressed: onResume,
              ),
              const SizedBox(height: 12),

              // Restart button
              _OverlayButton(
                label: 'RESTART',
                icon: Icons.refresh_rounded,
                gradient: [Colors.orange, Colors.red.shade700],
                textColor: Colors.white,
                onPressed: onRestart,
              ),
              const SizedBox(height: 12),

              // Quit to menu button
              _OverlayButton(
                label: 'QUIT TO MENU',
                icon: Icons.exit_to_app_rounded,
                gradient: [Colors.grey.shade700, Colors.grey.shade900],
                textColor: Colors.white70,
                onPressed: onQuitToMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.gameState,
    required this.asteroidsDestroyed,
    required this.isSaving,
    required this.onRestart,
    required this.onMainMenu,
    this.waveLabel = 'Wave',
  });

  final GameState gameState;
  final int asteroidsDestroyed;
  final bool isSaving;
  final VoidCallback onRestart;
  final VoidCallback onMainMenu;

  /// Stage label ("Wave" or "Boss") — shown over the current-stage stat.
  final String waveLabel;

  @override
  Widget build(BuildContext context) {
    final isNewBest = gameState.score >= gameState.highScore && gameState.score > 0;

    return Container(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Game over icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withOpacity(0.4), width: 2),
                  color: Colors.red.withOpacity(0.05),
                ),
                child: const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  shadows: [Shadow(color: Colors.red, blurRadius: 15)],
                ),
              ),
              if (isNewBest) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'NEW BEST!',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Stats grid
              Row(
                children: [
                  _StatBox(
                    label: 'ASTRIDS',
                    value: '${gameState.score}',
                    icon: Icons.stars,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 10),
                  _StatBox(
                    label: waveLabel.toUpperCase(),
                    value: '${gameState.currentWave}',
                    icon: Icons.waves,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  _StatBox(
                    label: 'DESTROYED',
                    value: '$asteroidsDestroyed',
                    icon: Icons.whatshot,
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Best score
              Text(
                'Best: ${gameState.highScore} astrids',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Saving indicator or buttons
              if (isSaving)
                Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(color: Colors.cyan, strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Saving progress...',
                      style: TextStyle(color: Colors.cyan.withOpacity(0.7), fontSize: 13),
                    ),
                  ],
                )
              else ...[
                _OverlayButton(
                  label: 'PLAY AGAIN',
                  icon: Icons.refresh_rounded,
                  gradient: const [Colors.cyan, Colors.blue],
                  textColor: Colors.white,
                  onPressed: onRestart,
                ),
                const SizedBox(height: 12),
                _OverlayButton(
                  label: 'MAIN MENU',
                  icon: Icons.home_rounded,
                  gradient: [Colors.indigo.shade600, Colors.indigo.shade900],
                  textColor: Colors.white70,
                  onPressed: onMainMenu,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A styled button used in overlays (pause + game over).
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small stat box shown in the game-over overlay.
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
