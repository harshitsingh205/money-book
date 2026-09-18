import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/due_tile.dart';
import '../theme/app_theme.dart';
import 'cash_out_screen.dart';

class DuesTab extends StatefulWidget {
  const DuesTab({super.key});

  @override
  State<DuesTab> createState() => _DuesTabState();
}

class _DuesTabState extends State<DuesTab> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = userProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    final allDueItems = expenseProvider.transactions
        .where((t) => t.isCashOut && t.dueDate != null)
        .toList();

    final activeDues = allDueItems.where((t) => !t.isPaid).toList()
      ..sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date));

    final completedDues = allDueItems.where((t) => t.isPaid).toList()
      ..sort((a, b) => (b.dueDate ?? b.date).compareTo(a.dueDate ?? a.date));

    final totalPendingAmount = activeDues.fold<double>(0.0, (sum, t) => sum + t.amount);
    final totalSettledAmount = completedDues.fold<double>(0.0, (sum, t) => sum + t.amount);

    final displayList = _showCompleted ? completedDues : activeDues;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdueCount = activeDues.where((d) {
      if (d.dueDate == null) return false;
      final dueDay = DateTime(d.dueDate!.year, d.dueDate!.month, d.dueDate!.day);
      return dueDay.isBefore(today);
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. FINTECH SUMMARY CARDS ──
          Row(
            children: [
              // Pending Dues Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: overdueCount > 0
                          ? AppTheme.warningOrange.withAlpha(100)
                          : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Dues',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${activeDues.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.warningOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormat.format(totalPendingAmount),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningOrange,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Settled Dues Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Settled Dues',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cashInGreen.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${completedDues.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cashInGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormat.format(totalSettledAmount),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cashInGreen,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 2. FILTER TABS & ADD ACTION ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: Text('Pending (${activeDues.length})'),
                    selected: !_showCompleted,
                    selectedColor: AppTheme.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: !_showCompleted ? AppTheme.primaryBlue : (isDark ? Colors.white70 : AppTheme.lightTextPrimary),
                    ),
                    side: BorderSide(
                      color: !_showCompleted ? AppTheme.primaryBlue : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _showCompleted = false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Settled (${completedDues.length})'),
                    selected: _showCompleted,
                    selectedColor: AppTheme.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _showCompleted ? AppTheme.primaryBlue : (isDark ? Colors.white70 : AppTheme.lightTextPrimary),
                    ),
                    side: BorderSide(
                      color: _showCompleted ? AppTheme.primaryBlue : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _showCompleted = true);
                    },
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CashOutScreen()),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Due', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 3. OVERDUE ALERT BANNER (if applicable) ──
          if (!_showCompleted && overdueCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.cashOutRed.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cashOutRed.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.cashOutRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$overdueCount payment${overdueCount > 1 ? 's are' : ' is'} overdue. Tap "Send Reminder" to notify.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.cashOutRed, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── 4. DUES LIST VIEW ──
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryBlue,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                await expenseProvider.loadData();
                if (syncProvider.isOnline && syncProvider.isSignedIn) {
                  await syncProvider.syncNow();
                }
              },
              child: displayList.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : AppTheme.lightBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                              ),
                              child: Icon(
                                _showCompleted ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                                size: 28,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _showCompleted ? 'No settled dues recorded' : 'All dues are settled',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _showCompleted
                                  ? 'Mark dues as paid to view history here'
                                  : 'Tap "Add Due" to schedule a payment reminder',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final due = displayList[index];
                        return DueTile(
                          transaction: due,
                          userName: userProvider.userName,
                          onMarkPaid: () {
                            expenseProvider.markAsPaid(due.id);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
