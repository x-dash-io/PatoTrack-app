bool isMpesaTransaction({
  required String description,
  String? categoryName,
}) {
  final normalizedDescription = description.toLowerCase().trim();
  final normalizedCategory = categoryName?.toLowerCase().trim() ?? '';

  if (normalizedDescription.contains('m-pesa') ||
      normalizedDescription.contains('mpesa')) {
    return true;
  }

  if (normalizedCategory.contains('m-pesa') ||
      normalizedCategory.contains('mpesa')) {
    return true;
  }

  final hasMpesaCode =
      RegExp(r'\([A-Z0-9]{10,}\)$').hasMatch(description.trim());
  final hasCommonMpesaVerb = normalizedDescription.startsWith('paid to ') ||
      normalizedDescription.startsWith('received from ') ||
      normalizedDescription.startsWith('sent to ') ||
      normalizedDescription.startsWith('bought airtime ') ||
      normalizedDescription.startsWith('paid bill to ');

  return hasMpesaCode && hasCommonMpesaVerb;
}
