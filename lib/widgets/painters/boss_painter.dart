import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/palette.dart';
import '../../models/enums.dart';

/// Paints the boss dreadnought: a wide armored capital battleship pointing
/// DOWN. Layered hull plating, 4 weapon-bay cannons, a central energy core
/// that shifts color with health, a rotating energy ring, thruster glow,
/// and low-health spark/exposed-core damage effects.
///
/// Variant extras: the Bulwark Sentinel renders a cracking energy shield
/// dome over the hull; the Void Lancer renders a charging laser cannon
/// that glows hotter as the shot approaches.
class BossPainter extends CustomPainter {
  BossPainter({
    required this.health,
    required this.maxHealth,
    this.frameCount = 0,
    this.bossType = BossType.triBeam,
    this.shieldHealth = 0,
    this.maxShieldHealth = 0,
    this.laserChargeProgress = 0,
  });

  final int health;
  final int maxHealth;
  final int frameCount;
  final BossType bossType;

  /// Remaining / total shield hits (Bulwark Sentinel only).
  final int shieldHealth;
  final int maxShieldHealth;

  /// 0..1 charge of the laser cannon (Void Lancer only).
  final double laserChargeProgress;

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

    // --- Variant extras ---
    if (bossType == BossType.shieldedBurst) {
      _paintShieldDome(canvas, w, h, cx, cy, pulse);
    } else if (bossType == BossType.laserCannon) {
      _paintLaserCannon(canvas, w, h, cx, cy, pulse);
    }
  }

  /// Bulwark Sentinel: a translucent cyan energy dome covering the hull.
  /// It pulses, dims as it takes hits, and shows cracks + flare-outs as
  /// it approaches breaking.
  void _paintShieldDome(Canvas canvas, double w, double h, double cx, double cy, double pulse) {
    if (maxShieldHealth <= 0) return;

    final shieldPct = (shieldHealth / maxShieldHealth).clamp(0.0, 1.0);
    final radius = w * 0.58;
    final domeRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Dimmer and more red-tinged as it weakens.
    final domeColor = Color.lerp(Colors.redAccent, Colors.cyan, shieldPct)!;

    // Dome body — a translucent radial fill.
    final domePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          domeColor.withOpacity(0.02),
          domeColor.withOpacity(0.10 + 0.08 * pulse),
          domeColor.withOpacity(0.35 + 0.15 * pulse),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(domeRect);
    canvas.drawCircle(Offset(cx, cy), radius, domePaint);

    // Hexagonal lattice suggesting energy panels.
    final latticePaint = Paint()
      ..color = domeColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int ring = 1; ring <= 2; ring++) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * ring / 3,
        latticePaint,
      );
    }
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(a) * radius, cy + sin(a) * radius),
        latticePaint,
      );
    }

    // Rim — brightens as the shield weakens (strain glow).
    final rimPaint = Paint()
      ..color = domeColor.withOpacity(0.5 + 0.4 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy), radius, rimPaint);

    // Cracks appear as the shield weakens (jagged white lines from rim
    // toward the core; more cracks = fewer hits remaining).
    final cracks = maxShieldHealth - shieldHealth;
    if (cracks > 0) {
      final crackPaint = Paint()
        ..color = Colors.white.withOpacity(0.55 + 0.3 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final random = Random(99);
      for (int i = 0; i < cracks; i++) {
        final a = (i * 2 * pi / maxShieldHealth) + random.nextDouble() * 0.4;
        var px = cx + cos(a) * radius;
        var py = cy + sin(a) * radius;
        for (int seg = 0; seg < 3; seg++) {
          final inward = radius * (0.22 * (seg + 1));
          final jitter = (random.nextDouble() - 0.5) * radius * 0.25;
          final nx = cx + cos(a) * (radius - inward) + jitter;
          final ny = cy + sin(a) * (radius - inward) + jitter;
          canvas.drawLine(Offset(px, py), Offset(nx, ny), crackPaint);
          px = nx;
          py = ny;
        }
      }
    }
  }

  /// Void Lancer: a long central cannon barrel below the hull that
  /// glows hotter and pulls in energy particles as it charges.
  void _paintLaserCannon(Canvas canvas, double w, double h, double cx, double cy, double pulse) {
    final charge = laserChargeProgress;

    // Cannon barrel — a tapered armored tube pointing down from the
    // hull's nose.
    final barrelTop = h * 0.72;
    final barrelBottom = h * 0.98;
    final barrelPath = Path()
      ..moveTo(cx - w * 0.10, barrelTop)
      ..lineTo(cx + w * 0.10, barrelTop)
      ..lineTo(cx + w * 0.055, barrelBottom)
      ..lineTo(cx - w * 0.055, barrelBottom)
      ..close();
    final barrelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF45474F), Color(0xFF26262F)],
      ).createShader(Rect.fromLTWH(0, barrelTop, w, barrelBottom - barrelTop));
    canvas.drawPath(barrelPath, barrelPaint);
    canvas.drawPath(
      barrelPath,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (charge <= 0) return;

    // Muzzle glow grows with charge.
    final muzzleY = barrelBottom - 4;
    final glowRadius = w * (0.08 + 0.16 * charge) * (0.9 + 0.1 * pulse);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.95),
          Palette.bossCoreLowHealth.withOpacity(0.8 * charge),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, muzzleY), radius: glowRadius * 2));
    canvas.drawCircle(Offset(cx, muzzleY), glowRadius * 2, glowPaint);

    // Energy particles spiraling into the muzzle as it charges —
    // faster approach as the shot nears.
    final random = Random(frameCount ~/ 3);
    for (int i = 0; i < 5; i++) {
      final a = frameCount * 0.15 + i * (2 * pi / 5);
      final dist = w * 0.4 * (1 - charge) * (0.5 + random.nextDouble() * 0.5);
      final px = cx + cos(a) * dist;
      final py = muzzleY + sin(a) * dist * 0.6;
      canvas.drawCircle(
        Offset(px, py),
        2.0 + charge,
        Paint()..color = Palette.bossCoreLowHealth.withOpacity(0.7 * charge),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BossPainter old) =>
      old.health != health ||
      old.frameCount != frameCount ||
      old.shieldHealth != shieldHealth ||
      old.laserChargeProgress != laserChargeProgress;
}
