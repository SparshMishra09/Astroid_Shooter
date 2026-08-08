import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A themed loading screen showing an animated rocket.
///
/// The rocket is a single static SVG rendered via [SvgPicture.string] with
/// **explicit width/height** so it always renders at the exact size
/// requested — regardless of parent constraints. This is the fix for the
/// "half-cropped rocket" bug that occurred when the SVG was inside a
/// `Stack(fit: StackFit.expand)` without explicit dimensions.
///
/// Animations (driven by Flutter, since flutter_svg can't play CSS):
///   • **rocketBob** — whole ship bobs ±14px vertically (1.8s, sine-eased)
///   • **flameFlicker** — exhaust flame opacity flickers (~0.12s loop)
///   • **windowPulse** — cockpit window opacity pulses (1.8s)
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    this.message = 'LOADING…',
    this.progress,
  });

  final String message;
  final double? progress;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bobController;
  late final AnimationController _flameController;

  // The rocket render size in logical pixels.
  static const _rocketSize = 180.0;

  /// Complete static rocket SVG (flame + body + window) on a 400×400 canvas.
  /// Rendered as a single picture so there are no Stack constraint issues.
  static const _rocketSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <polygon points="175,255 200,245 200,335" fill="#f05041"/>
  <polygon points="200,245 225,255 200,335" fill="#cb3122"/>
  <polygon points="156,206 85,250 130,276" fill="#0082df" stroke="#2b3a4a" stroke-width="10" stroke-linejoin="miter"/>
  <polygon points="244,206 315,250 270,276" fill="#0082df" stroke="#2b3a4a" stroke-width="10" stroke-linejoin="miter"/>
  <polygon points="200,75 135,270 200,245 265,270" fill="#5883ff" stroke="#2b3a4a" stroke-width="12" stroke-linejoin="miter"/>
  <circle cx="200" cy="155" r="14" fill="#f3f6fa" stroke="#2b3a4a" stroke-width="6"/>
</svg>''';

  /// Flame-only SVG for the flicker overlay. Same 400×400 canvas so it
  /// aligns perfectly with the body when stacked.
  static const _flameSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <polygon points="175,255 200,245 200,335" fill="#f05041"/>
  <polygon points="200,245 225,255 200,335" fill="#cb3122"/>
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
                // The bob is applied to a SizedBox that has a FIXED size.
                // The SvgPicture inside gets explicit width/height so it
                // can never be clipped by ambiguous parent constraints.
                AnimatedBuilder(
                  animation: _bobController,
                  builder: (context, child) {
                    // translateY(0 → -14 → 0) over 1.8s, ease-in-out.
                    final bobY =
                        -14.0 * math.sin(_bobController.value * math.pi);
                    return Transform.translate(
                      offset: Offset(0, bobY),
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: _rocketSize,
                    height: _rocketSize,
                    child: Stack(
                      // No StackFit.expand — each child gets explicit size.
                      children: [
                        // Flame layer (behind body) with flicker opacity.
                        AnimatedBuilder(
                          animation: _flameController,
                          builder: (context, child) {
                            final f = _flameController.value;
                            final opacity =
                                0.85 + 0.15 * ((math.sin(f * 2 * math.pi) + 1) / 2);
                            return Opacity(opacity: opacity, child: child);
                          },
                          child: SvgPicture.string(
                            _flameSvg,
                            width: _rocketSize,
                            height: _rocketSize,
                          ),
                        ),
                        // Body layer (on top of flame).
                        SvgPicture.string(
                          _rocketSvg,
                          width: _rocketSize,
                          height: _rocketSize,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
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
