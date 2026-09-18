import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/auth_provider.dart';
import 'services/connectivity_service.dart';
import 'services/firebase_sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase ────────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] Initialization notice: $e');
  }

  // ── 2. Connectivity monitor ────────────────────────────────────────────────
  try {
    await ConnectivityService().initialize();
  } catch (e) {
    debugPrint('[ConnectivityService] Initialization notice: $e');
  }

  // ── 3. Sync service (picks up pending flag from last session) ──────────────
  try {
    await FirebaseSyncService().initialize();
  } catch (e) {
    debugPrint('[FirebaseSyncService] Initialization notice: $e');
  }

  runApp(const MoneyBookApp());
}

class MoneyBookApp extends StatelessWidget {
  const MoneyBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, child) {
          return MaterialApp(
            title: 'Money Book',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const _AppRouter(),
          );
        },
      ),
    );
  }
}

/// Decides which screen to show based on auth + setup state.
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();

    // Show loading spinner while providers initialise.
    if (userProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ① Not signed in AND hasn't selected guest/offline mode → show Google login screen.
    if (!authProvider.isSignedIn && !authProvider.isGuestMode) {
      return const LoginScreen();
    }

    // ② First time launch → collect name / currency onboarding.
    if (!userProvider.isSetupComplete) {
      return const OnboardingScreen();
    }

    // ③ Returning user / ready → go straight to home.
    return const MainNavigationScreen();
  }
}
