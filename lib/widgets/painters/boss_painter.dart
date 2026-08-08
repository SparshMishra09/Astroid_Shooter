import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/palette.dart';

/// Paints the boss dreadnought: a wide armored capital battleship pointing
/// DOWN. Layered hull plating, 4 weapon-bay cannons, a central energy core
/// that shifts color with health, a rotating energy ring, thruster glow,
/// and low-health spark/exposed-core damage effects.
class BossPainter extends CustomPainter {
  BossPainter({
    required this.health,
    required this.maxHealth,
    this.frameCount = 0,
  });

  final int health;
  final int maxHealth;
  final int frameCount;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final healthPct = (health / maxHealth).clamp(0.0, 1.0);
    final pulse = 0.5 + 0.5 * sin(frameCount * 0.06);

    // Core color shifts with health
    final Color coreColor;
    if (healthPct > 0.5) {
      coreColor = Palette.bossCoreHighHealth;
    } else if (healthPct > 0.3) {
      coreColor = Palette.bossCoreMidHealth;
    } else {
      coreColor = Palette.bossCoreLowHealth;
    }

    // --- Outer energy field ---
    final fieldRect = Rect.fromCenter(center: Offset(cx, cy), width: w * 1.4, height: h * 1.4);
    final fieldPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          coreColor.withOpacity(0.35 + pulse * 0.15),
          coreColor.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(fieldRect);
    canvas.drawCircle(Offset(cx, cy), w * 0.7, fieldPaint);

    // --- Rotating energy ring ---
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(frameCount * 0.02);
    final ringPaint = Paint()
      ..color = Palette.bossRing.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final ringRect = Rect.fromCircle(center: Offset.zero, radius: w * 0.46);
    canvas.drawArc(ringRect, 0, pi * 1.4, false, ringPaint);
    canvas.drawArc(ringRect, pi * 1.6, pi * 0.8, false, ringPaint);
    canvas.restore();

    // --- Thruster glow at TOP (ship points down) ---
    final thrusterRect = Rect.fromCenter(center: Offset(cx, h * 0.02), width: w * 0.5, height: h * 0.1);
    final thrusterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Palette.bossThruster.withOpacity(0.9),
          Colors.yellow.withOpacity(0.6),
          Colors.transparent,
        ],
      ).createShader(thrusterRect);
    canvas.drawRRect(RRect.fromRectXY(thrusterRect, 8, 8), thrusterPaint);

    // --- Main hull: wide armored body ---
    final hullPath = Path()
      ..moveTo(cx, h * 0.92) // nose at bottom
      ..lineTo(cx + w * 0.45, h * 0.55)
      ..lineTo(cx + w * 0.42, h * 0.2)
      ..lineTo(cx + w * 0.25, h * 0.08)
      ..lineTo(cx - w * 0.25, h * 0.08)
      ..lineTo(cx - w * 0.42, h * 0.2)
      ..lineTo(cx - w * 0.45, h * 0.55)
      ..close();

    final hullPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: Palette.bossHull,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(hullPath, hullPaint);
    canvas.drawPath(hullPath, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);

    // --- Hull plating lines (metallic paneling) ---
    final platePaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx - w * 0.3, h * 0.3), Offset(cx + w * 0.3, h * 0.3), platePaint);
    canvas.drawLine(Offset(cx - w * 0.38, h * 0.45), Offset(cx + w * 0.38, h * 0.45), platePaint);
    canvas.drawLine(Offset(cx, h * 0.1), Offset(cx, h * 0.9), platePaint);

    // --- Side fins ---
    final finPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Palette.bossHull[2], Palette.bossHull[0]],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    final leftFin = Path()
      ..moveTo(cx - w * 0.42, h * 0.25)
      ..lineTo(cx - w * 0.5, h * 0.5)
      ..lineTo(cx - w * 0.38, h * 0.45)
      ..close();
    final rightFin = Path()
      ..moveTo(cx + w * 0.42, h * 0.25)
      ..lineTo(cx + w * 0.5, h * 0.5)
      ..lineTo(cx + w * 0.38, h * 0.45)
      ..close();
    canvas.drawPath(leftFin, finPaint);
    canvas.drawPath(rightFin, finPaint);

    // --- 4 weapon-bay cannons ---
    for (int i = 0; i < 4; i++) {
      final bx = cx + (i - 1.5) * w * 0.18;
      final by = h * 0.72;
      final cannonRect = Rect.fromCenter(center: Offset(bx, by), width: w * 0.08, height: h * 0.18);
      canvas.drawRRect(
        RRect.fromRectXY(cannonRect, 3, 3),
        Paint()..shader = RadialGradient(colors: [Colors.white, coreColor, Palette.bossHull[0]]).createShader(cannonRect),
      );
      // Muzzle glow
      final muzzleGlow = Paint()..color = coreColor.withOpacity(0.5 + pulse * 0.4);
      canvas.drawCircle(Offset(bx, by + h * 0.08), w * 0.03, muzzleGlow);
    }

    // --- Central energy core ---
    final coreRadius = w * 0.16;
    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.9),
          coreColor.withOpacity(0.85),
          coreColor.withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreRadius * 2.5));
    canvas.drawCircle(Offset(cx, cy), coreRadius * 2.5, coreGlow);

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, coreColor, Palette.bossHull[0]],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreRadius));
    canvas.drawCircle(Offset(cx, cy), coreRadius, corePaint);

    // Pulsing core highlight
    canvas.drawCircle(
      Offset(cx, cy),
      coreRadius * (0.6 + pulse * 0.15),
      Paint()..color = Colors.white.withOpacity(0.4 * pulse),
    );

    // --- Edge warning lights (cycling) ---
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * pi;
      final lx = cx + cos(angle) * w * 0.38;
      final ly = cy + sin(angle) * h * 0.32;
      final on = (frameCount + i * 6) % 40 < 20;
      canvas.drawCircle(
        Offset(lx, ly),
        3,
        Paint()..color = (on ? coreColor : Colors.amber).withOpacity(on ? 0.9 : 0.4),
      );
    }

    // --- Damage effects when low health ---
    if (healthPct < 0.4) {
      // Exposed core crackle
      final crackPaint = Paint()
        ..color = Colors.amber.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (int i = 0; i < 4; i++) {
        final a = i * pi / 2 + frameCount * 0.05;
        canvas.drawLine(
          Offset(cx + cos(a) * coreRadius * 0.5, cy + sin(a) * coreRadius * 0.5),
          Offset(cx + cos(a) * w * 0.35, cy + sin(a) * h * 0.3),
          crackPaint,
        );
      }

      // Random sparks
      if (healthPct < 0.3) {
        final random = Random(frameCount ~/ 5);
        for (int i = 0; i < 6; i++) {
          final sa = random.nextDouble() * 2 * pi;
          final sd = random.nextDouble() * w * 0.35;
          final sparkOn = random.nextBool();
          if (sparkOn) {
            canvas.drawCircle(
              Offset(cx + cos(sa) * sd, cy + sin(sa) * sd),
              2.5,
              Paint()..color = Colors.orange..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BossPainter old) =>
      old.health != health || old.frameCount != frameCount;
}
