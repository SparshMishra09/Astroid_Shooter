/// A snapshot of a user's persistent progress stored in Firestore.
///
/// This is the per-account data that survives across sessions and
/// devices — distinct from the per-run [GameState] which resets each
/// game.
///
/// Fields:
/// - [astrids]: currency balance (accumulated across all games, for
///   the future shop). Each completed game adds its score to this.
/// - [bestScore]: highest single-game score ever achieved.
/// - [highestWave]: highest wave reached in a single game.
/// - [totalAsteroidsDestroyed]: total asteroids/enemies destroyed
///   across all games (progress metric shown on the leaderboard).
class UserProgress {
  final String uid;
  final String displayName;
  final String email;
  final int astrids;
  final int bestScore;
  final int highestWave;
  final int totalAsteroidsDestroyed;

  const UserProgress({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.astrids,
    required this.bestScore,
    required this.highestWave,
    required this.totalAsteroidsDestroyed,
  });

  /// Create from a Firestore document.
  factory UserProgress.fromDoc(String uid, Map<String, dynamic> data) {
    return UserProgress(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? 'Pilot',
      email: (data['email'] as String?) ?? '',
      astrids: toInt(data['astrids']),
      bestScore: toInt(data['bestScore']),
      highestWave: toInt(data['highestWave']),
      totalAsteroidsDestroyed: toInt(data['totalAsteroidsDestroyed']),
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
      'UserProgress($displayName: astrids=$astrids, best=$bestScore, '
      'wave=$highestWave, destroyed=$totalAsteroidsDestroyed)';
}
