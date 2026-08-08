import 'dart:math';
import 'package:flutter/material.dart';
import '../config/palette.dart';

/// A single particle used in explosion/burst effects.
class Particle {
  double x;
  double y;
  double speedX;
  double speedY;
  double size;
  Color color;
  int lifeTimer;
  final int maxLifeTime;

  Particle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.color,
    this.lifeTimer = 60,
  }) : maxLifeTime = lifeTimer;

  void update() {
    x += speedX;
    y += speedY;
    lifeTimer--;
    speedY += 0.1; // gravity-like
    speedX *= 0.98; // air resistance
    speedY *= 0.98;
  }

  bool get isAlive => lifeTimer > 0;

  double get opacity => (lifeTimer / maxLifeTime.toDouble()).clamp(0.0, 1.0);

  double get currentSize {
    final progress = 1.0 - (lifeTimer / maxLifeTime.toDouble());
    return size * (1.0 - progress * 0.5);
  }
}

/// Explosion effect: a burst of particles radiating outward.
class ExplosionEffect {
  final double x;
  final double y;
  final List<Particle> particles = [];
  int duration;

  ExplosionEffect({
    required this.x,
    required this.y,
    int particleCount = 8,
    this.duration = 60,
    List<Color>? colors,
  }) {
    _createParticles(particleCount, colors ?? Palette.explosionColors);
  }

  void _createParticles(int count, List<Color> colors) {
    final random = Random();
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + random.nextDouble() * 0.3;
      final speed = 1.0 + random.nextDouble() * 3.0;
      particles.add(Particle(
        x: x,
        y: y,
        speedX: cos(angle) * speed,
        speedY: sin(angle) * speed,
        size: 2.0 + random.nextDouble() * 4.0,
        color: colors[random.nextInt(colors.length)],
        lifeTimer: 30 + random.nextInt(30),
      ));
    }
  }

  void update() {
    for (var particle in particles) {
      particle.update();
    }
    particles.removeWhere((particle) => !particle.isAlive);
    duration--;
  }

  bool get isActive => particles.isNotEmpty && duration > 0;
}

/// Hit spark shown when an enemy/boss takes non-lethal damage.
class HitEffect {
  final double x;
  final double y;
  final Color color;
  int lifeTimer;
  final int maxLifeTime;
  final double size;

  HitEffect({
    required this.x,
    required this.y,
    required this.color,
    this.lifeTimer = 30,
    this.size = 20.0,
  }) : maxLifeTime = lifeTimer;

  void update() => lifeTimer--;

  bool get isActive => lifeTimer > 0;

  double get opacity => (lifeTimer / maxLifeTime.toDouble()).clamp(0.0, 1.0);

  double get currentSize {
    final progress = 1.0 - (lifeTimer / maxLifeTime.toDouble());
    return size * (1.0 + progress * 0.5);
  }
}

/// Floating text used for score popups, power-up names, boss warnings.
class FloatingText {
  final String text;
  double x;
  double y;
  final double speedY;
  int lifeTimer;
  final Color color;
  final int maxLifeTime;
  final double fontSize;

  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    this.speedY = -1,
    this.lifeTimer = 120,
    this.color = Colors.yellow,
    this.fontSize = 16,
  }) : maxLifeTime = lifeTimer;

  void update() {
    y += speedY;
    lifeTimer--;
  }

  bool get isVisible => lifeTimer > 0;

  double get opacity => (lifeTimer / maxLifeTime.toDouble()).clamp(0.0, 1.0);
}
