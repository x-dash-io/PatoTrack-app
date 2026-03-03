import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../helpers/database_helper.dart';
import '../../../helpers/pdf_helper.dart';
import '../../../models/transaction.dart' as model;
import '../models/reports_view_data.dart';

enum ReportsRange {
  week,
  month,
  year,
}

class ReportsController extends ChangeNotifier {
  ReportsController({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  final DatabaseHelper _dbHelper;

  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  String? _exportMessage;
  ReportsRange _selectedRange = ReportsRange.month;
  ReportsViewData? _viewData;

  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  String? get errorMessage => _errorMessage;
  String? get exportMessage => _exportMessage;
  ReportsRange get selectedRange => _selectedRange;
  ReportsViewData? get viewData => _viewData;

  String get rangeLabel {
    switch (_selectedRange) {
      case ReportsRange.week:
        return 'This week';
      case ReportsRange.month:
        return 'This month';
      case ReportsRange.year:
        return 'This year';
    }
  }

  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    await refresh(userId);
  }

  Future<void> setRange(ReportsRange range, String userId) async {
    if (_selectedRange == range) {
      return;
    }
    _selectedRange = range;
    notifyListeners();
    await refresh(userId);
  }

  Future<void> refresh(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    _exportMessage = null;
    notifyListeners();

    try {
      final period = _currentPeriodRange(_selectedRange);
      final transactions = await _dbHelper.getTransactions(userId);
      final categories = await _dbHelper.getCategories(userId);
      final categoryNames = <int, String>{
        for (final category in categories)
          if (category.id != null) category.id!: category.name,
      };

      final businessTransactions = transactions.where((transaction) {
        final date = DateTime.tryParse(transaction.date);
        if (transaction.tag != 'business' || date == null) {
          return false;
        }

        return !date.isBefore(period.start) && !date.isAfter(period.end);
      }).toList()
        ..sort(
            (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

      double totalIncome = 0;
      double totalExpenses = 0;

      for (final transaction in businessTransactions) {
        if (transaction.type == 'income') {
          totalIncome += transaction.amount;
        } else {
          totalExpenses += transaction.amount;
        }
      }

      final expensesByCategory = <String, double>{};
      for (final transaction in businessTransactions
          .where((transaction) => transaction.type == 'expense')) {
        final categoryName = transaction.categoryId == null
            ? 'Uncategorized'
            : (categoryNames[transaction.categoryId] ?? 'Uncategorized');

        expensesByCategory.update(
          categoryName,
          (current) => current + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }

      final categoryTotals = expensesByCategory.entries
          .map((entry) => CategoryTotal(name: entry.key, total: entry.value))
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));

      final trendPoints = _buildTrendPoints(
        _selectedRange,
        period.start,
        period.end,
        businessTransactions,
      );

      _viewData = ReportsViewData(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        net: totalIncome - totalExpenses,
        businessTransactions: businessTransactions,
        categoryTotals: categoryTotals,
        trendPoints: trendPoints,
        periodStart: period.start,
        periodEnd: period.end,
      );
    } catch (_) {
      _errorMessage =
          'We could not load reports right now. Pull down to retry in a moment.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> exportReportPdf({
    required String userName,
    required String currencySymbol,
  }) async {
    if (_isExporting) {
      return null;
    }

    final data = _viewData;
    if (data == null || data.businessTransactions.isEmpty) {
      return 'No business transactions are available for this range.';
    }

    _isExporting = true;
    _exportMessage = null;
    notifyListeners();

    try {
      final fileName =
          'PatoTrack_Business_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      await PdfHelper.generateAndSharePdf(
        data.businessTransactions,
        userName,
        fileName,
        currencySymbol: currencySymbol,
      );
      _exportMessage = 'Report generated successfully.';
      return null;
    } catch (error) {
      return 'Could not export the report. Please retry.';
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  ({DateTime start, DateTime end}) _currentPeriodRange(ReportsRange range) {
    final now = DateTime.now();
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
      999,
    );

    switch (range) {
      case ReportsRange.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return (
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: end,
        );
      case ReportsRange.month:
        return (start: DateTime(now.year, now.month, 1), end: end);
      case ReportsRange.year:
        return (start: DateTime(now.year, 1, 1), end: end);
    }
  }

  List<TrendPoint> _buildTrendPoints(
    ReportsRange range,
    DateTime start,
    DateTime end,
    List<model.Transaction> transactions,
  ) {
    final points = <TrendPoint>[];

    if (range == ReportsRange.year) {
      final now = DateTime.now();
      for (int month = 1; month <= 12; month++) {
        final label = DateFormat('MMM').format(DateTime(now.year, month));

        double monthIncome = 0;
        double monthExpense = 0;

        for (final transaction in transactions) {
          final date = DateTime.parse(transaction.date);
          if (date.year == now.year && date.month == month) {
            if (transaction.type == 'income') {
              monthIncome += transaction.amount;
            } else {
              monthExpense += transaction.amount;
            }
          }
        }

        points.add(
          TrendPoint(
            x: (month - 1).toDouble(),
            label: label,
            income: monthIncome,
            expense: monthExpense,
          ),
        );
      }

      return points;
    }

    final totalDays = end.difference(start).inDays + 1;
    final maxDays = math.max(totalDays, 1);

    for (int dayIndex = 0; dayIndex < maxDays; dayIndex++) {
      final day = start.add(Duration(days: dayIndex));
      double income = 0;
      double expense = 0;

      for (final transaction in transactions) {
        final date = DateTime.parse(transaction.date);
        if (date.year == day.year &&
            date.month == day.month &&
            date.day == day.day) {
          if (transaction.type == 'income') {
            income += transaction.amount;
          } else {
            expense += transaction.amount;
          }
        }
      }

      points.add(
        TrendPoint(
          x: dayIndex.toDouble(),
          label: DateFormat(range == ReportsRange.week ? 'E' : 'd').format(day),
          income: income,
          expense: expense,
        ),
      );
    }

    return points;
  }
}
