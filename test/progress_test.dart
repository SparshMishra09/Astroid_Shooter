import 'package:flutter_test/flutter_test.dart';
import 'package:asteroid_shooter/models/game_state.dart';
import 'package:asteroid_shooter/models/user_progress.dart';

/// Tests for the per-user progress system: GameState wave tracking,
/// UserProgress data model, and the "starts from 0" contract.
void main() {
  group('GameState wavesCompleted', () {
    test('starts at 0 and increments on completeWave()', () {
      final state = GameState();
      expect(state.wavesCompleted, 0);

      state.completeWave();
      expect(state.wavesCompleted, 1);

      state.startNewWave(); // advances to wave 2
      state.completeWave();
      expect(state.wavesCompleted, 2);
    });

    test('resets to 0 on reset()', () {
      final state = GameState();
      state.completeWave();
      state.completeWave();
      expect(state.wavesCompleted, 2);

      state.reset();
      expect(state.wavesCompleted, 0);
    });

    test('currentWave tracks the wave the player is on', () {
      final state = GameState();
      expect(state.currentWave, 1);

      state.completeWave();
      expect(state.currentWave, 1); // still wave 1 during break

      state.startNewWave();
      expect(state.currentWave, 2); // now wave 2
    });
  });

  group('UserProgress model', () {
    test('zero() factory creates all-zero progress', () {
      final p = UserProgress.zero(uid: 'test-uid', displayName: 'TestPilot', email: 'test@test.com');
      expect(p.uid, 'test-uid');
      expect(p.displayName, 'TestPilot');
      expect(p.email, 'test@test.com');
      expect(p.astrids, 0);
      expect(p.bestScore, 0);
      expect(p.highestWave, 0);
      expect(p.totalAsteroidsDestroyed, 0);
      expect(p.classicBestScore, 0);
      expect(p.classicHighestWave, 0);
      expect(p.classicAsteroidsDestroyed, 0);
      expect(p.bossRushBestScore, 0);
      expect(p.bossRushHighestWave, 0);
      expect(p.bossRushBossesDefeated, 0);
    });

    test('fromDoc() parses Firestore data correctly', () {
      final p = UserProgress.fromDoc('uid-123', {
        'displayName': 'Ace',
        'email': 'ace@space.com',
        'astrids': 5000,
        'bestScore': 1200,
        'highestWave': 7,
        'totalAsteroidsDestroyed': 342,
        'classicBestScore': 1000,
        'classicHighestWave': 6,
        'classicAsteroidsDestroyed': 300,
        'bossRushBestScore': 4400,
        'bossRushHighestWave': 9,
        'bossRushBossesDefeated': 8,
      });
      expect(p.uid, 'uid-123');
      expect(p.displayName, 'Ace');
      expect(p.email, 'ace@space.com');
      expect(p.astrids, 5000);
      expect(p.bestScore, 1200);
      expect(p.highestWave, 7);
      expect(p.totalAsteroidsDestroyed, 342);
      expect(p.classicBestScore, 1000);
      expect(p.classicHighestWave, 6);
      expect(p.classicAsteroidsDestroyed, 300);
      expect(p.bossRushBestScore, 4400);
      expect(p.bossRushHighestWave, 9);
      expect(p.bossRushBossesDefeated, 8);
    });

    test('fromDoc() handles missing fields gracefully (legacy accounts)', () {
      final p = UserProgress.fromDoc('uid-456', {
        'displayName': 'OldPlayer',
        // No astrids, bestScore, highestWave, totalAsteroidsDestroyed fields
      });
      expect(p.astrids, 0);
      expect(p.bestScore, 0);
      expect(p.highestWave, 0);
      expect(p.totalAsteroidsDestroyed, 0);
      expect(p.classicBestScore, 0);
      expect(p.classicHighestWave, 0);
      expect(p.classicAsteroidsDestroyed, 0);
      expect(p.bossRushBestScore, 0);
      expect(p.bossRushHighestWave, 0);
      expect(p.bossRushBossesDefeated, 0);
    });

    test('fromDoc() migrates legacy docs to Classic stats (pre-mode-split data)', () {
      // Every game before the mode split was Classic Run, so a doc with
      // only flat fields must surface those values as Classic stats —
      // and Boss Rush stays at zero.
      final p = UserProgress.fromDoc('uid-legacy', {
        'displayName': 'Veteran',
        'astrids': 5000,
        'bestScore': 1200,
        'highestWave': 7,
        'totalAsteroidsDestroyed': 342,
      });
      expect(p.classicBestScore, 1200);
      expect(p.classicHighestWave, 7);
      expect(p.classicAsteroidsDestroyed, 342);
      expect(p.bossRushBestScore, 0);
      expect(p.bossRushHighestWave, 0);
      expect(p.bossRushBossesDefeated, 0);
    });

    test('fromDoc() with per-mode fields does NOT fall back to legacy', () {
      // Once a doc has been migrated, the per-mode fields are the source
      // of truth even if they're lower than the legacy globals.
      final p = UserProgress.fromDoc('uid-modern', {
        'displayName': 'Modern',
        'astrids': 9000,
        'bestScore': 3000,
        'highestWave': 12,
        'totalAsteroidsDestroyed': 800,
        'classicBestScore': 200,
        'classicHighestWave': 3,
        'classicAsteroidsDestroyed': 50,
      });
      expect(p.classicBestScore, 200);
      expect(p.classicHighestWave, 3);
      expect(p.classicAsteroidsDestroyed, 50);
    });

    test('toInt() handles various numeric types from Firestore', () {
      expect(UserProgress.toInt(null), 0);
      expect(UserProgress.toInt(42), 42);
      expect(UserProgress.toInt(42.0), 42);
      expect(UserProgress.toInt(42.9), 42); // truncates
      expect(UserProgress.toInt('42'), 42);
      expect(UserProgress.toInt('not a number'), 0);
    });
  });
}
