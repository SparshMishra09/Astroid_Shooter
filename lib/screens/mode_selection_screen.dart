import 'package:flutter/material.dart';
import '../models/enums.dart';
import 'game_screen.dart';

/// Two-step game launcher: first pick a game mode, then pick a
/// difficulty (the game's overall speed), then launch.
///
/// Step 1: one card per [GameMode].
/// Step 2: one card per [DifficultyLevel] with animated speed bars.
/// Both steps slide in/out with [AnimatedSwitcher] transitions.
class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen>
    with SingleTickerProviderStateMixin {
  /// null = step 1 (mode cards); set = step 2 (difficulty picker).
  GameMode? _pickedMode;

  static const _modeMeta = {
    GameMode.classicRun: (
      icon: Icons.travel_explore,
      iconColor: Color(0xFF22D3EE),
      gradient: [Color(0xFF0E7490), Color(0xFF155E75)],
      title: 'CLASSIC RUN',
      description: 'The endless voyage. Survive escalating waves of '
          'asteroids, fast-moving shards and enemy fighters — and when '
          'you hit 150 kills, a dreadnought comes for you.',
    ),
    GameMode.bossRush: (
      icon: Icons.local_fire_department,
      iconColor: Color(0xFFEF4444),
      gradient: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
      title: 'BOSS RUSH',
      description: 'Pure combat. Nine boss variants — shielded '
          'fortresses, laser lances, bomb barges and the twenty-bodied '
          'Swarm Lords — thrown at you in random order. How long can '
          'you last?',
    ),
  };

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
              _buildHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final inStep2 = child.key == const ValueKey('step2');
                    // Step 2 slides in from the right; step 1 exits left.
                    final dx = inStep2 ? 1.0 : -1.0;
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(dx, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _pickedMode == null
                      ? _buildModeStep(key: const ValueKey('step1'))
                      : _buildDifficultyStep(key: const ValueKey('step2')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final inStep2 = _pickedMode != null;
    final meta = inStep2 ? _modeMeta[_pickedMode!] : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          // Back: pops the screen on step 1, returns to step 2 to the
          // mode list on step 2.
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () {
              if (inStep2) {
                setState(() => _pickedMode = null);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: 8),
          Icon(
            meta?.icon ?? Icons.rocket_launch,
            color: meta?.iconColor ?? Colors.white70,
            size: 28,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inStep2 ? meta!.title : 'SELECT MODE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              Text(
                inStep2 ? 'choose your speed' : 'choose your battlefield',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  STEP 1 — game mode cards
  // =========================================================================

  Widget _buildModeStep({Key? key}) {
    return Center(
      key: key,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _modeMeta.entries) ...[
              _ModeCard(
                icon: entry.value.icon,
                iconColor: entry.value.iconColor,
                gradient: entry.value.gradient,
                title: entry.value.title,
                description: entry.value.description,
                onTap: () => setState(() => _pickedMode = entry.key),
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  //  STEP 2 — difficulty picker
  // =========================================================================

  Widget _buildDifficultyStep({Key? key}) {
    return Center(
      key: key,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DifficultyCard(
              level: DifficultyLevel.cadet,
              icon: Icons.shield_moon,
              iconColor: const Color(0xFF4ADE80),
              gradient: const [Color(0xFF166534), Color(0xFF14532D)],
              title: 'CADET',
              subtitle: 'Cruise pace — the classic speed',
              speedBars: 1,
              onTap: () => _launch(DifficultyLevel.cadet),
            ),
            const SizedBox(height: 16),
            _DifficultyCard(
              level: DifficultyLevel.veteran,
              icon: Icons.rocket_launch,
              iconColor: const Color(0xFFFBBF24),
              gradient: const [Color(0xFFB45309), Color(0xFF92400E)],
              title: 'VETERAN',
              subtitle: 'Combat pace — ~30% faster everything',
              speedBars: 2,
              onTap: () => _launch(DifficultyLevel.veteran),
            ),
            const SizedBox(height: 16),
            _DifficultyCard(
              level: DifficultyLevel.ace,
              icon: Icons.local_fire_department,
              iconColor: const Color(0xFFF87171),
              gradient: const [Color(0xFF991B1B), Color(0xFF7F1D1D)],
              title: 'ACE',
              subtitle: 'Blistering pace — ~60% faster, reflexes only',
              speedBars: 3,
              onTap: () => _launch(DifficultyLevel.ace),
            ),
            const SizedBox(height: 20),
            Text(
              'Difficulty sets the speed of the ENTIRE game — enemies, '
              'bullets, bosses and spawns all scale together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launch(DifficultyLevel difficulty) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => GameScreen(
        gameMode: _pickedMode!,
        difficulty: difficulty,
      ),
    ));
  }
}

/// A selectable mode card (step 1).
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final String title;
  final String description;
  final VoidCallback onTap;

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
          onTap: onTap,
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

/// A selectable difficulty card (step 2) with animated speed bars that
/// fill in sequence when the card appears.
class _DifficultyCard extends StatefulWidget {
  const _DifficultyCard({
    required this.level,
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.speedBars,
    required this.onTap,
  });

  final DifficultyLevel level;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final int speedBars;
  final VoidCallback onTap;

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barController;
  late final Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Each bar fills in sequence: bar N completes at N/speedBars.
    _barAnimation = CurvedAnimation(
      parent: _barController,
      curve: Curves.easeOutCubic,
    );
    _barController.forward();
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _barAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            border: Border.all(color: widget.iconColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: widget.iconColor.withOpacity(0.25), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(color: widget.iconColor.withOpacity(0.6), width: 2),
                      ),
                      child: Icon(widget.icon, color: widget.iconColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSpeedBars(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.play_arrow_rounded,
                        color: widget.iconColor.withOpacity(0.9), size: 34),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Speed gauge: N segments, each lighting up in sequence (staggered
  /// by the shared animation) — reads as a throttle meter filling up.
  Widget _buildSpeedBars() {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 34,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i < widget.speedBars
                  ? widget.iconColor.withOpacity(
                      // Segment i fills during its slice of the animation.
                      ((_barAnimation.value * 3) - i).clamp(0.0, 1.0) * 0.9 + 0.1,
                    )
                  : Colors.white.withOpacity(0.10),
              boxShadow: i < widget.speedBars && _barAnimation.value * 3 > i
                  ? [
                      BoxShadow(
                        color: widget.iconColor.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
        ],
        const SizedBox(width: 4),
        Text(
          '×${widget.level == DifficultyLevel.cadet ? '1.0' : widget.level == DifficultyLevel.veteran ? '1.3' : '1.6'}',
          style: TextStyle(
            color: widget.iconColor.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
