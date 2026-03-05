// Transaction model represents a financial transaction, including type, amount, and category.

class Transaction {
  final int? id;
  final String type;
  final double amount;
  final String description;
  final String date;
  final int? categoryId;
  final String tag;
  final String source; // manual | receipt | sms | api
  final double confidence;
  final bool isReviewed;
  final double? balanceAfter;
  final String? receiptImageUrl;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.categoryId,
    this.tag = 'business',
    this.source = 'manual',
    this.confidence = 1.0,
    this.isReviewed = true,
    this.balanceAfter,
    this.receiptImageUrl,
  });

  Transaction copyWith({
    int? id,
    String? type,
    double? amount,
    String? description,
    String? date,
    int? categoryId,
    String? tag,
    String? source,
    double? confidence,
    bool? isReviewed,
    double? balanceAfter,
    String? receiptImageUrl,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      tag: tag ?? this.tag,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      isReviewed: isReviewed ?? this.isReviewed,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'date': date,
      'category_id': categoryId,
      'tag': tag,
      'source': source,
      'confidence': confidence,
      'is_reviewed': isReviewed ? 1 : 0,
      'balance_after': balanceAfter,
      'receipt_image_url': receiptImageUrl,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      description: map['description'],
      date: map['date'],
      categoryId: map['category_id'],
      tag: map['tag'] ?? 'business',
      source: map['source'] ?? 'manual',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      isReviewed: (map['is_reviewed'] ?? 1) == 1,
      balanceAfter: (map['balance_after'] as num?)?.toDouble(),
      receiptImageUrl: map['receipt_image_url'] as String?,
    );
  }
}
