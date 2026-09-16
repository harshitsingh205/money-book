import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final bool isGoogleDriveConnected;
  final String? googleAccountEmail;
  final bool autoBackupEnabled;
  final ThemeMode themeMode;
  final DateTime? lastBackupTime;
  final bool isSetupComplete;
  final String currencySymbol; // e.g. '₹', '$', '€'
  final String currencyCode;   // e.g. 'INR', 'USD', 'EUR'

  UserProfile({
    required this.name,
    this.isGoogleDriveConnected = false,
    this.googleAccountEmail,
    this.autoBackupEnabled = false,
    this.themeMode = ThemeMode.system,
    this.lastBackupTime,
    this.isSetupComplete = false,
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isGoogleDriveConnected': isGoogleDriveConnected,
      'googleAccountEmail': googleAccountEmail,
      'autoBackupEnabled': autoBackupEnabled,
      'themeMode': themeMode.name,
      'lastBackupTime': lastBackupTime?.toIso8601String(),
      'isSetupComplete': isSetupComplete,
      'currencySymbol': currencySymbol,
      'currencyCode': currencyCode,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? 'User',
      isGoogleDriveConnected: json['isGoogleDriveConnected'] as bool? ?? false,
      googleAccountEmail: json['googleAccountEmail'] as String?,
      autoBackupEnabled: json['autoBackupEnabled'] as bool? ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (t) => t.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      lastBackupTime: json['lastBackupTime'] != null
          ? DateTime.parse(json['lastBackupTime'] as String)
          : null,
      isSetupComplete: json['isSetupComplete'] as bool? ?? false,
      currencySymbol: json['currencySymbol'] as String? ?? '₹',
      currencyCode: json['currencyCode'] as String? ?? 'INR',
    );
  }

  UserProfile copyWith({
    String? name,
    bool? isGoogleDriveConnected,
    String? googleAccountEmail,
    bool? autoBackupEnabled,
    ThemeMode? themeMode,
    DateTime? lastBackupTime,
    bool? isSetupComplete,
    String? currencySymbol,
    String? currencyCode,
  }) {
    return UserProfile(
      name: name ?? this.name,
      isGoogleDriveConnected: isGoogleDriveConnected ?? this.isGoogleDriveConnected,
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      themeMode: themeMode ?? this.themeMode,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
