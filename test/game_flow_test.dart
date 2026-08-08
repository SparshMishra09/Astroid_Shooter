import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asteroid_shooter/screens/game_screen.dart';
import 'package:asteroid_shooter/auth/auth_screen.dart';
import 'package:asteroid_shooter/game/game_controller.dart';
import 'package:asteroid_shooter/models/enums.dart';

/// Tests for the game flow and auth UI.
///
/// These tests avoid initializing Firebase (which requires native platform
/// channels unavailable in dart tests). Instead they pump individual
/// screens directly with a MaterialApp wrapper.
///
/// Game-logic tests (GameController, freeze regression) don't touch
/// Firebase at all and run without any special setup.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // === Game logic tests (no Firebase needed) ===

  testWidgets('GameController initializes player and gameState synchronously',
      (tester) async {
    final controller = GameController(mode: GameMode.classicRun);

    expect(controller.gameState.score, 0);
    expect(controller.gameState.currentWave, 1);
    expect(controller.player.lives, 3);
    expect(controller.player.x, greaterThan(0));

    controller.gameState.highScore = 500;
    controller.initialize(preserveHighScore: true);
    expect(controller.gameState.highScore, 500);
    expect(controller.gameState.score, 0);
    expect(controller.player.lives, 3);
  });

  testWidgets('Game loop tick advances frame count', (tester) async {
    final controller = GameController(mode: GameMode.classicRun);
    controller.setScreenSize(400, 800);
    controller.initialize();

    final initialFrame = controller.frameCount;
    controller.tick();
    expect(controller.frameCount, initialFrame + 1);
  });

  // === Game screen rendering tests (pumped directly, no Firebase) ===

  testWidgets('GameScreen renders HUD without grey screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Astrids:'), findsOneWidget);
    expect(find.textContaining('Classic Run'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('GameScreen survives multiple frames of the game loop',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.textContaining('Astrids:'), findsOneWidget);
  });

  // === Auth screen UI tests (pumped directly, no Firebase) ===

  testWidgets('AuthScreen shows title and login form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SPACE'), findsOneWidget);
    expect(find.text('WARS'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
    expect(find.text('LAUNCH MISSION'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('AuthScreen switches to signup tab and shows callsign field',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('SIGN UP'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pilot Callsign'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('AuthScreen validates empty email and password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    // Tap submit without entering anything
    await tester.tap(find.text('LAUNCH MISSION'));
    await tester.pump(const Duration(milliseconds: 300));

    // Should show validation errors
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('AuthScreen validates invalid email format', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField).first, 'notanemail');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('LAUNCH MISSION'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('AuthScreen validates short password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.enterText(find.byType(TextFormField).last, '12345');
    await tester.tap(find.text('LAUNCH MISSION'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('AuthScreen shows password visibility toggle', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    // The visibility toggle icon should be present
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    // Tap it to show password
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });
}
