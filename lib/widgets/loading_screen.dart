import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A themed loading screen that recreates the user's animated rocket SVG.
///
/// `flutter_svg` cannot play CSS/SMIL animations, so the rocket is drawn
/// natively with a [CustomPainter]. Three animations run off a single
/// [AnimationController]:
///   • **rocketBob**  — the whole ship bobs ±14px vertically (1.8s)
///   • **flameFlicker** — the exhaust flame scales & flickers (~0.12s loop)
///   • **windowPulse** — the cockpit window color pulses (1.8s)
///
/// A small "LOADING…" caption and a linear progress bar sit underneath.
/// An optional [message] can override the caption, and an optional
/// [progress] (0.0–1.0) switches the bar from indeterminate to determinate.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    this.message = 'LOADING…',
    this.progress,
  });

  /// Caption shown under the rocket. Defaults to "LOADING…".
  final String message;

  /// If non-null, the progress bar is determinate (0.0 → 1.0).
  /// If null, the bar is indeterminate.
  final double? progress;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bobController; // 1.8s bob + window pulse
  late final AnimationController _flameController; // 0.12s flame flicker

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bobController.dispose();
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1222),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1222), Color(0xFF1A2442)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Animated rocket
              AnimatedBuilder(
                animation: Listenable.merge([_bobController, _flameController]),
                builder: (context, _) {
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: _RocketPainter(
                        bob: _bobController.value,
                        flame: _flameController.value,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(flex: 1),
              // Caption
              Text(
                widget.message,
                style: const TextStyle(
                  color: Color(0xFF8FA3C8),
                  fontSize: 14,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              // Progress bar
              SizedBox(
                width: 220,
                child: widget.progress != null
                    ? LinearProgressIndicator(
                        value: widget.progress!.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: const Color(0xFF1E2A44),
                        color: const Color(0xFF5883FF),
                      )
                    : LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: const Color(0xFF1E2A44),
                        color: const Color(0xFF5883FF),
                      ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the rocket from the loading SVG.
///
/// Coordinates mirror the 400×400 viewBox of `loading_rocket.svg`, scaled
/// into the paint area. The [bob] value (0→1) drives the vertical bob via a
/// sine wave; the [flame] value (0→1) drives flame scale/opacity.
class _RocketPainter extends CustomPainter {
  _RocketPainter({required this.bob, required this.flame});

  /// 0..1 from the 1.8s bob controller.
  final double bob;
  /// 0..1 from the 0.12s flame controller.

  final double flame;

  // Original SVG palette.
  static const _hull = Color(0xFF5883FF);
  static const _hullStroke = Color(0xFF2B3A4A);
  static const _fin = Color(0xFF0082DF);
  static const _window = Color(0xFFF3F6FA);
  static const _windowBright = Color(0xFFFFFFFF);
  static const _flameOuter = Color(0xFFF05041);
  static const _flameInner = Color(0xFFCB3122);

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the 400×400 viewBox to fit the paint area, preserving aspect.
    final s = size.width / 400;
    canvas.save();
    canvas.scale(s);

    // --- Bob: translate the whole rocket vertically ---
    // SVG bob is translateY(0 → -14 → 0). A sine of the 0..1 value gives
    // a smooth ease-in-out matching CSS ease-in-out.
    final bobOffset = -14.0 * math.sin(bob * math.pi);
    canvas.translate(0, bobOffset);

    // --- Flame flicker ---
    // CSS keyframes: scaleY 1→1.18→0.85→1.22→0.95, scaleX 1→0.92→1.05→0.88→1,
    // opacity 0.95→1→0.85→1→0.9. We approximate the 5-stop loop with the
    // 0..1 value of a reverse-repeating controller mapped through sine.
    final f = flame; // 0..1, ping-pongs
    final flameScaleY = 1.0 + 0.18 * math.sin(f * 2 * math.pi);
    final flameScaleX = 1.0 - 0.10 * math.sin(f * 2 * math.pi);
    final flameOpacity = 0.85 + 0.15 * ((math.sin(f * 2 * math.pi) + 1) / 2);

    // Flame pivot is the SVG transform-origin (200, 245).
    _drawFlame(canvas, flameScaleX, flameScaleY, flameOpacity);

    // --- Fins ---
    _drawPolygon(
      canvas,
      const [Offset(156, 206), Offset(85, 250), Offset(130, 276)],
      fill: _fin,
      stroke: _hullStroke,
      strokeWidth: 10,
    );
    _drawPolygon(
      canvas,
      const [Offset(244, 206), Offset(315, 250), Offset(270, 276)],
      fill: _fin,
      stroke: _hullStroke,
      strokeWidth: 10,
    );

    // --- Main hull ---
    _drawPolygon(
      canvas,
      const [Offset(200, 75), Offset(135, 270), Offset(200, 245), Offset(265, 270)],
      fill: _hull,
      stroke: _hullStroke,
      strokeWidth: 12,
    );

    // --- Cockpit window (pulses color) ---
    final windowColor = Color.lerp(_window, _windowBright, bob)!;
    final windowPaint = Paint()..color = windowColor;
    final windowStroke = Paint()
      ..color = _hullStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(const Offset(200, 155), 14, windowPaint);
    canvas.drawCircle(const Offset(200, 155), 14, windowStroke);

    canvas.restore();
  }

  void _drawFlame(
    Canvas canvas,
    double scaleX,
    double scaleY,
    double opacity,
  ) {
    // Transform-origin in SVG is (200, 245).
    canvas.save();
    canvas.translate(200, 245);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-200, -245);

    final outer = Paint()..color = _flameOuter.withValues(alpha: opacity);
    final inner = Paint()..color = _flameInner.withValues(alpha: opacity);

    // Outer flame: (175,255) (200,245) (200,335)
    canvas.drawPath(
      _path(const [Offset(175, 255), Offset(200, 245), Offset(200, 335)]),
      outer,
    );
    // Inner flame: (200,245) (225,255) (200,335)
    canvas.drawPath(
      _path(const [Offset(200, 245), Offset(225, 255), Offset(200, 335)]),
      inner,
    );

    canvas.restore();
  }

  Path _path(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    return p..close();
  }

  void _drawPolygon(
    Canvas canvas,
    List<Offset> pts, {
    required Color fill,
    required Color stroke,
    required double strokeWidth,
  }) {
    final p = _path(pts);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(
      p,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(covariant _RocketPainter old) =>
      old.bob != bob || old.flame != flame;
}
