import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A themed loading screen showing an animated rocket.
///
/// This implementation is intentionally minimal to avoid any rendering
/// quirks: a single SVG asset rendered via [SvgPicture.asset] inside a
/// [SizedBox] with TIGHT constraints. The only animation is a gentle
/// vertical bob applied to the whole rocket via [Transform.translate].
///
/// Key design decisions that prevent clipping/cropping:
///   • [SvgPicture.asset] (not `.string`) — the asset loader is the most
///     battle-tested path in flutter_svg.
///   • The SVG file has NO `width`/`height` XML attributes — only
///     `viewBox`. This forces flutter_svg to use the Dart-side
///     `width`/`height` parameters for sizing.
///   • A [SizedBox] with explicit dimensions wraps the SVG, giving it
///     TIGHT constraints. No `Stack`, no layered rendering, no loose
///     constraints that could cause the SVG to render at its intrinsic
///     400×400 size.
///   • The [Container] has `width: double.infinity` + `height: double.infinity`
///     to guarantee it fills the entire screen.
///   • No [SafeArea] — the gradient extends edge-to-edge under the
///     status bar, and the content is vertically centered so it never
///     collides with system UI.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    this.message = 'LOADING…',
    this.progress,
  });

  final String message;

  /// If non-null, the progress bar is determinate (0.0 → 1.0).
  final double? progress;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No backgroundColor — the Container gradient covers everything.
      body: Container(
        // Explicit infinite dimensions guarantee the gradient fills
        // the entire screen on every device.
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1222), Color(0xFF1A2442)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---- Rocket with gentle bob ----
            // The child is built once (not rebuilt per frame) and only
            // the Transform is animated.
            AnimatedBuilder(
              animation: _bob,
              builder: (context, child) {
                // Smooth ease-in-out bob: 0 → -14px → 0 over 1.8s.
                final dy = -14.0 * math.sin(_bob.value * math.pi);
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                );
              },
              // SizedBox gives the SvgPicture TIGHT 180×180 constraints.
              // The SVG file has no width/height XML attributes, so
              // flutter_svg MUST use these dimensions.
              child: SizedBox(
                width: 180,
                height: 180,
                child: SvgPicture.asset(
                  'assets/images/loading_rocket_clean.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 40),
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
            const SizedBox(height: 20),
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
    );
  }
}
