import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/capture/services/sms_parser_service.dart';
import 'database_helper.dart';

class SmsSyncCancelledException implements Exception {
  const SmsSyncCancelledException();

  @override
  String toString() => 'SMS sync cancelled by user';
}

class SmsService {
  final SmsQuery _query = SmsQuery();
  final DatabaseHelper dbHelper = DatabaseHelper();
  final SmsParserService parser = SmsParserService();

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
      count: 400,
    );

    final existingTransactions = await dbHelper.getTransactions(userId);
    final existingCodes = existingTransactions
        .map((transaction) => _getTransactionCodeFromDescription(transaction.description))
        .whereType<String>()
        .toSet();

    var importedCount = 0;
    for (final message in messages) {
      if (shouldCancel?.call() == true) {
        throw const SmsSyncCancelledException();
      }

      final body = message.body?.trim();
      final date = message.dateSent ?? message.date;
      if (body == null || body.isEmpty || date == null) {
        continue;
      }

      if (!_looksLikeMpesaMessage(message)) {
        continue;
      }

      final transaction = parser.parseMpesa(body, date);
      if (transaction == null) {
        continue;
      }

      final transactionCode =
          _getTransactionCodeFromDescription(transaction.description);
      if (transactionCode == null || existingCodes.contains(transactionCode)) {
        continue;
      }

      final mpesaCategoryId = await _getOrCreateMpesaCategory(
        userId,
        transaction.type,
      );
      final transactionToSave =
          transaction.copyWith(categoryId: mpesaCategoryId);

      await dbHelper.addTransaction(transactionToSave, userId);
      importedCount++;
      existingCodes.add(transactionCode);
    }

    return importedCount;
  }

  String? _getTransactionCodeFromDescription(String description) {
    final codeRegex = RegExp(r'\(([A-Z0-9]+)\)$');
    final match = codeRegex.firstMatch(description.trim());
    return match?.group(1);
  }

  bool _looksLikeMpesaMessage(SmsMessage message) {
    final sender = (message.address ?? '').trim().toUpperCase();
    final body = (message.body ?? '').trim().toUpperCase();

    if (sender.contains('MPESA') || sender.contains('M-PESA')) {
      return true;
    }

    return body.contains('M-PESA') || body.contains('MPESA');
  }

  Future<int> _getOrCreateMpesaCategory(String userId, String type) async {
    const categoryName = 'M-Pesa';
    return dbHelper.getOrCreateCategory(categoryName, userId, type: type);
  }
}
