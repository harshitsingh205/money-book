import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/google_drive_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile _profile = UserProfile(name: 'User');
  bool _isLoading = true;

  UserProfile get profile => _profile;
  String get userName => _profile.name;
  bool get isGoogleDriveConnected => _profile.isGoogleDriveConnected;
  bool get isSetupComplete => _profile.isSetupComplete;
  bool get isLoading => _isLoading;
  String get currencySymbol => _profile.currencySymbol;
  String get currencyCode => _profile.currencyCode;

  UserProvider() {
    _init();
  }

  Future<void> _init() async {
    final loaded = await StorageService.loadUserProfile();
    if (loaded != null) {
      _profile = loaded;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _profile = _profile.copyWith(name: name, isSetupComplete: true);
    await StorageService.saveUserProfile(_profile);
    notifyListeners();
  }

  Future<void> updateGoogleDriveConnection({
    required bool isConnected,
    String? email,
  }) async {
    _profile = _profile.copyWith(
      isGoogleDriveConnected: isConnected,
      googleAccountEmail: email,
    );
    await StorageService.saveUserProfile(_profile);
    notifyListeners();
  }

  Future<void> toggleAutoBackup(bool enabled) async {
    _profile = _profile.copyWith(autoBackupEnabled: enabled);
    await StorageService.saveUserProfile(_profile);
    notifyListeners();
  }

  Future<void> setCurrency(String symbol, String code) async {
    _profile = _profile.copyWith(currencySymbol: symbol, currencyCode: code);
    await StorageService.saveUserProfile(_profile);
    notifyListeners();
  }

  Future<void> reload() async {
    final loaded = await StorageService.loadUserProfile();
    if (loaded != null) {
      _profile = loaded;
      notifyListeners();
    }
  }

  Future<GoogleDriveBackupResult> backupNow() async {
    final result = await GoogleDriveService.performBackupNow();
    if (result.success && result.backupTime != null) {
      _profile = _profile.copyWith(lastBackupTime: result.backupTime);
      await StorageService.saveUserProfile(_profile);
      notifyListeners();
    }
    return result;
  }

  Future<GoogleDriveBackupResult> restoreBackup() async {
    final result = await GoogleDriveService.restoreBackup();
    if (result.success) {
      final updated = await StorageService.loadUserProfile();
      if (updated != null) {
        _profile = updated;
      }
      notifyListeners();
    }
    return result;
  }
}
