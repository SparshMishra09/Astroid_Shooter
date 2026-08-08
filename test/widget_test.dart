import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:asteroid_shooter/auth/auth_screen.dart';

void main() {
  testWidgets('Auth screen builds without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('SPACE'), findsOneWidget);
  });
}
