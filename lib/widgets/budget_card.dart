import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_model.dart';
import '../theme/app_theme.dart';
import '../constants/categories.dart';

class BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final double spentAmount;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final String currencySymbol;

  const BudgetCard({
    super.key,
    required this.budget,
    required this.spentAmount,
    required this.onEdit,
    this.onDelete,
    this.currencySymbol = '₹',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    final ratio = (budget.limitAmount > 0) ? (spentAmount / budget.limitAmount) : 0.0;
    final clampedRatio = ratio.clamp(0.0, 1.0);

    Color statusColor = AppTheme.cashInGreen;
    String statusText = 'On Track';

    if (ratio >= 1.0) {
      statusColor = AppTheme.cashOutRed;
      statusText = 'OVER BUDGET!';
    } else if (ratio >= 0.8) {
      statusColor = AppTheme.warningOrange;
      statusText = 'Near Limit (${(ratio * 100).toInt()}%)';
    }

    final catInfo = AppCategories.getCategory(budget.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ratio >= 1.0
              ? AppTheme.cashOutRed.withAlpha(120)
              : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          width: ratio >= 1.0 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: catInfo.color.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(catInfo.icon, color: catInfo.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    budget.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Edit Budget',
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.cashOutRed),
                      onPressed: onDelete,
                      tooltip: 'Delete Budget',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Amounts row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${currencyFormat.format(spentAmount)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              Text(
                'Limit: ${currencyFormat.format(budget.limitAmount)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: clampedRatio,
              minHeight: 10,
              backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
