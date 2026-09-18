import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/firebase_sync_service.dart';

/// Exposes authentication state to the widget tree.
/// After a successful Google sign-in, it triggers an immediate Firebase sync.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseSyncService _syncService = FirebaseSyncService();

  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSub;

  AuthProvider() {
    // React to auth state changes (e.g. token refresh, sign-out).
    _authSub = _authService.authStateChanges.listen((user) {
      notifyListeners();
    });
  }

  bool _isGuestMode = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _authService.isSignedIn;
  bool get isGoogleSignedIn => _authService.isGoogleSignedIn;
  bool get isGuestMode => _isGuestMode;
  User? get currentUser => _authService.currentUser;

  String get displayName =>
      currentUser?.displayName ?? currentUser?.email ?? 'User';
  String? get photoUrl => currentUser?.photoURL;
  String? get email => currentUser?.email;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Continue without signing in (offline-only session).
  void continueAsGuest() {
    _isGuestMode = true;
    notifyListeners();
  }

  /// Launch Google sign-in flow. On success, triggers a cloud sync.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signInWithGoogle();

    if (result.success) {
      _isGuestMode = false;
      // Re-init sync service with the real Google UID, then restore or merge cloud data.
      await _syncService.initialize();
      await _syncService.syncOnLogin();
    } else {
      _errorMessage = result.message;
    }

    _isLoading = false;
    notifyListeners();
    return result.success;
  }

  /// Sign out and clear local error state.
  Future<void> signOut() async {
    _isGuestMode = false;
    await _authService.signOut();
    _errorMessage = null;
    notifyListeners();
  }

  /// Permanently delete account and cloud data (Play Store Compliance).
  Future<AuthResult> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    final result = await _authService.deleteAccount();
    if (result.success) {
      _isGuestMode = true;
    }
    _isLoading = false;
    notifyListeners();
    return result;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
