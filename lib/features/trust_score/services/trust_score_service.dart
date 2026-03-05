import 'dart:math' as math;
import '../../../models/transaction.dart' as model;
import '../models/trust_score_result.dart';

/// Pure computation service — no I/O, fully testable.
/// Accepts all transactions for the user and returns a [TrustScoreResult].
class TrustScoreService {
  const TrustScoreService();

  TrustScoreResult compute(List<model.Transaction> transactions) {
    if (transactions.isEmpty) return TrustScoreResult.empty();

    final income =
        transactions.where((t) => t.type == 'income').toList();
    final expenses =
        transactions.where((t) => t.type == 'expense').toList();

    final totalIncome =
        income.fold(0.0, (s, t) => s + t.amount);
    final totalExpenses =
        expenses.fold(0.0, (s, t) => s + t.amount);

    // ── Financial Health (max 40) ──────────────────────────────────────
    final cashFlowPts =
        _computeCashFlowPoints(totalIncome, totalExpenses);
    final expenseStabilityPts =
        _computeExpenseStabilityPoints(expenses);
    final growthTrendPts =
        _computeGrowthTrendPoints(income);
    final healthScore =
        cashFlowPts + expenseStabilityPts + growthTrendPts;

    // ── Transaction Integrity (max 30) ────────────────────────────────
    final dataAccuracyPts =
        _computeDataAccuracyPoints(transactions);
    final sourceDiversityPts =
        _computeSourceDiversityPoints(transactions);
    final consistencyPts =
        _computeConsistencyPoints(transactions);
    final integrityScore =
        dataAccuracyPts + sourceDiversityPts + consistencyPts;

    // ── Compliance Readiness (max 20) ─────────────────────────────────
    final documentationPts =
        _computeDocumentationPoints(expenses);
    final recordCompletenessPts =
        _computeRecordCompletenessPoints(transactions);
    final categorizationPts =
        _computeCategorizationPoints(transactions);
    final complianceScore =
        documentationPts + recordCompletenessPts + categorizationPts;

    // ── Financial Behavior (max 10) ───────────────────────────────────
    final timelinessPts = _computeTimelinessPoints();
    final budgetAdherencePts =
        _computeBudgetAdherencePoints(totalIncome, totalExpenses);
    final anomalyPts = _computeAnomalyPoints(transactions);
    final behaviorScore =
        timelinessPts + budgetAdherencePts + anomalyPts;

    // Weighted sum per spec:
    // Trust Score = (40×Health + 30×Integrity + 20×Compliance + 10×Behavior) / 100
    // Each pillar is already out of its max, so:
    final trustScore = _clamp(
      (healthScore / 40 * 40) +
          (integrityScore / 30 * 30) +
          (complianceScore / 20 * 20) +
          (behaviorScore / 10 * 10),
      0,
      100,
    );

    final riskBand =
        TrustRiskBandExtension.fromScore(trustScore);
    final insights =
        _generateInsights(
      cashFlowPts: cashFlowPts,
      expenseStabilityPts: expenseStabilityPts,
      growthTrendPts: growthTrendPts,
      dataAccuracyPts: dataAccuracyPts,
      sourceDiversityPts: sourceDiversityPts,
      consistencyPts: consistencyPts,
      documentationPts: documentationPts,
      recordCompletenessPts: recordCompletenessPts,
      categorizationPts: categorizationPts,
      timelinessPts: timelinessPts,
      budgetAdherencePts: budgetAdherencePts,
      anomalyPts: anomalyPts,
    );

    return TrustScoreResult(
      totalScore: trustScore,
      financialHealthScore: healthScore,
      integrityScore: integrityScore,
      complianceScore: complianceScore,
      behaviorScore: behaviorScore,
      riskBand: riskBand,
      insights: insights,
      computedAt: DateTime.now(),
      cashFlowPoints: cashFlowPts,
      expenseStabilityPoints: expenseStabilityPts,
      growthTrendPoints: growthTrendPts,
      dataAccuracyPoints: dataAccuracyPts,
      sourceDiversityPoints: sourceDiversityPts,
      consistencyPoints: consistencyPts,
      documentationPoints: documentationPts,
      recordCompletenessPoints: recordCompletenessPts,
      categorizationPoints: categorizationPts,
      timelinessPoints: timelinessPts,
      budgetAdherencePoints: budgetAdherencePts,
      anomalyPoints: anomalyPts,
    );
  }

