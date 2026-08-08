import 'dart:math';
import 'package:flutter/material.dart';
import 'game_object.dart';
import 'enums.dart';
import '../config/game_config.dart';
import '../config/palette.dart';

/// A floating power-up pickup dropped by destroyed entities.
class PowerUp extends GameObject {
  final PowerUpType type;
  double speedY;
  int lifeTimer;
  final int maxLifeTime;

  PowerUp({
    required double x,
    required double y,
    required this.type,
    double width = GameConfig.powerUpSize,
    double height = GameConfig.powerUpSize,
    this.speedY = GameConfig.powerUpFallSpeed,
  })  : lifeTimer = GameConfig.powerUpLifeTime,
        maxLifeTime = GameConfig.powerUpLifeTime,
        super(x: x, y: y, width: width, height: height);

  void update(double screenHeight) {
    y += speedY;
    lifeTimer--;
    if (y > screenHeight || lifeTimer <= 0) isVisible = false;
  }

  Color get color {
    switch (type) {
      case PowerUpType.shield:
        return Palette.shield;
      case PowerUpType.rapidFire:
        return Palette.rapidFire;
      case PowerUpType.tripleShot:
        return Palette.tripleShot;
      case PowerUpType.laserBeam:
        return Palette.laserBeam;
    }
  }

  IconData get icon {
    switch (type) {
      case PowerUpType.shield:
        return Icons.shield;
      case PowerUpType.rapidFire:
        return Icons.speed;
      case PowerUpType.tripleShot:
        return Icons.scatter_plot;
      case PowerUpType.laserBeam:
        return Icons.flash_on;
    }
  }

  static PowerUp random(double x, double y) {
    final random = Random();
    final types = PowerUpType.values;
    final type = types[random.nextInt(types.length)];
    return PowerUp(x: x, y: y, type: type);
  }
}

/// Manages an active (currently-equipped) power-up's remaining duration.
class ActivePowerUp {
  final PowerUpType type;
  int remainingTime;
  bool isActive;

  ActivePowerUp({
    required this.type,
    required this.remainingTime,
    this.isActive = true,
  });

  void update() {
    if (isActive && remainingTime > 0) {
      remainingTime--;
      if (remainingTime <= 0) isActive = false;
    }
  }

  /// Duration in frames (@ 60fps) for a given power-up type.
  static int getDuration(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return GameConfig.shieldDuration;
      case PowerUpType.rapidFire:
        return GameConfig.rapidFireDuration;
      case PowerUpType.tripleShot:
        return GameConfig.tripleShotDuration;
      case PowerUpType.laserBeam:
        return GameConfig.laserBeamDuration;
    }
  }

  /// Player-facing activation message.
  String get displayName {
    switch (type) {
      case PowerUpType.shield:
        return 'Shield Activated!';
      case PowerUpType.rapidFire:
        return 'Rapid Fire!';
      case PowerUpType.tripleShot:
        return 'Triple Shot!';
      case PowerUpType.laserBeam:
        return 'Laser Beam!';
    }
  }
}
