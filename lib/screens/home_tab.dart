import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/sync_provider.dart';
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
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = userProvider.userName;
    final upcomingDues = expenseProvider.upcomingDues;
    final recent = expenseProvider.recentTransactions;
    final currency = userProvider.currencySymbol;

    final now = DateTime.now();
    final monthlyIncome = expenseProvider.getMonthlyIncome(now.month, now.year);
    final monthlyExpense = expenseProvider.getMonthlyExpense(now.month, now.year);
    final monthlyNet = monthlyIncome - monthlyExpense;

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await expenseProvider.loadData();
        await userProvider.reload();
        if (syncProvider.isOnline && syncProvider.isSignedIn) {
          await syncProvider.syncNow();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Net Balance Hero Card ──────────────────────────────────
            BalanceCard(
              totalBalance: expenseProvider.totalBalance,
              totalCashIn: expenseProvider.totalCashIn,
              totalCashOut: expenseProvider.totalCashOut,
              currencySymbol: currency,
            ),
            const SizedBox(height: 14),

            // ── 2. Quick Actions (Minimalist Fintech Buttons) ───────────────
            _QuickActions(isDark: isDark),
            const SizedBox(height: 18),

            // ── 3. Monthly Cash Flow (Refined, Spacious & Minimalist) ───────
            _MonthlyCashFlowCard(
              income: monthlyIncome,
              expense: monthlyExpense,
              net: monthlyNet,
              currency: currency,
              isDark: isDark,
              onTapReports: () => onNavigateToTab(4),
            ),
            const SizedBox(height: 22),

            // ── 4. Upcoming Dues Alert (if any) ────────────────────────────
            if (upcomingDues.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.notifications_active_rounded,
                iconColor: AppTheme.warningOrange,
                title: 'Upcoming Dues',
                actionLabel: 'See All (${upcomingDues.length})',
                onAction: () => onNavigateToTab(3),
              ),
              const SizedBox(height: 10),
              DueTile(
                transaction: upcomingDues.first,
                userName: name,
                onMarkPaid: () {
                  HapticFeedback.selectionClick();
                  expenseProvider.markDueAsPaid(upcomingDues.first.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Due marked as paid'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
            ],

            // ── 5. Recent Activity Section ─────────────────────────────────
            _SectionHeader(
              icon: Icons.receipt_long_rounded,
              iconColor: AppTheme.primaryBlue,
              title: 'Recent Activity',
              actionLabel: 'View All',
              onAction: () => onNavigateToTab(1),
            ),
            const SizedBox(height: 10),

            if (recent.isEmpty)
              _EmptyTransactions(isDark: isDark)
            else
              _TransactionsList(
                transactions: recent,
                expenseProvider: expenseProvider,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions (Minimalist Dual Pills) ──────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final bool isDark;
  const _QuickActions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Cash In (Income)
        Expanded(
          child: _QuickActionButton(
            label: 'Cash In',
            sublabel: '+ Add Income',
            icon: Icons.arrow_downward_rounded,
            accentColor: AppTheme.cashInGreen,
            bgColor: isDark ? const Color(0xFF064E3B).withAlpha(85) : const Color(0xFFF0FDF4),
            borderColor: isDark ? const Color(0xFF047857).withAlpha(100) : const Color(0xFFBBF7D0),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashInScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Cash Out (Expense)
        Expanded(
          child: _QuickActionButton(
            label: 'Cash Out',
            sublabel: '- Add Expense',
            icon: Icons.arrow_upward_rounded,
            accentColor: AppTheme.cashOutRed,
            bgColor: isDark ? const Color(0xFF7F1D1D).withAlpha(85) : const Color(0xFFFEF2F2),
            borderColor: isDark ? const Color(0xFFB91C1C).withAlpha(100) : const Color(0xFFFECACA),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashOutScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: accentColor.withAlpha(35),
        highlightColor: accentColor.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: accentColor.withAlpha(190),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Monthly Cash Flow Card (Insightful, Clean & Minimalist) ────────────────────

class _MonthlyCashFlowCard extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final String currency;
  final bool isDark;
  final VoidCallback onTapReports;

  const _MonthlyCashFlowCard({
    required this.income,
    required this.expense,
    required this.net,
    required this.currency,
    required this.isDark,
    required this.onTapReports,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final formatter = NumberFormat.currency(symbol: currency, decimalDigits: 0);

    // Calculate spend ratio
    final totalFlow = income + expense;
    final incomeRatio = totalFlow > 0 ? (income / totalFlow).clamp(0.0, 1.0) : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$monthName Cash Flow',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              // Net Savings Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (net >= 0 ? AppTheme.cashInGreen : AppTheme.cashOutRed)
                      .withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  net >= 0 ? 'Net +${formatter.format(net)}' : 'Net -${formatter.format(net.abs())}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: net >= 0 ? AppTheme.cashInGreen : AppTheme.cashOutRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Ratio Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (incomeRatio * 100).toInt().clamp(1, 99),
                    child: Container(color: AppTheme.cashInGreen),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((1.0 - incomeRatio) * 100).toInt().clamp(1, 99),
                    child: Container(color: AppTheme.cashOutRed),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Two Metrics Columns: Inflow vs Outflow
          Row(
            children: [
              // Inflow
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.cashInGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Inflow',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatter.format(income),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
              const SizedBox(width: 16),
              // Outflow
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.cashOutRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Outflow',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatter.format(expense),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onAction();
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  final bool isDark;
  const _EmptyTransactions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(isDark ? 35 : 20),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 28,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Tap Cash In or Cash Out above to record your first entry.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transactions List ─────────────────────────────────────────────────────────

class _TransactionsList extends StatelessWidget {
  final List transactions;
  final ExpenseProvider expenseProvider;
  final bool isDark;

  const _TransactionsList({
    required this.transactions,
    required this.expenseProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _AnimatedTransactionItem(
          index: index,
          child: TransactionTile(
            transaction: tx,
            onDelete: () {
              HapticFeedback.mediumImpact();
              expenseProvider.deleteTransaction(tx.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction removed'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Animated Wrapper ──────────────────────────────────────────────────────────

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
      duration: const Duration(milliseconds: 320),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(
      Duration(milliseconds: widget.index * 40),
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
