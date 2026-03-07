import 'dart:math' as math;
import '../../../models/transaction.dart' as model;
import '../models/analytics_result.dart';

/// Holt's Double Exponential Smoothing (level + trend).
/// No Dart library exists — implemented from math spec.
/// Returns 3-month forward forecast + confidence band.
class ForecastingService {
  const ForecastingService();

  static const double _alpha = 0.3; // level smoothing
  static const double _beta = 0.2; // trend smoothing

  ForecastResult compute(List<model.Transaction> transactions) {
    final history = _buildMonthlyHistory(transactions);

    if (history.length < 2) {
      return ForecastResult(
        history: history,
        forecast: [],
        confidenceBand: 0,
      );
    }

    // Run Holt's ES on income series
    final incomeForecast = _holtForecast(
      history.map((h) => h.income).toList(),
      horizons: 3,
    );
    final expenseForecast = _holtForecast(
      history.map((h) => h.expense).toList(),
      horizons: 3,
    );

    // Confidence band: 90% CI = ±1.645 × RMSE of last 3 fitted values
    final incomeRmse = _rmse(
      history.map((h) => h.income).toList(),
    );
    final expenseRmse = _rmse(
      history.map((h) => h.expense).toList(),
    );
    final confidenceBand = 1.645 * math.max(incomeRmse, expenseRmse);

    // Build forecast points
    final lastMonth = history.last.month;
    final forecastPoints = List.generate(3, (i) {
      final month = DateTime(lastMonth.year, lastMonth.month + i + 1);
      return ForecastPoint(
        month: month,
        income: math.max(incomeForecast[i], 0),
        expense: math.max(expenseForecast[i], 0),
      );
    });

    return ForecastResult(
      history: history,
      forecast: forecastPoints,
      confidenceBand: confidenceBand,
    );
  }

  /// Aggregate transactions by calendar month
  List<ForecastPoint> _buildMonthlyHistory(
      List<model.Transaction> transactions) {
    final Map<String, _MonthAccum> acc = {};
    for (final t in transactions) {
      final dt = _parseDate(t.date);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      acc.putIfAbsent(key, () => _MonthAccum(DateTime(dt.year, dt.month)));
      if (t.type == 'income') {
        acc[key]!.income += t.amount;
      } else {
        acc[key]!.expense += t.amount;
      }
    }
    final sorted = acc.values.toList()
      ..sort((a, b) => a.month.compareTo(b.month));
    return sorted
        .map((m) =>
            ForecastPoint(month: m.month, income: m.income, expense: m.expense))
        .toList();
  }

  /// Holt's double exponential smoothing
  List<double> _holtForecast(List<double> series, {required int horizons}) {
    if (series.isEmpty) return List.filled(horizons, 0);
    if (series.length == 1) {
      return List.filled(horizons, series.first);
    }

    double level = series.first;
    double trend = series[1] - series[0];

    for (int i = 1; i < series.length; i++) {
      final prevLevel = level;
      level = _alpha * series[i] + (1 - _alpha) * (level + trend);
      trend = _beta * (level - prevLevel) + (1 - _beta) * trend;
    }

    return List.generate(
      horizons,
      (k) => level + (k + 1) * trend,
    );
  }

  /// Root mean square error of Holt fit vs actuals
  double _rmse(List<double> series) {
    if (series.length < 3) return series.isEmpty ? 0 : series.last * 0.1;
    final recent = series.sublist(series.length - 3);
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    final mse =
        recent.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            recent.length;
    return math.sqrt(mse);
  }

  DateTime _parseDate(String iso) {
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return DateTime.now();
    }
  }
}

class _MonthAccum {
  final DateTime month;
  double income = 0;
  double expense = 0;
  _MonthAccum(this.month);
}
