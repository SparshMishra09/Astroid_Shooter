import 'package:flutter/material.dart';
import '../models/enums.dart';
import 'game_screen.dart';

/// Mode picker shown from the home screen's PLAY button.
///
/// One card per [GameMode]. Adding a mode = one entry here; everything
/// else (spawning, bosses, HUD labels) is driven by its GameModeConfig.
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo.shade900],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header row with back button
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'SELECT MODE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  // Spacer balancing the back button so the title stays centered
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _ModeCard(
                          mode: GameMode.classicRun,
                          icon: Icons.travel_explore,
                          iconColor: Colors.cyan,
                          gradient: [Color(0xFF0E7490), Color(0xFF155E75)],
                          title: 'CLASSIC RUN',
                          description: 'Endless waves of asteroids and enemy '
                              'fighters. Difficulty climbs every wave — the '
                              'boss dreadnought arrives every 150 kills.',
                        ),
                        SizedBox(height: 18),
                        _ModeCard(
                          mode: GameMode.bossRush,
                          icon: Icons.local_fire_department,
                          iconColor: Colors.red,
                          gradient: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                          title: 'BOSS RUSH',
                          description: 'No asteroids. No waves. One boss '
                              'after another in random order — tri-beam, '
                              'rapid-fire, penta-beam and the escort carrier '
                              'with its fighter minions.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.title,
    required this.description,
  });

  final GameMode mode;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(color: iconColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: iconColor.withOpacity(0.25), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => GameScreen(gameMode: mode)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: iconColor.withOpacity(0.6), width: 2),
                  ),
                  child: Icon(icon, color: iconColor, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: iconColor.withOpacity(0.8), size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
