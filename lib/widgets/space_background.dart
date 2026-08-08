import 'dart:math';
import 'package:flutter/material.dart';

/// Scrolling parallax star field rendered as a single CustomPaint layer
/// instead of hundreds of Positioned widgets.
///
/// Star base positions are computed once (deterministic via seeded random)
/// and only the Y offset changes per frame, so this is far cheaper than
/// rebuilding a Stack of 180+ widgets every frame.
class SpaceBackground extends StatelessWidget {
  final double scrollOffset;
  final double width;
  final double height;

  const SpaceBackground({
    super.key,
    required this.scrollOffset,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _StarFieldPainter(scrollOffset: scrollOffset, w: width, h: height),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final double scrollOffset;
  final double w;
  final double h;

  _StarFieldPainter({required this.scrollOffset, required this.w, required this.h});

  // Pre-computed star definitions (seeded so positions are stable).
  // Cached statically and invalidated when screen dimensions change.
  static List<_Star>? _layer1;
  static List<_Star>? _layer2;
  static List<_Star>? _layer3;
  static List<_TwinkleStar>? _twinkle;
  static double _cachedW = 0;
  static double _cachedH = 0;

  void _ensureStars() {
    // Recompute if dimensions changed or first run.
    if (_layer1 != null && _cachedW == w && _cachedH == h) return;
    _cachedW = w;
    _cachedH = h;
    _layer1 = _getLayer(30, 72, 3.0, 5.0);
    _layer2 = _getLayer(50, 92, 2.0, 3.5);
    _layer3 = _getLayer(100, 192, 1.0, 2.5);
    _twinkle = _buildTwinkle();
  }

  List<_Star> _getLayer(int count, int seed, double minSize, double maxSize) {
    final random = Random(seed);
    return List.generate(count, (_) {
      final x = random.nextDouble() * w;
      final baseY = random.nextDouble() * h * 2;
      final size = minSize + random.nextDouble() * (maxSize - minSize);
      return _Star(x, baseY, size);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 2.0,
        colors: [Colors.indigo.shade900, Colors.black, Colors.black],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Initialize star layers once (cached across frames, recomputed only
    // if screen dimensions change).
    _ensureStars();

    // Draw each layer with parallax
    _drawLayer(canvas, _layer1!, 0.1, 0.6, 2.0);
    _drawLayer(canvas, _layer2!, 0.3, 0.8, 1.0);
    _drawLayer(canvas, _layer3!, 0.7, 1.0, 0.0);
    _drawTwinkle(canvas);
  }

  void _drawLayer(Canvas canvas, List<_Star> stars, double speed, double opacity, double blur) {
    final wrap = h + 100;
    final paint = Paint()..color = Colors.white.withOpacity(opacity);
    final glowPaint = Paint()..color = Colors.white.withOpacity(opacity * 0.5);

    for (final s in stars) {
      final y = (s.baseY + scrollOffset * speed) % wrap;
      if (blur > 0) {
        glowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
        canvas.drawCircle(Offset(s.x, y), s.size + blur, glowPaint);
      }
      canvas.drawCircle(Offset(s.x, y), s.size, paint);
    }
  }

  List<_TwinkleStar> _buildTwinkle() {
    final random = Random(999);
    return List.generate(15, (_) {
      final x = random.nextDouble() * w;
      final y = random.nextDouble() * h;
      final phase = random.nextDouble() * 2 * pi;
      return _TwinkleStar(x, y, phase);
    });
  }

  void _drawTwinkle(Canvas canvas) {
    for (int i = 0; i < _twinkle!.length; i++) {
      final t = _twinkle![i];
      final value = sin((scrollOffset * 0.05) + t.phase + (i * 0.3));
      final opacity = 0.3 + (value + 1) * 0.35;
      final size = 2.0 + value * 0.5;
      canvas.drawCircle(
        Offset(t.x, t.y),
        size,
        Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) => scrollOffset != old.scrollOffset;
}

class _Star {
  final double x;
  final double baseY;
  final double size;
  _Star(this.x, this.baseY, this.size);
}

class _TwinkleStar {
  final double x;
  final double y;
  final double phase;
  _TwinkleStar(this.x, this.y, this.phase);
}
