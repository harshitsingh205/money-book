import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../constants/categories.dart';
import '../theme/app_theme.dart';

class CashInScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final double? initialAmount;

  const CashInScreen({super.key, this.transactionToEdit, this.initialAmount});

  @override
  State<CashInScreen> createState() => _CashInScreenState();
}

class _CashInScreenState extends State<CashInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Salary';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _amountController.text = t.amount.toString();
      _titleController.text = t.title;
      _noteController.text = t.note;
      _selectedCategory = t.category;
      _selectedDate = t.date;
    } else if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount! % 1 == 0
          ? widget.initialAmount!.toInt().toString()
          : widget.initialAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveCashIn() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      final amount = double.parse(_amountController.text.trim());
      final provider = Provider.of<ExpenseProvider>(context, listen: false);

      if (widget.transactionToEdit != null) {
        final updated = widget.transactionToEdit!.copyWith(
          title: _titleController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          date: _selectedDate,
          note: _noteController.text.trim(),
        );
        provider.updateTransaction(updated);
      } else {
        final newTx = TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          amount: amount,
          type: TransactionType.cashIn,
          category: _selectedCategory,
          date: _selectedDate,
          note: _noteController.text.trim(),
        );
        provider.addTransaction(newTx);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.transactionToEdit != null
              ? 'Income updated successfully'
              : 'Cash In recorded successfully!'),
          backgroundColor: AppTheme.cashInGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionToEdit != null ? 'Edit Cash In' : 'Record Cash In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppTheme.cashInGreen, size: 28),
            onPressed: _saveCashIn,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cashInGreen.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, color: AppTheme.cashInGreen, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Cash In (Income)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cashInGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  hintText: '0.00',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Center(
                      widthFactor: 1.0,
                      child: Text(
                        Provider.of<UserProvider>(context).currencySymbol,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cashInGreen,
                        ),
                      ),
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  if (double.tryParse(val.trim()) == null) return 'Enter valid number';
                  if (double.parse(val.trim()) <= 0) return 'Amount must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Quick Amount Increment Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [100, 500, 1000, 2000, 5000].map((amt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 14, color: AppTheme.cashInGreen),
                        label: Text('+$amt', style: const TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final current = double.tryParse(_amountController.text.trim()) ?? 0;
                          final updated = current + amt;
                          setState(() {
                            _amountController.text = updated % 1 == 0
                                ? updated.toInt().toString()
                                : updated.toStringAsFixed(2);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Title Input
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title / Description *',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),

              // Category Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Income Source / Category',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: AppCategories.incomeCategories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.name,
                    child: Row(
                      children: [
                        Icon(c.icon, color: c.color, size: 20),
                        const SizedBox(width: 10),
                        Text(c.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date Picker Field
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryBlue),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note Input
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Optional Note',
                  hintText: 'Add details...',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveCashIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cashInGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Income Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
