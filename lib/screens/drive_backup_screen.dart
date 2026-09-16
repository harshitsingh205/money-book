import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/user_provider.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';

// Supported currencies list
class CurrencyOption {
  final String symbol;
  final String code;
  final String name;
  final String flag;

  const CurrencyOption({
    required this.symbol,
    required this.code,
    required this.name,
    required this.flag,
  });
}

const List<CurrencyOption> kCurrencies = [
  CurrencyOption(symbol: '₹', code: 'INR', name: 'Indian Rupee', flag: '🇮🇳'),
  CurrencyOption(symbol: '\$', code: 'USD', name: 'US Dollar', flag: '🇺🇸'),
  CurrencyOption(symbol: '€', code: 'EUR', name: 'Euro', flag: '🇪🇺'),
  CurrencyOption(symbol: '£', code: 'GBP', name: 'British Pound', flag: '🇬🇧'),
  CurrencyOption(symbol: '¥', code: 'JPY', name: 'Japanese Yen', flag: '🇯🇵'),
  CurrencyOption(symbol: '¥', code: 'CNY', name: 'Chinese Yuan', flag: '🇨🇳'),
  CurrencyOption(symbol: '₩', code: 'KRW', name: 'Korean Won', flag: '🇰🇷'),
  CurrencyOption(symbol: 'د.إ', code: 'AED', name: 'UAE Dirham', flag: '🇦🇪'),
  CurrencyOption(symbol: '﷼', code: 'SAR', name: 'Saudi Riyal', flag: '🇸🇦'),
  CurrencyOption(symbol: '৳', code: 'BDT', name: 'Bangladeshi Taka', flag: '🇧🇩'),
  CurrencyOption(symbol: 'Rs', code: 'PKR', name: 'Pakistani Rupee', flag: '🇵🇰'),
  CurrencyOption(symbol: '฿', code: 'THB', name: 'Thai Baht', flag: '🇹🇭'),
  CurrencyOption(symbol: 'Rp', code: 'IDR', name: 'Indonesian Rupiah', flag: '🇮🇩'),
  CurrencyOption(symbol: 'R\$', code: 'BRL', name: 'Brazilian Real', flag: '🇧🇷'),
  CurrencyOption(symbol: '₺', code: 'TRY', name: 'Turkish Lira', flag: '🇹🇷'),
];

class DriveBackupScreen extends StatefulWidget {
  const DriveBackupScreen({super.key});

  @override
  State<DriveBackupScreen> createState() => _DriveBackupScreenState();
}

class _DriveBackupScreenState extends State<DriveBackupScreen> {
  bool _isProcessing = false;
  DateTime? _lastAutoBackupTime;

  @override
  void initState() {
    super.initState();
    _loadLastBackupTime();
  }

  Future<void> _loadLastBackupTime() async {
    final t = await StorageService.getLastAutoBackupTime();
    if (mounted) setState(() => _lastAutoBackupTime = t);
  }

