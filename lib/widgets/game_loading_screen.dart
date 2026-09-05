import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The game-launch loading screen — shown while the game world
/// initializes behind it so the player never sees the ship pop in at
/// the center of the field.
///
/// Layers (back to front): a deep-space gradient, drifting parallax
/// stars (CustomPainter), the bobbing rocket SVG with an animated
/// engine-thrust plume beneath it, a pulsing launch ring around the
/// rocket, the caption with a shimmering progress bar, and rotating
/// status lines ("Warming up engines…") that cycle every 1.2s.
class GameLoadingScreen extends StatefulWidget {
  const GameLoadingScreen({super.key, this.message = 'PREPARING LAUNCH'});

  final String message;

  @override
  State<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends State<GameLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master; // drives everything
  late final AnimationController _bob; // rocket bob

  static const _statusLines = [
    'WARMING UP ENGINES',
    'LOADING STAR CHARTS',
    'CALIBRATING WEAPONS',
    'SCANNING ASTEROID FIELDS',
    'SYNCING PILOT PROFILE',
    'READY FOR LAUNCH',
  ];

  @override
  void initState() {
    super.initState();
    _master = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _bob = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _master.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060913), Color(0xFF0D1222), Color(0xFF1A2442)],
          ),
        ),
        child: Stack(
          children: [
            // Drifting parallax stars
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _master,
                builder: (context, _) =>
                    CustomPaint(painter: _DriftingStarsPainter(_master.value)),
              ),
            ),

            // Center content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rocket + thrust + pulse ring
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_master, _bob]),
                      builder: (context, _) {
                        final bobDy = -12.0 * math.sin(_bob.value * math.pi);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing launch ring
                            _PulseRing(progress: _master.value),
                            // Rocket, bobbing
                            Transform.translate(
                              offset: Offset(0, bobDy - 14),
                              child: SizedBox(
                                width: 150,
                                height: 150,
                                child: SvgPicture.asset(
                                  'assets/images/loading_rocket_clean.svg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            // Thrust plume under the rocket
                            Positioned(
                              bottom: 8,
                              child: _ThrustPlume(
                                  progress: _master.value, bob: _bob.value),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Caption
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Color(0xFF8FA3C8),
                      fontSize: 16,
                      letterSpacing: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Shimmering progress bar
                  const SizedBox(
                    width: 230,
                    child: _ShimmerBar(),
                  ),
                  const SizedBox(height: 18),

                  // Cycling status line
                  _CyclingStatus(
                    lines: _statusLines,
                    progress: _master.value,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two expanding rings that fade as they grow — a launch-pad feel.
class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(260, 260),
      painter: _PulseRingPainter(progress),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  _PulseRingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1.0; // 0..1
      final radius = 60 + phase * 70;
      final opacity = (1 - phase) * 0.35;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = const Color(0xFF5883FF).withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter old) => old.t != t;
}

/// Engine exhaust: flickering layered flame + rising spark particles.
class _ThrustPlume extends StatelessWidget {
  const _ThrustPlume({required this.progress, required this.bob});
  final double progress;
  final double bob;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 70),
      painter: _ThrustPainter(progress, bob),
    );
  }
}

class _ThrustPainter extends CustomPainter {
  _ThrustPainter(this.t, this.bob);
  final double t;
  final double bob;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final flicker = 0.7 + 0.3 * math.sin(t * 40);

    // Outer glow
    canvas.drawCircle(
      Offset(cx, size.height * 0.3),
      26 * flicker,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFF9D2E).withOpacity(0.5),
          const Color(0xFFFF9D2E).withOpacity(0.0),
        ]).createShader(Rect.fromCircle(
            center: Offset(cx, size.height * 0.3), radius: 26)),
    );

    // Flame body — narrows downward, flickering length.
    final flameLen = 34 + 10 * math.sin(t * 26);
    final flame = Path()
      ..moveTo(cx - 11, size.height * 0.05)
      ..quadraticBezierTo(cx, size.height * 0.05 + flameLen, cx + 11, size.height * 0.05)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
          const Color(0xFFFFC933).withOpacity(0.95),
          const Color(0xFFFF6A00).withOpacity(0.75),
          const Color(0xFFFF6A00).withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Inner hot core
    final core = Path()
      ..moveTo(cx - 5, size.height * 0.05)
      ..quadraticBezierTo(cx, size.height * 0.05 + flameLen * 0.55, cx + 5, size.height * 0.05)
      ..close();
    canvas.drawPath(
      core,
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    // Rising sparks
    final random = math.Random(7);
    for (var i = 0; i < 7; i++) {
      final phase = (t * 1.4 + i * 0.14) % 1.0;
      final sy = size.height * 0.35 + phase * size.height * 0.75;
      final sx = cx + (random.nextDouble() - 0.5) * 22 * (1 - phase);
      canvas.drawCircle(
        Offset(sx, sy),
        1.6 + random.nextDouble() * 1.4,
        Paint()..color = const Color(0xFFFFC933).withOpacity((1 - phase) * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThrustPainter old) => old.t != t;
}

/// Indeterminate bar with a light streak sweeping across.
class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar();

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(
            height: 5,
            color: const Color(0xFF1E2A44),
          ),
          // The shimmer: a fractional-alignment box that slides across
          // the bar. Kept a DIRECT child of the Stack (Positioned must
          // not be nested under builders).
          AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) {
              final x = -0.6 + _sweep.value * 1.2; // -0.6 .. 0.6
              return Align(
                alignment: Alignment(x, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF5883FF).withOpacity(0.0),
                          const Color(0xFF5883FF),
                          const Color(0xFF9DB8FF),
                          const Color(0xFF5883FF).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Status text that crossfades between lines as [progress] advances.
class _CyclingStatus extends StatelessWidget {
  const _CyclingStatus({required this.lines, required this.progress});
  final List<String> lines;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Full cycle = 3s master; each line shows for an equal slice.
    final idx = (progress * lines.length).floor() % lines.length;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        lines[idx],
        key: ValueKey(idx),
        style: const TextStyle(
          color: Color(0xFF5B6E96),
          fontSize: 11,
          letterSpacing: 3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Slow upward-drifting stars on two parallax layers.
class _DriftingStarsPainter extends CustomPainter {
  _DriftingStarsPainter(this.t);
  final double t;

  static final List<_Star> _stars = List.generate(60, (i) {
    final r = math.Random(i);
    return _Star(
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: 0.6 + r.nextDouble() * 1.8,
      speed: 0.02 + r.nextDouble() * 0.06,
      phase: r.nextDouble() * math.pi * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      final twinkle = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 6 + s.phase));
      final y = (s.y - t * s.speed) % 1.0;
      canvas.drawCircle(
        Offset(s.x * size.width, (y < 0 ? y + 1 : y) * size.height),
        s.size,
        Paint()..color = Colors.white.withOpacity(0.35 * twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DriftingStarsPainter old) => true;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
}
