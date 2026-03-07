import '../../../models/transaction.dart' as model;
import '../models/compliance_result.dart';

/// Pure computation: evaluates 5 bookkeeping compliance checks.
/// No tax logic, no CRB. Bookkeeping-only per spec.
class ComplianceService {
  const ComplianceService();

  ComplianceResult compute(
      List<model.Transaction> transactions, int periodDays) {
    if (transactions.isEmpty) return ComplianceResult.empty();

    final income = transactions.where((t) => t.type == 'income').toList();
    final expenses = transactions.where((t) => t.type == 'expense').toList();

    // ── 1. All income recorded (weight 25%) ───────────────────────────────
    // Proxy: % of income transactions that have both amount + description
    final completeIncome = income
        .where((t) => t.amount > 0 && t.description.trim().isNotEmpty)
        .length;
    final incomePct = income.isEmpty ? 1.0 : completeIncome / income.length;
    final incomeItem = _makeItem(
      title: 'All Income Recorded',
      detail: income.isEmpty
          ? 'No income transactions found'
          : '${(incomePct * 100).toInt()}% of income transactions are fully documented',
      pct: incomePct,
      weight: 0.25,
      passThreshold: 0.90,
      warnThreshold: 0.70,
    );

    // ── 2. Receipts for 80%+ of expenses (weight 25%) ─────────────────────
    final withReceipt =
        expenses.where((t) => t.receiptImageUrl?.isNotEmpty == true).length;
    final receiptPct = expenses.isEmpty ? 1.0 : withReceipt / expenses.length;
    final receiptItem = _makeItem(
      title: 'Receipts Attached (80%+ target)',
      detail: expenses.isEmpty
          ? 'No expenses to document (100%)'
          : '$withReceipt of ${expenses.length} expenses have receipts attached (${(receiptPct * 100).toInt()}%)',
      pct: receiptPct,
      weight: 0.25,
      passThreshold: 0.80,
      warnThreshold: 0.50,
    );

    // ── 3. No unexplained transactions (weight 20%) ────────────────────────
    // Proxy: % with a non-empty description
    final withDesc =
        transactions.where((t) => t.description.trim().isNotEmpty).length;
    final descPct = transactions.isEmpty ? 1.0 : withDesc / transactions.length;
    final descItem = _makeItem(
      title: 'No Unexplained Transactions',
      detail: '${(descPct * 100).toInt()}% of transactions have descriptions',
      pct: descPct,
      weight: 0.20,
      passThreshold: 0.95,
      warnThreshold: 0.75,
    );

    // ── 4. Documentation complete (weight 15%) ─────────────────────────────
    // Proxy: % with category assigned
    final withCat = transactions.where((t) => t.categoryId != null).length;
    final catPct = transactions.isEmpty ? 1.0 : withCat / transactions.length;
    final catItem = _makeItem(
      title: 'Documentation Complete',
      detail:
          '$withCat of ${transactions.length} transactions are categorized (${(catPct * 100).toInt()}%)',
      pct: catPct,
      weight: 0.15,
      passThreshold: 0.90,
      warnThreshold: 0.65,
    );

    // ── 5. Record consistency (weight 15%) ─────────────────────────────────
    // No large gaps (>21 days) between records
    double consistencyPct = 1.0;
    if (transactions.length >= 2) {
      final dates = transactions.map((t) {
        try {
          return DateTime.parse(t.date);
        } catch (_) {
          return DateTime.now();
        }
      }).toList()
        ..sort();
      int maxGap = 0;
      for (int i = 1; i < dates.length; i++) {
        final gap = dates[i].difference(dates[i - 1]).inDays;
        if (gap > maxGap) maxGap = gap;
      }
      // Map gap to pct: 0d→1.0, 14d→0.8, 21d→0.6, 30d→0.4, 60+d→0.1
      if (maxGap == 0) {
        consistencyPct = 1.0;
      } else if (maxGap <= 7) {
        consistencyPct = 0.95;
      } else if (maxGap <= 14) {
        consistencyPct = 0.80;
      } else if (maxGap <= 21) {
        consistencyPct = 0.60;
      } else if (maxGap <= 30) {
        consistencyPct = 0.40;
      } else {
        consistencyPct = 0.15;
      }
    }
    final consistencyItem = _makeItem(
      title: 'Consistent Record-Keeping',
      detail: consistencyPct >= 0.80
          ? 'Transactions are recorded consistently — no large gaps'
          : 'Large gaps detected between records. Aim to record daily.',
      pct: consistencyPct,
      weight: 0.15,
      passThreshold: 0.80,
      warnThreshold: 0.50,
    );

    final items = [
      incomeItem,
      receiptItem,
      descItem,
      catItem,
      consistencyItem,
    ];

    // Weighted score
    final score = items
        .map((item) => item.pct * item.weight * 100)
        .reduce((a, b) => a + b);

    return ComplianceResult(
      score: score.clamp(0, 100),
      items: items,
      computedAt: DateTime.now(),
      periodDays: periodDays,
    );
  }

  ComplianceItem _makeItem({
    required String title,
    required String detail,
    required double pct,
    required double weight,
    required double passThreshold,
    required double warnThreshold,
  }) {
    final status = pct >= passThreshold
        ? ComplianceStatus.pass
        : pct >= warnThreshold
            ? ComplianceStatus.warn
            : ComplianceStatus.fail;
    return ComplianceItem(
      title: title,
      detail: detail,
      status: status,
      weight: weight,
      pct: pct,
    );
  }
}
