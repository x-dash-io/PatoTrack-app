/// Tier 2: Keyword-based transaction categorization engine with user-learning.
///
/// Algorithm:
/// 1. Tokenize description (lowercase, strip punctuation)
/// 2. Match tokens against built-in keyword map + user corrections history
/// 3. Score each category: Σ(weight × frequency)
/// 4. Return top 3 [CategorySuggestion] sorted by score
/// 5. confidence < 0.7 → flagged for review

class CategorySuggestion {
  final String categoryName;
  final double confidence;

  const CategorySuggestion({
    required this.categoryName,
    required this.confidence,
  });
}

class CategorizationService {
  /// Built-in keyword seeds: keyword → (categoryName, weight)
  static const Map<String, Map<String, double>> _keywordMap = {
    // Income
    'sale': {'Sales': 2.0},
    'sales': {'Sales': 2.0},
    'revenue': {'Sales': 1.8},
    'invoice': {'Sales': 1.5},
    'payment received': {'Sales': 1.5},
    'received from': {'Sales': 1.0},
    'salary': {'Salary': 2.0},
    'wages': {'Salary': 2.0},
    'payroll': {'Salary': 2.0},
    'stipend': {'Salary': 1.5},
    'loan': {'Loans': 2.0},
    'credit': {'Loans': 1.5},
    'advance': {'Loans': 1.5},
    'overdraft': {'Loans': 1.5},
    'grant': {'Grants': 2.0},
    // Operating Expenses
    'rent': {'Rent': 2.0},
    'lease': {'Rent': 1.5},
    'premises': {'Rent': 1.0},
    'supplies': {'Supplies': 2.0},
    'stationery': {'Supplies': 1.5},
    'office supplies': {'Supplies': 2.0},
    'ads': {'Marketing': 2.0},
    'advertising': {'Marketing': 2.0},
    'marketing': {'Marketing': 2.0},
    'promotion': {'Marketing': 1.5},
    'facebook': {'Marketing': 1.5},
    'google ads': {'Marketing': 1.5},
    'uber': {'Travel': 2.0},
    'bolt': {'Travel': 2.0},
    'fuel': {'Travel': 2.0},
    'petrol': {'Travel': 2.0},
    'ticket': {'Travel': 1.5},
    'flight': {'Travel': 1.5},
    'transport': {'Travel': 1.0},
    'airtime': {'Airtime & Data': 2.0},
    'data': {'Airtime & Data': 1.5},
    'safaricom': {'Airtime & Data': 1.5},
    'airtel': {'Airtime & Data': 1.5},
    'telkom': {'Airtime & Data': 1.5},
    'internet': {'Communications': 2.0},
    'wifi': {'Communications': 2.0},
    'broadband': {'Communications': 1.5},
    // COGS
    'materials': {'Raw Materials': 2.0},
    'raw materials': {'Raw Materials': 2.0},
    'stock': {'Inventory': 2.0},
    'inventory': {'Inventory': 2.0},
    'purchase': {'Inventory': 1.0},
    // Compliance-lite
    'vat': {'Taxes & Compliance': 2.0},
    'tax': {'Taxes & Compliance': 2.0},
    'kra': {'Taxes & Compliance': 2.0},
    'insurance': {'Taxes & Compliance': 1.5},
    'license': {'Taxes & Compliance': 1.5},
    // Salary expense
    'paid to': {'Staff Salaries': 1.0},
    'bank transfer': {'Bank Charges': 1.0},
    'mpesa charges': {'Bank Charges': 2.0},
    'mpesa': {'Bank Charges': 0.5},
    'utility': {'Utilities': 1.5},
    'electricity': {'Utilities': 2.0},
    'water': {'Utilities': 1.5},
    'kenya power': {'Utilities': 2.0},
    'kplc': {'Utilities': 2.0},
    'nairobi water': {'Utilities': 2.0},
  };

  /// Suggest top-3 categories for the given [description].
  ///
  /// [corrections] is the user's history from `getUserCategoryCorrections()`.
  List<CategorySuggestion> suggest(
    String description, {
    List<Map<String, dynamic>> corrections = const [],
  }) {
    final tokens = _tokenize(description);
    if (tokens.isEmpty) return [];

    final scores = <String, double>{};

    // 1. Built-in keyword scoring
    for (final token in tokens) {
      for (final entry in _keywordMap.entries) {
        if (token.contains(entry.key) || entry.key.contains(token)) {
          for (final cat in entry.value.entries) {
            scores[cat.key] = (scores[cat.key] ?? 0) + cat.value;
          }
        }
      }
    }

    // 2. User correction boost (×3 weight = strong signal)
    for (final correction in corrections) {
      final corrDesc = (correction['description'] as String? ?? '').toLowerCase();
      final corrCat = correction['category_name'] as String? ?? '';
      final corrCatId = correction['category_id'];
      if (corrDesc.isNotEmpty && corrCat.isNotEmpty) {
        final corrTokens = _tokenize(corrDesc);
        int overlap = 0;
        for (final t in tokens) {
          if (corrTokens.contains(t)) overlap++;
        }
        if (overlap > 0) {
          final boost = 3.0 * overlap / tokens.length;
          scores[corrCat] = (scores[corrCat] ?? 0) + boost;
          // Store category_id as hint in a special key — callers look this up
          scores['__id__$corrCat'] = corrCatId.toDouble();
        }
      }
    }

    if (scores.isEmpty) return [];

    // Filter out __id__ meta-keys for sorting
    final categoryScores = scores.entries
        .where((e) => !e.key.startsWith('__id__'))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxScore = categoryScores.first.value;

    return categoryScores.take(3).map((e) {
      final normalized = (e.value / maxScore).clamp(0.0, 1.0);
      return CategorySuggestion(
        categoryName: e.key,
        confidence: normalized,
      );
    }).toList();
  }

  List<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();
  }
}
