/// A snapshot of a user's persistent progress stored in Firestore.
///
/// This is the per-account data that survives across sessions and
/// devices — distinct from the per-run [GameState] which resets each
/// game.
///
/// Global fields:
/// - [astrids]: currency balance (accumulated across all games in ALL
///   modes, for the future shop). Each completed game adds its score.
///
/// Legacy fields ([bestScore], [highestWave], [totalAsteroidsDestroyed])
/// are the pre-mode-split stats. All historical data was Classic Run,
/// so they double as the Classic fallback when the per-mode fields are
/// missing.
///
/// Per-mode fields (each mode only counts games played in that mode):
/// - Classic Run: [classicBestScore], [classicHighestWave],
///   [classicAsteroidsDestroyed].
/// - Boss Rush: [bossRushBestScore], [bossRushHighestWave] (highest
///   boss number reached), [bossRushBossesDefeated] (accumulated).
class UserProgress {
  final String uid;
  final String displayName;
  final String email;
  final int astrids;

  // Legacy / global-best fields
  final int bestScore;
  final int highestWave;
  final int totalAsteroidsDestroyed;

  // Classic Run
  final int classicBestScore;
  final int classicHighestWave;
  final int classicAsteroidsDestroyed;

  // Boss Rush
  final int bossRushBestScore;
  final int bossRushHighestWave;
  final int bossRushBossesDefeated;

  const UserProgress({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.astrids,
    required this.bestScore,
    required this.highestWave,
    required this.totalAsteroidsDestroyed,
    required this.classicBestScore,
    required this.classicHighestWave,
    required this.classicAsteroidsDestroyed,
    required this.bossRushBestScore,
    required this.bossRushHighestWave,
    required this.bossRushBossesDefeated,
  });

  /// Create from a Firestore document.
  ///
  /// Docs written before the mode split have only the legacy fields.
  /// Since every pre-split game was Classic Run, those values carry
  /// over as the player's Classic stats; Boss Rush starts at zero.
  factory UserProgress.fromDoc(String uid, Map<String, dynamic> data) {
    final legacyBest = toInt(data['bestScore']);
    final legacyWave = toInt(data['highestWave']);
    final legacyDestroyed = toInt(data['totalAsteroidsDestroyed']);

    final hasClassic = data.containsKey('classicBestScore');

    return UserProgress(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? 'Pilot',
      email: (data['email'] as String?) ?? '',
      astrids: toInt(data['astrids']),
      bestScore: legacyBest,
      highestWave: legacyWave,
      totalAsteroidsDestroyed: legacyDestroyed,
      classicBestScore:
          hasClassic ? toInt(data['classicBestScore']) : legacyBest,
      classicHighestWave:
          hasClassic ? toInt(data['classicHighestWave']) : legacyWave,
      classicAsteroidsDestroyed: hasClassic
          ? toInt(data['classicAsteroidsDestroyed'])
          : legacyDestroyed,
      bossRushBestScore: toInt(data['bossRushBestScore']),
      bossRushHighestWave: toInt(data['bossRushHighestWave']),
      bossRushBossesDefeated: toInt(data['bossRushBossesDefeated']),
    );
  }

  /// A fresh account starts with zero everything.
  factory UserProgress.zero({
    required String uid,
    String displayName = 'Pilot',
    String email = '',
  }) {
    return UserProgress(
      uid: uid,
      displayName: displayName,
      email: email,
      astrids: 0,
      bestScore: 0,
      highestWave: 0,
      totalAsteroidsDestroyed: 0,
      classicBestScore: 0,
      classicHighestWave: 0,
      classicAsteroidsDestroyed: 0,
      bossRushBestScore: 0,
      bossRushHighestWave: 0,
      bossRushBossesDefeated: 0,
    );
  }

  /// Firestore's int values may come back as num; normalize safely.
  /// Public so other services can reuse it.
  static int toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  String toString() =>
      'UserProgress($displayName: astrids=$astrids, classic(best=$classicBestScore, '
      'wave=$classicHighestWave, destroyed=$classicAsteroidsDestroyed), '
      'bossRush(best=$bossRushBestScore, wave=$bossRushHighestWave, '
      'bosses=$bossRushBossesDefeated))';
}
