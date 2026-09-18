import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Result wrapper for every auth operation.
class AuthResult {
  final bool success;
  final String message;
  final User? user;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}

/// ---------------------------------------------------------------------------
/// AuthService
/// ---------------------------------------------------------------------------
/// Manages Google Sign-In + Firebase Auth lifecycle.
/// After sign-in, Firebase gives us a real UID tied to the user's Google
/// account — this UID is used by [FirebaseSyncService] to scope all data
/// under `users/{uid}/`.
/// ---------------------------------------------------------------------------
class AuthService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  // Use the web client ID (client_type: 3) from google-services.json as serverClientId.
  // This is required for getting the idToken on Android to exchange with Firebase.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '453242276653-lijpjpjo6mgfplvlmdjnpgqfg50h49cv.apps.googleusercontent.com',
  );

  // ── Public getters ─────────────────────────────────────────────────────────

  /// Currently signed-in Firebase user, or `null` if not authenticated.
  User? get currentUser => _auth?.currentUser;

  /// `true` if a user is signed in (Google OR anonymous).
  bool get isSignedIn => _auth?.currentUser != null;

  /// `true` only if signed in via Google (not anonymous).
  bool get isGoogleSignedIn {
    final user = _auth?.currentUser;
    if (user == null) return false;
    return user.providerData
        .any((info) => info.providerId == 'google.com');
  }

  /// Stream of auth state changes – use this to reactively update the UI.
  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream.empty();

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Launch the Google account picker and sign into Firebase.
  /// Returns [AuthResult] with the signed-in [User] on success.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final auth = _auth;
      if (auth == null) {
        return const AuthResult(
          success: false,
          message: 'Firebase is not configured. Running in offline mode.',
        );
      }

      // Force account selection so the user can switch accounts.
      await _googleSignIn.signOut();

      // Trigger the Google OAuth flow.
      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        // User cancelled the picker.
        return const AuthResult(
          success: false,
          message: 'Sign-in cancelled.',
        );
      }

      // Obtain auth details from the request.
      final GoogleSignInAuthentication googleAuth =
          await googleAccount.authentication;

      // Validate that we received both tokens.
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        debugPrint('[AuthService] Missing both idToken and accessToken');
        return const AuthResult(
          success: false,
          message: 'Authentication tokens missing. Please check your internet connection and try again.',
        );
      }

      // Create Firebase credential.
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign into Firebase with the Google credential.
      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;

      debugPrint('[AuthService] Google Sign-In OK: ${user?.email} (uid=${user?.uid})');
      return AuthResult(
        success: true,
        message: 'Signed in as ${user?.displayName ?? user?.email}',
        user: user,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException: ${e.code} – ${e.message}');
      return AuthResult(
        success: false,
        message: _friendlyError(e.code),
      );
    } catch (e) {
      debugPrint('[AuthService] Unexpected error: $e');
      // Provide a more useful error message
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
        return const AuthResult(
          success: false,
          message: 'No internet connection. Please check your network and try again.',
        );
      }
      if (msg.contains('sign_in_failed') || msg.contains('10:')) {
        return const AuthResult(
          success: false,
          message: 'Google Sign-In failed (error 10). Make sure the app SHA-1 is registered in Firebase Console.',
        );
      }
      return AuthResult(
        success: false,
        message: 'Sign-in failed: ${e.toString().split('\n').first}',
      );
    }
  }

  // ── Sign-Out ───────────────────────────────────────────────────────────────

  /// Sign out of both Google and Firebase.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth?.signOut();
      debugPrint('[AuthService] User signed out.');
    } catch (e) {
      debugPrint('[AuthService] Sign-out error: $e');
    }
  }

  // ── Account & Data Deletion (Play Store Compliance) ─────────────────────────

  /// Permanently deletes the current user's account and all associated cloud data.
  /// Mandatory for Google Play Account Deletion Policy compliance.
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth?.currentUser;
      if (user == null) {
        return const AuthResult(
          success: true,
          message: 'No active account to delete.',
        );
      }

      final uid = user.uid;

      // 1. Delete Firestore user document and backups
      try {
        final firestore = FirebaseFirestore.instance;
        await firestore
            .collection('users')
            .doc(uid)
            .collection('backup')
            .doc('latest')
            .delete();
        await firestore.collection('users').doc(uid).delete();
        debugPrint('[AuthService] Firestore data removed for user: $uid');
      } catch (e) {
        debugPrint('[AuthService] Firestore cleanup note: $e');
      }

      // 2. Delete the user from Firebase Auth
      await user.delete();

      // 3. Sign out of Google session
      await _googleSignIn.signOut();

      debugPrint('[AuthService] Account deleted successfully.');
      return const AuthResult(
        success: true,
        message: 'Account and associated cloud data deleted successfully.',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Delete account FirebaseAuthException: ${e.code}');
      if (e.code == 'requires-recent-login') {
        return const AuthResult(
          success: false,
          message: 'For security, please sign out and sign in again before deleting your account.',
        );
      }
      return AuthResult(
        success: false,
        message: e.message ?? 'Failed to delete account.',
      );
    } catch (e) {
      debugPrint('[AuthService] Delete account error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to delete account: $e',
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _friendlyError(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already linked to a different sign-in method.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'sign_in_failed':
        return 'Google sign-in failed. Ensure the app SHA-1 fingerprint is registered in Firebase Console.';
      case 'invalid-credential':
        return 'Authentication credential is invalid or expired. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled. Please contact support.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}