  // ── Financial Health ──────────────────────────────────────────────────

  double _computeCashFlowPoints(double income, double expenses) {
    if (income == 0) return 0;
    final ratio = income / math.max(expenses, 1.0);
    if (ratio >= 2.0) return 30;
    if (ratio >= 1.5) return 24;
    if (ratio >= 1.0) return 18;
    if (ratio >= 0.5) return 10;
    return 3;
  }

  double _computeExpenseStabilityPoints(
      List<model.Transaction> expenses) {
    if (expenses.length < 2) return 3; // not enough data
    // Group by calendar month, sum per month
    final Map<String, double> monthlyTotals = {};
    for (final t in expenses) {
      final dt = _parseDate(t.date);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + t.amount;
    }
    if (monthlyTotals.length < 2) return 3;
    final values = monthlyTotals.values.toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    if (avg == 0) return 3;
    final variance = values
        .map((v) => (v - avg) * (v - avg))
        .reduce((a, b) => a + b) /
        values.length;
    final stddev = math.sqrt(variance);
    final cv = stddev / avg; // coefficient of variation
    if (cv < 0.2) return 7;
    if (cv < 0.4) return 5;
    if (cv < 0.6) return 3;
    return 1;
  }

  double _computeGrowthTrendPoints(List<model.Transaction> income) {
    if (income.isEmpty) return 0;
    final now = DateTime.now();
    final thisMonthKey = '${now.year}-${now.month}';
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthKey = '${lastMonth.year}-${lastMonth.month}';

    double thisMonthTotal = 0;
    double lastMonthTotal = 0;
    for (final t in income) {
      final dt = _parseDate(t.date);
      final key = '${dt.year}-${dt.month}';
      if (key == thisMonthKey) thisMonthTotal += t.amount;
      if (key == lastMonthKey) lastMonthTotal += t.amount;
    }
    if (lastMonthTotal == 0) return 2; // can't compare
    final growth = (thisMonthTotal - lastMonthTotal) / lastMonthTotal;
    if (growth >= 0.05) return 3;
    if (growth >= -0.05) return 2; // roughly flat
    return 0; // declining
  }

  // ── Transaction Integrity ─────────────────────────────────────────────

  double _computeDataAccuracyPoints(List<model.Transaction> txns) {
    if (txns.isEmpty) return 0;
    final complete = txns.where((t) =>
        t.amount > 0 &&
        t.date.isNotEmpty &&
        t.categoryId != null &&
        t.description.isNotEmpty).length;
    final pct = complete / txns.length;
    if (pct >= 0.95) return 15;
    if (pct >= 0.85) return 11;
    if (pct >= 0.70) return 7;
    return 3;
  }

  double _computeSourceDiversityPoints(
      List<model.Transaction> txns) {
    final sources = txns.map((t) => t.source.isEmpty ? 'manual' : t.source).toSet();
    if (sources.length >= 3) return 10;
    if (sources.length == 2) return 7;
    return 3;
  }

  double _computeConsistencyPoints(List<model.Transaction> txns) {
    if (txns.length < 2) return 1;
    final dates = txns
        .map((t) => _parseDate(t.date))
        .toList()
      ..sort();
    double maxGap = 0;
    for (int i = 1; i < dates.length; i++) {
      final gap = dates[i].difference(dates[i - 1]).inDays.toDouble();
      if (gap > maxGap) maxGap = gap;
    }
    if (maxGap < 7) return 5;
    if (maxGap < 14) return 3;
    if (maxGap < 30) return 1;
    return 0;
  }

  // ── Compliance Readiness ──────────────────────────────────────────────

  double _computeDocumentationPoints(
      List<model.Transaction> expenses) {
    if (expenses.isEmpty) return 1;
    final withReceipt =
        expenses.where((t) => t.receiptImageUrl?.isNotEmpty == true).length;
    final pct = withReceipt / expenses.length;
    if (pct >= 0.70) return 10;
    if (pct >= 0.40) return 7;
    if (pct >= 0.20) return 4;
    return 1;
  }

