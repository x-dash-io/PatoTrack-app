import '../../../models/transaction.dart' as model;

// ── Forecast ───────────────────────────────────────────────────────────────────

class ForecastPoint {
  final DateTime month;
  final double income;
  final double expense;
  double get net => income - expense;
  const ForecastPoint({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class ForecastResult {
  /// Historical monthly aggregates (actuals)
  final List<ForecastPoint> history;

  /// 3 projected months ahead
  final List<ForecastPoint> forecast;

  /// 90% confidence ± band (absolute amount)
  final double confidenceBand;

  const ForecastResult({
    required this.history,
    required this.forecast,
    required this.confidenceBand,
  });

  bool get hasEnoughData => history.length >= 2;
}

// ── Anomaly ────────────────────────────────────────────────────────────────────

enum AnomalyReason { highAmount, lowAmount, dailySpike, unusualTime }

class AnomalyFlag {
  final model.Transaction transaction;
  final double zScore;
  final AnomalyReason reason;
  const AnomalyFlag({
    required this.transaction,
    required this.zScore,
    required this.reason,
  });

  String get reasonLabel {
    switch (reason) {
      case AnomalyReason.highAmount:
        return 'Unusually large amount';
      case AnomalyReason.lowAmount:
        return 'Unusually small amount';
      case AnomalyReason.dailySpike:
        return 'High transaction frequency this day';
      case AnomalyReason.unusualTime:
        return 'Late-night transaction';
    }
  }
}

// ── Profitability Ratios ───────────────────────────────────────────────────────

class ProfitabilityRatios {
  final double grossMargin; // 0-1 or null if no COGS data
  final double operatingMargin; // 0-1
  final double netMargin; // 0-1
  final double cashVelocity; // KES/day income
  final double burnRate; // KES/day expense
  final double runway; // days
  final double incomeConcentration; // Gini-like: 0=even, 1=single source

  const ProfitabilityRatios({
    required this.grossMargin,
    required this.operatingMargin,
    required this.netMargin,
    required this.cashVelocity,
    required this.burnRate,
    required this.runway,
    required this.incomeConcentration,
  });
}

// ── Scenario ───────────────────────────────────────────────────────────────────

class ScenarioCase {
  final String name; // 'Best', 'Base', 'Worst'
  final double income3m;
  final double expense3m;
  double get net3m => income3m - expense3m;
  final double runway; // days
  /// 'best' | 'base' | 'worst' — resolved to Color in UI
  final String colorTag;

  const ScenarioCase({
    required this.name,
    required this.income3m,
    required this.expense3m,
    required this.runway,
    required this.colorTag,
  });
}

// Color is from Flutter — imported in the screen, not here.
// Use a string tag instead:
class ScenarioResult {
  final ScenarioCase best;
  final ScenarioCase base;
  final ScenarioCase worst;

  /// Sensitivity: net at revenue ±5/±10/±20%
  final Map<String, double> sensitivityNet;

  const ScenarioResult({
    required this.best,
    required this.base,
    required this.worst,
    required this.sensitivityNet,
  });
}

// ── Insights ───────────────────────────────────────────────────────────────────

enum InsightPriority { critical, warning, info, opportunity }

class AnalyticsInsight {
  final String title;
  final String detail;
  final double impactScore; // computed = (impact × prob × urgency) / complexity
  final InsightPriority priority;

  const AnalyticsInsight({
    required this.title,
    required this.detail,
    required this.impactScore,
    required this.priority,
  });
}

// ── Top-level summary ─────────────────────────────────────────────────────────

class AnalyticsSummary {
  final ForecastResult forecast;
  final List<AnomalyFlag> anomalies;
  final ProfitabilityRatios ratios;
  final ScenarioResult scenarios;
  final List<AnalyticsInsight> insights;
  final DateTime computedAt;

  // Period totals
  final double totalIncome;
  final double totalExpenses;
  final double netIncome;
  final int transactionCount;
  final int periodDays;

  const AnalyticsSummary({
    required this.forecast,
    required this.anomalies,
    required this.ratios,
    required this.scenarios,
    required this.insights,
    required this.computedAt,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netIncome,
    required this.transactionCount,
    required this.periodDays,
  });
}
