import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';
import 'connectivity_service.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

/// Result returned by every sync operation.
class SyncResult {
  final bool success;
  final String message;
  final DateTime? syncTime;

  const SyncResult({
    required this.success,
    required this.message,
    this.syncTime,
  });
}

/// Current sync status used to drive the UI cloud indicator.
enum SyncStatus {
  idle,     // No sync attempted yet
  syncing,  // Upload in progress
  synced,   // Last sync succeeded
  pending,  // Changes queued while offline
  error,    // Last sync failed (will retry on reconnect)
}

/// ---------------------------------------------------------------------------
/// FirebaseSyncService
/// ---------------------------------------------------------------------------
/// Offline-first Firebase Firestore backup.
///
/// Auth strategy
/// =============
/// Requires the user to be signed in via [firebase_auth] (Google Sign-In
/// handled by [AuthService]). The UID from the authenticated user is used to
/// scope all data: `users/{uid}/backup/latest`.
///
/// Sync flow
/// =========
/// 1. Local storage is always the source of truth for reads.
/// 2. After every write, [scheduleSync] is called:
///    - Online  → [syncNow] uploads immediately.
///    - Offline → `pendingSync` flag is stored in SharedPreferences.
/// 3. [ConnectivityService] triggers [syncNow] automatically when the device
///    comes back online with pending changes.
///
/// Firestore structure
/// ===================
/// ```
/// users/
///   {uid}/
///     backup/
///       latest  ← full JSON snapshot (transactions + budgets + profile)
/// ```
/// ---------------------------------------------------------------------------
class FirebaseSyncService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  // ── Dependencies ───────────────────────────────────────────────────────────
  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final ConnectivityService _connectivity = ConnectivityService();

  // ── State ──────────────────────────────────────────────────────────────────
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  String? _lastError;
  bool _pendingSync = false;
  bool _initialized = false;

  // ── Observables ────────────────────────────────────────────────────────────
  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  bool get pendingSync => _pendingSync;

  final StreamController<SyncStatus> _statusCtrl =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusCtrl.stream;

  StreamSubscription<bool>? _connectivitySub;

  // ── SharedPrefs keys ───────────────────────────────────────────────────────
  static const _kPending = 'mb_pending_sync';
  static const _kLastSync = 'mb_last_sync_time';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Call once from [main()] (or re-call after Google sign-in to pick up the
  /// real UID).
  Future<void> initialize() async {
    await _restoreLocalState();

    // Cancel any existing connectivity subscription before re-registering.
    await _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
      if (online && _pendingSync) {
        debugPrint('[FirebaseSyncService] Reconnected – flushing pending sync');
        syncNow();
      }
    });

    // Flush any pending writes immediately if already online.
    if (_connectivity.isOnline && _pendingSync && _auth?.currentUser != null) {
      syncNow();
    }

    _initialized = true;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusCtrl.close();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call after every local write.
  /// Syncs immediately when online; queues for later when offline.
  Future<SyncResult> scheduleSync() async {
    if (!_initialized) await initialize();

    if (_auth?.currentUser == null) {
      // Not signed in — skip cloud sync but don't error.
      return const SyncResult(
        success: true,
        message: 'Not signed in – data saved locally only.',
      );
    }

    if (_connectivity.isOnline) {
      return syncNow();
    } else {
      await _markPending(true);
      _setStatus(SyncStatus.pending);
      return const SyncResult(
        success: true,
        message: 'Offline – changes saved locally. Will sync when online.',
      );
    }
  }

  /// Upload the full local backup snapshot to Firestore right now.
  Future<SyncResult> syncNow() async {
    final uid = _auth?.currentUser?.uid;
    final db = _db;
    if (uid == null || db == null) {
      return const SyncResult(
        success: false,
        message: 'Not signed in. Please sign in to enable cloud backup.',
      );
    }

    _setStatus(SyncStatus.syncing);
    try {
      final backupJson = await StorageService.generateBackupJson();
      final backupMap = jsonDecode(backupJson) as Map<String, dynamic>;

      await db
          .collection('users')
          .doc(uid)
          .collection('backup')
          .doc('latest')
          .set({
        ...backupMap,
        'syncedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

      final now = DateTime.now();
      _lastSyncTime = now;
      await _markPending(false);
      await _saveLastSyncTime(now);
      _setStatus(SyncStatus.synced);

      debugPrint('[FirebaseSyncService] ✅ Synced at $now (uid=$uid)');
      return SyncResult(
        success: true,
        message: 'Backup synced to Firebase successfully.',
        syncTime: now,
      );
    } on FirebaseException catch (e) {
      _lastError = e.message;
      _setStatus(SyncStatus.error);
      await _markPending(true);
      debugPrint('[FirebaseSyncService] ❌ Firestore error: ${e.message}');
      return SyncResult(success: false, message: 'Sync failed: ${e.message}');
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      await _markPending(true);
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }

  /// Download and restore the latest Firestore backup for the signed-in user.
  Future<SyncResult> restoreFromCloud() async {
    final uid = _auth?.currentUser?.uid;
    final db = _db;
    if (uid == null || db == null) {
      return const SyncResult(
        success: false,
        message: 'Not signed in.',
      );
    }

    _setStatus(SyncStatus.syncing);
    try {
      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('backup')
          .doc('latest')
          .get();

      if (!doc.exists || doc.data() == null) {
        _setStatus(SyncStatus.idle);
        return const SyncResult(
          success: false,
          message: 'No cloud backup found for your account.',
        );
      }

      final data = Map<String, dynamic>.from(doc.data()!);
      data.remove('syncedAt');
      data.remove('platform');

      final restored =
          await StorageService.restoreFromBackupJson(jsonEncode(data));
      if (restored) {
        _setStatus(SyncStatus.synced);
        return SyncResult(
          success: true,
          message: 'Data restored from your Firebase backup.',
          syncTime: DateTime.now(),
        );
      }
      _setStatus(SyncStatus.error);
      return const SyncResult(
        success: false,
        message: 'Backup data is corrupted.',
      );
    } catch (e) {
      _setStatus(SyncStatus.error);
      return SyncResult(success: false, message: 'Restore failed: $e');
    }
  }

  /// Triggered after successful Google sign-in.
  /// 1. If cloud has a backup and local device has no transactions, auto-restores.
  /// 2. If cloud has a backup and local has transactions, merges them safely.
  /// 3. If cloud has no backup, uploads current local data to initialize cloud.
  Future<SyncResult> syncOnLogin() async {
    final uid = _auth?.currentUser?.uid;
    final db = _db;
    if (uid == null || db == null) {
      return const SyncResult(
        success: false,
        message: 'Not signed in or Firebase unavailable.',
      );
    }

    _setStatus(SyncStatus.syncing);
    try {
      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('backup')
          .doc('latest')
          .get();

      if (doc.exists && doc.data() != null) {
        final cloudData = Map<String, dynamic>.from(doc.data()!);
        cloudData.remove('syncedAt');
        cloudData.remove('platform');

        final localTransactions = await StorageService.loadTransactions();

        if (localTransactions.isEmpty) {
          // New device or fresh install: auto-restore from cloud
          final restored = await StorageService.restoreFromBackupJson(
            jsonEncode(cloudData),
          );
          if (restored) {
            final now = DateTime.now();
            _lastSyncTime = now;
            await _markPending(false);
            await _saveLastSyncTime(now);
            _setStatus(SyncStatus.synced);
            debugPrint('[FirebaseSyncService] ✅ Auto-restored cloud backup for new device');
            return SyncResult(
              success: true,
              message: 'Cloud backup restored successfully.',
              syncTime: now,
            );
          }
        } else {
          // Both local and cloud have data: merge safely by unique IDs
          final cloudTxRaw = cloudData['transactions'] as List? ?? [];
          final cloudTxList = cloudTxRaw
              .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

          final Map<String, TransactionModel> mergedMap = {};
          for (final tx in cloudTxList) {
            mergedMap[tx.id] = tx;
          }
          for (final tx in localTransactions) {
            mergedMap[tx.id] = tx;
          }

          await StorageService.saveTransactions(mergedMap.values.toList());

          // Merge budgets
          final localBudgets = await StorageService.loadBudgets();
          final cloudBudgetsRaw = cloudData['budgets'] as List? ?? [];
          final cloudBudgets = cloudBudgetsRaw
              .map((e) => BudgetModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

          final Map<String, BudgetModel> mergedBudgets = {};
          for (final b in cloudBudgets) {
            mergedBudgets[b.id] = b;
          }
          for (final b in localBudgets) {
            mergedBudgets[b.id] = b;
          }
          await StorageService.saveBudgets(mergedBudgets.values.toList());

          // Sync merged state back to cloud
          return await syncNow();
        }
      }

      // No cloud backup yet: upload current local data
      return await syncNow();
    } catch (e) {
      debugPrint('[FirebaseSyncService] syncOnLogin error, queuing: $e');
      return await scheduleSync();
    }
  }

  // ── Status label ───────────────────────────────────────────────────────────

  String get syncStatusLabel {
    if (_auth?.currentUser == null) return 'Sign in to enable cloud backup';
    switch (_status) {
      case SyncStatus.syncing:
        return 'Syncing…';
      case SyncStatus.synced:
        if (_lastSyncTime == null) return 'Synced';
        final diff = DateTime.now().difference(_lastSyncTime!);
        if (diff.inSeconds < 60) return 'Synced just now';
        if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
        if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
        return 'Synced ${diff.inDays}d ago';
      case SyncStatus.pending:
        return 'Pending sync (offline)';
      case SyncStatus.error:
        return 'Sync failed – will retry';
      case SyncStatus.idle:
        return 'Not synced yet';
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  Future<void> _markPending(bool pending) async {
    _pendingSync = pending;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPending, pending);
  }

  Future<void> _saveLastSyncTime(DateTime t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSync, t.toIso8601String());
  }

  Future<void> _restoreLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingSync = prefs.getBool(_kPending) ?? false;
    final ts = prefs.getString(_kLastSync);
    if (ts != null) _lastSyncTime = DateTime.tryParse(ts);

    if (_pendingSync) {
      _setStatus(SyncStatus.pending);
    } else if (_lastSyncTime != null) {
      _setStatus(SyncStatus.synced);
    }
  }
}
