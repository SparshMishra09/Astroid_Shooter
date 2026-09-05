import 'dart:math' show sin, cos, pi;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/asteroids.dart';
import '../models/enemy_ship.dart';
import '../models/swarm_unit.dart';
import '../models/boss.dart';
import '../models/projectiles.dart';
import '../models/power_ups.dart';
import '../models/effects.dart';
import '../models/player.dart';
import '../config/palette.dart';
import 'painters/enemy_ship_painter.dart';
import 'painters/boss_painter.dart';
import 'painters/huge_asteroid_painter.dart';
import 'painters/small_asteroid_painter.dart';
import 'painters/effects_painter.dart';

// ============================================================
//  PLAYER
// ============================================================

/// Player ship (approved SVG) + shield ring + engine trail.
class PlayerWidget extends StatelessWidget {
  const PlayerWidget({
    super.key,
    required this.player,
    required this.hasShield,
    required this.shieldHitsRemaining,
    required this.blinkVisible,
    required this.frameCount,
    required this.trailPoints,
  });

  final Player player;
  final bool hasShield;
  final int shieldHitsRemaining;
  final bool blinkVisible;
  final int frameCount;
  final List<Offset> trailPoints;

  @override
  Widget build(BuildContext context) {
    if (!blinkVisible) return const SizedBox.shrink();

    return Positioned(
      left: player.x,
      top: player.y,
      width: player.width,
      height: player.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shield bubble
          if (hasShield && shieldHitsRemaining > 0)
            Container(
              width: player.width + 20,
              height: player.height + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Palette.shield.withOpacity(0.8), width: 3),
                boxShadow: [
                  BoxShadow(color: Palette.shield.withOpacity(0.5), spreadRadius: 2, blurRadius: 10),
                ],
              ),
            ),
          // Ship SVG
          SvgPicture.asset('assets/images/spaceship.svg', width: player.width, height: player.height),
        ],
      ),
    );
  }
}

// ============================================================
//  ASTEROIDS
// ============================================================

/// Normal asteroid — uses the approved SVG asset.
class AsteroidWidget extends StatelessWidget {
  const AsteroidWidget({super.key, required this.asteroid});
  final Asteroid asteroid;

  @override
  Widget build(BuildContext context) {
    if (!asteroid.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: asteroid.x,
      top: asteroid.y,
      width: asteroid.width,
      height: asteroid.height,
      child: Transform.rotate(
        angle: asteroid.rotationAngle,
        child: SvgPicture.asset('assets/images/asteroid.svg', width: asteroid.width, height: asteroid.height),
      ),
    );
  }
}

/// Small fast asteroid — CustomPainter redesign.
class SmallAsteroidWidget extends StatelessWidget {
  const SmallAsteroidWidget({super.key, required this.asteroid, required this.frameCount});
  final SmallFastAsteroid asteroid;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!asteroid.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: asteroid.x,
      top: asteroid.y,
      width: asteroid.width,
      height: asteroid.height,
      child: CustomPaint(
        size: Size(asteroid.width, asteroid.height),
        painter: SmallAsteroidPainter(rotationAngle: asteroid.rotationAngle, frameCount: frameCount),
      ),
    );
  }
}

/// Huge slow asteroid — CustomPainter redesign.
class HugeAsteroidWidget extends StatelessWidget {
  const HugeAsteroidWidget({super.key, required this.asteroid});
  final HugeSlowAsteroid asteroid;

  @override
  Widget build(BuildContext context) {
    if (!asteroid.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: asteroid.x,
      top: asteroid.y,
      width: asteroid.width,
      height: asteroid.height,
      child: CustomPaint(
        size: Size(asteroid.width, asteroid.height),
        painter: HugeAsteroidPainter(
          health: asteroid.health,
          maxHealth: asteroid.maxHealth,
          rotationAngle: asteroid.rotationAngle,
        ),
      ),
    );
  }
}

// ============================================================
//  ENEMY SHIP & BOSS
// ============================================================

/// Enemy fighter (evil-twin) — CustomPainter redesign.
class EnemyShipWidget extends StatelessWidget {
  const EnemyShipWidget({super.key, required this.ship, required this.frameCount});
  final EnemyShip ship;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!ship.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: ship.x,
      top: ship.y,
      width: ship.width,
      height: ship.height,
      child: CustomPaint(
        size: Size(ship.width, ship.height),
        painter: EnemyShipPainter(
          health: ship.health,
          maxHealth: ship.maxHealth,
          frameCount: frameCount,
        ),
      ),
    );
  }
}

