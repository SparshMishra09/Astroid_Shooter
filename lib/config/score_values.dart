/// Base score values per entity (before combo multiplier).
class ScoreValues {
  ScoreValues._();

  static const int normalAsteroid = 10;
  static const int smallFastAsteroid = 15;
  static const int hugeSlowAsteroid = 30;
  static const int enemyShip = 40;
  static const int boss = 200;

  // --- Boss Rush variants ---
  static const int bossTriBeam = 200;
  static const int bossRapidFire = 300;
  static const int bossPentaBeam = 400;
  static const int bossMarksman = 500;
  static const int bossShieldedBurst = 350;
  static const int bossLaserCannon = 450;
}
