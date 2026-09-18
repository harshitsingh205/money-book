import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/budget_card.dart';
import '../constants/categories.dart';
import '../theme/app_theme.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  final int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  void _showSetBudgetDialog(BuildContext context, {String? category, double? initialLimit}) {
    final amountController = TextEditingController(
      text: initialLimit != null ? initialLimit.toStringAsFixed(2) : '',
    );
    String selectedCat = category ?? 'Overall';

    final currencySymbol = Provider.of<UserProvider>(context, listen: false).currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Set Budget (${DateFormat('MMM yyyy').format(DateTime(_selectedYear, _selectedMonth))})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCat,
                decoration: const InputDecoration(labelText: 'Budget Category'),
                items: [
                  'Overall',
                  ...AppCategories.expenseCategories.map((c) => c.name),
                ].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) {
                  if (val != null) selectedCat = val;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly Limit Amount',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Center(
                      widthFactor: 1.0,
                      child: Text(
                        currencySymbol,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final limit = double.tryParse(amountController.text.trim()) ?? 0;
                if (limit > 0) {
                  HapticFeedback.mediumImpact();
                  Provider.of<ExpenseProvider>(context, listen: false).setBudget(
                    category: selectedCat,
                    limitAmount: limit,
                    month: _selectedMonth,
                    year: _selectedYear,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                          const SizedBox(width: 8),
                          Text('Budget for $selectedCat set to $currencySymbol${limit.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save Budget'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final currencySymbol = Provider.of<UserProvider>(context, listen: false).currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    final budgets = provider.budgets.where((b) => b.month == _selectedMonth && b.year == _selectedYear).toList();
    final totalMonthlySpent = provider.getMonthlyExpense(_selectedMonth, _selectedYear);

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);
        await provider.loadData();
        if (syncProvider.isOnline && syncProvider.isSignedIn) {
          await syncProvider.syncNow();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action & Period Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth)),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Category limits & spend targets',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _showSetBudgetDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Set Budget', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),

          // Total Monthly Spend Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Spent This Month',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(totalMonthlySpent),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.cashOutRed,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Budget Categories & Limits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (budgets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 48,
                    color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                        .withAlpha(120),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No budgets set for this month.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "Set Budget" to define spending limits',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final budget = budgets[index];
                final spent = budget.category == 'Overall'
                    ? totalMonthlySpent
                    : provider.getCategoryMonthlyExpense(budget.category, _selectedMonth, _selectedYear);

                return BudgetCard(
                  budget: budget,
                  spentAmount: spent,
                  currencySymbol: currencySymbol,
                  onEdit: () => _showSetBudgetDialog(
                    context,
                    category: budget.category,
                    initialLimit: budget.limitAmount,
                  ),
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Budget?'),
                        content: Text('Are you sure you want to remove the budget for ${budget.category}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cashOutRed),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              provider.deleteBudget(budget.id);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Budget for ${budget.category} deleted')),
                              );
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
      ),
    );
  }
}