/// One Swarm Lords unit: an evil twin of the PLAYER's ship — the same
/// dart silhouette with swept wings, cockpit and engine flame, mirrored
/// to point DOWN and painted in hostile crimson. A pulsing hexagonal
/// energy shield wraps it until broken; an unshielded unit shows a
/// brighter eye and battle damage sparks.
class SwarmUnitWidget extends StatelessWidget {
  const SwarmUnitWidget({super.key, required this.unit, required this.frameCount});
  final SwarmUnit unit;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!unit.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: unit.x,
      top: unit.y,
      width: unit.width,
      height: unit.height,
      child: CustomPaint(
        size: Size(unit.width, unit.height),
        painter: _SwarmUnitPainter(
          hasShield: unit.hasShield,
          frameCount: frameCount,
          phase: unit.phase,
        ),
      ),
    );
  }
}

class _SwarmUnitPainter extends CustomPainter {
  _SwarmUnitPainter({
    required this.hasShield,
    required this.frameCount,
    required this.phase,
  });

  final bool hasShield;
  final int frameCount;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final pulse = 0.5 + 0.5 * sin(frameCount * 0.1 + phase);

    // --- Shield ring (hex) while shielded ---
    if (hasShield) {
      final radius = w * 0.78 + pulse * 2;
      final hex = Path();
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3 - pi / 6;
        final px = cx + cos(a) * radius;
        final py = h / 2 + sin(a) * radius;
        if (i == 0) {
          hex.moveTo(px, py);
        } else {
          hex.lineTo(px, py);
        }
      }
      hex.close();

      canvas.drawPath(
        hex,
        Paint()
          ..color = Colors.cyan.withOpacity(0.10 + 0.06 * pulse)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        hex,
        Paint()
          ..color = Colors.cyan.withOpacity(0.5 + 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      // Corner nodes on the hex.
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3 - pi / 6;
        canvas.drawCircle(
          Offset(cx + cos(a) * radius, h / 2 + sin(a) * radius),
          1.8,
          Paint()..color = Colors.cyan.withOpacity(0.6 + 0.4 * pulse),
        );
      }
    }

    // === Evil-twin hull: the player ship's dart, mirrored DOWN ===
    // Same geometry as spaceship.svg, flipped vertically and scaled.
    // Player: M25,5 L35,40 L25,35 L15,40 → mirrored about the center.
    final hull = Path()
      ..moveTo(cx, h * 0.90) // nose tip (bottom — points at the player)
      ..lineTo(cx + w * 0.22, h * 0.16) // right shoulder
      ..lineTo(cx, h * 0.28) // notch (mirrored cockpit keel)
      ..lineTo(cx - w * 0.22, h * 0.16) // left shoulder
      ..close();

