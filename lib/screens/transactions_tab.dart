import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../widgets/transaction_tile.dart';
import '../constants/categories.dart';
import '../theme/app_theme.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context, ExpenseProvider provider) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: provider.selectedDateRange,
    );
    if (picked != null) {
      provider.setDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = provider.filteredTransactions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          TextField(
            controller: _searchController,
            onChanged: (val) => provider.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Search transactions by title, category, note...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // Filters Horizontal Scroll Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type Filter Segmented Chips
                _filterChip(
                  label: 'All',
                  isSelected: provider.selectedType == 'All',
                  onSelected: () => provider.setSelectedType('All'),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Cash In',
                  isSelected: provider.selectedType == 'Cash In',
                  onSelected: () => provider.setSelectedType('Cash In'),
                  activeColor: AppTheme.cashInGreen,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Cash Out',
                  isSelected: provider.selectedType == 'Cash Out',
                  onSelected: () => provider.setSelectedType('Cash Out'),
                  activeColor: AppTheme.cashOutRed,
                ),
                const SizedBox(width: 12),
                Container(height: 24, width: 1, color: Colors.grey.withAlpha(100)),
                const SizedBox(width: 12),

                // Date Range Button
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(
                    provider.selectedDateRange == null
                        ? 'Date Filter'
                        : '${DateFormat('MMM dd').format(provider.selectedDateRange!.start)} - ${DateFormat('MMM dd').format(provider.selectedDateRange!.end)}',
                  ),
                  onPressed: () => _selectDateRange(context, provider),
                ),
                if (provider.selectedDateRange != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => provider.setDateRange(null),
                  ),
                ],
                const SizedBox(width: 12),

                // Category Filter Dropdown Chip
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: provider.selectedCategory,
                    hint: const Text('Category'),
                    items: ['All', ...AppCategories.expenseCategories.map((c) => c.name)]
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) provider.setSelectedCategory(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Transaction Count Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transactions (${items.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (provider.searchQuery.isNotEmpty ||
                  provider.selectedCategory != 'All' ||
                  provider.selectedType != 'All' ||
                  provider.selectedDateRange != null)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    provider.clearFilters();
                  },
                  child: const Text('Reset Filters'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Transaction List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                              .withAlpha(120),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching transactions found.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try clearing search or filters.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final tx = items[index];
                      return _AnimatedTxItem(
                        index: index,
                        child: TransactionTile(
                          transaction: tx,
                          onDelete: () {
                            provider.deleteTransaction(tx.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transaction deleted')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? activeColor,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: (activeColor ?? AppTheme.primaryBlue).withAlpha(50),
      onSelected: (_) => onSelected(),
    );
  }
}

/// Lightweight fade + slide entrance wrapper for list items.
class _AnimatedTxItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedTxItem({required this.index, required this.child});

  @override
  State<_AnimatedTxItem> createState() => _AnimatedTxItemState();
}

class _AnimatedTxItemState extends State<_AnimatedTxItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _opacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Cap stagger at 300ms for long lists
    final delay = (widget.index * 40).clamp(0, 300);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
