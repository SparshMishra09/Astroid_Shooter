import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/palette.dart';

/// Paints the huge slow asteroid: a jagged irregular rocky polygon with
/// depth-shaded craters, grey-brown rocky tones, and cracks that appear
/// as it takes damage (3 HP stages).
class HugeAsteroidPainter extends CustomPainter {
  HugeAsteroidPainter({
    this.health = 3,
    this.maxHealth = 3,
    this.rotationAngle = 0,
  });

  final int health;
  final int maxHealth;
  final double rotationAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final radius = min(w, h) / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationAngle);
    canvas.translate(-cx, -cy);

    // --- Jagged irregular outline (deterministic via seeded random) ---
    final random = Random(7);
    final points = <Offset>[];
    final segments = 12;
    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * pi;
      final r = radius * (0.78 + random.nextDouble() * 0.22);
      points.add(Offset(cx + cos(angle) * r, cy + sin(angle) * r));
    }

    final bodyPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      bodyPath.lineTo(points[i].dx, points[i].dy);
    }
    bodyPath.close();

    // --- Rocky body with radial gradient for 3D depth ---
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.9,
        colors: Palette.hugeAsteroidRock,
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, bodyPaint);

    // --- Dark rim shadow ---
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Palette.hugeAsteroidCrater
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // --- Highlight rim (top-left, fake light source) ---
    final highlightPath = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy);
    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = Palette.hugeAsteroidRock[2].withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // --- Craters with depth ---
    final craterRandom = Random(31);
    final craters = [
      {'x': -0.18, 'y': -0.15, 'r': 0.14},
      {'x': 0.22, 'y': 0.08, 'r': 0.1},
      {'x': -0.1, 'y': 0.25, 'r': 0.12},
      {'x': 0.1, 'y': -0.28, 'r': 0.08},
      {'x': -0.3, 'y': 0.1, 'r': 0.07},
      {'x': 0.28, 'y': -0.12, 'r': 0.09},
    ];
    for (final c in craters) {
      final ccx = cx + (c['x'] as double) * w;
      final ccy = cy + (c['y'] as double) * h;
      final cr = (c['r'] as double) * radius;

      // Crater shadow ring
      canvas.drawCircle(
        Offset(ccx, ccy),
        cr,
        Paint()..color = Palette.hugeAsteroidCrater.withOpacity(0.7),
      );
      // Crater inner highlight
      canvas.drawCircle(
        Offset(ccx - cr * 0.2, ccy - cr * 0.2),
        cr * 0.6,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [
              Palette.hugeAsteroidRock[2].withOpacity(0.6),
              Palette.hugeAsteroidCrater.withOpacity(0.3),
            ],
          ).createShader(Rect.fromCircle(center: Offset(ccx, ccy), radius: cr * 0.6)),
      );
    }

    // --- Small surface specks for texture ---
    for (int i = 0; i < 14; i++) {
      final a = craterRandom.nextDouble() * 2 * pi;
      final d = craterRandom.nextDouble() * radius * 0.7;
      canvas.drawCircle(
        Offset(cx + cos(a) * d, cy + sin(a) * d),
        1 + craterRandom.nextDouble() * 1.5,
        Paint()..color = Palette.hugeAsteroidCrater.withOpacity(0.4),
      );
    }

    // --- Damage cracks (per HP stage) ---
    final damage = maxHealth - health;
    if (damage >= 1) {
      final crackPaint = Paint()
        ..color = Palette.hugeAsteroidCrack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      // First crack
      final crack1 = Path()
        ..moveTo(cx - radius * 0.3, cy - radius * 0.4)
        ..lineTo(cx - radius * 0.1, cy - radius * 0.1)
        ..lineTo(cx - radius * 0.25, cy + radius * 0.2)
        ..lineTo(cx + radius * 0.05, cy + radius * 0.45);
      canvas.drawPath(crack1, crackPaint);
    }
    if (damage >= 2) {
      final crackPaint = Paint()
        ..color = Palette.hugeAsteroidCrack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      // Second crack + glow indicating near-destruction
      final crack2 = Path()
        ..moveTo(cx + radius * 0.35, cy - radius * 0.35)
        ..lineTo(cx + radius * 0.1, cy - radius * 0.05)
        ..lineTo(cx + radius * 0.3, cy + radius * 0.25);
      canvas.drawPath(crack2, crackPaint);

      // Hot glow in the cracks
      final glowPaint = Paint()
        ..color = Colors.orange.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(crack2, glowPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HugeAsteroidPainter old) =>
      old.health != health || old.rotationAngle != rotationAngle;
}
