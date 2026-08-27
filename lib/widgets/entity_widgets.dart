import 'dart:math' show sin;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/asteroids.dart';
import '../models/enemy_ship.dart';
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
