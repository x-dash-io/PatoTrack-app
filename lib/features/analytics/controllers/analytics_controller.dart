import 'package:flutter/foundation.dart';

import '../../../helpers/database_helper.dart';
import '../../../models/transaction.dart' as model;
import '../models/analytics_result.dart';
import '../services/anomaly_service.dart';
import '../services/forecasting_service.dart';
import '../services/insight_engine.dart';
import '../services/ratios_service.dart';
import '../services/scenario_service.dart';

enum AnalyticsPeriod { threeMonths, sixMonths, twelveMonths, all }

extension AnalyticsPeriodExt on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.threeMonths:
        return '3M';
      case AnalyticsPeriod.sixMonths:
        return '6M';
      case AnalyticsPeriod.twelveMonths:
        return '12M';
      case AnalyticsPeriod.all:
        return 'All';
    }
  }

  int? get days {
    switch (this) {
      case AnalyticsPeriod.threeMonths:
        return 90;
      case AnalyticsPeriod.sixMonths:
        return 180;
      case AnalyticsPeriod.twelveMonths:
        return 365;
      case AnalyticsPeriod.all:
        return null;
    }
  }
}

class AnalyticsController extends ChangeNotifier {
  AnalyticsController({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  final DatabaseHelper _dbHelper;
  final _forecasting = const ForecastingService();
  final _anomaly = const AnomalyService();
  final _ratios = const RatiosService();
  final _scenario = const ScenarioService();
  final _insights = const InsightEngine();

  bool _isLoading = true;
  bool _isInitialized = false;
  String? _errorMessage;
  AnalyticsSummary? _summary;
  AnalyticsPeriod _period = AnalyticsPeriod.threeMonths;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AnalyticsSummary? get summary => _summary;
  AnalyticsPeriod get selectedPeriod => _period;

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh(userId);
  }

  Future<void> setPeriod(AnalyticsPeriod period, String userId) async {
    if (_period == period) return;
    _period = period;
    await refresh(userId);
  }

  Future<void> refresh(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final all = await _dbHelper.getTransactions(userId);
      final cutoff = _period.days != null
          ? DateTime.now().subtract(Duration(days: _period.days!))
          : null;
      final filtered = cutoff != null
          ? all.where((t) {
              try {
                return DateTime.parse(t.date).isAfter(cutoff);
              } catch (_) {
                return true;
              }
            }).toList()
          : all;

      final periodDays = _period.days ?? _effectiveDays(filtered);

      // Run all services
      final forecast = _forecasting.compute(filtered);
      final anomalies = _anomaly.detect(filtered);
      final ratioResult = _ratios.compute(filtered, periodDays);
      final scenarioResult = _scenario.compute(forecast, ratioResult.burnRate);

      final income = filtered
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final expenses = filtered
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);
      final expenseTxns = filtered.where((t) => t.type == 'expense').toList();
      final uncategorized = filtered.where((t) => t.categoryId == null).length;
      final withReceipt = expenseTxns
          .where((t) => t.receiptImageUrl?.isNotEmpty == true)
          .length;

      final insightList = _insights.generate(
        totalIncome: income,
        totalExpenses: expenses,
        netIncome: income - expenses,
        burnRate: ratioResult.burnRate,
        runway: ratioResult.runway,
        grossMargin: ratioResult.grossMargin,
        incomeConcentration: ratioResult.incomeConcentration,
        anomalyCount: anomalies.length,
        uncategorizedCount: uncategorized,
        totalTransactions: filtered.length,
        transactionsWithReceipt: withReceipt,
        totalExpenseTransactions: expenseTxns.length,
        forecastPoints: forecast.forecast,
      );

      _summary = AnalyticsSummary(
        forecast: forecast,
        anomalies: anomalies,
        ratios: ratioResult,
        scenarios: scenarioResult,
        insights: insightList,
        computedAt: DateTime.now(),
        totalIncome: income,
        totalExpenses: expenses,
        netIncome: income - expenses,
        transactionCount: filtered.length,
        periodDays: periodDays,
      );
    } catch (e) {
      _errorMessage = 'Could not compute analytics. Pull down to retry.';
      debugPrint('AnalyticsController error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int _effectiveDays(List<model.Transaction> txns) {
    if (txns.length < 2) return 30;
    try {
      final dates = txns.map((t) => DateTime.parse(t.date)).toList()..sort();
      return dates.last.difference(dates.first).inDays.clamp(1, 9999);
    } catch (_) {
      return 30;
    }
  }
}
