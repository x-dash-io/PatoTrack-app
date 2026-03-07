import '../models/analytics_result.dart';

/// Generates ranked AI insights using:
///   Score = (Impact × Probability × Urgency) / Complexity
/// Returns top 5 sorted by score descending.
class InsightEngine {
  const InsightEngine();

  List<AnalyticsInsight> generate({
    required double totalIncome,
    required double totalExpenses,
    required double netIncome,
    required double burnRate,
    required double runway,
    required double grossMargin,
    required double incomeConcentration,
    required int anomalyCount,
    required int uncategorizedCount,
    required int totalTransactions,
    required int transactionsWithReceipt,
    required int totalExpenseTransactions,
    required List<ForecastPoint> forecastPoints,
  }) {
    final insights = <_RawInsight>[];

    // 1. Runway risk
    if (runway < 30) {
      insights.add(_RawInsight(
        title: 'Cash Runway Critical',
        detail:
            'At your current burn rate, you have approximately ${runway.toInt()} days of cash left. Prioritize revenue collection immediately.',
        impact: 10,
        probability: 9,
        urgency: 10,
        complexity: 2,
        priority: InsightPriority.critical,
      ));
    } else if (runway < 90) {
      insights.add(_RawInsight(
        title: 'Cash Runway Warning',
        detail:
            'You have ~${runway.toInt()} days of runway. Review expenses and accelerate invoicing.',
        impact: 8,
        probability: 7,
        urgency: 8,
        complexity: 2,
        priority: InsightPriority.warning,
      ));
    }

    // 2. Income concentration risk
    if (incomeConcentration > 0.70) {
      insights.add(_RawInsight(
        title: 'High Revenue Concentration',
        detail:
            '${(incomeConcentration * 100).toInt()}% of your income comes from one category. Diversify to reduce risk.',
        impact: 8,
        probability: 8,
        urgency: 6,
        complexity: 3,
        priority: InsightPriority.warning,
      ));
    }

    // 3. Over-spending
    if (totalIncome > 0 && totalExpenses > totalIncome) {
      final overspend = totalExpenses - totalIncome;
      insights.add(_RawInsight(
        title: 'Spending Exceeds Income',
        detail:
            'You are over-spending by ${_fmt(overspend)}. Review discretionary costs urgently.',
        impact: 9,
        probability: 10,
        urgency: 9,
        complexity: 3,
        priority: InsightPriority.critical,
      ));
    }

    // 4. Low gross margin
    if (grossMargin < 0.20 && totalIncome > 0) {
      insights.add(_RawInsight(
        title: 'Low Gross Margin',
        detail:
            'Your gross margin is ${(grossMargin * 100).toInt()}%. Industry healthy is 40%+. Review pricing or COGS.',
        impact: 7,
        probability: 8,
        urgency: 5,
        complexity: 4,
        priority: InsightPriority.warning,
      ));
    }

    // 5. Anomaly volume
    if (anomalyCount >= 3) {
      insights.add(_RawInsight(
        title: '$anomalyCount Unusual Transactions Detected',
        detail:
            'Multiple transactions fall outside normal spending patterns. Review the Anomalies section.',
        impact: 6,
        probability: 8,
        urgency: 7,
        complexity: 2,
        priority: InsightPriority.warning,
      ));
    }

    // 6. Poor categorization
    if (totalTransactions > 5 && uncategorizedCount > 0) {
      final pct = (uncategorizedCount / totalTransactions * 100).toInt();
      if (pct > 15) {
        insights.add(_RawInsight(
          title: '$pct% of Transactions Uncategorized',
          detail:
              'Uncategorized transactions reduce report accuracy and your Trust Score. Use the category suggestions.',
          impact: 5,
          probability: 9,
          urgency: 4,
          complexity: 2,
          priority: InsightPriority.info,
        ));
      }
    }

    // 7. Missing receipts
    if (totalExpenseTransactions > 5) {
      final receiptPct = transactionsWithReceipt / totalExpenseTransactions;
      if (receiptPct < 0.30) {
        insights.add(_RawInsight(
          title: 'Low Receipt Coverage',
          detail:
              'Only ${(receiptPct * 100).toInt()}% of expenses have receipts. Scan them for better compliance readiness.',
          impact: 5,
          probability: 9,
          urgency: 4,
          complexity: 2,
          priority: InsightPriority.info,
        ));
      }
    }

    // 8. Positive income trend
    if (forecastPoints.length == 3) {
      final trend = forecastPoints.last.income - forecastPoints.first.income;
      if (trend > 0 && totalIncome > 0) {
        insights.add(_RawInsight(
          title: 'Income Trend is Positive',
          detail:
              'Forecasted income is growing. Maintain current strategies and look for ways to accelerate.',
          impact: 6,
          probability: 7,
          urgency: 3,
          complexity: 2,
          priority: InsightPriority.opportunity,
        ));
      } else if (trend < 0) {
        insights.add(_RawInsight(
          title: 'Income Forecast is Declining',
          detail:
              'Projected income is declining over the next 3 months. Review revenue sources proactively.',
          impact: 8,
          probability: 6,
          urgency: 8,
          complexity: 3,
          priority: InsightPriority.warning,
        ));
      }
    }

    // 9. Burn rate vs velocity
    if (burnRate > 0 && totalExpenses > 0) {
      final cashVelocity = totalIncome / 30;
      if (burnRate > cashVelocity * 1.1) {
        insights.add(_RawInsight(
          title: 'Burn Rate Exceeds Income Velocity',
          detail:
              'Daily expenses outpace daily income. Close this gap by increasing invoicing speed or cutting costs.',
          impact: 8,
          probability: 9,
          urgency: 8,
          complexity: 3,
          priority: InsightPriority.warning,
        ));
      }
    }

    // Compute score and sort
    insights.sort((a, b) => b.score.compareTo(a.score));
    return insights
        .take(5)
        .map((r) => AnalyticsInsight(
              title: r.title,
              detail: r.detail,
              impactScore: r.score,
              priority: r.priority,
            ))
        .toList();
  }

  String _fmt(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }
}

class _RawInsight {
  final String title;
  final String detail;
  final double impact;
  final double probability;
  final double urgency;
  final double complexity;
  final InsightPriority priority;

  _RawInsight({
    required this.title,
    required this.detail,
    required this.impact,
    required this.probability,
    required this.urgency,
    required this.complexity,
    required this.priority,
  });

  // Score = (Impact × Probability × Urgency) / Complexity
  double get score => (impact * probability * urgency) / complexity;
}
