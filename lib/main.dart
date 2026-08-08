import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_gate.dart';

/// Entry point. Firebase is initialized before the app runs, then the
/// [AuthGate] routes the user to either the auth screen or the home
/// screen based on their login state.
void main() async {
  // Ensure Flutter is initialized before any async platform calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (reads google-services.json on Android).
  // If the file is missing, this throws — but we catch it and continue
  // so the app doesn't hard-crash in dev without config.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // In production this should never happen (google-services.json is
    // always present). In dev without config, we rethrow so the developer
    // knows to add the file.
    debugPrint('Firebase initialization failed: $e');
    rethrow;
  }

  // Set preferred orientations to portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AsteroidShooterApp());
}

class AsteroidShooterApp extends StatelessWidget {
  const AsteroidShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Wars',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}
