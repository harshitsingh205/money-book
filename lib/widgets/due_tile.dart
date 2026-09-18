import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = Provider.of<UserProvider>(context, listen: false).currencySymbol;
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    final isPaid = transaction.isPaid;
    final dueDate = transaction.dueDate;

    final dueDateStr = dueDate != null
        ? DateFormat('MMM dd, yyyy').format(dueDate)
        : 'No due date';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = dueDate != null ? DateTime(dueDate.year, dueDate.month, dueDate.day) : null;
    final diffDays = dueDay?.difference(today).inDays;

    final isOverdue = !isPaid && diffDays != null && diffDays < 0;
    final isDueSoon = !isPaid && diffDays != null && diffDays >= 0 && diffDays <= 3;

    Color statusColor;
    String statusLabel = '';
    if (isPaid) {
      statusColor = AppTheme.cashInGreen;
      statusLabel = 'Settled';
    } else if (isOverdue) {
      statusColor = AppTheme.cashOutRed;
      statusLabel = diffDays == -1 ? 'Overdue 1 day' : 'Overdue ${diffDays.abs()} days';
    } else if (isDueSoon) {
      statusColor = AppTheme.warningOrange;
      statusLabel = diffDays == 0 ? 'Due Today' : (diffDays == 1 ? 'Due Tomorrow' : 'Due in $diffDays days');
    } else {
      statusColor = AppTheme.lightTextSecondary;
      statusLabel = dueDateStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? AppTheme.cashOutRed.withAlpha(120)
              : (isDueSoon
                  ? AppTheme.warningOrange.withAlpha(120)
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          width: (isOverdue || isDueSoon) ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category / Due Indicator Icon
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppTheme.cashInGreen.withAlpha(20)
                      : (isOverdue
                          ? AppTheme.cashOutRed.withAlpha(20)
                          : AppTheme.warningOrange.withAlpha(20)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_circle_outline_rounded
                      : (isOverdue ? Icons.error_outline_rounded : Icons.schedule_rounded),
                  color: isPaid
                      ? AppTheme.cashInGreen
                      : (isOverdue ? AppTheme.cashOutRed : AppTheme.warningOrange),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Title & Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.2,
                        decoration: isPaid ? TextDecoration.lineThrough : null,
                        color: isPaid
                            ? (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                            : (isDark ? Colors.white : AppTheme.lightTextPrimary),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (transaction.phoneNumber != null && transaction.phoneNumber!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.phone_outlined, size: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                          const SizedBox(width: 3),
                          Text(
                            transaction.phoneNumber!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Amount
              Text(
                currencyFormat.format(transaction.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isPaid
                      ? AppTheme.cashInGreen
                      : (isOverdue ? AppTheme.cashOutRed : (isDark ? Colors.white : AppTheme.lightTextPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          const SizedBox(height: 10),
          // Action Buttons: Reminder & Mark Paid / Undo
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isPaid) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ReminderBottomSheet.show(
                      context,
                      transaction: transaction,
                      userName: userName,
                      currencySymbol: currencySymbol,
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 14, color: AppTheme.primaryBlue),
                  label: const Text('Send Reminder', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    side: BorderSide(color: AppTheme.primaryBlue.withAlpha(80)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onMarkPaid();
                },
                icon: Icon(
                  isPaid ? Icons.undo_rounded : Icons.check_rounded,
                  size: 14,
                ),
                label: Text(
                  isPaid ? 'Mark Unpaid' : 'Mark as Paid',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isPaid
                      ? (isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0))
                      : AppTheme.cashInGreen,
                  foregroundColor: isPaid
                      ? (isDark ? Colors.white70 : AppTheme.lightTextPrimary)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
