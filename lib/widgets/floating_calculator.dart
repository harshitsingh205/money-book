import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../screens/cash_out_screen.dart';
import '../screens/cash_in_screen.dart';

// ── Floating Calculator Launcher ──────────────────────────────────────────────

class FloatingCalculator extends StatelessWidget {
  const FloatingCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'floating_calculator_btn',
      onPressed: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _CalculatorSheet(),
        );
      },
      backgroundColor: AppTheme.primaryBlue,
      elevation: 3,
      tooltip: 'Quick Calculator',
      child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 25),
    );
  }
}

// ── Calculator Bottom Sheet ───────────────────────────────────────────────────

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet();

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  // ── Calculator State
  String _display = '0';
  String _expression = '';
  double _storedNum = 0;
  String _pendingOp = '';
  bool _isNewEntry = true;
  bool _justEvaluated = false;
  String _livePreview = '';

  // ── Calculation Logic

  void _press(String key) {
    HapticFeedback.lightImpact();

    setState(() {
      switch (key) {
        case 'AC':
          HapticFeedback.mediumImpact();
          _display = '0';
          _expression = '';
          _storedNum = 0;
          _pendingOp = '';
          _isNewEntry = true;
          _justEvaluated = false;
          _livePreview = '';

        case '⌫':
          if (_justEvaluated) {
            _display = '0';
            _isNewEntry = true;
            _justEvaluated = false;
          } else if (_display.length > 1) {
            _display = _display.substring(0, _display.length - 1);
          } else {
            _display = '0';
            _isNewEntry = true;
          }
          _updateLivePreview();

        case '+/-':
          final v = double.tryParse(_display) ?? 0;
          _display = _fmt(-v);
          _updateLivePreview();

        case '%':
          final v = double.tryParse(_display) ?? 0;
          _display = _fmt(v / 100);
          _updateLivePreview();

        case '+':
        case '-':
        case '×':
        case '÷':
          if (_pendingOp.isNotEmpty && !_isNewEntry) {
            // Chain calculation: evaluate previous operation first
            _evaluate(isChaining: true);
          }
          _storedNum = double.tryParse(_display) ?? 0;
          _pendingOp = key;
          _expression = '${_fmtDisplayNum(_storedNum)} $key';
          _isNewEntry = true;
          _justEvaluated = false;
          _livePreview = '';

        case '=':
          HapticFeedback.mediumImpact();
          _evaluate();

        case '.':
          if (_isNewEntry) {
            _display = '0.';
            _isNewEntry = false;
          } else if (!_display.contains('.')) {
            _display += '.';
          }
          _justEvaluated = false;
          _updateLivePreview();

        default:
          // Digits 0-9
          if (_isNewEntry || _display == '0') {
            _display = key;
            _isNewEntry = false;
          } else {
            if (_display.length < 12) _display += key;
          }
          _justEvaluated = false;
          _updateLivePreview();
      }
    });
  }

  void _updateLivePreview() {
    if (_pendingOp.isNotEmpty && !_isNewEntry) {
      final num2 = double.tryParse(_display) ?? 0;
      double result = 0;
      switch (_pendingOp) {
        case '+': result = _storedNum + num2;
        case '-': result = _storedNum - num2;
        case '×': result = _storedNum * num2;
        case '÷': result = num2 != 0 ? _storedNum / num2 : 0;
      }
      _livePreview = '= ${_fmtDisplayNum(result)}';
    } else {
      _livePreview = '';
    }
  }

  void _evaluate({bool isChaining = false}) {
    if (_pendingOp.isEmpty) return;
    final num2 = double.tryParse(_display) ?? 0;
    double result = 0;
    switch (_pendingOp) {
      case '+': result = _storedNum + num2;
      case '-': result = _storedNum - num2;
      case '×': result = _storedNum * num2;
      case '÷': result = num2 != 0 ? _storedNum / num2 : 0;
    }

    if (!isChaining) {
      _expression = '${_fmtDisplayNum(_storedNum)} $_pendingOp ${_fmtDisplayNum(num2)} =';
      _display = _fmt(result);
      _pendingOp = '';
      _isNewEntry = true;
      _justEvaluated = true;
      _livePreview = '';
    } else {
      _display = _fmt(result);
      _storedNum = result;
      _livePreview = '';
    }
  }

  double get _currentValue => double.tryParse(_display) ?? 0;

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if (v == v.truncateToDouble() && v.abs() < 1e12) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _fmtDisplayNum(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    final formatter = NumberFormat('#,##0.######');
    return formatter.format(v);
  }

  String _formatCurrentDisplay() {
    if (_display.contains('.')) {
      final parts = _display.split('.');
      final intPart = double.tryParse(parts[0]) ?? 0;
      final formattedInt = NumberFormat('#,##0').format(intPart);
      return '$formattedInt.${parts[1]}';
    }
    final numVal = double.tryParse(_display);
    if (numVal != null) {
      return NumberFormat('#,##0').format(numVal);
    }
    return _display;
  }

  // ── Build Method

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currency = userProvider.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.72,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 90 : 30),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calculate_rounded, color: AppTheme.primaryBlue, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Quick Calculator',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // ── Modern Display Box
          _DisplayCard(
            expression: _expression,
            livePreview: _livePreview,
            displayFormatted: _formatCurrentDisplay(),
            rawDisplay: _display,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // ── Contextual Action Shortcuts (+ Income / - Expense)
          _QuickFinancialActions(
            currentValue: _currentValue,
            currency: currency,
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),

          // ── Ergonomic Pro Keypad
          Expanded(
            child: _Keypad(
              onPress: _press,
              activeOp: _pendingOp,
              isDark: isDark,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Display Card ──────────────────────────────────────────────────────────────

class _DisplayCard extends StatelessWidget {
  final String expression;
  final String livePreview;
  final String displayFormatted;
  final String rawDisplay;
  final bool isDark;

  const _DisplayCard({
    required this.expression,
    required this.livePreview,
    required this.displayFormatted,
    required this.rawDisplay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expression & Live Preview row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Copy button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: rawDisplay));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Result copied to clipboard'),
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Expression or Live Subtotal
              Flexible(
                child: Text(
                  livePreview.isNotEmpty ? livePreview : expression,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: livePreview.isNotEmpty
                        ? AppTheme.primaryBlue
                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Main Number Display
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              displayFormatted,
              key: const Key('calc_display_text'),
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.2,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Financial Action Shortcuts ──────────────────────────────────────────

class _QuickFinancialActions extends StatelessWidget {
  final double currentValue;
  final String currency;
  final VoidCallback onClose;

  const _QuickFinancialActions({
    required this.currentValue,
    required this.currency,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = currentValue > 0;
    final formattedVal = NumberFormat.compactCurrency(symbol: currency, decimalDigits: 0).format(currentValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Add as Income
          Expanded(
            child: _ActionPill(
              label: enabled ? 'Add Income ($formattedVal)' : 'Add as Income',
              icon: Icons.arrow_downward_rounded,
              color: AppTheme.cashInGreen,
              enabled: enabled,
              isDark: isDark,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onClose();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CashInScreen(initialAmount: currentValue),
                        ),
                      );
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // Add as Expense
          Expanded(
            child: _ActionPill(
              label: enabled ? 'Add Expense ($formattedVal)' : 'Add as Expense',
              icon: Icons.arrow_upward_rounded,
              color: AppTheme.cashOutRed,
              enabled: enabled,
              isDark: isDark,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onClose();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CashOutScreen(initialAmount: currentValue),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool isDark;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = enabled
        ? color.withAlpha(isDark ? 35 : 20)
        : (isDark ? const Color(0xFF334155).withAlpha(40) : const Color(0xFFF1F5F9));
    final textColor = enabled
        ? color
        : (isDark ? AppTheme.darkTextSecondary.withAlpha(120) : AppTheme.lightTextSecondary.withAlpha(120));

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? color.withAlpha(isDark ? 70 : 50) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ergonomic Keypad ──────────────────────────────────────────────────────────

class _Keypad extends StatelessWidget {
  final void Function(String) onPress;
  final String activeOp;
  final bool isDark;

  const _Keypad({
    required this.onPress,
    required this.activeOp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          // Row 1: AC  +/-  %  ÷
          _KeyRow(
            keys: const ['AC', '+/-', '%', '÷'],
            types: const ['fn', 'fn', 'fn', 'op'],
            activeOp: activeOp,
            onPress: onPress,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // Row 2: 7  8  9  ×
          _KeyRow(
            keys: const ['7', '8', '9', '×'],
            types: const ['num', 'num', 'num', 'op'],
            activeOp: activeOp,
            onPress: onPress,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // Row 3: 4  5  6  -
          _KeyRow(
            keys: const ['4', '5', '6', '-'],
            types: const ['num', 'num', 'num', 'op'],
            activeOp: activeOp,
            onPress: onPress,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // Row 4: 1  2  3  +
          _KeyRow(
            keys: const ['1', '2', '3', '+'],
            types: const ['num', 'num', 'num', 'op'],
            activeOp: activeOp,
            onPress: onPress,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // Row 5: 0 (double wide), ., ⌫, =
          _BottomKeyRow(
            activeOp: activeOp,
            onPress: onPress,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<String> keys;
  final List<String> types;
  final String activeOp;
  final void Function(String) onPress;
  final bool isDark;

  const _KeyRow({
    required this.keys,
    required this.types,
    required this.activeOp,
    required this.onPress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(keys.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
            child: _CalcKey(
              label: keys[i],
              type: types[i],
              isActiveOp: activeOp == keys[i],
              onPress: onPress,
              isDark: isDark,
            ),
          ),
        );
      }),
    );
  }
}

class _BottomKeyRow extends StatelessWidget {
  final String activeOp;
  final void Function(String) onPress;
  final bool isDark;

  const _BottomKeyRow({
    required this.activeOp,
    required this.onPress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 0 - double width
        Expanded(
          flex: 2,
          child: _CalcKey(
            label: '0',
            type: 'num',
            isActiveOp: false,
            onPress: onPress,
            isDark: isDark,
            alignLeft: true,
          ),
        ),
        const SizedBox(width: 8),
        // Decimal point
        Expanded(
          child: _CalcKey(
            label: '.',
            type: 'num',
            isActiveOp: false,
            onPress: onPress,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        // Backspace
        Expanded(
          child: _CalcKey(
            label: '⌫',
            type: 'fn',
            isActiveOp: false,
            onPress: onPress,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        // Equals
        Expanded(
          child: _CalcKey(
            label: '=',
            type: 'eq',
            isActiveOp: false,
            onPress: onPress,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _CalcKey extends StatelessWidget {
  final String label;
  final String type; // 'num', 'fn', 'op', 'eq'
  final bool isActiveOp;
  final void Function(String) onPress;
  final bool isDark;
  final bool alignLeft;

  const _CalcKey({
    required this.label,
    required this.type,
    required this.isActiveOp,
    required this.onPress,
    required this.isDark,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    const double height = 52;

    if (isActiveOp) {
      // Highlighted active operator
      bgColor = AppTheme.primaryBlue;
      textColor = Colors.white;
    } else {
      switch (type) {
        case 'fn':
          // Sophisticated slate for function keys
          bgColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
          textColor = isDark ? Colors.white : const Color(0xFF334155);
        case 'op':
          // Soft primary tint for operators
          bgColor = AppTheme.primaryBlue.withAlpha(isDark ? 45 : 20);
          textColor = AppTheme.primaryBlue;
        case 'eq':
          // Prominent primary for equals
          bgColor = AppTheme.primaryBlue;
          textColor = Colors.white;
        default: // 'num'
          bgColor = isDark ? AppTheme.darkCard : Colors.white;
          textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
      }
    }

    return SizedBox(
      height: height,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onPress(label),
          onLongPress: label == '⌫' ? () => onPress('AC') : null,
          borderRadius: BorderRadius.circular(14),
          splashColor: textColor.withAlpha(35),
          highlightColor: textColor.withAlpha(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActiveOp
                    ? AppTheme.primaryBlue
                    : (isDark ? AppTheme.darkBorder.withAlpha(70) : AppTheme.lightBorder),
                width: 1,
              ),
            ),
            child: Align(
              alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
              child: Padding(
                padding: alignLeft ? const EdgeInsets.only(left: 20) : EdgeInsets.zero,
                child: label == '⌫'
                    ? Icon(Icons.backspace_outlined, size: 19, color: textColor)
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: type == 'op' || type == 'eq' ? 22 : 19,
                          fontWeight: type == 'num'
                              ? FontWeight.w500
                              : (type == 'eq' || isActiveOp ? FontWeight.w700 : FontWeight.w600),
                          color: textColor,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
