/// All game modes.
///
/// Adding a new mode: add an entry here AND implement a
/// [GameModeConfig] for it in `lib/game/`.
enum GameMode {
  classicRun,
}

/// The four temporary power-ups that can drop from destroyed entities.
enum PowerUpType {
  shield,
  rapidFire,
  tripleShot,
  laserBeam,
}

/// Enemy classification used for spawning probability tables and rendering.
enum EnemyType {
  normalAsteroid,
  smallFastAsteroid,
  hugeSlowAsteroid,
  enemyShip,
  boss,
}
