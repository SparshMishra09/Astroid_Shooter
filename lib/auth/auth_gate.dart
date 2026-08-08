import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'auth_screen.dart';
import '../screens/home_screen.dart';

/// The root of the app after Firebase is initialized. Watches the auth
/// state stream and routes the user to either the auth screen or the
/// home screen accordingly.
///
/// Shows a themed loading screen while Firebase resolves the auth state
/// (there's a brief moment at app startup where the stream hasn't
/// emitted yet).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // While the auth state is resolving, show a themed loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
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

/// A brief themed loading screen shown while Firebase resolves auth state.
class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo.shade900],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SPACE WARS',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                color: Colors.cyan,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