  double _computeRecordCompletenessPoints(
      List<model.Transaction> txns) {
    if (txns.isEmpty) return 0;
    final withDesc =
        txns.where((t) => t.description.trim().isNotEmpty).length;
    final pct = withDesc / txns.length;
    if (pct >= 0.90) return 5;
    if (pct >= 0.70) return 3;
    return 1;
  }

  double _computeCategorizationPoints(
      List<model.Transaction> txns) {
    if (txns.isEmpty) return 0;
    final withCat =
        txns.where((t) => t.categoryId != null).length;
    final pct = withCat / txns.length;
    if (pct >= 0.95) return 5;
    if (pct >= 0.80) return 3;
    if (pct >= 0.60) return 2;
    return 0;
  }

  // ── Financial Behavior ────────────────────────────────────────────────

  // No bill data available here — default to 4 (good-faith)
  double _computeTimelinessPoints() => 4;

  double _computeBudgetAdherencePoints(
      double income, double expenses) {
    if (income == 0) return 0;
    final spendRate = expenses / income;
    if (spendRate <= 0.70) return 3;
    if (spendRate <= 0.90) return 2;
    if (spendRate <= 1.00) return 1;
    return 0; // over-spending
  }

  double _computeAnomalyPoints(List<model.Transaction> txns) {
    if (txns.length < 3) return 2;
    final amounts = txns.map((t) => t.amount).toList();
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final anomalies = amounts.where((a) => a > mean * 3).length;
    if (anomalies == 0) return 2;
    if (anomalies == 1) return 1;
    return 0;
  }

  // ── Insights ─────────────────────────────────────────────────────────

  List<String> _generateInsights({
    required double cashFlowPts,
    required double expenseStabilityPts,
    required double growthTrendPts,
    required double dataAccuracyPts,
    required double sourceDiversityPts,
    required double consistencyPts,
    required double documentationPts,
    required double recordCompletenessPts,
    required double categorizationPts,
    required double timelinessPts,
    required double budgetAdherencePts,
    required double anomalyPts,
  }) {
    final tips = <String>[];

    if (cashFlowPts < 18) {
      tips.add(
          'Your income-to-expense ratio is low. Try to bring income to at least 1.5× your expenses.');
    }
    if (expenseStabilityPts < 5) {
      tips.add(
          'Expense volatility is high. Irregular spending can signal cash flow risk — aim for steadier monthly costs.');
    }
    if (growthTrendPts < 2) {
      tips.add(
          'Income this month is lower than last month. Review revenue sources and look for growth opportunities.');
    }
    if (dataAccuracyPts < 11) {
      tips.add(
          'Many transactions are missing categories or descriptions. Complete each transaction for a higher accuracy score.');
    }
    if (sourceDiversityPts < 7) {
      tips.add(
          'All transactions come from one source. Use receipt scanning and M-Pesa sync to improve source diversity.');
    }
    if (consistencyPts < 3) {
      tips.add(
          'There are large gaps between recorded transactions. Record transactions consistently to improve continuity.');
    }
    if (documentationPts < 7) {
      tips.add(
          'Less than 40% of expenses have attached receipts. Scan receipts for better compliance readiness.');
    }
    if (recordCompletenessPts < 3) {
      tips.add(
          'Many transactions have no description. Add notes to complete your records.');
    }
    if (categorizationPts < 3) {
      tips.add(
          'Over 20% of transactions are uncategorized. Use the category suggestions to tag them quickly.');
    }
    if (budgetAdherencePts == 0) {
      tips.add(
          'Spending exceeds income this period. Review expenses and reduce discretionary costs.');
    }
    if (anomalyPts < 2) {
      tips.add(
          'Unusually large transactions detected. Review them to ensure they\'re correctly categorized.');
    }

    // Return the most impactful 5 tips (or fewer)
    return tips.take(5).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  DateTime _parseDate(String iso) {
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return DateTime.now();
    }
  }

  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);
}
