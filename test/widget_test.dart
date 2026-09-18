import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneybook/main.dart';
import 'package:moneybook/widgets/floating_calculator.dart';
import 'package:moneybook/widgets/balance_card.dart';
import 'package:moneybook/widgets/budget_card.dart';
import 'package:moneybook/widgets/transaction_tile.dart';
import 'package:moneybook/models/budget_model.dart';
import 'package:moneybook/models/transaction_model.dart';
import 'package:moneybook/providers/expense_provider.dart';
import 'package:moneybook/providers/user_provider.dart';
import 'package:moneybook/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'exp_tracker_user_profile': '{"name":"John Doe","isGoogleDriveConnected":false}',
    });
  });

  testWidgets('App smoke test loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyBookApp());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('BalanceCard displays formatted currency values', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BalanceCard(
            totalBalance: 2450.50,
            totalCashIn: 3000.00,
            totalCashOut: 549.50,
            currencySymbol: '\$',
          ),
        ),
      ),
    );

    expect(find.text('Total Net Balance'), findsOneWidget);
    expect(find.text('\$2,450.50'), findsOneWidget);
    expect(find.text('Cash In'), findsOneWidget);
    expect(find.text('\$3,000.00'), findsOneWidget);
    expect(find.text('Cash Out'), findsOneWidget);
    expect(find.text('\$549.50'), findsOneWidget);
  });

  testWidgets('BudgetCard shows correct status indicators', (WidgetTester tester) async {
    final budget = BudgetModel(
      id: 'b-1',
      category: 'Food',
      limitAmount: 500.00,
      month: 9,
      year: 2026,
    );

    // 1. On Track (<80%)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetCard(
            budget: budget,
            spentAmount: 250.00,
            onEdit: () {},
          ),
        ),
      ),
    );
    expect(find.text('On Track'), findsOneWidget);

    // 2. Near Limit (80%-99%)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetCard(
            budget: budget,
            spentAmount: 450.00,
            onEdit: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Near Limit'), findsOneWidget);

    // 3. OVER BUDGET! (>=100%)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetCard(
            budget: budget,
            spentAmount: 550.00,
            onEdit: () {},
          ),
        ),
      ),
    );
    expect(find.text('Over Budget'), findsOneWidget);
  });

  testWidgets('TransactionTile displays title, category, and formatted amount', (WidgetTester tester) async {
    final tx = TransactionModel(
      id: 'tx-1',
      title: 'Coffee & Snacks',
      amount: 12.50,
      type: TransactionType.cashOut,
      category: 'Food',
      date: DateTime(2026, 9, 16),
      note: 'Afternoon cafe',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionTile(
            transaction: tx,
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Coffee & Snacks'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('-₹12.50'), findsOneWidget);
    expect(find.text('Afternoon cafe'), findsOneWidget);
  });

  testWidgets('FloatingCalculator arithmetic and Add as Expense', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingCalculator(),
          ),
        ),
      ),
    );

    // Find and tap the floating calculator button
    final calcFab = find.byType(FloatingActionButton);
    expect(calcFab, findsOneWidget);
    await tester.tap(calcFab);
    await tester.pumpAndSettle();

    // Verify modal dialog appeared
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Add as Expense'), findsOneWidget);

    // Calculate: 5 + 3 = 8
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('='));
    await tester.pumpAndSettle();

    final displayTextFinder = find.byKey(const Key('calc_display_text'));
    expect(displayTextFinder, findsOneWidget);
    expect((tester.widget(displayTextFinder) as Text).data, '8');

    // Tap "Add as Expense"
    final addAsExpenseFinder = find.text('Add as Expense');
    await tester.ensureVisible(addAsExpenseFinder);
    await tester.pumpAndSettle();
    await tester.tap(addAsExpenseFinder);
    await tester.pumpAndSettle();

    // Verify it navigated to Cash Out screen with 8.00 prefilled
    expect(find.text('Record Cash Out'), findsOneWidget);
    expect(find.text('8.00'), findsOneWidget);
  });
}
