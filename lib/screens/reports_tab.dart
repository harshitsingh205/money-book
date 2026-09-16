import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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
  final int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final currencySymbol = Provider.of<UserProvider>(context, listen: false).currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    final income = provider.getMonthlyIncome(_selectedMonth, _selectedYear);
    final expense = provider.getMonthlyExpense(_selectedMonth, _selectedYear);
    final remaining = income - expense;

    final categoryMap = provider.getCategoryExpensesMap(_selectedMonth, _selectedYear);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Month Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Monthly analytics & category breakdowns',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (index) => index + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(DateFormat('MMM').format(DateTime(2026, m))),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMonth = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3 Metric Overview Cards (Monthly Income, Monthly Expense, Remaining Balance)
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
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  title: 'Expenses',
                  amount: currencyFormat.format(expense),
                  color: AppTheme.cashOutRed,
                  icon: Icons.arrow_upward_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  title: 'Net Saved',
                  amount: currencyFormat.format(remaining),
                  color: remaining >= 0 ? AppTheme.primaryBlue : AppTheme.warningOrange,
                  icon: Icons.account_balance_wallet_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Income vs Expense Comparison Bar Chart Section
          const Text(
            'Income vs Expense Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (income > expense ? income : expense) * 1.25 + 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
                          case 1:
                            return const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: income,
                        color: AppTheme.cashInGreen,
                        width: 32,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: expense,
                        color: AppTheme.cashOutRed,
                        width: 32,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category-wise Breakdown Section
          const Text(
            'Category Expenses Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (categoryMap.isEmpty)
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
              child: const Center(
                child: Text('No expense data for this month.'),
              ),
            )
          else ...[
            // Pie Chart Widget
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: categoryMap.entries.map((entry) {
                    final catInfo = AppCategories.getCategory(entry.key);
                    final percentage = expense > 0 ? (entry.value / expense * 100) : 0.0;
                    return PieChartSectionData(
                      color: catInfo.color,
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category List Progress Items
            ...categoryMap.entries.map((entry) {
              final catInfo = AppCategories.getCategory(entry.key);
              final ratio = expense > 0 ? (entry.value / expense) : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: catInfo.color.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(catInfo.icon, color: catInfo.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                currencyFormat.format(entry.value),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                              valueColor: AlwaysStoppedAnimation<Color>(catInfo.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
