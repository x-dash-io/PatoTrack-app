import 'package:flutter/foundation.dart';

import '../../../helpers/database_helper.dart';
import '../models/advice_models.dart';
import '../services/advice_service.dart';
import '../services/what_if_service.dart';

class AdviceController extends ChangeNotifier {
  AdviceController({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper();

  final DatabaseHelper _db;
  final _adviceService = const AdviceService();
  final _whatIfService = const WhatIfService();

  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;
  AdviceSummary? _summary;

  // What-if state — user-adjustable
  WhatIfType _selectedType = WhatIfType.hireStaff;
  double _whatIfParam = 50000; // default
  WhatIfResult? _whatIfResult;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AdviceSummary? get summary => _summary;
  WhatIfType get selectedType => _selectedType;
  double get whatIfParam => _whatIfParam;
  WhatIfResult? get whatIfResult => _whatIfResult;

  // Cached base metrics for live what-if recompute
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  double _burnRate = 0;
  double _balance = 0;

  Future<void> initialize(String userId) async {
    if (_initialized) return;
    _initialized = true;
    await refresh(userId);
  }

  Future<void> refresh(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final all = await _db.getTransactions(userId);
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final txns = all.where((t) {
        try {
          return DateTime.parse(t.date).isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();

      final income =
          txns.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
      final expenses =
          txns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
      final expenseTxns = txns.where((t) => t.type == 'expense').toList();

      // Monthly averages (90-day window → 3 months)
      _monthlyIncome = income / 3;
      _monthlyExpense = expenses / 3;
      _burnRate = expenses / 90;
      _balance = income - expenses;

      // Metrics for advice service
      final grossMargin = income > 0 ? (income - expenses) / income : 0.0;
      final operatingMargin = grossMargin;

      final withReceipt = expenseTxns
          .where((t) => t.receiptImageUrl?.isNotEmpty == true)
          .length;
      final receiptCoverage =
          expenseTxns.isEmpty ? 0.0 : withReceipt / expenseTxns.length;

      final withCat = txns.where((t) => t.categoryId != null).length;
      final categorizationRate =
          txns.isEmpty ? 1.0 : withCat / txns.length;

      // Income concentration
      final incomeTxns = txns.where((t) => t.type == 'income').toList();
      double concentration = 0;
      if (incomeTxns.isNotEmpty) {
        final Map<String, double> byCat = {};
        for (final t in incomeTxns) {
          final key = t.categoryName ?? 'Uncategorized';
          byCat[key] = (byCat[key] ?? 0) + t.amount;
        }
        final maxVal = byCat.values.reduce((a, b) => a > b ? a : b);
        concentration = income > 0 ? maxVal / income : 0;
      }

      // Trend from last two months
      final now = DateTime.now();
      final prevMonth = txns.where((t) {
        try {
          final d = DateTime.parse(t.date);
          return d.month == (now.month - 1) || (now.month == 1 && d.month == 12);
        } catch (_) {
          return false;
        }
      }).toList();
      final thisMonth = txns.where((t) {
        try {
          return DateTime.parse(t.date).month == now.month;
        } catch (_) {
          return false;
        }
      }).toList();
      final prevInc = prevMonth
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final thisInc = thisMonth
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final prevExp = prevMonth
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);
      final thisExp = thisMonth
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);

      final runway = _burnRate > 0 ? _balance / _burnRate : 999.0;

      final insights = _adviceService.generate(
        monthlyIncome: _monthlyIncome,
        monthlyExpense: _monthlyExpense,
        grossMargin: grossMargin.clamp(-1, 1),
        operatingMargin: operatingMargin.clamp(-1, 1),
        burnRate: _burnRate,
        runway: runway.clamp(0, 9999),
        incomeConcentration: concentration.clamp(0, 1),
        anomalyCount: 0, // populated from analytics if available
        receiptCoverage: receiptCoverage,
        categorizationRate: categorizationRate,
        incomeGrowing: thisInc >= prevInc,
        expenseGrowing: thisExp > prevExp,
      );

      // Default what-if at current param
      _whatIfResult = _computeWhatIf();

      // Compile default what-if for each type at sensible defaults
      final defaultWhatIf = <WhatIfType, WhatIfResult>{};
      final defaults = {
        WhatIfType.hireStaff: _monthlyExpense * 0.3,
        WhatIfType.priceChange: 10.0,
        WhatIfType.loanProceeds: _monthlyIncome * 2,
        WhatIfType.majorClient: _monthlyIncome * 0.5,
      };
      for (final type in WhatIfType.values) {
        defaultWhatIf[type] = _whatIfService.compute(
          type: type,
          paramValue: defaults[type]!,
          monthlyIncome: _monthlyIncome,
          monthlyExpense: _monthlyExpense,
          burnRate: _burnRate,
          currentBalance: _balance,
        );
      }

      _summary = AdviceSummary(
        insights: insights,
        defaultWhatIf: defaultWhatIf,
      );
    } catch (e) {
      _errorMessage = 'Could not load advice. Pull down to retry.';
      debugPrint('AdviceController error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setWhatIfType(WhatIfType type) {
    _selectedType = type;
    // Reset param to sensible default
    _whatIfParam = switch (type) {
      WhatIfType.hireStaff => _monthlyExpense * 0.3 > 0 ? _monthlyExpense * 0.3 : 50000,
      WhatIfType.priceChange => 10.0,
      WhatIfType.loanProceeds => _monthlyIncome * 2 > 0 ? _monthlyIncome * 2 : 100000,
      WhatIfType.majorClient => _monthlyIncome * 0.5 > 0 ? _monthlyIncome * 0.5 : 50000,
    };
    _whatIfResult = _computeWhatIf();
    notifyListeners();
  }

  void setWhatIfParam(double value) {
    _whatIfParam = value;
    _whatIfResult = _computeWhatIf();
    notifyListeners();
  }

  WhatIfResult _computeWhatIf() {
    return _whatIfService.compute(
      type: _selectedType,
      paramValue: _whatIfParam,
      monthlyIncome: _monthlyIncome,
      monthlyExpense: _monthlyExpense,
      burnRate: _burnRate,
      currentBalance: _balance,
    );
  }
}
