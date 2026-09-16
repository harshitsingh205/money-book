import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

enum ReminderStyle {
  professional,
  friendly,
  urgent,
}

abstract class SmsGatewayProvider {
  Future<bool> sendSms({required String phoneNumber, required String message});
}

class SystemNativeSmsGateway implements SmsGatewayProvider {
  @override
  Future<bool> sendSms({required String phoneNumber, required String message}) async {
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: <String, String>{
          'body': message,
        },
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        final fallbackUri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('SMS Launcher Error: $e');
      return false;
    }
  }
}

class SmsService {
  static SmsGatewayProvider _gateway = SystemNativeSmsGateway();

  /// Set a custom SMS API gateway for future integration (e.g. Twilio / Fast2SMS)
  static void setSmsGateway(SmsGatewayProvider gateway) {
    _gateway = gateway;
  }

  /// Builds a formatted reminder message based on template style & currency symbol
  static String buildDueReminderMessage({
    required TransactionModel transaction,
    required String userName,
    String currencySymbol = '₹',
    ReminderStyle style = ReminderStyle.professional,
  }) {
    final dueDateStr = transaction.dueDate != null
        ? DateFormat('dd MMM yyyy').format(transaction.dueDate!)
        : 'soon';
    final formattedAmount = '$currencySymbol${transaction.amount.toStringAsFixed(2)}';
    final userLabel = userName.trim().isNotEmpty ? userName.trim() : 'Money Book User';

    switch (style) {
      case ReminderStyle.friendly:
        return 'Hi! Hope you are doing well.\n\nJust a friendly reminder from $userLabel regarding "${transaction.title}" for an amount of $formattedAmount due on $dueDateStr.\n\nPlease let me know once settled. Thank you!';

      case ReminderStyle.urgent:
        return 'URGENT PAYMENT REMINDER:\n\nThe payment of $formattedAmount for "${transaction.title}" is due on $dueDateStr.\n\nKindly clear this pending balance at your earliest convenience.\n\nFrom: $userLabel\n(Tracked via Money Book)';

      case ReminderStyle.professional:
        return 'Dear Sir/Madam,\n\nThis is a gentle payment reminder from $userLabel regarding "${transaction.title}".\n\n• Amount Due: $formattedAmount\n• Due Date: $dueDateStr\n\nPlease arrange for the settlement at your earliest convenience.\n\nThank you,\n$userLabel\n(Tracked via Money Book)';
    }
  }

  /// Sends or opens SMS reminder for an upcoming due payment
  static Future<bool> sendDueReminderSms({
    required TransactionModel transaction,
    required String userName,
    String currencySymbol = '₹',
    String? customMessage,
    ReminderStyle style = ReminderStyle.professional,
  }) async {
    if (transaction.phoneNumber == null || transaction.phoneNumber!.trim().isEmpty) {
      return false;
    }

    final message = customMessage ??
        buildDueReminderMessage(
          transaction: transaction,
          userName: userName,
          currencySymbol: currencySymbol,
          style: style,
        );

    return await _gateway.sendSms(
      phoneNumber: transaction.phoneNumber!,
      message: message,
    );
  }

  /// Send reminder message directly via WhatsApp
  static Future<bool> sendDueReminderWhatsApp({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      var cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanPhone.isEmpty) return false;
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      }

      final whatsappUrl = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return true;
      } else {
        return await launchUrl(whatsappUrl, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      debugPrint('WhatsApp Launcher Error: $e');
      return false;
    }
  }

  /// Universal share option (Share sheet, Email, Telegram, WhatsApp, copy)
  static Future<void> shareDueReminder({
    required String message,
    String subject = 'Payment Reminder - Money Book',
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: subject,
        ),
      );
    } catch (e) {
      debugPrint('Share Error: $e');
    }
  }
}
