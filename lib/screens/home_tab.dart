import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/due_tile.dart';
import '../theme/app_theme.dart';
import 'cash_in_screen.dart';
import 'cash_out_screen.dart';

class HomeTab extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const HomeTab({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = userProvider.userName;
    final upcomingDues = expenseProvider.upcomingDues;
    final recent = expenseProvider.recentTransactions;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Balance Hero Card
          BalanceCard(
            totalBalance: expenseProvider.totalBalance,
            totalCashIn: expenseProvider.totalCashIn,
            totalCashOut: expenseProvider.totalCashOut,
            currencySymbol: userProvider.currencySymbol,
          ),
          const SizedBox(height: 20),

          // Quick Action Buttons: Cash In & Cash Out
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CashInScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                  label: const Text('Cash In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cashInGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CashOutScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  label: const Text('Cash Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cashOutRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Upcoming Dues Alert Widget (If any exist)
          if (upcomingDues.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notification_important_rounded, color: AppTheme.warningOrange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Upcoming Dues',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(3), // Navigate to Dues Tab
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DueTile(
              transaction: upcomingDues.first,
              userName: name,
              onMarkPaid: () {
                expenseProvider.markDueAsPaid(upcomingDues.first.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment marked as paid!')),
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // Recent Transactions Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => onNavigateToTab(1), // Navigate to Transactions Tab
                child: const Text('View History'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Recent Transactions List
          if (recent.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                        .withAlpha(120),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions recorded yet.',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap Cash In or Cash Out above to get started',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              itemBuilder: (context, index) {
                final tx = recent[index];
                return _AnimatedTransactionItem(
                  index: index,
                  child: TransactionTile(
                    transaction: tx,
                    onDelete: () {
                      expenseProvider.deleteTransaction(tx.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction deleted')),
                      );
                    },
                  ),
                );
              },
            ),
          const SizedBox(height: 80), // Padding for floating calculator
        ],
      ),
    );
  }
}

/// Staggered fade + slide-up animation wrapper for transaction list items.
class _AnimatedTransactionItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedTransactionItem({required this.index, required this.child});

  @override
  State<_AnimatedTransactionItem> createState() =>
      _AnimatedTransactionItemState();
}

class _AnimatedTransactionItemState extends State<_AnimatedTransactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger delay by index
    Future.delayed(
      Duration(milliseconds: widget.index * 60),
      () {
        if (mounted) _ctrl.forward();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
