import 'package:flutter/material.dart';

/// Centralized color palettes for redesigned entities and UI.
///
/// Using named palettes instead of raw `Colors.xxx` scattered through
/// painters keeps the visual identity consistent and easy to retheme.
class Palette {
  Palette._();

  // --- Player ship (kept SVG, but trail/flashes use these) ---
  static const Color playerTrail = Color(0xFF4A7AFF);
  static const Color muzzleFlash = Color(0xFFFFE066);

  // --- Enemy ship (evil-twin fighter) ---
  static const List<Color> enemyShipHull = [
    Color(0xFF1A0808), // darkest base
    Color(0xFF3D0F12), // crimson shadow
    Color(0xFF6B1A1F), // crimson body
    Color(0xFF8C2730), // crimson highlight
  ];
  static const Color enemyShipEye = Color(0xFFFF2A2A);
  static const Color enemyShipEngine = Color(0xFFFF6A00);
  static const Color enemyShipAura = Color(0xFFFF2A2A);

  // --- Boss dreadnought ---
  static const List<Color> bossHull = [
    Color(0xFF0E0E14), // near-black base
    Color(0xFF26262F), // dark steel
    Color(0xFF45474F), // mid steel
    Color(0xFF6E7178), // light steel highlight
  ];
  static const Color bossCoreHighHealth = Color(0xFF9D4EDD); // purple
  static const Color bossCoreMidHealth = Color(0xFFFF7B00); // orange
  static const Color bossCoreLowHealth = Color(0xFFFF2D2D); // red
  static const Color bossRing = Color(0xFFB388FF);
  static const Color bossThruster = Color(0xFFFF6A00);

  // --- Huge asteroid ---
  static const List<Color> hugeAsteroidRock = [
    Color(0xFF5A4A3A), // dark rocky brown
    Color(0xFF7B6753), // mid brown
    Color(0xFF9E8870), // light brown
  ];
  static const Color hugeAsteroidCrater = Color(0xFF3D2E22);
  static const Color hugeAsteroidCrack = Color(0xFF1A0F08);

  // --- Small fast asteroid ---
  static const List<Color> smallAsteroidRock = [
    Color(0xFF4A4038),
    Color(0xFF6B5D52),
    Color(0xFF8C7B6E),
  ];
  static const Color smallAsteroidGlow = Color(0xFFFF7B00);
  static const Color smallAsteroidTrail = Color(0xFFFFB347);

  // --- Explosions ---
  static const List<Color> explosionColors = [
    Colors.orange,
    Colors.red,
    Colors.yellow,
    Colors.deepOrange,
    Colors.amber,
  ];

  // --- Power-up colors ---
  static const Color shield = Colors.blue;
  static const Color rapidFire = Colors.red;
  static const Color tripleShot = Colors.green;
  static const Color laserBeam = Colors.purple;
  static const Color pentaShot = Colors.tealAccent;
  static const Color wingDrones = Colors.lightGreenAccent;

  // --- Wing drones ---
  static const Color droneHull = Colors.cyanAccent;
  static const Color droneEngine = Colors.cyan;

  // --- UI ---
  static const Color astridText = Colors.amber;
  static const Color waveBadgeStart = Colors.orange;
  static const Color waveBadgeEnd = Colors.red;
  static const Color waveNotifyStart = Colors.cyan;
  static const Color waveNotifyEnd = Colors.blue;
  static const Color waveCompleteStart = Colors.yellow;
  static const Color waveCompleteEnd = Colors.orange;
  static const Color enemyBullet = Color(0xFFFF3B3B);
  static const Color laserOuter = Colors.purple;
  static const Color laserMain = Colors.pink;
  static const Color laserCore = Colors.white;
}
