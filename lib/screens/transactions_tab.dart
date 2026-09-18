import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/transaction_tile.dart';
import '../constants/categories.dart';
import '../theme/app_theme.dart';
import 'cash_out_screen.dart';

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
            child: RefreshIndicator(
              color: AppTheme.primaryBlue,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                await provider.loadData();
                if (syncProvider.isOnline && syncProvider.isSignedIn) {
                  await syncProvider.syncNow();
                }
              },
              child: items.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 48,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.searchQuery.isNotEmpty || provider.selectedCategory != 'All' || provider.selectedType != 'All'
                                  ? 'No matching transactions'
                                  : 'No transactions recorded yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              provider.searchQuery.isNotEmpty || provider.selectedCategory != 'All' || provider.selectedType != 'All'
                                  ? 'Try changing or clearing your search filters'
                                  : 'Add your first income or expense to start tracking',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (provider.searchQuery.isNotEmpty || provider.selectedCategory != 'All' || provider.selectedType != 'All')
                              OutlinedButton.icon(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _searchController.clear();
                                  provider.clearFilters();
                                },
                                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                                label: const Text('Clear Filters'),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CashOutScreen()),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Record Transaction'),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final tx = items[index];
                        return _AnimatedTxItem(
                          index: index,
                          child: TransactionTile(
                            transaction: tx,
                            onDelete: () {
                              HapticFeedback.mediumImpact();
                              provider.deleteTransaction(tx.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('${tx.title} deleted')),
                                    ],
                                  ),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    textColor: Colors.amberAccent,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      provider.addTransaction(tx);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
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
