import '../../../models/transaction.dart' as model;
import '../models/analytics_result.dart';

/// Computes profitability ratios from transaction ledger.
class RatiosService {
  const RatiosService();

  ProfitabilityRatios compute(
    List<model.Transaction> transactions,
    int periodDays,
  ) {
    if (transactions.isEmpty) {
      return const ProfitabilityRatios(
        grossMargin: 0,
        operatingMargin: 0,
        netMargin: 0,
        cashVelocity: 0,
        burnRate: 0,
        runway: 0,
        incomeConcentration: 0,
      );
    }

    final safedays = periodDays > 0 ? periodDays : 30;
    final income = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final allExpenses = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    // COGS: expenses in cogs-like categories (raw materials, inventory, delivery)
    final cogsKeywords = ['cogs', 'cost of goods', 'raw material', 'inventory', 'stock'];
    final cogs = transactions
        .where((t) =>
            t.type == 'expense' &&
            cogsKeywords.any((kw) =>
                (t.description.toLowerCase()).contains(kw)))
        .fold(0.0, (s, t) => s + t.amount);

    final grossProfit = income - cogs;
    final grossMargin = income > 0 ? grossProfit / income : 0.0;
    final operatingMargin =
        income > 0 ? (income - allExpenses) / income : 0.0;
    final netMargin = operatingMargin; // simplified (no tax/interest data)

    final cashVelocity = income / safedays;
    final burnRate = allExpenses / safedays;

    // Runway = current net balance / burn rate
    final balance = income - allExpenses;
    final runway = burnRate > 0 ? balance / burnRate : 999.0;

    // Income concentration: fraction of income from the single largest source
    // (by category). 0 = perfectly spread, 1 = single source all income
    final incomeTxns = transactions.where((t) => t.type == 'income').toList();
    double concentration = 0;
    if (incomeTxns.length > 1) {
      final Map<String, double> byCat = {};
      for (final t in incomeTxns) {
        final key = t.categoryId?.toString() ?? 'Uncategorized';
        byCat[key] = (byCat[key] ?? 0) + t.amount;
      }
      final maxVal =
          byCat.values.reduce((a, b) => a > b ? a : b);
      concentration = income > 0 ? maxVal / income : 0;
    }

    return ProfitabilityRatios(
      grossMargin: grossMargin.clamp(-1, 1),
      operatingMargin: operatingMargin.clamp(-1, 1),
      netMargin: netMargin.clamp(-1, 1),
      cashVelocity: cashVelocity,
      burnRate: burnRate,
      runway: runway.clamp(0, 9999),
      incomeConcentration: concentration.clamp(0, 1),
    );
  }
}
