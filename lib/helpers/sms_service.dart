import 'dart:developer' as developer;

import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import '../models/transaction.dart' as model;

class SmsSyncCancelledException implements Exception {
  const SmsSyncCancelledException();

  @override
  String toString() => 'SMS sync cancelled by user';
}

class SmsService {
  final SmsQuery _query = SmsQuery();
  final dbHelper = DatabaseHelper();

  Future<int> syncMpesaMessages(
    String userId, {
    bool Function()? shouldCancel,
  }) async {
    final permission = await Permission.sms.status;
    if (!permission.isGranted) {
      return 0;
    }

    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      address: 'MPESA',
      count: 50, // Fetches the 50 most recent messages
    );

    final existingTransactions = await dbHelper.getTransactions(userId);
    final existingCodes = existingTransactions
        .map((t) => _getTransactionCodeFromDescription(t.description))
        .whereType<String>()
        .toSet();

    var importedCount = 0;
    for (final message in messages) {
      if (shouldCancel?.call() == true) {
        throw const SmsSyncCancelledException();
      }
      if (message.body == null || message.date == null) {
        continue;
      }

      final transactionCode = _getTransactionCode(message.body!);
      if (transactionCode == null || existingCodes.contains(transactionCode)) {
        continue;
      }

      final created = await _parseAndSave(message, transactionCode, userId);
      if (created) {
        importedCount++;
        existingCodes.add(transactionCode);
      }
    }

    return importedCount;
  }

  String? _getTransactionCode(String body) {
    final codeRegex = RegExp(r'^([A-Z0-9]+)\sConfirmed\.');
    final match = codeRegex.firstMatch(body);
    return match?.group(1);
  }

  String? _getTransactionCodeFromDescription(String description) {
    final codeRegex = RegExp(r'\(([A-Z0-9]+)\)');
    final match = codeRegex.firstMatch(description);
    return match?.group(1);
  }

  Future<bool> _parseAndSave(
    SmsMessage message,
    String transactionCode,
    String userId,
  ) async {
    final String body = message.body!;
    String description = '';
    double? amount;
    String transactionType = 'expense';

    final amountRegex = RegExp(r"Ksh([\d,]+\.\d{2})");
    final match = amountRegex.firstMatch(body);
    if (match != null) {
      amount = double.parse(match.group(1)!.replaceAll(',', ''));
    } else {
      return false;
    }

    final paidToRegex = RegExp(r"paid to (.+?)\.");
    final receivedFromRegex =
        RegExp(r"received Ksh[\d,]+\.\d{2} from (.+?) on");
    final sentToRegex = RegExp(r"sent to (.+?) on");
    final boughtAirtimeRegex =
        RegExp(r"You bought Ksh[\d,]+\.\d{2} of airtime for number (\d+)");
    final payBillRegex = RegExp(r"sent to (.+?) for account");

    if (payBillRegex.hasMatch(body)) {
      final recipient = payBillRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Paid bill to $recipient';
      transactionType = 'expense';
    } else if (paidToRegex.hasMatch(body)) {
      final recipient = paidToRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Paid to $recipient';
      transactionType = 'expense';
    } else if (receivedFromRegex.hasMatch(body)) {
      final sender =
          receivedFromRegex.firstMatch(body)!.group(1)!.trim().split(' ').first;
      description = 'Received from $sender';
      transactionType = 'income';
    } else if (sentToRegex.hasMatch(body)) {
      final recipient =
          sentToRegex.firstMatch(body)!.group(1)!.trim().split(' ').first;
      description = 'Sent to $recipient';
      transactionType = 'expense';
    } else if (boughtAirtimeRegex.hasMatch(body)) {
      final number = boughtAirtimeRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Bought airtime for $number';
      transactionType = 'expense';
    } else {
      description = 'M-Pesa Transaction';
    }

    description += ' ($transactionCode)';

    final newTransaction = model.Transaction(
      type: transactionType,
      amount: amount,
      description: description,
      date: (message.date ?? DateTime.now()).toIso8601String(),
      categoryId: await _getOrCreateMpesaCategory(userId),
    );

    await dbHelper.addTransaction(newTransaction, userId);
    developer.log('MPESA transaction ($transactionCode) automatically synced!');
    return true;
  }

  Future<int> _getOrCreateMpesaCategory(String userId) async {
    const categoryName = 'M-Pesa';
    return dbHelper.getOrCreateCategory(categoryName, userId, type: 'expense');
  }
}
