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

/// Boss dreadnought — CustomPainter redesign + health bar.
class BossWidget extends StatelessWidget {
  const BossWidget({super.key, required this.boss, required this.frameCount});
  final Boss boss;
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    if (!boss.isVisible) return const SizedBox.shrink();
    final healthPct = (boss.health / boss.maxHealth).clamp(0.0, 1.0);

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
              painter: BossPainter(health: boss.health, maxHealth: boss.maxHealth, frameCount: frameCount),
            ),
          ),
          const SizedBox(height: 4),
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

/// Laser beam — follows the player x, multi-layer glow.
class LaserBeamWidget extends StatelessWidget {
  const LaserBeamWidget({super.key, required this.laser});
  final LaserBeam laser;

  @override
  Widget build(BuildContext context) {
    if (!laser.isVisible) return const SizedBox.shrink();
    return Positioned(
      left: laser.x,
      top: laser.y,
      width: laser.width + 4,
      height: laser.height,
      child: Stack(
        children: [
          // Outer glow
          Container(
            width: laser.width + 4,
            height: laser.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.laserOuter.withOpacity(0.3), Palette.laserMain.withOpacity(0.2)],
              ),
            ),
          ),
          // Main beam
          Positioned(
            left: 2,
            child: Container(
              width: laser.width,
              height: laser.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Palette.laserOuter.withOpacity(0.9), Palette.laserMain.withOpacity(0.8)],
                ),
              ),
            ),
          ),
          // Inner core
          Positioned(
            left: 3,
            child: Container(
              width: laser.width - 2,
              height: laser.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Palette.laserCore.withOpacity(0.8), Palette.laserMain.withOpacity(0.9)],
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
