import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/cash_out_screen.dart';

class FloatingCalculator extends StatefulWidget {
  const FloatingCalculator({super.key});

  @override
  State<FloatingCalculator> createState() => _FloatingCalculatorState();
}

class _FloatingCalculatorState extends State<FloatingCalculator> {
  void _openCalculatorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CalculatorModalDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'floating_calculator_btn',
      onPressed: () => _openCalculatorDialog(context),
      backgroundColor: AppTheme.primaryBlue,
      elevation: 4,
      tooltip: 'Quick Calculator',
      child: const Icon(
        Icons.calculate_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

class CalculatorModalDialog extends StatefulWidget {
  const CalculatorModalDialog({super.key});

  @override
  State<CalculatorModalDialog> createState() => _CalculatorModalDialogState();
}

class _CalculatorModalDialogState extends State<CalculatorModalDialog> {
  String _display = '0';
  String _expression = '';
  double _num1 = 0;
  double _num2 = 0;
  String _operand = '';
  bool _isNewNumber = true;

  void _onBtnPress(String text) {
    setState(() {
      if (text == 'C') {
        _display = '0';
        _expression = '';
        _num1 = 0;
        _num2 = 0;
        _operand = '';
        _isNewNumber = true;
      } else if (text == '⌫') {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
          _isNewNumber = true;
        }
      } else if (text == '+' || text == '-' || text == '×' || text == '÷') {
        _num1 = double.tryParse(_display) ?? 0;
        _operand = text;
        _expression = '$_display $text';
        _isNewNumber = true;
      } else if (text == '=') {
        _evaluatePending();
      } else if (text == '.') {
        if (!_display.contains('.')) {
          _display += '.';
          _isNewNumber = false;
        }
      } else {
        // Digits
        if (_display == '0' || _isNewNumber) {
          _display = text;
          _isNewNumber = false;
        } else {
          _display += text;
        }
      }
    });
  }

  double _evaluatePending() {
    if (_operand.isNotEmpty) {
      _num2 = double.tryParse(_display) ?? 0;
      double result = 0;
      switch (_operand) {
        case '+':
          result = _num1 + _num2;
          break;
        case '-':
          result = _num1 - _num2;
          break;
        case '×':
          result = _num1 * _num2;
          break;
        case '÷':
          result = _num2 != 0 ? _num1 / _num2 : 0;
          break;
      }
      _expression = '$_num1 $_operand $_num2 =';
      _display = result % 1 == 0 ? result.toInt().toString() : result.toStringAsFixed(2);
      _operand = '';
      _isNewNumber = true;
      return result;
    }
    return double.tryParse(_display) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate_rounded, color: AppTheme.primaryBlue, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Calculator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Calculator Display Screen
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _display,
                        key: const Key('calc_display_text'),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Keypad Grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.25,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                _calcBtn('C', color: Colors.orange),
                _calcBtn('⌫', color: Colors.orange),
                _calcBtn('÷', color: AppTheme.primaryBlue),
                _calcBtn('×', color: AppTheme.primaryBlue),

                _calcBtn('7'),
                _calcBtn('8'),
                _calcBtn('9'),
                _calcBtn('-', color: AppTheme.primaryBlue),

                _calcBtn('4'),
                _calcBtn('5'),
                _calcBtn('6'),
                _calcBtn('+', color: AppTheme.primaryBlue),

                _calcBtn('1'),
                _calcBtn('2'),
                _calcBtn('3'),
                _calcBtn('=', color: AppTheme.primaryBlue, isPrimary: true),

                _calcBtn('0', isDoubleWidth: false),
                _calcBtn('.'),
              ],
            ),
            const SizedBox(height: 16),

            // Action Button: Use Amount in Cash Out
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final amount = _evaluatePending();
                  if (amount > 0) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CashOutScreen(initialAmount: amount),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter or calculate an amount greater than 0.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: const Text('Add as Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cashOutRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _calcBtn(String text, {Color? color, bool isPrimary = false, bool isDoubleWidth = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isPrimary
          ? AppTheme.primaryBlue
          : (color != null
              ? color.withAlpha(isDark ? 50 : 25)
              : (isDark ? AppTheme.darkBg : AppTheme.lightBg)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _onBtnPress(text),
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPrimary
                  ? Colors.white
                  : (color ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}
