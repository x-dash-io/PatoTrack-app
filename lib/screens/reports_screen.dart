import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart';
import '../helpers/pdf_helper.dart';
import '../helpers/responsive_helper.dart';
import '../models/transaction.dart' as model;
import '../widgets/loading_widgets.dart';
import '../helpers/notification_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, dynamic>> _reportDataFuture;
  String _currencySymbol = 'KSh';
  final compactFormatter = NumberFormat.compact();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isExportingPDF = false;

  String _selectedTimeFilter = 'month';

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _prepareReportData();
    _loadCurrencyPreference();
  }

  Future<void> _loadCurrencyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currencySymbol = prefs.getString('currency') ?? 'KSh';
    });
  }

  void _refreshReports() {
    setState(() {
      _reportDataFuture = _prepareReportData();
    });
  }

  Future<Map<String, dynamic>> _prepareReportData() async {
    if (_currentUser == null) return {};
    final dbHelper = DatabaseHelper();
    final transactions = await dbHelper.getTransactions(_currentUser.uid);
    final categories = await dbHelper.getCategories(_currentUser.uid);
    final categoryMap = {for (var cat in categories) cat.id!: cat.name};
    return {'transactions': transactions, 'categoryMap': categoryMap};
  }

  ({double profitLoss, String tip, Color color}) _getProfitLossAndTip(
      List<model.Transaction> transactions, String timeFilter) {
    final businessTransactions =
        transactions.where((t) => t.tag == 'business').toList();

    DateTime now = DateTime.now();
    DateTime startDate;

    switch (timeFilter) {
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'month':
      default:
        startDate = DateTime(now.year, now.month, 1);
        break;
    }

    final periodTransactions = businessTransactions.where((t) {
      try {
        return DateTime.parse(t.date).isAfter(startDate);
      } catch (e) {
        return false;
      }
    }).toList();

    double income = periodTransactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    double expenses = periodTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    double profitLoss = income - expenses;

    String periodText = timeFilter == 'week'
        ? 'this week'
        : (timeFilter == 'month' ? 'this month' : 'this year');

    if (profitLoss > 0) {
      return (
        profitLoss: profitLoss,
        tip: 'Great business performance $periodText!',
        color: Colors.green
      );
    } else if (profitLoss < 0) {
      return (
        profitLoss: profitLoss,
        tip: 'Your business is at a loss $periodText. Review expenses.',
        color: Colors.red
      );
    } else {
      return (
        profitLoss: 0,
        tip: 'Your business has broken even $periodText.',
        color: Colors.orange
      );
    }
  }

  // Removed tag breakdown - only business transactions now

  Map<String, double> _prepareExpenseData(
      List<model.Transaction> transactions, Map<int, String> categoryMap) {
    final Map<String, double> expenseData = {};
    for (var transaction in transactions.where((t) => t.type == 'expense')) {
      if (transaction.categoryId != null) {
        final categoryName =
            categoryMap[transaction.categoryId] ?? 'Uncategorized';
        expenseData.update(categoryName, (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount);
      }
    }
    return expenseData;
  }

  Map<String, double> _prepareBarChartData(
      List<model.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;
    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpenses += t.amount;
      }
    }
    return {'Income': totalIncome, 'Expenses': totalExpenses};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Business Reports',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshReports,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _reportDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildReportsLoadingState();
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData ||
                (snapshot.data!['transactions'] as List).isEmpty) {
              return const Center(child: Text('No data to display.'));
            }

            final allTransactions =
                snapshot.data!['transactions'] as List<model.Transaction>;
            final categoryMap =
                snapshot.data!['categoryMap'] as Map<int, String>;

            DateTime now = DateTime.now();
            DateTime startDate;
            switch (_selectedTimeFilter) {
              case 'week':
                startDate = now.subtract(Duration(days: now.weekday - 1));
                startDate =
                    DateTime(startDate.year, startDate.month, startDate.day);
                break;
              case 'year':
                startDate = DateTime(now.year, 1, 1);
                break;
              case 'month':
              default:
                startDate = DateTime(now.year, now.month, 1);
                break;
            }

            final timeFilteredTransactions = allTransactions.where((t) {
              try {
                return DateTime.parse(t.date).isAfter(startDate);
              } catch (e) {
                return false;
              }
            }).toList();

            // Only show business transactions
            final fullyFilteredTransactions = timeFilteredTransactions
                .where((t) => t.tag == 'business')
                .toList();

            final expenseData =
                _prepareExpenseData(fullyFilteredTransactions, categoryMap);
            final barChartData =
                _prepareBarChartData(fullyFilteredTransactions);
            final totalExpenses =
                expenseData.values.fold(0.0, (sum, amount) => sum + amount);
            final profitLossData = _getProfitLossAndTip(
                fullyFilteredTransactions, _selectedTimeFilter);

            return Column(
              children: [
                Padding(
                  padding: ResponsiveHelper.edgeInsets(context, 8, 16, 8, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'week', label: Text('Week')),
                            ButtonSegment(value: 'month', label: Text('Month')),
                            ButtonSegment(value: 'year', label: Text('Year')),
                          ],
                          selected: {_selectedTimeFilter},
                          onSelectionChanged: (newSelection) => setState(
                              () => _selectedTimeFilter = newSelection.first),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tag filter removed - only business transactions now
                Expanded(
                  child: ListView(
                    padding:
                        ResponsiveHelper.edgeInsets(context, 12, 20, 20, 20),
                    children: [
                      // Modernized Profit/Loss Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              profitLossData.color.withOpacity(0.25),
                              profitLossData.color.withOpacity(0.12),
                              profitLossData.color.withOpacity(0.05),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveHelper.radius(context, 28)),
                          border: Border.all(
                            color: profitLossData.color.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: profitLossData.color.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: ResponsiveHelper.edgeInsets(
                            context, 24, 20, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: ResponsiveHelper.edgeInsetsAll(
                                      context, 8),
                                  decoration: BoxDecoration(
                                    color:
                                        profitLossData.color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.radius(context, 10)),
                                  ),
                                  child: Icon(
                                    profitLossData.profitLoss >= 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    color: profitLossData.color,
                                    size:
                                        ResponsiveHelper.iconSize(context, 22),
                                  ),
                                ),
                                SizedBox(
                                    width:
                                        ResponsiveHelper.spacing(context, 10)),
                                Flexible(
                                  child: Text(
                                    'Business Profit/Loss',
                                    style: GoogleFonts.inter(
                                      fontSize: ResponsiveHelper.fontSize(
                                          context, 15),
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: 0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                                height: ResponsiveHelper.spacing(context, 16)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$_currencySymbol ${NumberFormat.currency(locale: 'en_US', symbol: '').format(profitLossData.profitLoss.abs())}',
                                style: GoogleFonts.inter(
                                  fontSize:
                                      ResponsiveHelper.fontSize(context, 32),
                                  fontWeight: FontWeight.bold,
                                  color: profitLossData.color,
                                  letterSpacing: -1,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ),
                            SizedBox(
                                height: ResponsiveHelper.spacing(context, 12)),
                            Container(
                              padding: ResponsiveHelper.edgeInsetsSymmetric(
                                  context, 14, 10),
                              decoration: BoxDecoration(
                                color: profitLossData.color.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.radius(context, 12)),
                                border: Border.all(
                                  color: profitLossData.color.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _selectedTimeFilter.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize:
                                      ResponsiveHelper.fontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: profitLossData.color,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            SizedBox(
                                height: ResponsiveHelper.spacing(context, 16)),
                            Container(
                              padding: ResponsiveHelper.edgeInsets(
                                  context, 14, 12, 12, 12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.8),
                                borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.radius(context, 14)),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: ResponsiveHelper.edgeInsetsAll(
                                        context, 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.radius(context, 8)),
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: ResponsiveHelper.iconSize(
                                          context, 16),
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  SizedBox(
                                      width: ResponsiveHelper.spacing(
                                          context, 10)),
                                  Expanded(
                                    child: Text(
                                      profitLossData.tip,
                                      style: GoogleFonts.inter(
                                        fontSize: ResponsiveHelper.fontSize(
                                            context, 12.5),
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.left,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                      // Modernized Income vs Expenses Card
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                              ResponsiveHelper.radius(context, 28)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: ResponsiveHelper.edgeInsets(
                            context, 22, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: ResponsiveHelper.edgeInsetsAll(
                                      context, 10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.radius(context, 12)),
                                  ),
                                  child: Icon(
                                    Icons.analytics_rounded,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    size:
                                        ResponsiveHelper.iconSize(context, 24),
                                  ),
                                ),
                                SizedBox(
                                    width:
                                        ResponsiveHelper.spacing(context, 12)),
                                Expanded(
                                  child: Text(
                                    'Income vs Expenses',
                                    style: GoogleFonts.inter(
                                      fontSize: ResponsiveHelper.fontSize(
                                          context, 20),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                                height: ResponsiveHelper.spacing(context, 16)),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final screenWidth =
                                    MediaQuery.of(context).size.width;
                                final isSmallScreen = screenWidth <= 400;
                                // Much smaller bar chart for small screens
                                final chartHeight = isSmallScreen
                                    ? screenWidth *
                                        0.55 // ~220px for 400px screen
                                    : ResponsiveHelper.height(context, 250);

                                return SizedBox(
                                  height: chartHeight,
                                  child: Builder(
                                    builder: (context) {
                                      final maxValue =
                                          (barChartData['Income']! >
                                                  barChartData['Expenses']!
                                              ? barChartData['Income']!
                                              : barChartData['Expenses']!);
                                      final safeMaxY = maxValue > 0
                                          ? maxValue * 1.15
                                          : 100.0;
                                      // Ensure interval is never zero - calculate interval or use a safe default
                                      final calculatedInterval =
                                          maxValue > 0 ? (maxValue / 5) : 20.0;
                                      final safeInterval =
                                          calculatedInterval > 0 &&
                                                  calculatedInterval.isFinite
                                              ? calculatedInterval
                                              : 20.0;

                                      return BarChart(
                                        BarChartData(
                                          alignment:
                                              BarChartAlignment.spaceAround,
                                          maxY: safeMaxY,
                                          barGroups: [
                                            _buildModernBarGroupData(
                                              0,
                                              barChartData['Income'] ?? 0,
                                              Colors.green.shade600,
                                              theme,
                                            ),
                                            _buildModernBarGroupData(
                                              1,
                                              barChartData['Expenses'] ?? 0,
                                              Colors.red.shade600,
                                              theme,
                                            ),
                                          ],
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  String text = '';
                                                  if (value.toInt() == 0)
                                                    text = 'Income';
                                                  if (value.toInt() == 1)
                                                    text = 'Expenses';
                                                  return Padding(
                                                    padding: EdgeInsets.only(
                                                        top: ResponsiveHelper
                                                            .spacing(
                                                                context, 8.0)),
                                                    child: Text(
                                                      text,
                                                      style: GoogleFonts.inter(
                                                        fontSize:
                                                            ResponsiveHelper
                                                                .fontSize(
                                                                    context,
                                                                    13),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize:
                                                    ResponsiveHelper.width(
                                                        context, 60),
                                                getTitlesWidget: (value, meta) {
                                                  if (value == 0)
                                                    return const Text('');
                                                  return Padding(
                                                    padding: EdgeInsets.only(
                                                        right: ResponsiveHelper
                                                            .spacing(
                                                                context, 8.0)),
                                                    child: Text(
                                                      compactFormatter
                                                          .format(value),
                                                      style: GoogleFonts.inter(
                                                        fontSize:
                                                            ResponsiveHelper
                                                                .fontSize(
                                                                    context,
                                                                    11),
                                                        color: theme.colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                interval: safeInterval,
                                              ),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                          ),
                                          borderData: FlBorderData(
                                            show: true,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: theme.colorScheme.outline
                                                    .withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                              left: BorderSide(
                                                color: theme.colorScheme.outline
                                                    .withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            horizontalInterval: safeInterval,
                                            getDrawingHorizontalLine: (value) =>
                                                FlLine(
                                              color: theme.colorScheme.outline
                                                  .withOpacity(0.15),
                                              strokeWidth: 1,
                                              dashArray: [5, 5],
                                            ),
                                          ),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData:
                                                BarTouchTooltipData(
                                              getTooltipColor: (group) =>
                                                  theme.colorScheme.surface,
                                              tooltipRoundedRadius: 8,
                                              tooltipPadding:
                                                  const EdgeInsets.all(8),
                                              tooltipMargin: 8,
                                              getTooltipItem: (group,
                                                  groupIndex, rod, rodIndex) {
                                                return BarTooltipItem(
                                                  '$_currencySymbol${NumberFormat.currency(locale: 'en_US', symbol: '').format(rod.toY)}',
                                                  GoogleFonts.inter(
                                                    color: theme
                                                        .colorScheme.onSurface,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: ResponsiveHelper
                                                        .fontSize(context, 12),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            SizedBox(
                                height: ResponsiveHelper.spacing(context, 20)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLegendItem(
                                  context,
                                  'Income',
                                  Colors.green.shade600,
                                  barChartData['Income'] ?? 0,
                                  theme,
                                ),
                                _buildLegendItem(
                                  context,
                                  'Expenses',
                                  Colors.red.shade600,
                                  barChartData['Expenses'] ?? 0,
                                  theme,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (expenseData.isNotEmpty) ...[
                        SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                        // Modernized Expense Breakdown Card
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                                ResponsiveHelper.radius(context, 28)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          padding: ResponsiveHelper.edgeInsets(
                              context, 22, 20, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: ResponsiveHelper.edgeInsetsAll(
                                        context, 10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.radius(context, 12)),
                                    ),
                                    child: Icon(
                                      Icons.pie_chart_rounded,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      size: ResponsiveHelper.iconSize(
                                          context, 24),
                                    ),
                                  ),
                                  SizedBox(
                                      width: ResponsiveHelper.spacing(
                                          context, 12)),
                                  Expanded(
                                    child: Text(
                                      'Expense Breakdown',
                                      style: GoogleFonts.inter(
                                        fontSize: ResponsiveHelper.fontSize(
                                            context, 20),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                  height:
                                      ResponsiveHelper.spacing(context, 20)),
                              // Pie Chart - smaller and better contained
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final screenWidth =
                                      MediaQuery.of(context).size.width;
                                  final isSmallScreen = screenWidth <= 400;
                                  final isVerySmall = screenWidth <= 380;

                                  // Smaller, more compact chart dimensions
                                  final chartSize = isVerySmall
                                      ? screenWidth *
                                          0.50 // ~190px for 380px screen
                                      : isSmallScreen
                                          ? screenWidth *
                                              0.55 // ~220px for 400px screen
                                          : ResponsiveHelper.width(context,
                                              220); // Smaller fixed size for larger screens

                                  // Proportional pie chart dimensions
                                  final centerSpaceRadius =
                                      chartSize * 0.15; // 15% of chart size
                                  final radius =
                                      chartSize * 0.35; // 35% of chart size

                                  return Column(
                                    children: [
                                      // Centered pie chart
                                      SizedBox(
                                        height: chartSize,
                                        width: chartSize,
                                        child: PieChart(
                                          PieChartData(
                                            sectionsSpace: 2,
                                            centerSpaceRadius:
                                                centerSpaceRadius,
                                            sections: expenseData.entries
                                                .map((entry) {
                                              final percentage = (entry.value /
                                                      totalExpenses) *
                                                  100;
                                              return PieChartSectionData(
                                                color:
                                                    _getModernColorForCategory(
                                                        entry.key, theme),
                                                value: entry.value,
                                                title: percentage > 5
                                                    ? '${percentage.toStringAsFixed(1)}%'
                                                    : '',
                                                radius: radius,
                                                titleStyle: GoogleFonts.inter(
                                                  fontSize:
                                                      ResponsiveHelper.fontSize(
                                                          context, 11),
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                badgeWidget: percentage <= 5
                                                    ? Container(
                                                        padding:
                                                            ResponsiveHelper
                                                                .edgeInsetsAll(
                                                                    context, 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .surface,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Text(
                                                          '${percentage.toStringAsFixed(0)}%',
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize:
                                                                ResponsiveHelper
                                                                    .fontSize(
                                                                        context,
                                                                        9),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface,
                                                          ),
                                                        ),
                                                      )
                                                    : null,
                                                badgePositionPercentageOffset:
                                                    1.2,
                                              );
                                            }).toList(),
                                            pieTouchData: PieTouchData(
                                              touchCallback:
                                                  (FlTouchEvent event,
                                                      pieTouchResponse) {},
                                              enabled: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                          height: ResponsiveHelper.spacing(
                                              context, 24)),
                                      // Legend below chart - properly spaced
                                      Wrap(
                                        spacing: ResponsiveHelper.spacing(
                                            context, 12),
                                        runSpacing: ResponsiveHelper.spacing(
                                            context, 10),
                                        alignment: WrapAlignment.center,
                                        children: expenseData.entries
                                            .map((entry) =>
                                                _buildCategoryLegendItem(
                                                  entry.key,
                                                  _getModernColorForCategory(
                                                      entry.key, theme),
                                                  entry.value,
                                                  totalExpenses,
                                                  theme,
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Container(
                          padding: ResponsiveHelper.edgeInsetsAll(context, 40),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                                ResponsiveHelper.radius(context, 28)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                size: ResponsiveHelper.iconSize(context, 64),
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.4),
                              ),
                              SizedBox(
                                  height:
                                      ResponsiveHelper.spacing(context, 16)),
                              Text(
                                'No Business Expense Data',
                                style: GoogleFonts.inter(
                                  fontSize:
                                      ResponsiveHelper.fontSize(context, 18),
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(
                                  height: ResponsiveHelper.spacing(context, 8)),
                              Text(
                                'Add transactions to see your expense breakdown',
                                style: GoogleFonts.inter(
                                  fontSize:
                                      ResponsiveHelper.fontSize(context, 14),
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Modernized PDF Export Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primaryContainer
                                  .withOpacity(0.7),
                              theme.colorScheme.primaryContainer
                                  .withOpacity(0.4),
                              theme.colorScheme.primaryContainer
                                  .withOpacity(0.3),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveHelper.radius(context, 24)),
                          border: Border.all(
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  theme.colorScheme.primary.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: ResponsiveHelper.edgeInsetsAll(context, 22),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Export Business Report',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'PDF with clean descriptions',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isExportingPDF
                                    ? null
                                    : () async {
                                        if (_currentUser != null &&
                                            !_isExportingPDF) {
                                          setState(
                                              () => _isExportingPDF = true);
                                          try {
                                            // Filter to only business transactions for PDF
                                            final businessTransactions =
                                                fullyFilteredTransactions
                                                    .where((t) =>
                                                        t.tag == 'business')
                                                    .toList();

                                            if (businessTransactions.isEmpty) {
                                              if (mounted) {
                                                setState(() =>
                                                    _isExportingPDF = false);
                                                NotificationHelper.showWarning(
                                                    this.context,
                                                    message:
                                                        'No business transactions found in the selected period. Cannot generate report.');
                                              }
                                              return;
                                            }

                                            final dateStr =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(DateTime.now());
                                            final fileName =
                                                'PatoTrack_Business_Report_$dateStr.pdf';

                                            await PdfHelper.generateAndSharePdf(
                                                businessTransactions,
                                                _currentUser.displayName ??
                                                    'User',
                                                fileName);
                                            if (mounted) {
                                              setState(() =>
                                                  _isExportingPDF = false);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              setState(() =>
                                                  _isExportingPDF = false);
                                              NotificationHelper.showError(
                                                  this.context,
                                                  message:
                                                      'Error generating report: $e');
                                            }
                                          }
                                        }
                                      },
                                icon: _isExportingPDF
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Icon(Icons.picture_as_pdf_rounded,
                                        size: ResponsiveHelper.iconSize(
                                            context, 22)),
                                label: Text(
                                  _isExportingPDF
                                      ? 'Generating...'
                                      : 'Generate PDF Report',
                                  style: GoogleFonts.inter(
                                    fontSize:
                                        ResponsiveHelper.fontSize(context, 16),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      vertical: ResponsiveHelper.buttonHeight(
                                          context, 16)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.radius(context, 16)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  BarChartGroupData _buildModernBarGroupData(
      int x, double y, Color color, ThemeData theme) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 50,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
          ),
        ),
      ],
    );
  }

  Color _getModernColorForCategory(String category, ThemeData theme) {
    // Modern color palette
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.pink.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.amber.shade600,
      Colors.red.shade600,
      Colors.cyan.shade600,
      Colors.deepPurple.shade600,
      Colors.lime.shade600,
    ];
    int hash = category.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color,
      double value, ThemeData theme) {
    return Container(
      padding: ResponsiveHelper.edgeInsetsSymmetric(context, 16, 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius:
            BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ResponsiveHelper.width(context, 12),
                height: ResponsiveHelper.width(context, 12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: ResponsiveHelper.fontSize(context, 13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          Text(
            '$_currencySymbol${NumberFormat.currency(locale: 'en_US', symbol: '').format(value)}',
            style: GoogleFonts.inter(
              fontSize: ResponsiveHelper.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLegendItem(String category, Color color, double value,
      double total, ThemeData theme) {
    final percentage = (value / total) * 100;
    return Builder(
      builder: (context) {
        return Container(
          padding: ResponsiveHelper.edgeInsetsSymmetric(context, 12, 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius:
                BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 10)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category,
                      style: GoogleFonts.inter(
                        fontSize: ResponsiveHelper.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                    Text(
                      '${percentage.toStringAsFixed(1)}% · $_currencySymbol${value.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: ResponsiveHelper.fontSize(context, 11),
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsLoadingState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const ReportsProfitLossShimmer(),
          const ChartShimmer(height: 320),
          const ChartShimmer(height: 320),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
