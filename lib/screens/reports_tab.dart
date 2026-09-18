import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../constants/categories.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  void _exportReportSummary(
    BuildContext context, {
    required double income,
    required double expense,
    required double net,
    required Map<String, double> categoryMap,
    required String currencySymbol,
  }) {
    HapticFeedback.lightImpact();
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final format = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    final buffer = StringBuffer();
    buffer.writeln('Money Book Financial Summary');
    buffer.writeln('Period: $monthName');
    buffer.writeln('------------------------------');
    buffer.writeln('Total Income:   ${format.format(income)}');
    buffer.writeln('Total Expense:  ${format.format(expense)}');
    buffer.writeln('Net Balance:    ${format.format(net)}');
    final savingsRate = income > 0 ? ((net / income) * 100).toStringAsFixed(1) : '0.0';
    buffer.writeln('Savings Rate:   $savingsRate%');
    buffer.writeln('');
    if (categoryMap.isNotEmpty) {
      buffer.writeln('Category Breakdown:');
      final sorted = categoryMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        final pct = expense > 0 ? (e.value / expense * 100).toStringAsFixed(1) : '0';
        buffer.writeln('• ${e.key}: ${format.format(e.value)} ($pct%)');
      }
    }
    buffer.writeln('------------------------------');
    buffer.writeln('Generated via Money Book');

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Financial Report - $monthName',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    final income = provider.getMonthlyIncome(_selectedMonth, _selectedYear);
    final expense = provider.getMonthlyExpense(_selectedMonth, _selectedYear);
    final net = income - expense;
    final savingsRate = income > 0 ? ((net / income) * 100) : 0.0;

    final categoryMap = provider.getCategoryExpensesMap(_selectedMonth, _selectedYear);
    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final monthDate = DateTime(_selectedYear, _selectedMonth);
    final monthLabel = DateFormat('MMMM yyyy').format(monthDate);

    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final dailyAvgExpense = daysInMonth > 0 ? (expense / daysInMonth) : 0.0;

    final monthlyTxList = provider.transactions.where((t) {
      return t.date.month == _selectedMonth && t.date.year == _selectedYear;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. MONTH SELECTOR & EXPORT ACTION ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: _previousMonth,
                      tooltip: 'Previous Month',
                      visualDensity: VisualDensity.compact,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        monthLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: _nextMonth,
                      tooltip: 'Next Month',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportReportSummary(
                  context,
                  income: income,
                  expense: expense,
                  net: net,
                  categoryMap: categoryMap,
                  currencySymbol: currencySymbol,
                ),
                icon: const Icon(Icons.share_outlined, size: 15, color: AppTheme.primaryBlue),
                label: const Text('Export', style: TextStyle(fontSize: 12.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  side: BorderSide(color: AppTheme.primaryBlue.withAlpha(80)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. METRIC OVERVIEW CARDS (Fintech 3-Grid) ──
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Income',
                  amount: currencyFormat.format(income),
                  color: AppTheme.cashInGreen,
                  icon: Icons.arrow_downward_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  title: 'Expenses',
                  amount: currencyFormat.format(expense),
                  color: AppTheme.cashOutRed,
                  icon: Icons.arrow_upward_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCard(
                  title: 'Net Saved',
                  amount: currencyFormat.format(net),
                  color: net >= 0 ? AppTheme.primaryBlue : AppTheme.cashOutRed,
                  icon: Icons.account_balance_wallet_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Savings Rate Progress Card
          if (income > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        'Monthly Savings Rate',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Text(
                        '${savingsRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: net >= 0 ? AppTheme.cashInGreen : AppTheme.cashOutRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: income > 0 ? (net > 0 ? (net / income).clamp(0.0, 1.0) : 0.0) : 0.0,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        net >= 0 ? AppTheme.cashInGreen : AppTheme.cashOutRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 3. CASH FLOW VISUALIZATION BAR ──
          if (income > 0 || expense > 0) ...[
            _sectionHeader('Cash Flow Ratio'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  // Dual ratio bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (income * 100).toInt().clamp(1, 1000000),
                            child: Container(color: AppTheme.cashInGreen),
                          ),
                          Expanded(
                            flex: (expense * 100).toInt().clamp(1, 1000000),
                            child: Container(color: AppTheme.cashOutRed),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.cashInGreen, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'Income: ${((income / (income + expense)) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.cashOutRed, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'Expenses: ${((expense / (income + expense)) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 4. CATEGORY EXPENSES BREAKDOWN ──
          _sectionHeader('Spending by Category'),
          const SizedBox(height: 10),

          if (categoryMap.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pie_chart_outline_rounded,
                    size: 40,
                    color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary).withAlpha(100),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No expenses recorded for this month',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap Cash Out to record expenses and track analytics',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Donut chart card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 46,
                        sections: sortedCategories.map((entry) {
                          final catInfo = AppCategories.getCategory(entry.key);
                          final pct = expense > 0 ? (entry.value / expense * 100) : 0.0;
                          return PieChartSectionData(
                            color: catInfo.color,
                            value: entry.value,
                            title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                            radius: 38,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Ranked categories list
                  ...sortedCategories.map((entry) {
                    final catInfo = AppCategories.getCategory(entry.key);
                    final pct = expense > 0 ? (entry.value / expense) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: catInfo.color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(catInfo.icon, size: 15, color: catInfo.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ),
                              Text(
                                '${(pct * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                currencyFormat.format(entry.value),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(catInfo.color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 5. MONTHLY INSIGHTS & STATS ──
          _sectionHeader('Monthly Insights'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Column(
              children: [
                _insightRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Recorded Transactions',
                  value: '${monthlyTxList.length} items',
                  isDark: isDark,
                ),
                Divider(height: 16, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                _insightRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Average Daily Spend',
                  value: currencyFormat.format(dailyAvgExpense),
                  isDark: isDark,
                ),
                if (sortedCategories.isNotEmpty) ...[
                  Divider(height: 16, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  _insightRow(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Top Spending Category',
                    value: '${sortedCategories.first.key} (${currencyFormat.format(sortedCategories.first.value)})',
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _insightRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