    canvas.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF6B1A1F), Color(0xFF8C2730)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      hull,
      Paint()
        ..color = const Color(0xFF1A0808)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Swept wings (mirrored from the player's).
    final wingPaint = Paint()..color = const Color(0xFFB91C1C);
    final wingStroke = Paint()
      ..color = const Color(0xFF1A0808)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final leftWing = Path()
      ..moveTo(cx - w * 0.20, h * 0.40)
      ..lineTo(cx - w * 0.46, h * 0.16)
      ..lineTo(cx - w * 0.22, h * 0.30)
      ..close();
    final rightWing = Path()
      ..moveTo(cx + w * 0.20, h * 0.40)
      ..lineTo(cx + w * 0.46, h * 0.16)
      ..lineTo(cx + w * 0.22, h * 0.30)
      ..close();
    canvas.drawPath(leftWing, wingPaint);
    canvas.drawPath(leftWing, wingStroke);
    canvas.drawPath(rightWing, wingPaint);
    canvas.drawPath(rightWing, wingStroke);

    // Engine flame at the TOP (ship is inverted) — flickering.
    final flamePulse = 0.7 + 0.3 * sin(frameCount * 0.5 + phase);
    final flame = Path()
      ..moveTo(cx - w * 0.07, h * 0.14)
      ..lineTo(cx, h * 0.02 - flamePulse * 2)
      ..lineTo(cx + w * 0.07, h * 0.14)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF6A00).withOpacity(0.9),
            const Color(0xFFFFC933).withOpacity(0.5 * flamePulse),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.2)),
    );

    // Cockpit eye — glows brighter when unshielded ("enraged").
    final eyeRadius = w * 0.11;
    final eyeGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.9),
          const Color(0xFFFF2A2A).withOpacity(hasShield ? 0.75 : 1.0),
          const Color(0xFFFF2A2A).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, h * 0.52), radius: eyeRadius * 2.2));
    canvas.drawCircle(Offset(cx, h * 0.52), eyeRadius * 2.2, eyeGlow);
    canvas.drawCircle(
      Offset(cx, h * 0.52),
      eyeRadius,
      Paint()..color = const Color(0xFFFF2A2A).withOpacity(hasShield ? 0.85 : 1.0),
    );
    canvas.drawCircle(
      Offset(cx - eyeRadius * 0.25, h * 0.52 - eyeRadius * 0.25),
      eyeRadius * 0.35,
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    // Hull panel line (mirrored metallic detail).
    canvas.drawLine(
      Offset(cx, h * 0.30),
      Offset(cx, h * 0.78),
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..strokeWidth = 1,
    );

    // Battle damage sparks once the shield is gone.
    if (!hasShield) {
      final sparkPaint = Paint()
        ..color = Colors.amber.withOpacity(0.4 + 0.6 * pulse)
        ..strokeWidth = 1.2;
      for (int i = 0; i < 3; i++) {
        final a = frameCount * 0.2 + i * 2 * pi / 3;
        canvas.drawLine(
          Offset(cx, h * 0.68),
          Offset(cx + cos(a) * w * 0.20, h * 0.68 + sin(a) * h * 0.16),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SwarmUnitPainter old) =>
      old.frameCount != frameCount || old.hasShield != hasShield;
}

/// Boss dreadnought — CustomPainter redesign + health bar (+ shield bar
/// for the Bulwark Sentinel).
class BossWidget extends StatelessWidget {
  const BossWidget({super.key, required this.boss, required this.frameCount});
  final Boss boss;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!boss.isVisible) return const SizedBox.shrink();
    final healthPct = (boss.health / boss.maxHealth).clamp(0.0, 1.0);
    final shieldPct =
        boss.maxShieldHealth > 0 ? (boss.shieldHealth / boss.maxShieldHealth).clamp(0.0, 1.0) : 0.0;

    return Positioned(
      left: boss.x,
      top: boss.y,
      width: boss.width,
      height: boss.height + 14, // room for health bar below
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: boss.width,
            height: boss.height,
            child: CustomPaint(
              painter: BossPainter(
                health: boss.health,
                maxHealth: boss.maxHealth,
                frameCount: frameCount,
                bossType: boss.bossType,
                shieldHealth: boss.shieldHealth,
                maxShieldHealth: boss.maxShieldHealth,
                laserChargeProgress: boss.laserChargeProgress,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Shield bar (Bulwark Sentinel only) — sits above the hull bar
          if (boss.maxShieldHealth > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: SizedBox(
                width: boss.width,
                child: Stack(
                  children: [
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white38, width: 1),
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: shieldPct,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.cyan, Colors.lightBlueAccent]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Health bar
          SizedBox(
            width: boss.width,
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white38, width: 1),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: healthPct,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        healthPct > 0.5 ? Colors.purple : Colors.red,
                        healthPct > 0.3 ? Colors.blue : Colors.orange,
                      ]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Void Lancer's laser: a vertical instant-kill beam fired
/// straight down from the boss's cannon.
///
/// While the boss CHARGES, this renders a thin blinking red warning
/// line (the telegraph); while FIRING it renders the full lethal beam
/// — white-hot core, red energy body, flickering aura, impact flare at
/// the bottom of the screen.
class BossLaserBeamWidget extends StatelessWidget {
  const BossLaserBeamWidget({
    super.key,
    required this.boss,
    required this.screenHeight,
    required this.frameCount,
    required this.beamWidth,
  });

  final Boss boss;

  /// Screen height — the beam runs from the boss's cannon to the
  /// bottom edge, passed in rather than using MediaQuery so it stays a
  /// pure function of game state.
  final double screenHeight;
  final int frameCount;
  final double beamWidth;

  @override
  Widget build(BuildContext context) {
    if (!boss.isVisible ||
        (boss.laserPhase != BossLaserPhase.charging &&
            boss.laserPhase != BossLaserPhase.firing)) {
      return const SizedBox.shrink();
    }

    final beamCenter = boss.x + boss.width / 2;
    final beamTop = boss.y + boss.height;
    final beamHeight = screenHeight - beamTop;
    final t = frameCount.toDouble();
    final flicker = 0.75 + 0.25 * sin(t * 1.1);

    // --- Telegraph: thin blinking warning line while charging ---
    if (boss.laserPhase == BossLaserPhase.charging) {
      final blink = (sin(t * 0.5) > 0) ? 0.8 : 0.25;
      return Positioned(
        left: beamCenter - 1.5,
        top: beamTop,
        width: 3,
        height: beamHeight,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.withOpacity(blink),
                Colors.red.withOpacity(blink * 0.5),
              ],
            ),
          ),
        ),
      );
    }

    // --- Full beam while firing ---
    final auraWidth = beamWidth * 2.6;
    return Positioned(
      left: beamCenter - auraWidth / 2,
      top: beamTop,
      width: auraWidth,
      height: beamHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Aura
          Center(
            child: Container(
              width: auraWidth,
              height: beamHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.red.withOpacity(0.35 * flicker),
                    Colors.deepOrange.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Beam body
          Container(
            width: beamWidth,
            height: beamHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.red.withOpacity(0.9),
                  Colors.deepOrange.withOpacity(0.85 * flicker),
                ],
              ),
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.7 * flicker),
                  spreadRadius: 3,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          // White-hot core
          Container(
            width: beamWidth * 0.4,
            height: beamHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(0.85 * flicker),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Impact flare at the bottom of the screen
          Positioned(
            bottom: -10,
            child: Container(
              width: beamWidth * 2.2,
              height: beamWidth * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.red.withOpacity(0.6 * flicker),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  PROJECTILES
// ============================================================

/// Bomb barrel dropped by the Demolition Titan: a spinning metal drum
/// with hazard stripes and a warning light that blinks faster as it
/// falls toward the player's level, going solid red right before the
/// blast.
class BombBarrelWidget extends StatelessWidget {
  const BombBarrelWidget({super.key, required this.barrel, required this.frameCount});
  final BombBarrel barrel;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!barrel.isVisible) return const SizedBox.shrink();

    final fall = barrel.fallProgress; // 0 = dropped .. 1 = at player level
    final critical = fall > 0.75;

    // Blink rate accelerates as the barrel closes on its target line.
    final blinkPeriod = critical ? 4 : (fall > 0.5 ? 8 : 14);
    final blinkOn = (frameCount % blinkPeriod) < (blinkPeriod ~/ 2);

    final warningColor = critical ? Colors.red : Colors.orange;
    final glowOpacity = critical ? (blinkOn ? 0.9 : 0.5) : (blinkOn ? 0.55 : 0.15);

    return Positioned(
      left: barrel.x,
      top: barrel.y,
      width: barrel.width,
      height: barrel.height,
      child: Transform.rotate(
        angle: barrel.rotationAngle,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5A5A66), Color(0xFF33333C), Color(0xFF5A5A66)],
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: warningColor.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: warningColor.withOpacity(glowOpacity),
                spreadRadius: critical ? 3 : 1,
                blurRadius: critical ? 12 : 6,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hazard stripes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 2; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 3,
                      height: barrel.height * 0.55,
                      color: Colors.amber.withOpacity(0.6),
                    ),
                ],
              ),
              // Warning light — blinks, then solid red near detonation
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: critical
                      ? warningColor.withOpacity(blinkOn ? 1.0 : 0.6)
                      : warningColor.withOpacity(blinkOn ? 0.9 : 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: warningColor.withOpacity(glowOpacity),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wing drone: a small cyan companion ship flanking the player,
/// with a bobbing hover and its own engine glow. Rendered above the
/// effects layer but below HUD.
class WingDroneWidget extends StatelessWidget {
  const WingDroneWidget({
    super.key,
    required this.x,
    required this.y,
    required this.size,
    required this.frameCount,
  });

  final double x;
  final double y;
  final double size;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    // Gentle hover bob, phase-shifted per drone via x so the pair
    // doesn't bob in unison.
    final bob = sin((frameCount + x) * 0.12) * 3;
    final enginePulse = 0.6 + 0.4 * sin((frameCount + x) * 0.4);

    return Positioned(
      left: x - size / 2,
      top: y - size / 2 + bob,
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Engine glow beneath
          Positioned(
            bottom: -4,
            child: Container(
              width: size * 0.5,
              height: size * 0.35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Palette.droneEngine.withOpacity(0.9 * enginePulse),
                    Palette.droneEngine.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Hull — a small dart
          CustomPaint(
            size: Size(size, size),
            painter: _WingDronePainter(frameCount: frameCount),
          ),
        ],
      ),
    );
  }
}

/// Miniature hull for a wing drone: a compact cyan dart with a lit
/// cockpit dot and thin winglets.
class _WingDronePainter extends CustomPainter {
  _WingDronePainter({required this.frameCount});
  final int frameCount;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final pulse = 0.5 + 0.5 * sin(frameCount * 0.15);

    // Hull — small dart pointing up.
    final hull = Path()
      ..moveTo(cx, h * 0.06)
      ..lineTo(cx + w * 0.30, h * 0.45)
      ..lineTo(cx + w * 0.22, h * 0.92)
      ..lineTo(cx - w * 0.22, h * 0.92)
      ..lineTo(cx - w * 0.30, h * 0.45)
      ..close();
    canvas.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Palette.droneHull.withOpacity(0.95),
            Palette.droneEngine.withOpacity(0.8),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      hull,
      Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Winglets.
    final wingPaint = Paint()..color = Palette.droneHull.withOpacity(0.85);
    canvas.drawLine(Offset(cx - w * 0.28, h * 0.55), Offset(cx - w * 0.46, h * 0.75), wingPaint);
    canvas.drawLine(Offset(cx + w * 0.28, h * 0.55), Offset(cx + w * 0.46, h * 0.75), wingPaint);

    // Cockpit light.
    canvas.drawCircle(
      Offset(cx, h * 0.38),
      w * 0.09,
      Paint()..color = Colors.white.withOpacity(0.7 + 0.3 * pulse),
    );
  }

  @override
  bool shouldRepaint(covariant _WingDronePainter old) =>
      old.frameCount != frameCount;
}

/// Player bullet — approved SVG asset.
class BulletWidget extends StatelessWidget {
  const BulletWidget({super.key, required this.bullet});
  final Bullet bullet;

  @override
  Widget build(BuildContext context) {
    if (!bullet.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: bullet.x,
      top: bullet.y,
      width: bullet.width,
      height: bullet.height,
      child: SvgPicture.asset('assets/images/bullet.svg', width: bullet.width, height: bullet.height),
    );
  }
}

/// Enemy bullet — glowing red plasma bolt.
class EnemyBulletWidget extends StatelessWidget {
  const EnemyBulletWidget({super.key, required this.bullet, required this.frameCount});
  final EnemyBullet bullet;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!bullet.isVisible) return const SizedBox.shrink();
    final pulse = 0.7 + 0.3 * (frameCount % 8 / 8);
    return Positioned(
      left: bullet.x,
      top: bullet.y,
      width: bullet.width,
      height: bullet.height,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [Colors.white, Palette.enemyBullet]),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: Palette.enemyBullet.withOpacity(0.6 * pulse), spreadRadius: 1, blurRadius: 5),
          ],
        ),
      ),
    );
  }
}

