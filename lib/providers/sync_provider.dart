import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/auth_service.dart';

/// Exposes [FirebaseSyncService] state to the widget tree via [ChangeNotifier].
class SyncProvider extends ChangeNotifier {
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final ConnectivityService _connectivity = ConnectivityService();
  final AuthService _authService = AuthService();

  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<User?>? _authSub;

  SyncProvider() {
    _statusSub = _syncService.statusStream.listen((_) => notifyListeners());
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen((_) => notifyListeners());
    // Re-notify when auth state changes (e.g. user signs in/out).
    _authSub = _authService.authStateChanges.listen((_) {
      notifyListeners();
    });
  }

  // ── Exposed state ──────────────────────────────────────────────────────────

  bool get isOnline => _connectivity.isOnline;
  SyncStatus get status => _syncService.status;
  DateTime? get lastSyncTime => _syncService.lastSyncTime;
  bool get pendingSync => _syncService.pendingSync;
  String get syncStatusLabel => _syncService.syncStatusLabel;
  bool get isSyncing => _syncService.status == SyncStatus.syncing;
  bool get isSignedIn => _authService.isSignedIn;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<SyncResult> syncNow() => _syncService.syncNow();
  Future<SyncResult> restoreFromCloud() => _syncService.restoreFromCloud();

  @override
  void dispose() {
    _statusSub?.cancel();
    _connectivitySub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