  // ── BACKUP TO GOOGLE DRIVE / CLOUD ──
  Future<void> _backupToGoogleDrive() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    try {
      final jsonPayload = await StorageService.generateBackupJson();

      if (kIsWeb) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup export not supported on web. Use Android/iOS.')),
        );
        return;
      }

      // Also save a local backup copy for safety
      await StorageService.saveLocalBackupCopy(jsonPayload);

      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/Money_Book_Backup_$timestamp.json');
      await file.writeAsString(jsonPayload);

      if (!mounted) return;

      // Show Google Drive Guidance Dialog before opening native share sheet
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: AppTheme.primaryBlue),
              SizedBox(width: 10),
              Text('Save to Google Drive'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Money Book backup has been generated. When the share sheet opens:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildInstructionStep('1', 'Select "Save to Drive" (Google Drive icon).'),
              const SizedBox(height: 6),
              _buildInstructionStep('2', 'Choose your Google account & folder.'),
              const SizedBox(height: 6),
              _buildInstructionStep('3', 'Tap "Save" to securely store in the cloud.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Open & Save to Drive'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        setState(() => _isProcessing = false);
        return;
      }

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Money Book Backup - $timestamp',
          text: 'Money Book backup file ($timestamp). Save to Google Drive or cloud storage.',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        _loadLastBackupTime(); // refresh banner timestamp
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ Backup successfully sent to Google Drive / Cloud!'),
            backgroundColor: AppTheme.cashInGreen,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: AppTheme.cashOutRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── QUICK SYNC LATEST AUTO-BACKUP TO GOOGLE DRIVE ──
  Future<void> _syncLatestToGoogleDrive() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final latestFile = await StorageService.getLatestBackupFile();
      if (latestFile == null) {
        await _backupToGoogleDrive();
        return;
      }

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(latestFile.path)],
          subject: 'Money Book Auto-Backup to Google Drive',
          text: 'Money Book latest auto-backup snapshot. Save to Google Drive.',
        ),
      );
      if (result.status == ShareResultStatus.success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ Auto-backup synced to Google Drive successfully!'),
            backgroundColor: AppTheme.cashInGreen,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: AppTheme.cashOutRed),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── RESTORE FROM GOOGLE DRIVE / FILES ──
  Future<void> _restoreFromGoogleDrive(
    BuildContext context,
    ExpenseProvider expenseProvider,
    UserProvider userProvider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    try {
      // Use FileType.any so Google Drive files in Android SAF are NEVER grayed out
      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final pickedFile = files.first;
      final jsonPayload = pickedFile.path != null
          ? await File(pickedFile.path!).readAsString()
          : await pickedFile.xFile.readAsString();

      final restored = await StorageService.restoreFromBackupJson(jsonPayload);
      if (restored) {
        await expenseProvider.loadData();
        await userProvider.reload();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ Backup restored successfully! All transactions & settings updated.'),
            backgroundColor: AppTheme.cashInGreen,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('❌ Selected file is not a valid Money Book JSON backup.'),
            backgroundColor: AppTheme.cashOutRed,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: AppTheme.cashOutRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── RESTORE FROM RECENT LOCAL BACKUP ──
  Future<void> _showLocalBackupsModal(
    ExpenseProvider expenseProvider,
    UserProvider userProvider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final localFiles = await StorageService.getLocalBackups();
    if (!mounted) return;

    if (localFiles.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No local backups found. Use "Backup to Google Drive" to create one.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Local Backup Snapshot',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'These backups were created and saved on this device:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: localFiles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = localFiles[i];
                    final modified = f.lastModifiedSync();
                    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(modified);
                    final sizeKb = (f.lengthSync() / 1024).toStringAsFixed(1);

                    return ListTile(
                      leading: const Icon(Icons.restore_page_rounded, color: AppTheme.primaryBlue),
                      title: Text(
                        formattedDate,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${f.path.split(Platform.pathSeparator).last} ($sizeKb KB)'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final payload = await f.readAsString();
                        final restored = await StorageService.restoreFromBackupJson(payload);
                        if (!mounted) return;
                        if (restored) {
                          await expenseProvider.loadData();
                          await userProvider.reload();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('✅ Data restored from local snapshot!'),
                              backgroundColor: AppTheme.cashInGreen,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('❌ Failed to restore snapshot file.'),
                              backgroundColor: AppTheme.cashOutRed,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── RESTORE CHOOSER MODAL ──
  void _showRestoreOptions(
    BuildContext context,
    ExpenseProvider expenseProvider,
    UserProvider userProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Restore Your Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose where to retrieve your Money Book backup file:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Google Drive / Cloud file picker
              _modalActionTile(
                icon: Icons.cloud_download_rounded,
                iconColor: AppTheme.primaryBlue,
                title: 'Google Drive / File Browser',
                subtitle: 'Select backup from Google Drive, Downloads, or SD card',
                onTap: () {
                  Navigator.pop(ctx);
                  _restoreFromGoogleDrive(context, expenseProvider, userProvider);
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Local Device Snapshot
              _modalActionTile(
                icon: Icons.history_rounded,
                iconColor: AppTheme.cashInGreen,
                title: 'Recent Device Snapshot',
                subtitle: 'Restore from automatic snapshots stored on this device',
                onTap: () {
                  Navigator.pop(ctx);
                  _showLocalBackupsModal(expenseProvider, userProvider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modalActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: iconColor.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withAlpha(40)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: onTap,
      ),
    );
  }

  static Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppTheme.primaryBlue,
          child: Text(
            number,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3)),
        ),
      ],
    );
  }

  void _showCurrencyPicker(BuildContext context, UserProvider userProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Currency',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your preferred currency for displaying amounts',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: kCurrencies.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = kCurrencies[i];
                    final isSelected = userProvider.currencyCode == c.code;
                    return ListTile(
                      leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                      title: Text('${c.name} (${c.code})'),
                      subtitle: Text('Symbol: ${c.symbol}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue)
                          : null,
                      selected: isSelected,
                      selectedTileColor: AppTheme.primaryBlue.withAlpha(15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        userProvider.setCurrency(c.symbol, c.code);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Currency set to ${c.name} (${c.symbol})'),
                            backgroundColor: AppTheme.cashInGreen,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedCurrency = kCurrencies.firstWhere(
      (c) => c.code == userProvider.currencyCode,
      orElse: () => kCurrencies.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Backup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── DATA SNAPSHOT OVERVIEW ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFFF59E0B),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Money Book Database',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${expenseProvider.transactions.length} Transactions  •  ${expenseProvider.budgets.length} Budgets',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cashInGreen.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Protected',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── AUTO-BACKUP REALTIME BANNER ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cashInGreen.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cashInGreen.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cashInGreen.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_done_rounded,
                      color: AppTheme.cashInGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-Backup: ON',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _lastAutoBackupTime != null
                              ? 'Last saved: ${DateFormat('MMM dd, hh:mm a').format(_lastAutoBackupTime!)}'
                              : 'Every transaction auto-saved to device snapshots',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: AppTheme.cashInGreen, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),


            // ── GOOGLE DRIVE & CLOUD BACKUP SECTION ──
            _sectionTitle('Google Drive Cloud Backup'),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Save your database to your personal Google Drive account. Restore it anytime on this phone or any new device.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ),

            _settingsCard(
              isDark,
              child: Column(
                children: [
                  // Backup to Google Drive
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.cashInGreen.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: AppTheme.cashInGreen,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Backup to Google Drive',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Export & save securely to your Google account'),
                    trailing: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _isProcessing ? null : _backupToGoogleDrive,
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                  // Sync Latest Auto-Backup
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: Color(0xFFF59E0B),
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Sync Auto-Backup to Drive',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Send latest auto-backup snapshot to Google Drive'),
                    trailing: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _isProcessing ? null : _syncLatestToGoogleDrive,
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                  // Restore from Google Drive
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_download_rounded,
                        color: AppTheme.primaryBlue,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Restore from Google Drive',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Select your backup from Google Drive or device'),
                    trailing: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _isProcessing
                        ? null
                        : () => _showRestoreOptions(context, expenseProvider, userProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── CURRENCY SECTION ──
            _sectionTitle('Currency Settings'),
            const SizedBox(height: 12),
            _settingsCard(
              isDark,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    selectedCurrency.symbol,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                title: const Text(
                  'Active Currency',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${selectedCurrency.flag} ${selectedCurrency.name} (${selectedCurrency.symbol})'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showCurrencyPicker(context, userProvider),
              ),
            ),
            const SizedBox(height: 24),

            // ── APP PREFERENCES ──
            _sectionTitle('Preferences'),
            const SizedBox(height: 12),
            _settingsCard(
              isDark,
              child: Column(
                children: [
                  // Theme toggle
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        themeProvider.isDarkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(themeProvider.isDarkMode ? 'Enabled' : 'Disabled'),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      activeTrackColor: AppTheme.primaryBlue,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                  // User name
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'User Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(userProvider.userName),
                    trailing: const Icon(Icons.edit_rounded, size: 18),
                    onTap: () {
                      final controller = TextEditingController(text: userProvider.userName);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Edit Your Name'),
                          content: TextField(
                            controller: controller,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (controller.text.trim().isNotEmpty) {
                                  userProvider.setUserName(controller.text.trim());
                                  Navigator.pop(ctx);
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── PRIVACY & CLOUD CARD ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryBlue.withAlpha(60),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.security_rounded, color: AppTheme.primaryBlue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy Guarantee: Money Book operates offline-first. Your financial data is saved locally on your phone and can be backed up to your personal Google Drive without any external database tracking.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _settingsCard(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: child,
    );
  }
}
