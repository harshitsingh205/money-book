import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_sync_service.dart';

class ExpenseProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;

  // Search & Filters
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedType = 'All'; // 'All', 'Cash In', 'Cash Out'
  DateTimeRange? _selectedDateRange;

  List<TransactionModel> get transactions => _transactions;
  List<BudgetModel> get budgets => _budgets;
  bool get isLoading => _isLoading;

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedType => _selectedType;
  DateTimeRange? get selectedDateRange => _selectedDateRange;

  Future<void>? _loadingFuture;

  ExpenseProvider() {
    loadData();
  }

  Future<void> loadData() async {
    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }
    _loadingFuture = _performLoad();
    await _loadingFuture;
    _loadingFuture = null;
  }

  Future<void> _performLoad() async {
    _isLoading = true;
    notifyListeners();
    _transactions = await StorageService.loadTransactions();
    _budgets = await StorageService.loadBudgets();
    _isLoading = false;
    notifyListeners();
  }

  // Financial Summaries
  double get totalBalance {
    return totalCashIn - totalCashOut;
  }

  double get totalCashIn {
    return _transactions
        .where((t) => t.isCashIn)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalCashOut {
    return _transactions
        .where((t) => t.isCashOut)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Monthly breakdown helpers
  double getMonthlyIncome(int month, int year) {
    return _transactions
        .where((t) => t.isCashIn && t.date.month == month && t.date.year == year)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getMonthlyExpense(int month, int year) {
    return _transactions
        .where((t) => t.isCashOut && t.date.month == month && t.date.year == year)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getCategoryMonthlyExpense(String category, int month, int year) {
    return _transactions
        .where((t) =>
            t.isCashOut &&
            t.category.toLowerCase() == category.toLowerCase() &&
            t.date.month == month &&
            t.date.year == year)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> getCategoryExpensesMap(int month, int year) {
    final Map<String, double> map = {};
    for (var t in _transactions) {
      if (t.isCashOut && t.date.month == month && t.date.year == year) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    return map;
  }

  // Upcoming Dues
  List<TransactionModel> get upcomingDues {
    final list = _transactions.where((t) => t.isDue).toList();
    list.sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date));
    return list;
  }

  // Recent Transactions (Limit to 5)
  List<TransactionModel> get recentTransactions {
    final sorted = List<TransactionModel>.from(_transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(5).toList();
  }

  // Filtered Transactions
  List<TransactionModel> get filteredTransactions {
    return _transactions.where((t) {
      // Search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = t.title.toLowerCase().contains(query);
        final matchCategory = t.category.toLowerCase().contains(query);
        final matchNote = t.note.toLowerCase().contains(query);
        final matchAmount = t.amount.toString().contains(query);
        if (!matchTitle && !matchCategory && !matchNote && !matchAmount) {
          return false;
        }
      }

      // Type Filter
      if (_selectedType == 'Cash In' && !t.isCashIn) return false;
      if (_selectedType == 'Cash Out' && !t.isCashOut) return false;

      // Category Filter
      if (_selectedCategory != 'All' &&
          t.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      // Date Range Filter
      if (_selectedDateRange != null) {
        final start = _selectedDateRange!.start;
        final end = _selectedDateRange!.end.add(const Duration(days: 1));
        if (t.date.isBefore(start) || t.date.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Actions
  Future<void> addTransaction(TransactionModel item) async {
    _transactions.insert(0, item);
    await StorageService.saveTransactions(_transactions);
    StorageService.triggerAutoBackup(); // Auto-backup to protected snapshot
    FirebaseSyncService().scheduleSync(); // Cloud backup (online: immediate, offline: queued)
    notifyListeners();
  }

  Future<void> updateTransaction(TransactionModel updated) async {
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _transactions[index] = updated;
      await StorageService.saveTransactions(_transactions);
      StorageService.triggerAutoBackup();
      FirebaseSyncService().scheduleSync();
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await StorageService.saveTransactions(_transactions);
    StorageService.triggerAutoBackup();
    FirebaseSyncService().scheduleSync();
    notifyListeners();
  }

  Future<void> markDueAsPaid(String id, [bool isPaid = true]) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      _transactions[index] = _transactions[index].copyWith(isPaid: isPaid);
      await StorageService.saveTransactions(_transactions);
      StorageService.triggerAutoBackup();
      FirebaseSyncService().scheduleSync();
      notifyListeners();
    }
  }

  Future<void> markAsPaid(String id, [bool isPaid = true]) => markDueAsPaid(id, isPaid);

  // Budget Actions
  Future<void> setBudget({
    required String category,
    required double limitAmount,
    required int month,
    required int year,
  }) async {
    final index = _budgets.indexWhere((b) =>
        b.category.toLowerCase() == category.toLowerCase() &&
        b.month == month &&
        b.year == year);

    final newBudget = BudgetModel(
      id: index != -1 ? _budgets[index].id : DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      limitAmount: limitAmount,
      month: month,
      year: year,
    );

    if (index != -1) {
      _budgets[index] = newBudget;
    } else {
      _budgets.add(newBudget);
    }

    await StorageService.saveBudgets(_budgets);
    StorageService.triggerAutoBackup();
    FirebaseSyncService().scheduleSync();
    notifyListeners();
  }

  Future<void> deleteBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);
    await StorageService.saveBudgets(_budgets);
    StorageService.triggerAutoBackup();
    FirebaseSyncService().scheduleSync();
    notifyListeners();
  }

  // Search & Filter Setters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setSelectedType(String type) {
    _selectedType = type;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _selectedDateRange = range;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _selectedType = 'All';
    _selectedDateRange = null;
    notifyListeners();
  }
}
