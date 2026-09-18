import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/sms_service.dart';
import '../theme/app_theme.dart';

class ReminderBottomSheet extends StatefulWidget {
  final TransactionModel transaction;
  final String userName;
  final String currencySymbol;

  const ReminderBottomSheet({
    super.key,
    required this.transaction,
    required this.userName,
    required this.currencySymbol,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionModel transaction,
    required String userName,
    required String currencySymbol,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderBottomSheet(
        transaction: transaction,
        userName: userName,
        currencySymbol: currencySymbol,
      ),
    );
  }

  @override
  State<ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<ReminderBottomSheet> {
  ReminderStyle _selectedStyle = ReminderStyle.professional;
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: SmsService.buildDueReminderMessage(
        transaction: widget.transaction,
        userName: widget.userName,
        currencySymbol: widget.currencySymbol,
        style: _selectedStyle,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _onStyleChanged(ReminderStyle newStyle) {
    setState(() {
      _selectedStyle = newStyle;
      _messageController.text = SmsService.buildDueReminderMessage(
        transaction: widget.transaction,
        userName: widget.userName,
        currencySymbol: widget.currencySymbol,
        style: newStyle,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedAmount = '${widget.currencySymbol}${widget.transaction.amount.toStringAsFixed(2)}';
    final dueDateStr = widget.transaction.dueDate != null
        ? DateFormat('MMM dd, yyyy').format(widget.transaction.dueDate!)
        : 'N/A';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Reminder',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.transaction.title} · $formattedAmount',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recipient Details Card
              Container(
                padding: const EdgeInsets.all(12),
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
                        const Icon(Icons.person_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          widget.transaction.phoneNumber ?? 'No Phone Number',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Due: $dueDateStr',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Template Style Selector
              const Text(
                'Reminder Style:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Professional'),
                      selected: _selectedStyle == ReminderStyle.professional,
                      selectedColor: AppTheme.primaryBlue.withAlpha(40),
                      onSelected: (_) => _onStyleChanged(ReminderStyle.professional),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Friendly'),
                      selected: _selectedStyle == ReminderStyle.friendly,
                      selectedColor: AppTheme.cashInGreen.withAlpha(40),
                      onSelected: (_) => _onStyleChanged(ReminderStyle.friendly),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Urgent'),
                      selected: _selectedStyle == ReminderStyle.urgent,
                      selectedColor: AppTheme.cashOutRed.withAlpha(40),
                      onSelected: (_) => _onStyleChanged(ReminderStyle.urgent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Message Preview Box
              const Text(
                'Message Preview (Editable):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons Row
              Row(
                children: [
                  // Send SMS Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final sent = await SmsService.sendDueReminderSms(
                          transaction: widget.transaction,
                          userName: widget.userName,
                          currencySymbol: widget.currencySymbol,
                          customMessage: _messageController.text.trim(),
                        );
                        nav.pop();
                        if (!sent) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Could not launch SMS app on this device.'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.sms_rounded, size: 18),
                      label: const Text('SMS'),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // WhatsApp Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        if (widget.transaction.phoneNumber == null ||
                            widget.transaction.phoneNumber!.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('No phone number attached.')),
                          );
                          return;
                        }
                        final sent = await SmsService.sendDueReminderWhatsApp(
                          phoneNumber: widget.transaction.phoneNumber!,
                          message: _messageController.text.trim(),
                        );
                        nav.pop();
                        if (!sent) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Could not open WhatsApp on this device.'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Universal Share / Copy Button
                  IconButton.filledTonal(
                    onPressed: () async {
                      Navigator.pop(context);
                      await SmsService.shareDueReminder(
                        message: _messageController.text.trim(),
                        subject: 'Payment Reminder - ${widget.transaction.title}',
                      );
                    },
                    tooltip: 'Share via other apps',
                    icon: const Icon(Icons.share_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
