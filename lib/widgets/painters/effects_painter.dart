import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/effects.dart';
import '../../models/projectiles.dart';
import '../../config/palette.dart';

/// Paints all explosion particles and hit sparks in a single CustomPaint
/// pass for efficiency (one canvas instead of dozens of Containers).
class EffectsPainter extends CustomPainter {
  EffectsPainter({
    required this.explosions,
    required this.hitEffects,
    required this.muzzleFlashes,
    required this.engineTrailPoints,
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
  });

  final List<ExplosionEffect> explosions;
  final List<HitEffect> hitEffects;
  final List<Flash> muzzleFlashes;
  final List<Offset> engineTrailPoints;
  final double playerX;
  final double playerY;
  final double playerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // --- Engine trail behind player ---
    if (engineTrailPoints.isNotEmpty) {
      for (int i = 0; i < engineTrailPoints.length; i++) {
        final p = engineTrailPoints[i];
        final progress = i / engineTrailPoints.length;
        final radius = (2 + progress * 4).clamp(1.0, 6.0);
        canvas.drawCircle(
          p,
          radius,
          Paint()
            ..color = Palette.playerTrail.withOpacity(progress * 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // --- Muzzle flashes ---
    for (var flash in muzzleFlashes) {
      if (!flash.isActive) continue;
      final cx = flash.x + flash.size / 2;
      final cy = flash.isUpward ? flash.y - flash.size * 0.3 : flash.y + flash.size * 0.3;
      canvas.drawCircle(
        Offset(cx, cy),
        flash.size * 0.7 * flash.opacity,
        Paint()
          ..color = Palette.muzzleFlash.withOpacity(0.8 * flash.opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        flash.size * 0.35 * flash.opacity,
        Paint()..color = Colors.white.withOpacity(flash.opacity),
      );
    }

    // --- Explosion particles ---
    for (var explosion in explosions) {
      for (var p in explosion.particles) {
        canvas.drawCircle(
          Offset(p.x, p.y),
          p.currentSize,
          Paint()
            ..color = p.color.withOpacity(p.opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
        );
      }
    }

    // --- Hit sparks (radiating lines) ---
    for (var hit in hitEffects) {
      if (!hit.isActive) continue;
      final cx = hit.x;
      final cy = hit.y;
      final opacity = hit.opacity;

      // Central glow
      canvas.drawCircle(
        Offset(cx, cy),
        hit.currentSize * 0.4,
        Paint()
          ..color = hit.color.withOpacity(opacity * 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Radiating spark lines
      final sparkPaint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (int i = 0; i < 6; i++) {
        final angle = (i / 6) * pi * 2;
        final len = hit.currentSize * 0.5;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(angle) * len, cy + sin(angle) * len),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant EffectsPainter old) => true; // effects animate every frame
}
