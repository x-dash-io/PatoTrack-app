import '../models/advice_models.dart';

/// Generates structured financial advice insights in 4 categories.
/// Score = (Impact × Probability × Urgency) / Complexity
class AdviceService {
  const AdviceService();

  List<AdviceInsight> generate({
    required double monthlyIncome,
    required double monthlyExpense,
    required double grossMargin,
    required double operatingMargin,
    required double burnRate,
    required double runway,
    required double incomeConcentration,
    required int anomalyCount,
    required double receiptCoverage,
    required double categorizationRate,
    required bool incomeGrowing, // from Holt's last trend polarity
    required bool expenseGrowing,
  }) {
    final raw = <_Raw>[];

    // ── Performance ────────────────────────────────────────────────────────
    if (grossMargin < 0.30 && monthlyIncome > 0) {
      raw.add(_Raw(
        title: 'Gross Margin Below 30%',
        body:
            'Your gross margin is ${(grossMargin * 100).toStringAsFixed(1)}%. '
            'Review COGS: renegotiate supplier terms, reduce waste, or consider '
            'a price increase to push toward the 40%+ target.',
        category: AdviceCategory.performance,
        impact: 8,
        probability: 9,
        urgency: 6,
        complexity: 4,
      ));
    }
    if (operatingMargin > 0.20 && monthlyIncome > 0) {
      raw.add(_Raw(
        title: 'Strong Operating Margin — Reinvest Now',
        body:
            'Your operating margin is ${(operatingMargin * 100).toStringAsFixed(1)}%. '
            'This is a good time to reinvest in marketing, equipment, or inventory.',
        category: AdviceCategory.performance,
        impact: 7,
        probability: 8,
        urgency: 4,
        complexity: 2,
      ));
    }
    if (expenseGrowing && !incomeGrowing) {
      raw.add(const _Raw(
        title: 'Costs Rising Faster Than Revenue',
        body: 'Expenses are trending upward while income stagnates. Audit '
            'recurring costs, pause non-essential spend, and accelerate invoicing.',
        category: AdviceCategory.performance,
        impact: 9,
        probability: 7,
        urgency: 8,
        complexity: 3,
      ));
    }

    // ── Risk ───────────────────────────────────────────────────────────────
    if (runway < 60 && monthlyExpense > 0) {
      raw.add(_Raw(
        title: 'Cash Runway Under 60 Days',
        body: 'At your current burn rate you have ${runway.toInt()} days of '
            'runway. Consider a bridge loan, accelerating receivables, or '
            'deferring non-critical spend.',
        category: AdviceCategory.risk,
        impact: 10,
        probability: 9,
        urgency: 10,
        complexity: 2,
      ));
    }
    if (incomeConcentration > 0.65) {
      raw.add(_Raw(
        title: 'Revenue Concentration Risk',
        body:
            '${(incomeConcentration * 100).toInt()}% of income flows from one '
            'source. Diversify — add at least two new revenue streams in the next 90 days.',
        category: AdviceCategory.risk,
        impact: 8,
        probability: 8,
        urgency: 6,
        complexity: 3,
      ));
    }
    if (anomalyCount > 2) {
      raw.add(_Raw(
        title: '$anomalyCount Irregular Transactions Flagged',
        body: 'Multiple transactions fall outside your normal patterns. Review '
            'each in the Anomalies section — potential fraud or data-entry errors.',
        category: AdviceCategory.risk,
        impact: 7,
        probability: 8,
        urgency: 8,
        complexity: 2,
      ));
    }

    // ── Opportunity ────────────────────────────────────────────────────────
    if (incomeGrowing && grossMargin >= 0.30) {
      raw.add(const _Raw(
        title: 'Growth Momentum — Scale Marketing',
        body: 'Income is trending up and your margin supports it. Now is a '
            'good time to invest in customer acquisition and retention.',
        category: AdviceCategory.opportunity,
        impact: 7,
        probability: 7,
        urgency: 5,
        complexity: 3,
      ));
    }
    if (burnRate > 0 &&
        monthlyIncome > 0 &&
        monthlyIncome / burnRate / 30 > 2) {
      raw.add(const _Raw(
        title: 'Income-to-Burn Ratio Is Healthy',
        body: 'Your income covers expenses more than 2×. You have room to '
            'invest in growth, build a 3-month cash reserve, or explore equipment financing.',
        category: AdviceCategory.opportunity,
        impact: 6,
        probability: 8,
        urgency: 3,
        complexity: 2,
      ));
    }

    // ── Compliance-lite ────────────────────────────────────────────────────
    if (receiptCoverage < 0.50) {
      raw.add(_Raw(
        title: 'Low Receipt Coverage (${(receiptCoverage * 100).toInt()}%)',
        body: 'Fewer than half your expenses have receipts. Scan and attach '
            'them — this protects you in an audit and improves your Trust Score.',
        category: AdviceCategory.complianceLite,
        impact: 5,
        probability: 9,
        urgency: 4,
        complexity: 1,
      ));
    }
    if (categorizationRate < 0.80) {
      raw.add(_Raw(
        title: 'Improve Transaction Categorization',
        body:
            '${((1 - categorizationRate) * 100).toInt()}% of transactions are '
            'uncategorized, reducing report accuracy. Use category suggestions '
            'when adding transactions.',
        category: AdviceCategory.complianceLite,
        impact: 4,
        probability: 9,
        urgency: 3,
        complexity: 1,
      ));
    }

    // Sort by score then return top 6
    raw.sort((a, b) => b.score.compareTo(a.score));
    return raw
        .take(6)
        .map((r) => AdviceInsight(
              title: r.title,
              body: r.body,
              category: r.category,
              score: r.score,
            ))
        .toList();
  }
}

class _Raw {
  final String title;
  final String body;
  final AdviceCategory category;
  final double impact;
  final double probability;
  final double urgency;
  final double complexity;

  const _Raw({
    required this.title,
    required this.body,
    required this.category,
    required this.impact,
    required this.probability,
    required this.urgency,
    required this.complexity,
  });

  double get score => (impact * probability * urgency) / complexity;
}
