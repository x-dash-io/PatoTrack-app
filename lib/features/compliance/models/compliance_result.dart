// ── Checklist Item ────────────────────────────────────────────────────────────

enum ComplianceStatus { pass, warn, fail }

class ComplianceItem {
  final String title;
  final String detail; // what passed or needs fixing
  final ComplianceStatus status;
  final double weight; // category weight in final score (sum to 1.0)
  final double pct; // 0.0–1.0 actual value

  const ComplianceItem({
    required this.title,
    required this.detail,
    required this.status,
    required this.weight,
    required this.pct,
  });
}

// ── Top-level ─────────────────────────────────────────────────────────────────

class ComplianceResult {
  /// 0–100 weighted compliance score
  final double score;

  /// Individual checklist items
  final List<ComplianceItem> items;

  final DateTime computedAt;
  final int periodDays;

  const ComplianceResult({
    required this.score,
    required this.items,
    required this.computedAt,
    required this.periodDays,
  });

  ComplianceStatus get overallStatus {
    if (score >= 80) return ComplianceStatus.pass;
    if (score >= 50) return ComplianceStatus.warn;
    return ComplianceStatus.fail;
  }

  factory ComplianceResult.empty() => ComplianceResult(
        score: 0,
        items: [],
        computedAt: DateTime.now(),
        periodDays: 0,
      );
}
