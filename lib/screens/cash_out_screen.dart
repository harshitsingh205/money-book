import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../constants/categories.dart';
import '../theme/app_theme.dart';

class CashOutScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final double? initialAmount;

  const CashOutScreen({
    super.key,
    this.transactionToEdit,
    this.initialAmount,
  });

  @override
  State<CashOutScreen> createState() => _CashOutScreenState();
}

class _CashOutScreenState extends State<CashOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  bool _enableDueReminder = false;

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
      _dueDate = t.dueDate;
      _enableDueReminder = t.reminderEnabled;
      _phoneController.text = t.phoneNumber ?? '';
    } else {
      _titleController.text = 'Expense Payment';
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _phoneController.dispose();
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _enableDueReminder = true;
      });
    }
  }

  void _saveCashOut() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text.trim());
      final provider = Provider.of<ExpenseProvider>(context, listen: false);

      if (widget.transactionToEdit != null) {
        final updated = widget.transactionToEdit!.copyWith(
          title: _titleController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          date: _selectedDate,
          note: _noteController.text.trim(),
          dueDate: _dueDate,
          reminderEnabled: _enableDueReminder,
          phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        );
        provider.updateTransaction(updated);
      } else {
        final newTx = TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          amount: amount,
          type: TransactionType.cashOut,
          category: _selectedCategory,
          date: _selectedDate,
          note: _noteController.text.trim(),
          dueDate: _dueDate,
          reminderEnabled: _enableDueReminder,
          phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        );
        provider.addTransaction(newTx);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.transactionToEdit != null
              ? 'Expense updated successfully'
              : 'Cash Out recorded successfully!'),
          backgroundColor: AppTheme.cashOutRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionToEdit != null ? 'Edit Cash Out' : 'Record Cash Out'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppTheme.cashOutRed, size: 28),
            onPressed: _saveCashOut,
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
                  color: AppTheme.cashOutRed.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, color: AppTheme.cashOutRed, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Cash Out (Expense)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cashOutRed,
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
                          color: AppTheme.cashOutRed,
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
              const SizedBox(height: 16),

              // Title Input
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Expense Title / Description *',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),

              // Category Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Expense Category *',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: AppCategories.expenseCategories.map((c) {
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

              // Transaction Date Picker
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
                  hintText: 'Add notes...',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),

              // Optional Due Date & Reminder Section Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: AppTheme.warningOrange),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Due Payment & Reminder (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _dueDate = null;
                                _enableDueReminder = false;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Due Date Button
                    OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.alarm_rounded, size: 18),
                      label: Text(
                        _dueDate == null
                            ? 'Set Due Date'
                            : 'Due Date: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}',
                      ),
                    ),

                    if (_dueDate != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Send Reminder Alert:'),
                          const Spacer(),
                          Switch(
                            value: _enableDueReminder,
                            activeTrackColor: AppTheme.warningOrange,
                            onChanged: (val) {
                              setState(() => _enableDueReminder = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number for SMS Reminder (Optional)',
                          hintText: '+1234567890',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveCashOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cashOutRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Expense Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
