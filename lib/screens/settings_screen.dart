import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/user_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class CurrencyOption {
  final String symbol;
  final String code;
  final String name;

  const CurrencyOption({
    required this.symbol,
    required this.code,
    required this.name,
  });
}

const List<CurrencyOption> kCurrencies = [
  CurrencyOption(symbol: '₹', code: 'INR', name: 'Indian Rupee'),
  CurrencyOption(symbol: '\$', code: 'USD', name: 'US Dollar'),
  CurrencyOption(symbol: '€', code: 'EUR', name: 'Euro'),
  CurrencyOption(symbol: '£', code: 'GBP', name: 'British Pound'),
  CurrencyOption(symbol: '¥', code: 'JPY', name: 'Japanese Yen'),
  CurrencyOption(symbol: '¥', code: 'CNY', name: 'Chinese Yuan'),
  CurrencyOption(symbol: 'د.إ', code: 'AED', name: 'UAE Dirham'),
  CurrencyOption(symbol: '﷼', code: 'SAR', name: 'Saudi Riyal'),
  CurrencyOption(symbol: 'C\$', code: 'CAD', name: 'Canadian Dollar'),
  CurrencyOption(symbol: 'A\$', code: 'AUD', name: 'Australian Dollar'),
  CurrencyOption(symbol: 'S\$', code: 'SGD', name: 'Singapore Dollar'),
  CurrencyOption(symbol: '৳', code: 'BDT', name: 'Bangladeshi Taka'),
  CurrencyOption(symbol: 'Rs', code: 'PKR', name: 'Pakistani Rupee'),
  CurrencyOption(symbol: 'R\$', code: 'BRL', name: 'Brazilian Real'),
  CurrencyOption(symbol: '₺', code: 'TRY', name: 'Turkish Lira'),
  CurrencyOption(symbol: '₩', code: 'KRW', name: 'Korean Won'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isRestoring = false;
  DateTime? _lastAutoBackupTime;

  @override
  void initState() {
    super.initState();
    _loadBackupTime();
  }

  Future<void> _loadBackupTime() async {
    final t = await StorageService.getLastAutoBackupTime();
    if (mounted) setState(() => _lastAutoBackupTime = t);
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://privacy-moneybook.vercel.app/');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy URL.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final jsonPayload = await StorageService.generateBackupJson();
      if (kIsWeb) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup export is not supported on web.')),
        );
        return;
      }

      await StorageService.saveLocalBackupCopy(jsonPayload);
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/MoneyBook_Backup_$timestamp.json');
      await file.writeAsString(jsonPayload);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Money Book Backup ($timestamp)',
          text: 'Money Book secure data backup ($timestamp)',
        ),
      );

      _loadBackupTime();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _restoreBackup(ExpenseProvider expProvider, UserProvider userProvider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isEmpty) return;

      setState(() => _isRestoring = true);
      final picked = files.first;
      final jsonString = picked.path != null
          ? await File(picked.path!).readAsString()
          : await picked.xFile.readAsString();

      final success = await StorageService.restoreFromBackupJson(jsonString);
      if (success) {
        await expProvider.loadData();
        await userProvider.reload();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Backup restored successfully.'),
              backgroundColor: AppTheme.cashInGreen,
            ),
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Invalid backup file format.'),
            backgroundColor: AppTheme.cashOutRed,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Restore error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showCurrencyPicker(BuildContext context, UserProvider userProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Currency',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: kCurrencies.length,
                    separatorBuilder: (context, _) => Divider(
                      height: 1,
                      indent: 64,
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                    itemBuilder: (_, index) {
                      final item = kCurrencies[index];
                      final isSelected = item.code == userProvider.currencyCode;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBlue.withAlpha(25)
                                : (isDark ? AppTheme.darkSurface : AppTheme.lightBg),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                            ),
                          ),
                          child: Text(
                            item.symbol,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white : AppTheme.lightTextPrimary),
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${item.code} (${item.symbol})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue, size: 22)
                            : null,
                        onTap: () {
                          userProvider.setCurrency(item.symbol, item.code);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, UserProvider userProvider) {
    final controller = TextEditingController(text: userProvider.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            hintText: 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                userProvider.setUserName(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedCurrency = kCurrencies.firstWhere(
      (c) => c.code == userProvider.currencyCode,
      orElse: () => kCurrencies.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. PROFILE HEADER CARD (Fintech Style) ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Profile Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => _showEditNameDialog(context, userProvider),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkCard : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    userProvider.userName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _showEditNameDialog(context, userProvider),
                                  child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primaryBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Account Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: authProvider.isGoogleSignedIn
                                    ? AppTheme.cashInGreen.withAlpha(20)
                                    : (isDark ? Colors.white10 : AppTheme.lightBg),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: authProvider.isGoogleSignedIn
                                      ? AppTheme.cashInGreen.withAlpha(50)
                                      : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    authProvider.isGoogleSignedIn
                                        ? Icons.cloud_done_rounded
                                        : Icons.phone_android_rounded,
                                    size: 13,
                                    color: authProvider.isGoogleSignedIn
                                        ? AppTheme.cashInGreen
                                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    authProvider.isGoogleSignedIn ? 'Cloud Synced' : 'Offline Account',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: authProvider.isGoogleSignedIn
                                          ? AppTheme.cashInGreen
                                          : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (authProvider.isGoogleSignedIn && authProvider.email != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                authProvider.email!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  const SizedBox(height: 14),
                  // Google Sign-In or Sign-Out Button
                  if (authProvider.isGoogleSignedIn)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Google Account Linked',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Text('Sign Out'),
                                      content: const Text(
                                        'Your data remains safely stored on this device. Sign out of your Google account?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: FilledButton.styleFrom(backgroundColor: AppTheme.cashOutRed),
                                          child: const Text('Sign Out'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    await authProvider.signOut();
                                  }
                                },
                          icon: const Icon(Icons.logout_rounded, size: 16, color: AppTheme.cashOutRed),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppTheme.cashOutRed, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () async {
                                final success = await authProvider.signInWithGoogle();
                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Signed in with Google. Cloud sync active.'),
                                        backgroundColor: AppTheme.cashInGreen,
                                      ),
                                    );
                                  } else if (authProvider.errorMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(authProvider.errorMessage!),
                                        backgroundColor: AppTheme.cashOutRed,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: authProvider.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.account_circle_outlined, size: 18, color: AppTheme.primaryBlue),
                        label: const Text(
                          'Sign in with Google to Sync Cloud',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppTheme.primaryBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. PREFERENCES SECTION ──
            _sectionTitle('Preferences'),
            const SizedBox(height: 10),
            _cardContainer(
              isDark,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedCurrency.symbol,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    title: const Text(
                      'Currency',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    subtitle: Text('${selectedCurrency.name} (${selectedCurrency.code})'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => _showCurrencyPicker(context, userProvider),
                  ),
                  Divider(height: 1, indent: 64, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? Colors.white70 : AppTheme.lightTextPrimary,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    subtitle: Text(themeProvider.isDarkMode ? 'Dark theme active' : 'Light theme active'),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      activeTrackColor: AppTheme.primaryBlue,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 3. DATA & STORAGE (Compact & Offline-Friendly) ──
            _sectionTitle('Data & Storage'),
            const SizedBox(height: 10),
            _cardContainer(
              isDark,
              child: Column(
                children: [
                  // Auto-save status
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.cashInGreen.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.cashInGreen, size: 20),
                    ),
                    title: const Text(
                      'Local Auto-Save',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    subtitle: Text(
                      _lastAutoBackupTime != null
                          ? 'Saved ${DateFormat('MMM dd, hh:mm a').format(_lastAutoBackupTime!)}'
                          : 'Every transaction is saved securely on this device',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.cashInGreen.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: AppTheme.cashInGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (authProvider.isGoogleSignedIn) ...[
                    Divider(height: 1, indent: 64, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.sync_rounded, color: AppTheme.primaryBlue, size: 20),
                      ),
                      title: const Text(
                        'Cloud Sync Status',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        syncProvider.lastSyncTime != null
                            ? 'Last synced: ${DateFormat('hh:mm a').format(syncProvider.lastSyncTime!)}'
                            : 'Synchronized with Firebase Cloud',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: syncProvider.isSyncing
                            ? null
                            : () async {
                                await syncProvider.syncNow();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cloud sync complete.')),
                                  );
                                }
                              },
                        child: syncProvider.isSyncing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sync Now', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  Divider(height: 1, indent: 64, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  // Export Backup
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: AppTheme.primaryBlue, size: 20),
                    ),
                    title: const Text(
                      'Export Backup File',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    subtitle: const Text('Save or share encrypted JSON data snapshot', style: TextStyle(fontSize: 12)),
                    trailing: _isExporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: _isExporting ? null : _exportBackup,
                  ),
                  Divider(height: 1, indent: 64, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  // Restore Backup
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.download_rounded, color: AppTheme.primaryBlue, size: 20),
                    ),
                    title: const Text(
                      'Restore from Backup File',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    subtitle: const Text('Select and import JSON backup from phone', style: TextStyle(fontSize: 12)),
                    trailing: _isRestoring
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: _isRestoring ? null : () => _restoreBackup(expenseProvider, userProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 4. LEGAL & PRIVACY ──
            _sectionTitle('Legal & Support'),
            const SizedBox(height: 10),
            _cardContainer(
              isDark,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppTheme.primaryBlue, size: 20),
                    ),
                    title: const Text(
                      'Privacy Policy',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppTheme.primaryBlue),
                    onTap: _openPrivacyPolicy,
                  ),
                  Divider(height: 1, indent: 64, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline_rounded, size: 20),
                    ),
                    title: const Text(
                      'App Version',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    subtitle: const Text('Money Book 1.0.0 (Production Release)', style: TextStyle(fontSize: 12)),
                  ),
                  Divider(height: 1, indent: 64, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.cashOutRed.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_forever_rounded, color: AppTheme.cashOutRed, size: 20),
                    ),
                    title: const Text(
                      'Delete Account & Data',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: AppTheme.cashOutRed,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently remove your account & cloud backups',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.cashOutRed),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.cashOutRed),
                              SizedBox(width: 8),
                              Text('Delete Account?'),
                            ],
                          ),
                          content: const Text(
                            'This action permanently deletes your account and removes all associated cloud backup data from Firebase servers. This cannot be undone.\n\nDo you want to proceed?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.cashOutRed),
                              child: const Text('Delete Permanently'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        final res = await authProvider.deleteAccount();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: res.success ? AppTheme.cashInGreen : AppTheme.cashOutRed,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trust badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.lightTextSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline-first security: All your transactions, categories, and dues are stored locally on your device.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _cardContainer(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: child,
    );
  }
}
