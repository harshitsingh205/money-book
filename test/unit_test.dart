import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneybook/models/transaction_model.dart';
import 'package:moneybook/models/budget_model.dart';
import 'package:moneybook/models/user_profile.dart';
import 'package:moneybook/providers/expense_provider.dart';
import 'package:moneybook/services/storage_service.dart';
import 'package:moneybook/services/notification_service.dart';
import 'package:moneybook/services/sms_service.dart';
import 'package:moneybook/constants/categories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Model Serialization Tests', () {
    test('TransactionModel serialization and deserialization', () {
      final now = DateTime(2026, 9, 16, 12, 0);
      final tx = TransactionModel(
        id: 'tx-1',
        title: 'Grocery Store',
        amount: 85.50,
        type: TransactionType.cashOut,
        category: 'Food',
        date: now,
        note: 'Weekly fruits & milk',
        dueDate: now.add(const Duration(days: 5)),
        reminderEnabled: true,
        phoneNumber: '+1234567890',
        isPaid: false,
      );

      final json = tx.toJson();
      final restored = TransactionModel.fromJson(json);

      expect(restored.id, 'tx-1');
      expect(restored.title, 'Grocery Store');
      expect(restored.amount, 85.50);
      expect(restored.type, TransactionType.cashOut);
      expect(restored.isCashOut, true);
      expect(restored.isCashIn, false);
      expect(restored.category, 'Food');
      expect(restored.note, 'Weekly fruits & milk');
      expect(restored.reminderEnabled, true);
      expect(restored.phoneNumber, '+1234567890');
      expect(restored.isDue, true);
      expect(restored.isPaid, false);
    });

    test('BudgetModel serialization and deserialization', () {
      final budget = BudgetModel(
        id: 'b-1',
        category: 'Food',
        limitAmount: 500.0,
        month: 9,
        year: 2026,
      );

      final json = budget.toJson();
      final restored = BudgetModel.fromJson(json);

      expect(restored.id, 'b-1');
      expect(restored.category, 'Food');
      expect(restored.limitAmount, 500.0);
      expect(restored.month, 9);
      expect(restored.year, 2026);
    });

    test('UserProfile serialization and deserialization', () {
      final now = DateTime.now();
      final profile = UserProfile(
        name: 'Alice',
        isGoogleDriveConnected: true,
        googleAccountEmail: 'alice@gmail.com',
        autoBackupEnabled: true,
        lastBackupTime: now,
        isSetupComplete: true,
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.name, 'Alice');
      expect(restored.isGoogleDriveConnected, true);
      expect(restored.googleAccountEmail, 'alice@gmail.com');
      expect(restored.autoBackupEnabled, true);
      expect(restored.isSetupComplete, true);
    });
  });

  group('ExpenseProvider Financial Calculations & Filters', () {
    test('Calculates balance, cash in, cash out correctly', () async {
      final provider = ExpenseProvider();
      await provider.loadData();

      // Clear any sample transactions for isolation
      for (final t in List<TransactionModel>.from(provider.transactions)) {
        await provider.deleteTransaction(t.id);
      }

      expect(provider.totalBalance, 0.0);
      expect(provider.totalCashIn, 0.0);
      expect(provider.totalCashOut, 0.0);

      // Add Cash In: Salary $3000
      await provider.addTransaction(
        TransactionModel(
          id: '1',
          title: 'Salary',
          amount: 3000.0,
          type: TransactionType.cashIn,
          category: 'Salary',
          date: DateTime(2026, 9, 1),
        ),
      );

      // Add Cash Out: Rent $1000
      await provider.addTransaction(
        TransactionModel(
          id: '2',
          title: 'Rent',
          amount: 1000.0,
          type: TransactionType.cashOut,
          category: 'Rent',
          date: DateTime(2026, 9, 2),
        ),
      );

      // Add Cash Out: Food $200
      await provider.addTransaction(
        TransactionModel(
          id: '3',
          title: 'Groceries',
          amount: 200.0,
          type: TransactionType.cashOut,
          category: 'Food',
          date: DateTime(2026, 9, 5),
        ),
      );

      expect(provider.totalCashIn, 3000.0);
      expect(provider.totalCashOut, 1200.0);
      expect(provider.totalBalance, 1800.0);

      // Verify Monthly Breakdown
      expect(provider.getMonthlyIncome(9, 2026), 3000.0);
      expect(provider.getMonthlyExpense(9, 2026), 1200.0);
      expect(provider.getCategoryMonthlyExpense('Food', 9, 2026), 200.0);
      expect(provider.getCategoryMonthlyExpense('Rent', 9, 2026), 1000.0);
    });

    test('Filters transactions by type, category, and search query', () async {
      final provider = ExpenseProvider();
      await provider.loadData();

      // Clear existing
      for (final t in List<TransactionModel>.from(provider.transactions)) {
        await provider.deleteTransaction(t.id);
      }

      await provider.addTransaction(
        TransactionModel(
          id: '1',
          title: 'Software Engineer Salary',
          amount: 4000.0,
          type: TransactionType.cashIn,
          category: 'Salary',
          date: DateTime(2026, 9, 10),
        ),
      );

      await provider.addTransaction(
        TransactionModel(
          id: '2',
          title: 'Flight Ticket',
          amount: 450.0,
          type: TransactionType.cashOut,
          category: 'Travel',
          date: DateTime(2026, 9, 12),
        ),
      );

      // Filter by Type
      provider.setSelectedType('Cash In');
      expect(provider.filteredTransactions.length, 1);
      expect(provider.filteredTransactions.first.title, 'Software Engineer Salary');

      provider.setSelectedType('Cash Out');
      expect(provider.filteredTransactions.length, 1);
      expect(provider.filteredTransactions.first.title, 'Flight Ticket');

      provider.setSelectedType('All');
      expect(provider.filteredTransactions.length, 2);

      // Filter by Search Query
      provider.setSearchQuery('Flight');
      expect(provider.filteredTransactions.length, 1);
      expect(provider.filteredTransactions.first.title, 'Flight Ticket');

      // Filter by Category
      provider.setSearchQuery('');
      provider.setSelectedCategory('Travel');
      expect(provider.filteredTransactions.length, 1);
      expect(provider.filteredTransactions.first.category, 'Travel');

      // Clear filters
      provider.clearFilters();
      expect(provider.filteredTransactions.length, 2);
    });

    test('Budget add and delete functionality', () async {
      final provider = ExpenseProvider();
      await provider.loadData();

      await provider.setBudget(
        category: 'Food',
        limitAmount: 400.0,
        month: 9,
        year: 2026,
      );

      final foodBudget = provider.budgets.firstWhere((b) => b.category == 'Food');
      expect(foodBudget.limitAmount, 400.0);

      await provider.deleteBudget(foodBudget.id);
      expect(provider.budgets.any((b) => b.category == 'Food'), false);
    });

    test('Marking dues as paid', () async {
      final provider = ExpenseProvider();
      await provider.loadData();

      final dueTx = TransactionModel(
        id: 'due-1',
        title: 'Electricity Bill',
        amount: 80.0,
        type: TransactionType.cashOut,
        category: 'Bills',
        date: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 3)),
        isPaid: false,
      );

      await provider.addTransaction(dueTx);
      expect(provider.upcomingDues.any((t) => t.id == 'due-1'), true);

      await provider.markDueAsPaid('due-1');
      expect(provider.upcomingDues.any((t) => t.id == 'due-1'), false);
    });
  });

  group('NotificationService Alerts', () {
    test('Identifies overdue and upcoming dues correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final transactions = [
        TransactionModel(
          id: '1',
          title: 'Internet Bill',
          amount: 60.0,
          type: TransactionType.cashOut,
          category: 'Bills',
          date: today,
          dueDate: today.subtract(const Duration(days: 1)), // Overdue
          isPaid: false,
        ),
        TransactionModel(
          id: '2',
          title: 'Water Bill',
          amount: 30.0,
          type: TransactionType.cashOut,
          category: 'Bills',
          date: today,
          dueDate: today, // Due today
          isPaid: false,
        ),
        TransactionModel(
          id: '3',
          title: 'House Rent',
          amount: 1200.0,
          type: TransactionType.cashOut,
          category: 'Rent',
          date: today,
          dueDate: today.add(const Duration(days: 2)), // Approaching
          isPaid: false,
        ),
        TransactionModel(
          id: '4',
          title: 'Paid Loan',
          amount: 500.0,
          type: TransactionType.cashOut,
          category: 'Bills',
          date: today,
          dueDate: today.add(const Duration(days: 1)),
          isPaid: true, // Already paid!
        ),
      ];

      final alerts = NotificationService.getPendingDueAlerts(transactions, thresholdDays: 3);

      expect(alerts.length, 3); // The 3 unpaid dues
      expect(alerts[0].isOverdue, true);
      expect(alerts[1].isDueToday, true);
      expect(alerts[2].daysRemaining, 2);
    });
  });

  group('SmsService Reminder Message Tests', () {
    test('Builds professional, friendly, and urgent templates with correct currency', () {
      final tx = TransactionModel(
        id: 'due-1',
        title: 'Office WiFi Bill',
        amount: 850.00,
        type: TransactionType.cashOut,
        category: 'Bills',
        date: DateTime(2026, 9, 16),
        dueDate: DateTime(2026, 9, 20),
        phoneNumber: '9876543210',
      );

      final proMsg = SmsService.buildDueReminderMessage(
        transaction: tx,
        userName: 'Rahul',
        currencySymbol: '₹',
        style: ReminderStyle.professional,
      );
      expect(proMsg.contains('₹850.00'), true);
      expect(proMsg.contains('Office WiFi Bill'), true);
      expect(proMsg.contains('Rahul'), true);
      expect(proMsg.contains('Money Book'), true);

      final friendMsg = SmsService.buildDueReminderMessage(
        transaction: tx,
        userName: 'Rahul',
        currencySymbol: '₹',
        style: ReminderStyle.friendly,
      );
      expect(friendMsg.contains('₹850.00'), true);
      expect(friendMsg.contains('friendly reminder'), true);

      final urgentMsg = SmsService.buildDueReminderMessage(
        transaction: tx,
        userName: 'Rahul',
        currencySymbol: '₹',
        style: ReminderStyle.urgent,
      );
      expect(urgentMsg.contains('₹850.00'), true);
      expect(urgentMsg.contains('URGENT PAYMENT REMINDER'), true);
    });
  });

  group('StorageService Backup & Restore', () {
    test('Generates and restores valid JSON backup payload', () async {
      final transactions = [
        TransactionModel(
          id: 'bk-1',
          title: 'Consulting Income',
          amount: 1500.0,
          type: TransactionType.cashIn,
          category: 'Freelance',
          date: DateTime(2026, 9, 15),
        ),
      ];
      await StorageService.saveTransactions(transactions);

      final budgets = [
        BudgetModel(
          id: 'bk-b1',
          category: 'Entertainment',
          limitAmount: 150.0,
          month: 9,
          year: 2026,
        ),
      ];
      await StorageService.saveBudgets(budgets);

      await StorageService.saveUserProfile(
        UserProfile(name: 'BackupTester', isGoogleDriveConnected: false),
      );

      final payload = await StorageService.generateBackupJson();
      expect(payload.contains('Money Book'), true);
      expect(payload.contains('Consulting Income'), true);
      expect(payload.contains('Entertainment'), true);

      // Now clear and restore
      await StorageService.saveTransactions([]);
      expect(await StorageService.loadTransactions(), isEmpty);

      final restored = await StorageService.restoreFromBackupJson(payload);
      expect(restored, true);

      final loadedTx = await StorageService.loadTransactions();
      expect(loadedTx.length, 1);
      expect(loadedTx.first.title, 'Consulting Income');
    });
  });

  group('Category Consistency', () {
    test('All 10 required expense categories are present', () {
      final requiredExpenseCats = [
        'Food',
        'Travel',
        'Fuel',
        'Shopping',
        'Bills',
        'Rent',
        'Education',
        'Medical',
        'Entertainment',
        'Other',
      ];

      final actualCats = AppCategories.expenseCategories.map((c) => c.name).toList();

      for (final cat in requiredExpenseCats) {
        expect(actualCats.contains(cat), true, reason: 'Missing category $cat');
      }
    });
  });
}
