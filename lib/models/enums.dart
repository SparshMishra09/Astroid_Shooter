/// All game modes.
///
/// Adding a new mode: add an entry here AND implement a
/// [GameModeConfig] for it in `lib/game/`.
enum GameMode {
  classicRun,
  bossRush,
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

/// Boss variants. Each has a distinct attack pattern and energy color.
///
/// Boss Rush spawns all six in random order; Classic Run only uses
/// [triBeam] (the original dreadnought).
enum BossType {
  /// 3-way bullet spread — the original dreadnought.
  triBeam,

  /// Very short shoot interval — a bullet hose aimed straight down.
  rapidFire,

  /// 5-way bullet spread.
  pentaBeam,

  /// Single aimed shot at the player + 3 escort minion ships.
  marksman,

  /// Energy shield that must be broken before the hull takes damage,
  /// plus bursts of 3 bullets in a single line aimed at the player.
  /// Boss Rush exclusive.
  shieldedBurst,

  /// Stops moving to charge and fire a vertical instant-kill laser
  /// (survivable only with an active shield). Boss Rush exclusive.
  laserCannon,
}
