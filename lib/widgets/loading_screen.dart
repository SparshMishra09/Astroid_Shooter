import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A themed loading screen that recreates the user's animated rocket SVG.
///
/// `flutter_svg` cannot play CSS/SMIL animations, so the rocket is split
/// into two static SVG strings (flame + body) rendered with
/// [SvgPicture.string]. Flutter [Transform] and [Opacity] widgets drive
/// the three animations from the original SVG:
///   • **rocketBob**   — whole ship bobs ±14px vertically (1.8s)
///   • **flameFlicker** — exhaust flame scales & flickers (~0.12s loop)
///   • **windowPulse**  — cockpit window color pulses (1.8s)
///
/// Using [SvgPicture.string] instead of a hand-rolled [CustomPainter]
/// guarantees correct rendering, sizing, and aspect-ratio handling on
/// any device — no clipping or cropping.
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
  /// 1.8s controller — drives both the rocket bob and the window pulse
  /// (they share the same period in the original SVG).
  late final AnimationController _bobController;

  /// 0.12s controller — drives the fast flame flicker.
  late final AnimationController _flameController;

  // ---- Static SVG fragments (no CSS <style> — animations are in Flutter) ----

  /// Just the exhaust flame, on a transparent 400×400 canvas.
  static const _flameSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <polygon points="175,255 200,245 200,335" fill="#f05041"/>
  <polygon points="200,245 225,255 200,335" fill="#cb3122"/>
</svg>''';

  /// Rocket body (fins + hull + window) on a transparent 400×400 canvas.
  static const _bodySvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <polygon points="156,206 85,250 130,276" fill="#0082df" stroke="#2b3a4a" stroke-width="10" stroke-linejoin="miter"/>
  <polygon points="244,206 315,250 270,276" fill="#0082df" stroke="#2b3a4a" stroke-width="10" stroke-linejoin="miter"/>
  <polygon points="200,75 135,270 200,245 265,270" fill="#5883ff" stroke="#2b3a4a" stroke-width="12" stroke-linejoin="miter"/>
  <circle cx="200" cy="155" r="14" fill="#f3f6fa" stroke="#2b3a4a" stroke-width="6"/>
</svg>''';

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

  /// Convert a [Color] to an SVG hex string (`#rrggbb`).
  String _colorToHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
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
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Animated rocket ----
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_bobController, _flameController]),
                  builder: (context, _) {
                    // Bob: translateY(0 → -14 → 0) over 1.8s, ease-in-out.
                    // Sine of the 0..1 value gives a smooth ease-in-out that
                    // matches CSS `ease-in-out`.
                    final bobY = -14.0 * math.sin(_bobController.value * math.pi);

                    // Flame flicker: 5-stop keyframes approximated with sine.
                    final f = _flameController.value; // 0..1, ping-pongs
                    final flameScaleY = 1.0 + 0.18 * math.sin(f * 2 * math.pi);
                    final flameScaleX = 1.0 - 0.10 * math.sin(f * 2 * math.pi);
                    final flameOpacity =
                        0.85 + 0.15 * ((math.sin(f * 2 * math.pi) + 1) / 2);

                    // Window pulse: lerp #f3f6fa → #ffffff over 1.8s.
                    final windowColor = Color.lerp(
                      const Color(0xFFF3F6FA),
                      const Color(0xFFFFFFFF),
                      _bobController.value,
                    )!;

                    // The SVG viewBox is 400×400, rendered inside a 200×200
                    // widget (scale = 0.5). Bob offset in SVG space (-14)
                    // maps to -7px in widget space.
                    const svgScale = 0.5;

                    return SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Flame layer — drawn first (behind body).
                          // Scaled around the SVG transform-origin (200, 245),
                          // which maps to Alignment(0, 0.225) in the widget.
                          Transform.translate(
                            offset: Offset(0, bobY * svgScale),
                            child: Transform(
                              alignment: const Alignment(0, 0.225),
                              transform: Matrix4.diagonal3Values(
                                flameScaleX,
                                flameScaleY,
                                1.0,
                              ),
                              child: Opacity(
                                opacity: flameOpacity,
                                child: SvgPicture.string(
                                  _flameSvg,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          // Body layer — drawn second (on top of flame).
                          // Window color is injected dynamically for the pulse.
                          Transform.translate(
                            offset: Offset(0, bobY * svgScale),
                            child: SvgPicture.string(
                              _bodySvg.replaceAll(
                                '#f3f6fa',
                                _colorToHex(windowColor),
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                // ---- Caption ----
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
                // ---- Progress bar ----
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
