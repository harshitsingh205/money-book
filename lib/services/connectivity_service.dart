import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity and notifies listeners when the
/// connection state changes.  Used by [FirebaseSyncService] to
/// trigger a sync as soon as the device comes back online.
class ConnectivityService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  /// Stream of connectivity booleans: `true` = online, `false` = offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Call once from [main] after [Firebase.initializeApp()].
  Future<void> initialize() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = _hasConnection(results);

    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final nowOnline = _hasConnection(results);
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        _controller.add(_isOnline);
        debugPrint('[ConnectivityService] Status changed → ${_isOnline ? "ONLINE" : "OFFLINE"}');
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }
}
