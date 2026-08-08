import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'auth_screen.dart';
import '../screens/home_screen.dart';
import '../widgets/loading_screen.dart';

/// The root of the app after Firebase is initialized. Watches the auth
/// state stream and routes the user to either the auth screen or the
/// home screen accordingly.
///
/// Shows the animated [LoadingScreen] while Firebase resolves the auth
/// state (there's a brief moment at app startup where the stream hasn't
/// emitted yet).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // While the auth state is resolving, show the themed loader.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(message: 'INITIALIZING SYSTEMS…');
        }

        // Logged in → home screen
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Logged out → auth screen
        return const AuthScreen();
      },
    );
  }
}
