// Forward to the clean, modern SettingsScreen
export 'settings_screen.dart';
import 'package:flutter/material.dart';
import 'settings_screen.dart';

class DriveBackupScreen extends StatelessWidget {
  const DriveBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
