import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
///   astrids: number                    // currency (accumulated)
///   bestScore: number                  // best single-game score
///   highestWave: number                // highest wave reached in one game
///   totalAsteroidsDestroyed: number    // total kills across all games
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
  /// - [scoreEarned]: astrids earned this game (added to currency balance).
  /// - [waveReached]: the wave the player was on when the game ended.
  /// - [asteroidsDestroyed]: number of asteroids/enemies destroyed this game.
  ///
  /// Uses a transaction so the read-modify-write is atomic (prevents
  /// lost updates if two games finish simultaneously, e.g. on two
  /// devices).
  Future<void> submitGameResult({
    required int scoreEarned,
    required int waveReached,
    required int asteroidsDestroyed,
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
        String displayName = user.displayName ?? 'Pilot';
        String email = user.email ?? '';

        if (snapshot.exists) {
          final data = snapshot.data()!;
          currentAstrids = UserProgress.toInt(data['astrids']);
          currentBest = UserProgress.toInt(data['bestScore']);
          currentHighestWave = UserProgress.toInt(data['highestWave']);
          currentTotalDestroyed = UserProgress.toInt(data['totalAsteroidsDestroyed']);
          displayName = (data['displayName'] as String?) ?? displayName;
          email = (data['email'] as String?) ?? email;
        }

        tx.set(docRef, {
          'astrids': currentAstrids + scoreEarned,
          'bestScore': scoreEarned > currentBest ? scoreEarned : currentBest,
          'highestWave':
              waveReached > currentHighestWave ? waveReached : currentHighestWave,
          'totalAsteroidsDestroyed': currentTotalDestroyed + asteroidsDestroyed,
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
