import '../../../models/transaction.dart' as model;

class SmsParserService {
  /// Parses an M-Pesa SMS body into a partial Transaction model.
  /// Returns null if the message is not a valid M-Pesa confirmation.
  model.Transaction? parseMpesa(String body, DateTime date) {
    final transactionCode = _getTransactionCode(body);
    if (transactionCode == null) return null;

    double? amount;
    String description = '';
    String type = 'expense';
    double? balanceAfter;

    final amountRegex = RegExp(r"Ksh([\d,]+\.\d{2})");
    final amountMatch = amountRegex.firstMatch(body);
    if (amountMatch != null) {
      amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));
    } else {
      return null;
    }

    // Extract balance if available
    final balanceRegex = RegExp(r"New M-PESA balance is Ksh([\d,]+\.\d{2})");
    final balanceMatch = balanceRegex.firstMatch(body);
    if (balanceMatch != null) {
      balanceAfter = double.parse(balanceMatch.group(1)!.replaceAll(',', ''));
    }

    final paidToRegex = RegExp(r"paid to (.+?)\.");
    final receivedFromRegex = RegExp(r"received Ksh[\d,]+\.\d{2} from (.+?) on");
    final sentToRegex = RegExp(r"sent to (.+?) on");
    final boughtAirtimeRegex = RegExp(r"You bought Ksh[\d,]+\.\d{2} of airtime for number (\d+)");
    final payBillRegex = RegExp(r"sent to (.+?) for account");

    if (payBillRegex.hasMatch(body)) {
      final recipient = payBillRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Paid bill to $recipient';
      type = 'expense';
    } else if (paidToRegex.hasMatch(body)) {
      final recipient = paidToRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Paid to $recipient';
      type = 'expense';
    } else if (receivedFromRegex.hasMatch(body)) {
      final sender = receivedFromRegex.firstMatch(body)!.group(1)!.trim().split(' ').first;
      description = 'Received from $sender';
      type = 'income';
    } else if (sentToRegex.hasMatch(body)) {
      final recipient = sentToRegex.firstMatch(body)!.group(1)!.trim().split(' ').first;
      description = 'Sent to $recipient';
      type = 'expense';
    } else if (boughtAirtimeRegex.hasMatch(body)) {
      final number = boughtAirtimeRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Bought airtime for $number';
      type = 'expense';
    } else {
      description = 'M-Pesa Transaction';
    }

    description += ' ($transactionCode)';

    return model.Transaction(
      type: type,
      amount: amount,
      description: description,
      date: date.toIso8601String(),
      source: 'sms',
      confidence: 1.0, // M-Pesa SMS is high confidence if it matches the code pattern
      isReviewed: true, // Auto-approve clear M-Pesa patterns
      balanceAfter: balanceAfter,
    );
  }

  String? _getTransactionCode(String body) {
    final codeRegex = RegExp(r'^([A-Z0-9]+)\sConfirmed\.');
    final match = codeRegex.firstMatch(body);
    return match?.group(1);
  }
}
