import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import '../features/capture/services/sms_parser_service.dart';

class SmsSyncCancelledException implements Exception {
  const SmsSyncCancelledException();

  @override
  String toString() => 'SMS sync cancelled by user';
}

class SmsService {
  final SmsQuery _query = SmsQuery();
  final dbHelper = DatabaseHelper();
  final parser = SmsParserService();

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
      count: 100, // Fetches more messages to catch missed ones
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

      final transaction = parser.parseMpesa(message.body!, message.date!);
      if (transaction == null) continue;

      final transactionCode = _getTransactionCodeFromDescription(transaction.description);
      if (transactionCode == null || existingCodes.contains(transactionCode)) {
        continue;
      }

      final mpesaCategoryId = await _getOrCreateMpesaCategory(userId);
      final transactionToSave = transaction.copyWith(categoryId: mpesaCategoryId);

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

  Future<int> _getOrCreateMpesaCategory(String userId) async {
    const categoryName = 'M-Pesa';
    return dbHelper.getOrCreateCategory(categoryName, userId, type: 'expense');
  }
}
