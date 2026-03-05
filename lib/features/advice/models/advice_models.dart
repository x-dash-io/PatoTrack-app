// ── What-If Scenario ──────────────────────────────────────────────────────────

enum WhatIfType {
  hireStaff,
  priceChange,
  loanProceeds,
  majorClient,
}

extension WhatIfTypeExt on WhatIfType {
  String get label {
    switch (this) {
      case WhatIfType.hireStaff:
        return 'Hire Staff';
      case WhatIfType.priceChange:
        return 'Pricing Change';
      case WhatIfType.loanProceeds:
        return 'Take a Loan';
      case WhatIfType.majorClient:
        return 'Major Client';
    }
  }

  String get description {
    switch (this) {
      case WhatIfType.hireStaff:
        return 'Model the impact of adding a new employee';
      case WhatIfType.priceChange:
        return 'See what happens if you raise or cut prices';
      case WhatIfType.loanProceeds:
        return 'Model cash injection vs repayment burden';
      case WhatIfType.majorClient:
        return 'Simulate landing a large recurring client';
    }
  }

  String get paramLabel {
    switch (this) {
      case WhatIfType.hireStaff:
        return 'Monthly salary (KES)';
      case WhatIfType.priceChange:
        return 'Price change (%)';
      case WhatIfType.loanProceeds:
        return 'Loan amount (KES)';
      case WhatIfType.majorClient:
        return 'Monthly revenue (KES)';
    }
  }
}

class WhatIfResult {
  final WhatIfType type;

  /// The user-set parameter value (amount or %)
  final double paramValue;

  // ── 3-month projected deltas ──
  final double deltaIncome3m;   // change in income vs base
  final double deltaExpense3m;  // change in expense vs base
  double get deltaNet3m => deltaIncome3m - deltaExpense3m;

  // ── Runway impact ──
  final double baseRunway;      // days (before)
  final double newRunway;       // days (after)

  // ── Summary narrative ──
  final String summary;

  // ── Break-even note (for hireStaff + loanProceeds) ──
  final String? breakEvenNote;

  const WhatIfResult({
    required this.type,
    required this.paramValue,
    required this.deltaIncome3m,
    required this.deltaExpense3m,
    required this.baseRunway,
    required this.newRunway,
    required this.summary,
    this.breakEvenNote,
  });
}

// ── Advice Insight ─────────────────────────────────────────────────────────────

enum AdviceCategory { performance, risk, opportunity, complianceLite }

class AdviceInsight {
  final String title;
  final String body;
  final AdviceCategory category;
  final double score; // Impact × Probability × Urgency / Complexity

  const AdviceInsight({
    required this.title,
    required this.body,
    required this.category,
    required this.score,
  });
}

// ── Top-level summary ──────────────────────────────────────────────────────────

class AdviceSummary {
  final List<AdviceInsight> insights;

  /// Pre-computed what-if result for each type at a default parameter
  final Map<WhatIfType, WhatIfResult> defaultWhatIf;

  const AdviceSummary({
    required this.insights,
    required this.defaultWhatIf,
  });
}
