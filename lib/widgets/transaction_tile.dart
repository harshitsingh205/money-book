import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../constants/categories.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../screens/cash_in_screen.dart';
import '../screens/cash_out_screen.dart';
import 'reminder_bottom_sheet.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onDelete;
  final VoidCallback? onUpdate;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onDelete,
    this.onUpdate,
  });

  void _showDetails(BuildContext context, String currencySymbol) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catInfo = AppCategories.getCategory(
      transaction.category,
      isIncome: transaction.isCashIn,
    );
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    final dateStr = DateFormat('EEEE, MMMM dd, yyyy').format(transaction.date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header with icon and amount
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: catInfo.color.withAlpha(isDark ? 60 : 30),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(catInfo.icon, color: catInfo.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: (transaction.isCashIn ? AppTheme.cashInGreen : AppTheme.cashOutRed)
                                .withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            transaction.isCashIn ? 'Cash In' : 'Cash Out',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: transaction.isCashIn ? AppTheme.cashInGreen : AppTheme.cashOutRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${transaction.isCashIn ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: transaction.isCashIn ? AppTheme.cashInGreen : AppTheme.cashOutRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Details grid
              _detailRow(Icons.category_rounded, 'Category', transaction.category, isDark),
              const SizedBox(height: 14),
              _detailRow(Icons.calendar_today_rounded, 'Date', dateStr, isDark),
              if (transaction.note.isNotEmpty) ...[
                const SizedBox(height: 14),
                _detailRow(Icons.notes_rounded, 'Note', transaction.note, isDark),
              ],
              if (transaction.isDue) ...[
                const SizedBox(height: 14),
                _detailRow(
                  Icons.event_busy_rounded,
                  'Due Date',
                  transaction.dueDate != null
                      ? DateFormat('MMM dd, yyyy').format(transaction.dueDate!)
                      : 'N/A',
                  isDark,
                ),
                if (transaction.phoneNumber != null && transaction.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _detailRow(Icons.phone_rounded, 'Reminder Phone', transaction.phoneNumber!, isDark),
                ],
                const SizedBox(height: 14),
                _detailRow(
                  Icons.check_circle_rounded,
                  'Status',
                  transaction.isPaid ? 'Paid ✓' : 'Pending',
                  isDark,
                  valueColor: transaction.isPaid ? AppTheme.cashInGreen : AppTheme.warningOrange,
                ),
              ],
              if (transaction.isDue && !transaction.isPaid && transaction.phoneNumber != null && transaction.phoneNumber!.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final userName = Provider.of<UserProvider>(context, listen: false).userName;
                      ReminderBottomSheet.show(
                        context,
                        transaction: transaction,
                        userName: userName,
                        currencySymbol: currencySymbol,
                      );
                    },
                    icon: const Icon(Icons.notifications_active_rounded, size: 18),
                    label: const Text('Send Reminder (SMS / WhatsApp)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (transaction.isCashIn) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CashInScreen(transactionToEdit: transaction),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CashOutScreen(transactionToEdit: transaction),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cashOutRed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String currencySymbol = '₹';
    try {
      currencySymbol = Provider.of<UserProvider>(context, listen: false).currencySymbol;
    } catch (_) {
      currencySymbol = '₹';
    }
    final catInfo = AppCategories.getCategory(
      transaction.category,
      isIncome: transaction.isCashIn,
    );
    final dateStr = DateFormat('MMM dd, yyyy').format(transaction.date);
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);

    return InkWell(
      onTap: () => _showDetails(context, currencySymbol),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: catInfo.color.withAlpha(isDark ? 50 : 25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              catInfo.icon,
              color: catInfo.color,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  transaction.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (transaction.isDue)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'DUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    transaction.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              if (transaction.note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  transaction.note,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                        .withAlpha(180),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          trailing: Text(
            '${transaction.isCashIn ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: transaction.isCashIn ? AppTheme.cashInGreen : AppTheme.cashOutRed,
            ),
          ),
        ),
      ),
    );
  }
}