/// Laser beam — a multi-layered energy lance following the player x.
///
/// Layers (back to front): a wide breathing aura, the glowing beam
/// body, a white-hot flickering core, bright energy pulses racing from
/// the ship up the beam, a muzzle orb where the beam emits from the
/// ship, and an impact flare where it strikes the top of the screen.
class LaserBeamWidget extends StatelessWidget {
  const LaserBeamWidget({super.key, required this.laser, required this.frameCount});
  final LaserBeam laser;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!laser.isVisible) return const SizedBox.shrink();

    final w = laser.width; // beam body width (8)
    final h = laser.height;
    final t = frameCount.toDouble();

    // Fast flicker so the beam feels electric and alive.
    final flicker = 0.7 + 0.3 * (0.5 + 0.5 * sin(t * 0.9));
    // Slow "breathing" of the aura width.
    final breathe = 1.0 + 0.3 * sin(t * 0.13);

    // The stack is wider than the beam so the aura and glow have room.
    final auraWidth = (w * 3.2) * breathe;

    return Positioned(
      left: laser.x - (auraWidth - w) / 2,
      top: laser.y,
      width: auraWidth,
      height: h,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // --- 1. Wide breathing aura ---
          Center(
            child: Container(
              width: auraWidth,
              height: h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Palette.laserOuter.withOpacity(0.05),
                    Palette.laserOuter.withOpacity(0.22 * flicker),
                    Palette.laserMain.withOpacity(0.30 * flicker),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          // --- 2. Beam body (purple → pink, edge-glowed) ---
          Container(
            width: w + 6,
            height: h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Palette.laserOuter.withOpacity(0.55),
                  Palette.laserMain.withOpacity(0.75),
                  Palette.laserMain.withOpacity(0.9),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Palette.laserOuter.withOpacity(0.55 * flicker),
                  spreadRadius: 2,
                  blurRadius: 8,
                ),
              ],
            ),
          ),

          // --- 3. White-hot flickering core ---
          Container(
            width: w - 2,
            height: h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.35 * flicker),
                  Colors.white.withOpacity(0.75),
                  Colors.white.withOpacity(0.95 * flicker),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // --- 4. Energy pulses racing from the ship up the beam ---
          for (int i = 0; i < 3; i++)
            Positioned(
              top: h - ((t * 9 + i * (h + 60) / 3) % (h + 60)),
              child: Container(
                width: w * 1.8,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.laserMain.withOpacity(0.8),
                      spreadRadius: 2,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

          // --- 5. Muzzle orb where the beam emits from the ship ---
          Positioned(
            bottom: -6,
            child: Container(
              width: w * 2.4,
              height: w * 2.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white,
                    Palette.laserMain.withOpacity(0.9 * flicker),
                    Palette.laserOuter.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // --- 6. Impact flare where the beam strikes the screen top ---
          Positioned(
            top: -8,
            child: Container(
              width: w * 3.0,
              height: w * 1.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.95),
                    Palette.laserMain.withOpacity(0.7 * flicker),
                    Palette.laserOuter.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  POWER-UPS & FLOATING TEXT
// ============================================================

/// Pulsing power-up pickup orb.
class PowerUpWidget extends StatelessWidget {
  const PowerUpWidget({super.key, required this.powerUp, required this.frameCount});
  final PowerUp powerUp;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!powerUp.isVisible) return const SizedBox.shrink();
    // Simple pulsing scale
    final scale = 1.0 + (frameCount % 30 < 15 ? 0.15 : -0.05);

    return Positioned(
      left: powerUp.x,
      top: powerUp.y,
      width: powerUp.width,
      height: powerUp.height,
      child: Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            color: powerUp.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: powerUp.color.withOpacity(0.6), spreadRadius: 2, blurRadius: 10),
            ],
          ),
          child: Icon(powerUp.icon, color: Colors.white, size: powerUp.width * 0.6),
        ),
      ),
    );
  }
}

