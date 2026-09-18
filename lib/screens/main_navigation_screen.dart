import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../services/firebase_sync_service.dart';
import '../widgets/floating_calculator.dart';
import 'home_tab.dart';
import 'transactions_tab.dart';
import 'budget_tab.dart';
import 'dues_tab.dart';
import 'reports_tab.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final List<Widget> tabs = [
      HomeTab(onNavigateToTab: _onTabSelected),
      const TransactionsTab(),
      const BudgetTab(),
      const DuesTab(),
      const ReportsTab(),
    ];

    // For home tab show greeting, for others show tab title
    Widget titleWidget;
    if (_currentIndex == 0) {
      final name = userProvider.userName;
      titleWidget = Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryBlue.withAlpha(35),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_getGreeting()}, $name',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Money Book · Financial Overview',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final titles = ['', 'Transactions', 'Monthly Budget', 'Dues & Reminders', 'Financial Reports'];
      titleWidget = Text(
        titles[_currentIndex],
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: titleWidget,
        actions: [
          // ── Sync Status Chip ──────────────────────────────────────────────
          _SyncStatusChip(syncProvider: syncProvider),
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => themeProvider.toggleTheme(),
          ),
          // ── Profile / Settings Icon Button ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: Tooltip(
              message: 'Settings & Profile',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: authProvider.isGoogleSignedIn
                          ? AppTheme.cashInGreen
                          : AppTheme.primaryBlue.withAlpha(120),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage: authProvider.photoUrl != null
                        ? NetworkImage(authProvider.photoUrl!)
                        : null,
                    backgroundColor: AppTheme.primaryLight,
                    child: authProvider.photoUrl == null
                        ? Text(
                            userProvider.userName.isNotEmpty
                                ? userProvider.userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      floatingActionButton: const FloatingCalculator(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance_rounded),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Dues',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

// ── Sync Status Chip Widget ──────────────────────────────────────────────────

class _SyncStatusChip extends StatelessWidget {
  final SyncProvider syncProvider;

  const _SyncStatusChip({required this.syncProvider});

  @override
  Widget build(BuildContext context) {
    final status = syncProvider.status;
    final isOnline = syncProvider.isOnline;
    final isSignedIn = syncProvider.isSignedIn;

    // Not signed in: show a greyed-out cloud icon
    if (!isSignedIn) {
      return Tooltip(
        message: 'No cloud backup - sign in with Google to enable',
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.cloud_off_rounded,
              size: 22, color: Colors.grey.shade400),
        ),
      );
    }

    // Determine icon, color and tooltip text
    final IconData icon;
    final Color color;
    final String tooltip;

    if (!isOnline) {
      icon = Icons.cloud_off_rounded;
      color = Colors.orange;
      tooltip = 'Offline - data saved locally, will sync when online';
    } else {
      switch (status) {
        case SyncStatus.syncing:
          icon = Icons.sync_rounded;
          color = Colors.blue;
          tooltip = 'Syncing to Firebase...';
        case SyncStatus.synced:
          icon = Icons.cloud_done_rounded;
          color = Colors.green;
          tooltip = syncProvider.syncStatusLabel;
        case SyncStatus.pending:
          icon = Icons.cloud_upload_rounded;
          color = Colors.orange;
          tooltip = 'Uploading pending changes...';
        case SyncStatus.error:
          icon = Icons.cloud_off_rounded;
          color = Colors.red;
          tooltip = 'Sync failed - tap to retry';
        case SyncStatus.idle:
          icon = Icons.cloud_outlined;
          color = Colors.grey;
          tooltip = 'Not synced yet';
      }
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          if ((status == SyncStatus.error || status == SyncStatus.pending) && isOnline) {
            syncProvider.syncNow();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Syncing data to Firebase...'),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );
          } else if (status == SyncStatus.synced) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(syncProvider.syncStatusLabel),
                  ],
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (!isOnline) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Offline. Changes saved locally, will sync when online.'),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: status == SyncStatus.syncing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
