import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/sms_service.dart';
import 'reminder_bottom_sheet.dart';

class DueTile extends StatelessWidget {
  final TransactionModel transaction;
  final String userName;
  final VoidCallback onMarkPaid;

  const DueTile({
    super.key,
    required this.transaction,
    required this.userName,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = Provider.of<UserProvider>(context, listen: false).currencySymbol;
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    final dueDateStr = transaction.dueDate != null
        ? DateFormat('MMM dd, yyyy').format(transaction.dueDate!)
        : 'No due date';

    final daysRemaining = transaction.dueDate != null
        ? transaction.dueDate!.difference(DateTime.now()).inDays
        : 0;

    final isUrgent = daysRemaining <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? AppTheme.warningOrange.withAlpha(150)
              : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          width: isUrgent ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withAlpha(isDark ? 50 : 25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.warningOrange,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Due: $dueDateStr',
                      style: TextStyle(
                        fontSize: 12,
                        color: isUrgent
                            ? AppTheme.warningOrange
                            : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (transaction.phoneNumber != null && transaction.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        transaction.phoneNumber!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(transaction.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.cashOutRed,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue, size: 20),
                      tooltip: 'Send Payment Reminder',
                      onPressed: () {
                        ReminderBottomSheet.show(
                          context,
                          transaction: transaction,
                          userName: userName,
                          currencySymbol: currencySymbol,
                        );
                      },
                    ),
                  ElevatedButton(
                    onPressed: onMarkPaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cashInGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(60, 32),
                    ),
                    child: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
