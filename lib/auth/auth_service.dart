import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Thrown when an auth operation fails. Carries a user-friendly message.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The Web OAuth client ID from google-services.json.
///
/// google_sign_in needs this as [serverClientId] to obtain an ID token
/// that Firebase Auth can verify. The Android OAuth client (type 1) is
/// used automatically by the plugin for the native sign-in flow; the
/// Web client (type 3) is needed for the ID-token exchange step.
const String _kWebClientId =
    '98150244948-k43jpf2t5grps59j0mettti39c67np8d.apps.googleusercontent.com';

/// A singleton wrapper around Firebase Auth + Firestore that the rest of
/// the app uses. Keeps all Firebase calls in one place so the auth flow
/// is easy to maintain and test.
///
/// Methods return void on success and throw [AuthException] on failure.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// GoogleSignIn configured with the Web client ID as serverClientId.
  /// This is required for Firebase Auth to receive a valid ID token
  /// after the native Google sign-in completes.
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: _kWebClientId,
  );

  /// Stream of the current user's auth state. Emits null when logged out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently logged-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// True if a user is currently logged in.
  bool get isLoggedIn => _auth.currentUser != null;

  /// Sign up with email + password, then create a Firestore profile.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update the display name if provided
      if (displayName != null && displayName.trim().isNotEmpty) {
        await cred.user!.updateDisplayName(displayName.trim());
      }

      // Create a Firestore user profile
      await _createUserProfile(cred.user!, displayName);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    } catch (e) {
      throw AuthException('Sign up failed. Please try again.');
    }
  }

  /// Sign in with email + password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    } catch (e) {
      throw AuthException('Sign in failed. Please check your connection.');
    }
  }

  /// Sign in with Google. Returns false if the user cancelled the flow.
  ///
  /// Uses the native Google account picker, then exchanges the resulting
  /// ID token for Firebase credentials.
  Future<bool> signInWithGoogle() async {
    try {
      // Trigger the native Google sign-in flow. This shows the account
      // picker if there are multiple accounts, or signs in directly if
      // there's only one.
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        // User cancelled the flow (pressed back)
        return false;
      }

      // Get the auth tokens needed for Firebase
      final googleAuth = await googleAccount.authentication;

      if (googleAuth.idToken == null) {
        debugPrint('Google sign-in: idToken is null');
        // Technical detail (SHA-1 fingerprint registration) is logged
        // for developers; the player only sees a friendly message.
        throw const AuthException(
          'Google sign-in hit a snag. Please try again in a moment.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      // Create profile if this is a new user
      final userDoc = await _firestore
          .collection('users')
          .doc(userCred.user!.uid)
          .get();
      if (!userDoc.exists) {
        await _createUserProfile(userCred.user!, googleAccount.displayName);
      }

      return true;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in FirebaseAuthException: ${e.code} - ${e.message}');
      throw AuthException(_friendlyMessage(e));
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      throw AuthException(
        'Google sign-in failed. Check your internet connection and try again.',
      );
    }
  }

  /// Sign out from Firebase + Google (if signed in via Google).
  Future<void> signOut() async {
    try {
      // Sign out of Google first (if the user was signed in via Google)
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      } catch (e) {
        debugPrint('Google signOut error (non-fatal): $e');
      }
      await _auth.signOut();
    } catch (e) {
      // Best-effort — still try to sign out of Firebase
      debugPrint('signOut error: $e');
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  /// Create a user profile document in Firestore.
  /// New users start at 0 for everything (astrids, bestScore, waves).
  Future<void> _createUserProfile(User user, String? displayName) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? 'Pilot',
        'createdAt': FieldValue.serverTimestamp(),
        'astrids': 0,
        'bestScore': 0,
        'highestWave': 0,
        'totalAsteroidsDestroyed': 0,
      });
    } catch (e) {
      // Profile creation is best-effort — don't fail the sign-up
      // if Firestore is temporarily unavailable.
      debugPrint('Create user profile error: $e');
    }
  }

  /// Get the user's display name from Firestore (falls back to auth name).
  Future<String> getDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return 'Pilot';

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('displayName')) {
        return doc['displayName'] as String;
      }
    } catch (_) {}
    return user.displayName ?? 'Pilot';
  }

  /// Convert Firebase error codes to user-friendly messages. Never
  /// surfaces raw Firebase/plugin error strings to the player.
  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
      case 'invalid-action-code':
      case 'expired-action-code':
        return 'Verification failed. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
      case 'internal-error':
      case 'api-not-available':
      case 'channel-error':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
      case 'app-not-authorized':
      case 'unauthorized-domain':
      case 'missing-android-pkg-name':
        return 'This sign-in method is not available right now. Please try again later.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'An account already exists with this email using a different sign-in method.';
      case 'user-token-expired':
      case 'requires-recent-login':
        return 'Your session expired. Please sign in again.';
      case 'no-current-user':
        return 'You are signed out. Please sign in again.';
      case 'captcha-check-failed':
        return 'Security check failed. Please try again.';
      case 'timeout':
        return 'The request timed out. Please try again.';
      default:
        // Friendly generic — the raw code/message is logged for devs
        // but never shown to the player.
        debugPrint('Unhandled auth error ${e.code}: ${e.message}');
        return 'Something went wrong. Please try again.';
    }
  }
}
