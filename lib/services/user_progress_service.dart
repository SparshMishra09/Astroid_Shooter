import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/user_progress.dart';

/// Thrown when a progress operation fails. Carries a user-friendly message.
class ProgressException implements Exception {
  const ProgressException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A singleton service that reads and writes per-user progress data
/// to Firestore, and provides leaderboard queries.
///
/// Firestore document shape (`users/{uid}`):
/// ```
/// {
///   email: string
///   displayName: string
///   createdAt: timestamp
///   astrids: number                      // currency (accumulated, ALL modes)
///   // Legacy pre-mode-split fields — all historical data was Classic:
///   bestScore: number
///   highestWave: number
///   totalAsteroidsDestroyed: number
///   // Per-mode stats (each mode only counts its own games):
///   classicBestScore: number
///   classicHighestWave: number
///   classicAsteroidsDestroyed: number
///   bossRushBestScore: number
///   bossRushHighestWave: number          // highest boss number reached
///   bossRushBossesDefeated: number       // accumulated across games
/// }
/// ```
class UserProgressService {
  UserProgressService._internal();
  static final UserProgressService instance = UserProgressService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Get the current logged-in user's progress from Firestore.
  /// Returns a zero-progress snapshot if the doc doesn't exist yet
  /// (e.g. legacy accounts created before this feature).
  Future<UserProgress> getMyProgress() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ProgressException('Not logged in.');
    }
    return getProgress(user.uid);
  }

  /// Get any user's progress by uid.
  Future<UserProgress> getProgress(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) {
        final user = _auth.currentUser;
        return UserProgress.zero(
          uid: uid,
          displayName: user?.displayName ?? 'Pilot',
          email: user?.email ?? '',
        );
      }
      return UserProgress.fromDoc(uid, doc.data()!);
    } catch (e) {
      debugPrint('getProgress error: $e');
      throw const ProgressException('Could not load progress. Check your connection.');
    }
  }

  /// Submit a completed game's results to Firestore.
  ///
  /// - [scoreEarned]: astrids earned this game (added to the currency
  ///   balance regardless of mode).
  /// - [waveReached]: the wave (Classic) or boss number (Boss Rush) the
  ///   player was on when the game ended.
  /// - [asteroidsDestroyed]: asteroids/enemies destroyed this game
  ///   (Classic Run only counts these).
  /// - [bossesDefeated]: bosses killed this game (Boss Rush only).
  /// - [gameMode]: which mode the game was played in — decides which
  ///   per-mode stats this run updates.
  ///
  /// Uses a transaction so the read-modify-write is atomic (prevents
  /// lost updates if two games finish simultaneously, e.g. on two
  /// devices).
  ///
  /// Legacy docs (written before the mode split) are migrated in the
  /// same transaction: their flat stats carry over as Classic stats
  /// before this run is applied.
  Future<void> submitGameResult({
    required int scoreEarned,
    required int waveReached,
    required int asteroidsDestroyed,
    required GameMode gameMode,
    int bossesDefeated = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ProgressException('Not logged in.');
    }

    try {
      final docRef = _users.doc(user.uid);

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);

        int currentAstrids = 0;
        int currentBest = 0;
        int currentHighestWave = 0;
        int currentTotalDestroyed = 0;
        int classicBest = 0;
        int classicHighestWave = 0;
        int classicDestroyed = 0;
        int rushBest = 0;
        int rushHighestWave = 0;
        int rushBosses = 0;
        String displayName = user.displayName ?? 'Pilot';
        String email = user.email ?? '';

        if (snapshot.exists) {
          final data = snapshot.data()!;
          currentAstrids = UserProgress.toInt(data['astrids']);
          currentBest = UserProgress.toInt(data['bestScore']);
          currentHighestWave = UserProgress.toInt(data['highestWave']);
          currentTotalDestroyed =
              UserProgress.toInt(data['totalAsteroidsDestroyed']);
          displayName = (data['displayName'] as String?) ?? displayName;
          email = (data['email'] as String?) ?? email;

          // Migrate legacy docs: pre-split data was all Classic Run, so
          // flat stats seed the Classic fields on first touch.
          if (data.containsKey('classicBestScore')) {
            classicBest = UserProgress.toInt(data['classicBestScore']);
            classicHighestWave =
                UserProgress.toInt(data['classicHighestWave']);
            classicDestroyed =
                UserProgress.toInt(data['classicAsteroidsDestroyed']);
          } else {
            classicBest = currentBest;
            classicHighestWave = currentHighestWave;
            classicDestroyed = currentTotalDestroyed;
          }
          rushBest = UserProgress.toInt(data['bossRushBestScore']);
          rushHighestWave = UserProgress.toInt(data['bossRushHighestWave']);
          rushBosses = UserProgress.toInt(data['bossRushBossesDefeated']);
        }

        // Legacy flat fields track the global best across modes so old
        // readers keep working; the per-mode leaderboards use the
        // per-mode fields below.
        if (scoreEarned > currentBest) currentBest = scoreEarned;
        if (waveReached > currentHighestWave) {
          currentHighestWave = waveReached;
        }
        currentTotalDestroyed += asteroidsDestroyed;

        switch (gameMode) {
          case GameMode.classicRun:
            if (scoreEarned > classicBest) classicBest = scoreEarned;
            if (waveReached > classicHighestWave) {
              classicHighestWave = waveReached;
            }
            classicDestroyed += asteroidsDestroyed;
            break;
          case GameMode.bossRush:
            if (scoreEarned > rushBest) rushBest = scoreEarned;
            if (waveReached > rushHighestWave) rushHighestWave = waveReached;
            rushBosses += bossesDefeated;
            break;
        }

        tx.set(docRef, {
          'astrids': currentAstrids + scoreEarned,
          'bestScore': currentBest,
          'highestWave': currentHighestWave,
          'totalAsteroidsDestroyed': currentTotalDestroyed,
          'classicBestScore': classicBest,
          'classicHighestWave': classicHighestWave,
          'classicAsteroidsDestroyed': classicDestroyed,
          'bossRushBestScore': rushBest,
          'bossRushHighestWave': rushHighestWave,
          'bossRushBossesDefeated': rushBosses,
          'displayName': displayName,
          'email': email,
          if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('submitGameResult error: $e');
      throw const ProgressException('Could not save your progress.');
    }
  }

  /// Stream of top players ordered by the given field (for the leaderboard).
  /// Emits a new list whenever any player's data changes.
  Stream<List<UserProgress>> getLeaderboardStream({
    int limit = 50,
    required String orderBy,
  }) {
    return _users
        .orderBy(orderBy, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserProgress.fromDoc(doc.id, doc.data());
      }).toList();
    });
  }
}
