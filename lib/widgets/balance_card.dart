import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class BalanceCard extends StatefulWidget {
  final double totalBalance;
  final double totalCashIn;
  final double totalCashOut;
  final String currencySymbol;

  const BalanceCard({
    super.key,
    required this.totalBalance,
    required this.totalCashIn,
    required this.totalCashOut,
    this.currencySymbol = '₹',
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;
  bool _isBalanceHidden = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(symbol: widget.currencySymbol, decimalDigits: 2);

    final savingsRate = widget.totalCashIn > 0
        ? ((widget.totalCashIn - widget.totalCashOut) /
                widget.totalCashIn *
                100)
            .clamp(-999.0, 100.0)
        : null;

    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (ctx, child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF2563EB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withAlpha(50),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Shimmer highlight sweep
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Opacity(
                  opacity: 0.08,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(_shimmerAnim.value - 0.8, -0.5),
                        end: Alignment(_shimmerAnim.value + 0.2, 0.5),
                        colors: const [
                          Colors.transparent,
                          Colors.white,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Total Net Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isBalanceHidden = !_isBalanceHidden);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        _isBalanceHidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              if (savingsRate != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        savingsRate >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: savingsRate >= 0
                            ? AppTheme.cashInGreen
                            : AppTheme.cashOutRed,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${savingsRate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: savingsRate >= 0
                              ? AppTheme.cashInGreen
                              : AppTheme.cashOutRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white70,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Balance
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Text(
                _isBalanceHidden
                    ? '${widget.currencySymbol} ••••••••'
                    : currencyFormatter.format(widget.totalBalance),
                key: ValueKey(_isBalanceHidden),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          Text(
            'Lifetime Overview',
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 20),

          // Sub-cards row
          Row(
            children: [
              _statChip(
                icon: Icons.arrow_downward_rounded,
                iconBg: AppTheme.cashInGreen,
                label: 'Cash In',
                value: _isBalanceHidden
                    ? '••••••'
                    : currencyFormatter.format(widget.totalCashIn),
              ),
              const SizedBox(width: 12),
              _statChip(
                icon: Icons.arrow_upward_rounded,
                iconBg: AppTheme.cashOutRed,
                label: 'Cash Out',
                value: _isBalanceHidden
                    ? '••••••'
                    : currencyFormatter.format(widget.totalCashOut),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg.withAlpha(210),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
