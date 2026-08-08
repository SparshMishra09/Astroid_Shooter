import 'package:flutter_test/flutter_test.dart';
import 'package:asteroid_shooter/game/game_controller.dart';
import 'package:asteroid_shooter/models/enums.dart';
import 'package:asteroid_shooter/models/asteroids.dart';
import 'package:asteroid_shooter/models/projectiles.dart';
import 'package:asteroid_shooter/config/game_config.dart';

/// Regression tests for the mid-game freeze bug.
///
/// Root cause: when a bullet destroyed a HugeSlowAsteroid during the
/// `for (var enemy in enemies)` collision loop, `splitHugeAsteroid()`
/// called `enemies.add(...)` mid-iteration → ConcurrentModificationError
/// → exception propagated up through tick() → setState() never called →
/// the UI froze permanently.
///
/// These tests verify that splitting now works without modifying the
/// enemies list during iteration, and that the game loop survives many
/// frames of heavy collision processing.
void main() {
  late GameController controller;

  setUp(() {
    controller = GameController(mode: GameMode.classicRun);
    controller.setScreenSize(400, 800);
    controller.initialize();
  });

  test('splitHugeAsteroid does not modify enemies list during call', () {
    final huge = HugeSlowAsteroid(x: 100, y: 100, size: 80, speedY: 1);
    controller.enemies.add(huge);

    final countBefore = controller.enemies.length;
    controller.splitHugeAsteroid(huge);
    final countAfter = controller.enemies.length;

    // splitHugeAsteroid must add to the pending buffer, NOT enemies.
    // If it added directly, a concurrent for-in loop would throw.
    expect(countAfter, countBefore,
        reason: 'splitHugeAsteroid must not mutate enemies directly');
  });

  test('pending enemies are flushed after tick', () {
    final huge = HugeSlowAsteroid(x: 100, y: 100, size: 80, speedY: 1);
    controller.enemies.add(huge);
    controller.splitHugeAsteroid(huge);

    // Before tick: enemies unchanged (just the huge one), pending has 2
    expect(controller.enemies.length, 1);

    controller.tick();

    // After tick: the huge asteroid is destroyed (invisible) but still in
    // the list until cleanup, plus 2 new split asteroids = 3 total.
    // The key assertion: no ConcurrentModificationError was thrown.
    final smallCount = controller.enemies.whereType<SmallFastAsteroid>().length;
    expect(smallCount, 2,
        reason: '2 split asteroids should be flushed into enemies after tick');
  });

  test('bullet destroying huge asteroid does not throw ConcurrentModificationError', () {
    // Set up: one huge asteroid positioned where a bullet will hit it.
    final hugeX = 100.0;
    final hugeY = 100.0;
    final hugeSize = 80.0;
    final huge = HugeSlowAsteroid(x: hugeX, y: hugeY, size: hugeSize, speedY: 1);
    controller.enemies.add(huge);

    // Damage it twice (health goes 3→2→1) so the next hit destroys it.
    huge.takeDamage(1);
    huge.takeDamage(1);
    expect(huge.health, 1);

    // Bullet overlapping the huge asteroid — this hit will destroy it
    // and trigger splitHugeAsteroid during the collision for-in loop.
    final bullet = Bullet(
      x: hugeX + 10,
      y: hugeY + 10,
      width: GameConfig.bulletWidth,
      height: GameConfig.bulletHeight,
      speedY: GameConfig.bulletSpeed,
    );
    controller.bullets.add(bullet);

    // This must NOT throw.
    expect(() => controller.tick(), returnsNormally,
        reason: 'Destroying a huge asteroid must not cause ConcurrentModificationError');
  });

  test('game loop survives 300 frames with continuous spawning', () {
    // Simulate ~5 seconds of gameplay with many entities spawning.
    // This stress-tests all iteration + mutation paths.
    expect(() {
      for (int i = 0; i < 300; i++) {
        controller.tick();
      }
    }, returnsNormally,
        reason: 'Game loop must not throw over 300 frames of gameplay');
  });

  test('game loop survives 500 frames with forced enemy spawns', () {
    // Force-spawn enemies every frame to maximize collision complexity.
    expect(() {
      for (int i = 0; i < 500; i++) {
        // Seed some enemies directly to stress the collision loop
        if (i % 30 == 0) {
          controller.enemies.add(
            HugeSlowAsteroid(x: 50.0 + i % 200, y: 50, size: 80, speedY: 1),
          );
        }
        controller.tick();
      }
    }, returnsNormally,
        reason: 'Game loop must not throw with frequent enemy spawns');
  });

  test('multiple huge asteroids destroyed in same frame', () {
    // Two huge asteroids + two bullets, all overlapping — both destroyed
    // in the same checkCollisions() call.
    for (int i = 0; i < 2; i++) {
      final huge = HugeSlowAsteroid(x: 80.0 + i * 100, y: 100, size: 80, speedY: 1);
      huge.takeDamage(1);
      huge.takeDamage(1); // health = 1, one more hit destroys
      controller.enemies.add(huge);

      controller.bullets.add(Bullet(
        x: 90.0 + i * 100,
        y: 110,
        width: GameConfig.bulletWidth,
        height: GameConfig.bulletHeight,
        speedY: GameConfig.bulletSpeed,
      ));
    }

    expect(() => controller.tick(), returnsNormally);
    // Both huge asteroids destroyed → 4 split asteroids flushed in.
    // (The 2 destroyed huge asteroids are still in the list as invisible
    // until cleanup runs, so we count only the SmallFastAsteroids.)
    final smallCount = controller.enemies.whereType<SmallFastAsteroid>().length;
    expect(smallCount, 4,
        reason: 'Both huge asteroids should split into 4 small ones total');
  });

  test('pendingEnemies is cleared after flush', () {
    final huge = HugeSlowAsteroid(x: 100, y: 100, size: 80, speedY: 1);
    controller.enemies.add(huge);
    controller.splitHugeAsteroid(huge);
    controller.tick();

    // After tick, pending should be empty (flushed into enemies)
    final smallCount1 = controller.enemies.whereType<SmallFastAsteroid>().length;
    expect(smallCount1, 2);

    // Next tick should work fine with no leftover pending
    controller.tick();
    final smallCount2 = controller.enemies.whereType<SmallFastAsteroid>().length;
    expect(smallCount2, 2, reason: 'No new splits should occur on second tick');
  });
}
