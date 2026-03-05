enum TrustRiskBand { low, moderate, high, critical }

extension TrustRiskBandExtension on TrustRiskBand {
  String get label {
    switch (this) {
      case TrustRiskBand.low:
        return 'LOW RISK';
      case TrustRiskBand.moderate:
        return 'MODERATE';
      case TrustRiskBand.high:
        return 'HIGH RISK';
      case TrustRiskBand.critical:
        return 'CRITICAL';
    }
  }

  static TrustRiskBand fromScore(double score) {
    if (score >= 80) return TrustRiskBand.low;
    if (score >= 60) return TrustRiskBand.moderate;
    if (score >= 40) return TrustRiskBand.high;
    return TrustRiskBand.critical;
  }
}

class TrustScoreResult {
  // ── Totals ────────────────────────────────────────────────────────────
  final double totalScore; // 0–100
  final double financialHealthScore; // 0–40
  final double integrityScore; // 0–30
  final double complianceScore; // 0–20
  final double behaviorScore; // 0–10
  final TrustRiskBand riskBand;
  final List<String> insights; // 3–5 improvement tips
  final DateTime computedAt;

  // ── Financial Health sub-factors ──────────────────────────────────────
  final double cashFlowPoints; // 0–30
  final double expenseStabilityPoints; // 0–7
  final double growthTrendPoints; // 0–3

  // ── Integrity sub-factors ─────────────────────────────────────────────
  final double dataAccuracyPoints; // 0–15
  final double sourceDiversityPoints; // 0–10
  final double consistencyPoints; // 0–5

  // ── Compliance sub-factors ────────────────────────────────────────────
  final double documentationPoints; // 0–10
  final double recordCompletenessPoints; // 0–5
  final double categorizationPoints; // 0–5

  // ── Behavior sub-factors ──────────────────────────────────────────────
  final double timelinessPoints; // 0–5
  final double budgetAdherencePoints; // 0–3
  final double anomalyPoints; // 0–2

  const TrustScoreResult({
    required this.totalScore,
    required this.financialHealthScore,
    required this.integrityScore,
    required this.complianceScore,
    required this.behaviorScore,
    required this.riskBand,
    required this.insights,
    required this.computedAt,
    required this.cashFlowPoints,
    required this.expenseStabilityPoints,
    required this.growthTrendPoints,
    required this.dataAccuracyPoints,
    required this.sourceDiversityPoints,
    required this.consistencyPoints,
    required this.documentationPoints,
    required this.recordCompletenessPoints,
    required this.categorizationPoints,
    required this.timelinessPoints,
    required this.budgetAdherencePoints,
    required this.anomalyPoints,
  });

  static TrustScoreResult empty() => TrustScoreResult(
        totalScore: 0,
        financialHealthScore: 0,
        integrityScore: 0,
        complianceScore: 0,
        behaviorScore: 0,
        riskBand: TrustRiskBand.critical,
        insights: [
          'Add income and expense transactions to generate your Trust Score.',
        ],
        computedAt: DateTime.now(),
        cashFlowPoints: 0,
        expenseStabilityPoints: 0,
        growthTrendPoints: 0,
        dataAccuracyPoints: 0,
        sourceDiversityPoints: 0,
        consistencyPoints: 0,
        documentationPoints: 0,
        recordCompletenessPoints: 0,
        categorizationPoints: 0,
        timelinessPoints: 0,
        budgetAdherencePoints: 0,
        anomalyPoints: 0,
      );
}
