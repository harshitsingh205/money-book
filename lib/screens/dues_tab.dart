import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/due_tile.dart';
import '../theme/app_theme.dart';
import 'cash_out_screen.dart';

class DuesTab extends StatefulWidget {
  const DuesTab({super.key});

  @override
  State<DuesTab> createState() => _DuesTabState();
}

class _DuesTabState extends State<DuesTab> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allDueItems = expenseProvider.transactions
        .where((t) => t.isCashOut && t.dueDate != null)
        .toList();

    final activeDues = allDueItems.where((t) => !t.isPaid).toList()
      ..sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date));

    final completedDues = allDueItems.where((t) => t.isPaid).toList();

    final displayList = _showCompleted ? completedDues : activeDues;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dues & Reminders',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Track pending payments and send SMS reminders',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CashOutScreen()),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Due'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented Toggle Filter: Pending Dues / Paid History
          Row(
            children: [
              ChoiceChip(
                label: Text('Pending Dues (${activeDues.length})'),
                selected: !_showCompleted,
                selectedColor: AppTheme.warningOrange.withAlpha(50),
                onSelected: (_) => setState(() => _showCompleted = false),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: Text('Paid History (${completedDues.length})'),
                selected: _showCompleted,
                selectedColor: AppTheme.cashInGreen.withAlpha(50),
                onSelected: (_) => setState(() => _showCompleted = true),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Urgent Due Banner
          if (!_showCompleted && activeDues.any((d) => d.dueDate != null && d.dueDate!.difference(DateTime.now()).inDays <= 3)) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningOrange.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.warningOrange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You have payments due soon. Tap the SMS button to send reminders.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Dues List View
          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showCompleted
                              ? Icons.task_alt_rounded
                              : Icons.notifications_paused_rounded,
                          size: 56,
                          color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                              .withAlpha(120),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showCompleted
                              ? 'No completed due payments yet.'
                              : 'No upcoming due payments pending!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'You can attach optional due dates to any Cash Out transaction.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final item = displayList[index];
                      return DueTile(
                        transaction: item,
                        userName: userProvider.userName,
                        onMarkPaid: () {
                          expenseProvider.markDueAsPaid(item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Marked as paid!')),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
