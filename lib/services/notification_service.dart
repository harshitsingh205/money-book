import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class DueReminderAlert {
  final TransactionModel transaction;
  final int daysRemaining;
  final bool isOverdue;
  final bool isDueToday;

  DueReminderAlert({
    required this.transaction,
    required this.daysRemaining,
    required this.isOverdue,
    required this.isDueToday,
  });

  String get alertMessage {
    if (isOverdue) {
      return 'Payment for "${transaction.title}" of \$${transaction.amount.toStringAsFixed(2)} is overdue!';
    } else if (isDueToday) {
      return 'Payment for "${transaction.title}" of \$${transaction.amount.toStringAsFixed(2)} is due TODAY!';
    } else {
      return 'Payment for "${transaction.title}" of \$${transaction.amount.toStringAsFixed(2)} is due in $daysRemaining day(s).';
    }
  }
}

class NotificationService {
  /// Checks transactions for any pending dues approaching within [thresholdDays] or overdue.
  static List<DueReminderAlert> getPendingDueAlerts(
    List<TransactionModel> transactions, {
    int thresholdDays = 3,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alerts = <DueReminderAlert>[];

    for (final t in transactions) {
      if (t.isDue && t.dueDate != null) {
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        final diffInDays = due.difference(today).inDays;

        if (diffInDays <= thresholdDays) {
          alerts.add(
            DueReminderAlert(
              transaction: t,
              daysRemaining: diffInDays,
              isOverdue: diffInDays < 0,
              isDueToday: diffInDays == 0,
            ),
          );
        }
      }
    }

    // Sort by urgency: overdue first, then due today, then closest due date
    alerts.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return alerts;
  }

  /// Show an in-app snackbar or banner if there are urgent dues pending today or overdue
  static void checkAndShowDueAlerts(BuildContext context, List<TransactionModel> transactions) {
    final alerts = getPendingDueAlerts(transactions, thresholdDays: 1);
    if (alerts.isNotEmpty) {
      final mostUrgent = alerts.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.alarm_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mostUrgent.alertMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: mostUrgent.isOverdue ? Colors.red.shade700 : Colors.amber.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
