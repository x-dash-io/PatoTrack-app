import '../../../models/transaction.dart' as model;

class CategoryTotal {
  const CategoryTotal({required this.name, required this.total});

  final String name;
  final double total;
}

class TrendPoint {
  const TrendPoint({
    required this.x,
    required this.label,
    required this.income,
    required this.expense,
  });

  final double x;
  final String label;
  final double income;
  final double expense;
}

class ReportsViewData {
  const ReportsViewData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.net,
    required this.businessTransactions,
    required this.categoryTotals,
    required this.trendPoints,
    required this.periodStart,
    required this.periodEnd,
  });

  final double totalIncome;
  final double totalExpenses;
  final double net;
  final List<model.Transaction> businessTransactions;
  final List<CategoryTotal> categoryTotals;
  final List<TrendPoint> trendPoints;
  final DateTime periodStart;
  final DateTime periodEnd;

  bool get hasData => businessTransactions.isNotEmpty;
}