/// Floating text for score popups / notifications.
class FloatingTextWidget extends StatelessWidget {
  const FloatingTextWidget({super.key, required this.text});
  final FloatingText text;

  @override
  Widget build(BuildContext context) {
    if (!text.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: text.x,
      top: text.y,
      child: Opacity(
        opacity: text.opacity,
        child: Text(
          text.text,
          style: TextStyle(
            color: text.color,
            fontSize: text.fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  EFFECTS LAYER (single CustomPaint for all particles/sparks)
// ============================================================

/// Renders all explosions, hit sparks, muzzle flashes and the engine trail
/// in one paint pass.
class EffectsLayer extends StatelessWidget {
  const EffectsLayer({
    super.key,
    required this.explosions,
    required this.hitEffects,
    required this.muzzleFlashes,
    required this.engineTrailPoints,
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.width,
    required this.height,
  });

  final List<ExplosionEffect> explosions;
  final List<HitEffect> hitEffects;
  final List<Flash> muzzleFlashes;
  final List<Offset> engineTrailPoints;
  final double playerX;
  final double playerY;
  final double playerWidth;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: width,
      height: height,
      child: CustomPaint(
        painter: EffectsPainter(
          explosions: explosions,
          hitEffects: hitEffects,
          muzzleFlashes: muzzleFlashes,
          engineTrailPoints: engineTrailPoints,
          playerX: playerX,
          playerY: playerY,
          playerWidth: playerWidth,
        ),
      ),
    );
  }
}
