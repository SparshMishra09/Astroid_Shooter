import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/palette.dart';

/// Paints the enemy fighter: an evil, downward-pointing twin of the
/// player's ship. Crimson hull, swept wings, a glowing red eye, and an
/// orange engine plume at the top (it's inverted, so thrust faces up).
class EnemyShipPainter extends CustomPainter {
  EnemyShipPainter({
    this.health = 5,
    this.maxHealth = 5,
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

    final damage = 1.0 - (health / maxHealth); // 0 = fresh, 1 = near death
    final pulse = 0.5 + 0.5 * sin(frameCount * 0.12);

    // --- Hostile aura (pulses faster as damage rises) ---
    final auraPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          Palette.enemyShipAura.withOpacity(0.25 + pulse * 0.2),
          Palette.enemyShipAura.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCenter(center: Offset(cx, h / 2), width: w * 1.5, height: h * 1.8));
    canvas.drawCircle(Offset(cx, h / 2), w * 0.75, auraPaint);

    // --- Engine plume at the TOP (ship is inverted) ---
    final engineFlicker = 0.7 + 0.3 * sin(frameCount * 0.6);
    final engineRect = Rect.fromCenter(center: Offset(cx, h * 0.04), width: w * 0.35, height: h * 0.12);
    final enginePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Palette.enemyShipEngine.withOpacity(0.9),
          Colors.yellow.withOpacity(0.7 * engineFlicker),
          Colors.transparent,
        ],
      ).createShader(engineRect);
    canvas.drawRRect(RRect.fromRectXY(engineRect, 6, 6), enginePaint);

    // --- Wings (swept outward, pointing down) ---
    final wingPath = Path();
    // Left wing
    wingPath.moveTo(cx - w * 0.1, h * 0.45);
    wingPath.lineTo(cx - w * 0.5, h * 0.75);
    wingPath.lineTo(cx - w * 0.18, h * 0.7);
    wingPath.close();
    // Right wing
    wingPath.moveTo(cx + w * 0.1, h * 0.45);
    wingPath.lineTo(cx + w * 0.5, h * 0.75);
    wingPath.lineTo(cx + w * 0.18, h * 0.7);
    wingPath.close();

    final wingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: Palette.enemyShipHull,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(wingPath, wingPaint);
    canvas.drawPath(wingPath, Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // --- Hull (downward-pointing dart, mirror of player) ---
    final hullPath = Path()
      ..moveTo(cx, h * 0.9) // nose at the bottom
      ..lineTo(cx + w * 0.28, h * 0.45)
      ..lineTo(cx + w * 0.18, h * 0.15)
      ..lineTo(cx - w * 0.18, h * 0.15)
      ..lineTo(cx - w * 0.28, h * 0.45)
      ..close();

    final hullPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: Palette.enemyShipHull,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(hullPath, hullPaint);
    canvas.drawPath(hullPath, Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // --- Metallic paneling lines ---
    final panelPaint = Paint()
      ..color = Colors.black38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx, h * 0.2), Offset(cx, h * 0.8), panelPaint);
    canvas.drawLine(Offset(cx - w * 0.1, h * 0.5), Offset(cx - w * 0.05, h * 0.75), panelPaint);
    canvas.drawLine(Offset(cx + w * 0.1, h * 0.5), Offset(cx + w * 0.05, h * 0.75), panelPaint);

    // --- Glowing red eye (cockpit) ---
    final eyeY = h * 0.38;
    final eyeRadius = w * 0.1;
    final eyeGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Palette.enemyShipEye.withOpacity(0.9 * (0.6 + pulse * 0.4)),
          Palette.enemyShipEye.withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, eyeY), radius: eyeRadius * 2.2));
    canvas.drawCircle(Offset(cx, eyeY), eyeRadius * 2.2, eyeGlow);
    canvas.drawCircle(Offset(cx, eyeY), eyeRadius, Paint()..color = Palette.enemyShipEye);
    canvas.drawCircle(
      Offset(cx - eyeRadius * 0.3, eyeY - eyeRadius * 0.3),
      eyeRadius * 0.35,
      Paint()..color = Colors.white.withOpacity(0.8),
    );

    // --- Damage cracks (appear as health drops) ---
    if (damage > 0.3) {
      final crackPaint = Paint()
        ..color = Colors.amber.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final crackPath = Path()
        ..moveTo(cx - w * 0.15, h * 0.3)
        ..lineTo(cx - w * 0.05, h * 0.5)
        ..lineTo(cx - w * 0.12, h * 0.65);
      if (damage > 0.6) {
        crackPath.moveTo(cx + w * 0.12, h * 0.25);
        crackPath.lineTo(cx + w * 0.04, h * 0.55);
      }
      canvas.drawPath(crackPath, crackPaint);
    }

    // --- Low-health smoke puffs ---
    if (damage > 0.6) {
      final smokePaint = Paint()..color = Colors.grey.withOpacity(0.4);
      for (int i = 0; i < 3; i++) {
        final sx = cx + sin(frameCount * 0.2 + i * 2) * w * 0.15;
        final sy = h * 0.1 - (frameCount * 0.5 + i * 8) % (h * 0.3);
        canvas.drawCircle(Offset(sx, sy), 2 + (i % 2), smokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EnemyShipPainter old) =>
      old.health != health || old.frameCount != frameCount;
}
