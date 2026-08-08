import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/palette.dart';

/// Paints the small fast asteroid: a sharp rocky shard with a hot glowing
/// edge (signals the fast/dangerous variant) and a motion-blur trail.
class SmallAsteroidPainter extends CustomPainter {
  SmallAsteroidPainter({
    this.rotationAngle = 0,
    this.frameCount = 0,
  });

  final double rotationAngle;
  final int frameCount;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final radius = min(w, h) / 2;

    // --- Motion-blur trail (drawn behind, not rotated) ---
    final trailRect = Rect.fromLTWH(0, h * 0.4, w, h * 1.2);
    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Palette.smallAsteroidTrail.withOpacity(0.0),
          Palette.smallAsteroidTrail.withOpacity(0.3),
          Palette.smallAsteroidTrail.withOpacity(0.0),
        ],
      ).createShader(trailRect);
    canvas.drawRect(trailRect, trailPaint);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationAngle);
    canvas.translate(-cx, -cy);

    // --- Sharp shard outline ---
    final random = Random(13);
    final points = <Offset>[];
    final segments = 7;
    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * pi;
      final r = radius * (0.6 + random.nextDouble() * 0.4);
      points.add(Offset(cx + cos(angle) * r, cy + sin(angle) * r));
    }

    final bodyPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      bodyPath.lineTo(points[i].dx, points[i].dy);
    }
    bodyPath.close();

    // --- Rocky body ---
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: Palette.smallAsteroidRock,
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, bodyPaint);

    // --- Hot glowing edge (signals fast/dangerous) ---
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Palette.smallAsteroidGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Palette.smallAsteroidGlow.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // --- Small crater specks ---
    for (int i = 0; i < 3; i++) {
      final a = random.nextDouble() * 2 * pi;
      final d = random.nextDouble() * radius * 0.5;
      canvas.drawCircle(
        Offset(cx + cos(a) * d, cy + sin(a) * d),
        1 + random.nextDouble(),
        Paint()..color = Palette.hugeAsteroidCrater.withOpacity(0.6),
      );
    }

    // --- Hot core ember ---
    final emberPulse = 0.6 + 0.4 * sin(frameCount * 0.3);
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.18,
      Paint()..color = Palette.smallAsteroidGlow.withOpacity(0.5 * emberPulse),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SmallAsteroidPainter old) =>
      old.rotationAngle != rotationAngle || old.frameCount != frameCount;
}
