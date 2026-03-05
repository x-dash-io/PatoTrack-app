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
    'client': {'Sales': 1.0},
    'customer': {'Sales': 1.0},
    'fee': {'Sales': 1.5},
    'deposit': {'Sales': 1.2},
    'salary': {'Salary': 2.0},
    'wages': {'Salary': 2.0},
    'payroll': {'Salary': 2.0},
    'stipend': {'Salary': 1.5},
    'bonus': {'Salary': 1.5},
    'loan': {'Loans': 2.0},
    'credit': {'Loans': 1.5},
    'advance': {'Loans': 1.5},
    'overdraft': {'Loans': 1.5},
    'grant': {'Grants': 2.0},
    'funding': {'Grants': 2.0},
    'investment': {'Investment': 2.0},
    'dividend': {'Investment': 2.0},
    'interest': {'Investment': 2.0},

    // Expenses - Facilities & Utilities
    'rent': {'Rent': 2.0},
    'lease': {'Rent': 1.5},
    'premises': {'Rent': 1.0},
    'utility': {'Utilities': 1.5},
    'electricity': {'Utilities': 2.0},
    'water': {'Utilities': 1.5},
    'kenya power': {'Utilities': 2.0},
    'kplc': {'Utilities': 2.0},
    'nairobi water': {'Utilities': 2.0},
    'garbage': {'Utilities': 2.0},
    'token': {'Utilities': 1.5},
    'stima': {'Utilities': 2.0},

    // Expenses - Operations
    'supplies': {'Supplies': 2.0},
    'stationery': {'Supplies': 1.5},
    'office supplies': {'Supplies': 2.0},
    'paper': {'Supplies': 1.0},
    'ink': {'Supplies': 1.0},
    'printing': {'Supplies': 1.5},
    'materials': {'Raw Materials': 2.0},
    'raw materials': {'Raw Materials': 2.0},
    'stock': {'Inventory': 2.0},
    'inventory': {'Inventory': 2.0},
    'purchase': {'Inventory': 1.0},
    'goods': {'Inventory': 1.5},
    'wholesale': {'Inventory': 1.5},
    'equipment': {'Equipment': 2.0},
    'tools': {'Equipment': 2.0},
    'machinery': {'Equipment': 2.0},
    'hardware': {'Equipment': 1.5},
    'laptop': {'Equipment': 2.0},
    'computer': {'Equipment': 2.0},

    // Expenses - Marketing & Sales
    'ads': {'Marketing': 2.0},
    'advertising': {'Marketing': 2.0},
    'marketing': {'Marketing': 2.0},
    'promotion': {'Marketing': 1.5},
    'facebook': {'Marketing': 1.5},
    'google ads': {'Marketing': 1.5},
    'seo': {'Marketing': 2.0},
    'campaign': {'Marketing': 1.5},
    'social media': {'Marketing': 2.0},
    'sponsor': {'Marketing': 1.5},
    
    // Expenses - Transport & Travel
    'uber': {'Travel': 2.0},
    'bolt': {'Travel': 2.0},
    'little cab': {'Travel': 2.0},
    'fuel': {'Travel': 2.0},
    'petrol': {'Travel': 2.0},
    'diesel': {'Travel': 2.0},
    'gas': {'Travel': 1.5},
    'shell': {'Travel': 1.5},
    'total energies': {'Travel': 1.5},
    'rubis': {'Travel': 1.5},
    'ticket': {'Travel': 1.5},
    'flight': {'Travel': 1.5},
    'transport': {'Travel': 1.0},
    'matatu': {'Travel': 2.0},
    'bus': {'Travel': 1.5},
    'taxi': {'Travel': 2.0},
    'parking': {'Travel': 2.0},
    'toll': {'Travel': 2.0},
    
    // Expenses - Communications & Tech
    'airtime': {'Airtime & Data': 2.0},
    'data': {'Airtime & Data': 1.5},
    'safaricom': {'Airtime & Data': 1.5},
    'airtel': {'Airtime & Data': 1.5},
    'telkom': {'Airtime & Data': 1.5},
    'bundles': {'Airtime & Data': 2.0},
    'internet': {'Communications': 2.0},
    'wifi': {'Communications': 2.0},
    'broadband': {'Communications': 1.5},
    'zuku': {'Communications': 2.0},
    'jtl': {'Communications': 2.0},
    'software': {'Software': 2.0},
    'subscription': {'Software': 1.5},
    'app': {'Software': 1.0},
    'hosting': {'Software': 2.0},
    'domain': {'Software': 2.0},
    'aws': {'Software': 2.0},
    'github': {'Software': 2.0},

    // Expenses - Compliance & Admin
    'vat': {'Taxes & Compliance': 2.0},
    'tax': {'Taxes & Compliance': 2.0},
    'kra': {'Taxes & Compliance': 2.0},
    'paye': {'Taxes & Compliance': 2.0},
    'nhif': {'Taxes & Compliance': 2.0},
    'nssf': {'Taxes & Compliance': 2.0},
    'insurance': {'Taxes & Compliance': 1.5},
    'license': {'Taxes & Compliance': 1.5},
    'permit': {'Taxes & Compliance': 2.0},
    'county': {'Taxes & Compliance': 1.5},
    'kanjo': {'Taxes & Compliance': 2.0},
    
    // Expenses - HR & Professional
    'paid to': {'Staff Salaries': 1.0},
    'wage': {'Staff Salaries': 2.0},
    'casual': {'Staff Salaries': 1.5},
    'allowance': {'Staff Salaries': 1.5},
    'per diem': {'Staff Salaries': 1.5},
    'consulting': {'Professional Fees': 2.0},
    'legal': {'Professional Fees': 2.0},
    'lawyer': {'Professional Fees': 2.0},
    'audit': {'Professional Fees': 2.0},
    'accountant': {'Professional Fees': 2.0},
    
    // Expenses - Financial
    'bank transfer': {'Bank Charges': 1.0},
    'mpesa charges': {'Bank Charges': 2.0},
    'mpesa': {'Bank Charges': 0.5},
    'withdrawal': {'Bank Charges': 1.5},
    'paybill charge': {'Bank Charges': 2.0},
    'till number': {'Bank Charges': 1.0},
    'late fee': {'Interest Payments': 1.8},
    'loan repayment': {'Loan Repayment': 2.0},
    
    // Expenses - Miscellaneous
    'food': {'Food & Dining': 2.0},
    'lunch': {'Food & Dining': 2.0},
    'dinner': {'Food & Dining': 2.0},
    'restaurant': {'Food & Dining': 2.0},
    'coffee': {'Food & Dining': 2.0},
    'tea': {'Food & Dining': 1.5},
    'snacks': {'Food & Dining': 2.0},
    'water': {'Food & Dining': 1.0},
    'meal': {'Food & Dining': 2.0},
    'entertainment': {'Entertainment': 2.0},
    'event': {'Entertainment': 1.5},
    'party': {'Entertainment': 1.5},
    'repair': {'Repairs & Maintenance': 2.0},
    'maintenance': {'Repairs & Maintenance': 2.0},
    'fixing': {'Repairs & Maintenance': 1.5},
    'service': {'Repairs & Maintenance': 1.0},
    'delivery': {'Logistics': 2.0},
    'shipping': {'Logistics': 2.0},
    'courier': {'Logistics': 2.0},
    'freight': {'Logistics': 2.0},
    'postage': {'Logistics': 2.0},
    'g4s': {'Logistics': 2.0},
    'fargo': {'Logistics': 2.0},
    'sendy': {'Logistics': 2.0},
    'glovo': {'Logistics': 2.0},
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
