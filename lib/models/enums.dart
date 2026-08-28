/// All game modes.
///
/// Adding a new mode: add an entry here AND implement a
/// [GameModeConfig] for it in `lib/game/`.
enum GameMode {
  classicRun,
  bossRush,
}

/// The temporary power-ups that can drop from destroyed entities.
enum PowerUpType {
  shield,
  rapidFire,
  tripleShot,
  laserBeam,

  /// 5 bullets in a V spread; slightly slower cadence. Mutually
  /// exclusive with [tripleShot] (the most recently collected wins).
  pentaShot,

  /// Two invulnerable companion ships flank the player and fire rapid
  /// shots for the duration. Only the player takes damage / collects.
  wingDrones,
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
/// Boss Rush spawns all nine in random order; Classic Run only uses
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
  /// plus bursts of 10 bullets in a single line aimed at the player.
  /// Boss Rush exclusive.
  shieldedBurst,

  /// Stops moving to charge and fire a vertical instant-kill laser
  /// (survivable only with an active shield). Boss Rush exclusive.
  laserCannon,

  /// Drops bomb barrels that fall, then detonate in a blast radius the
  /// player must dodge. Boss Rush exclusive.
  bombardier,

  /// Fires a 7-bullet volley in a V formation — all straight down, but
  /// staggered vertically so the wall snakes toward the player.
  /// Boss Rush exclusive.
  serpentVolley,

  /// Not one ship but ten: a swarm of small shielded units that each
  /// fire single aimed bullets. The encounter ends when all ten die.
  /// Boss Rush exclusive.
  swarm,
}
