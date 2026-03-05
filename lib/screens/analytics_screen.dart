import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_icons.dart';
import '../features/analytics/controllers/analytics_controller.dart';
import '../features/analytics/models/analytics_result.dart';
import '../features/trust_score/controllers/trust_score_controller.dart';
import '../features/trust_score/models/trust_score_result.dart';
import '../features/trust_score/widgets/trust_score_gauge.dart';
import '../providers/currency_provider.dart';
import '../screens/trust_score_screen.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin<AnalyticsScreen> {
  final AnalyticsController _analyticsCtrl = AnalyticsController();
  final TrustScoreController _trustCtrl = TrustScoreController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _analyticsCtrl.initialize(user.uid);
      _trustCtrl.initialize(user.uid);
    }
  }

  @override
  void dispose() {
    _analyticsCtrl.dispose();
    _trustCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view analytics.')),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AnalyticsController>.value(
            value: _analyticsCtrl),
        ChangeNotifierProvider<TrustScoreController>.value(value: _trustCtrl),
      ],
      child: Consumer3<AnalyticsController, TrustScoreController,
          CurrencyProvider>(
        builder: (context, analytics, trust, currency, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Analytics',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              actions: [
                IconButton(
                  icon: const Icon(AppIcons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: () {
                    analytics.refresh(user.uid);
                    trust.refresh(user.uid);
                  },
                ),
              ],
            ),
            body: AppScreenBackground(
              includeSafeArea: false,
              child: RefreshIndicator(
                color: AppColors.brand,
                onRefresh: () async {
                  await analytics.refresh(user.uid);
                  await trust.refresh(user.uid);
                },
                child: analytics.isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: ModernLoadingIndicator(
                              message: 'Running AI analytics…',
                            ),
                          ),
                        ],
                      )
                    : analytics.errorMessage != null
                        ? _ErrorState(
                            message: analytics.errorMessage!,
                            onRetry: () => analytics.refresh(user.uid),
                          )
                        : _AnalyticsBody(
                            summary: analytics.summary!,
                            analytics: analytics,
                            trust: trust,
                            currency: currency,
                            userId: user.uid,
                          ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({
    required this.summary,
    required this.analytics,
    required this.trust,
    required this.currency,
    required this.userId,
  });

  final AnalyticsSummary summary;
  final AnalyticsController analytics;
  final TrustScoreController trust;
  final CurrencyProvider currency;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 100),
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _PeriodSelector(
            selected: analytics.selectedPeriod,
            onChanged: (p) => analytics.setPeriod(p, userId),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // KPI row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _KpiRow(summary: summary, currency: currency),
        ),
        const SizedBox(height: AppSpacing.md),

        // Forecast chart
        if (summary.forecast.hasEnoughData) ...[
          _SectionHeader(title: '3-Month Forecast', icon: AppIcons.trending_up_rounded),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _ForecastChartCard(
              forecast: summary.forecast,
              currency: currency,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Profitability ratios
        _SectionHeader(title: 'Profitability', icon: AppIcons.bar_chart_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _RatioGrid(ratios: summary.ratios, currency: currency),
        ),
        const SizedBox(height: AppSpacing.md),

        // Scenario modeling
        _SectionHeader(title: 'Scenario Outlook', icon: AppIcons.savings_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _ScenarioCard(scenarios: summary.scenarios, currency: currency),
        ),
        const SizedBox(height: AppSpacing.md),

        // AI Insights
        if (summary.insights.isNotEmpty) ...[
          _SectionHeader(
            title: 'AI Insights',
            icon: AppIcons.auto_awesome_rounded,
            badge: '${summary.insights.length}',
          ),
          ...summary.insights.map(
            (ins) => Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: _InsightCard(insight: ins),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Anomaly section
        if (summary.anomalies.isNotEmpty) ...[
          _SectionHeader(
            title: 'Anomalies Detected',
            icon: AppIcons.warning_amber_rounded,
            badge: '${summary.anomalies.length}',
          ),
          ...summary.anomalies.take(5).map(
                (a) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: _AnomalyTile(flag: a, currency: currency),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Trust Score card
        _SectionHeader(title: 'Business Trust Score', icon: AppIcons.shield_check_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _TrustCard(trust: trust),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector(
      {required this.selected, required this.onChanged});
  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = AnalyticsPeriod.values;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceElevatedDark
            : AppColors.surfaceElevatedLight,
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = p == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.surfaceDark : Colors.white)
                      : Colors.transparent,
                  borderRadius: AppSpacing.radiusSm,
                  boxShadow: isSelected ? AppShadows.subtle() : null,
                ),
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.brand
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.summary, required this.currency});
  final AnalyticsSummary summary;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final net = summary.netIncome;

    return Column(
      children: [
        // Net hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.heroGradientDark
                  : AppColors.heroGradientLight,
            ),
            borderRadius: AppSpacing.radiusXl,
            boxShadow: const [AppShadows.cardMd],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net ${summary.periodDays}d',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(net, decimalDigits: 0),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatPill(
                    label: 'Burn/day',
                    value: currency.format(summary.ratios.burnRate,
                        decimalDigits: 0),
                    color: AppColors.expense,
                  ),
                  const SizedBox(height: 4),
                  _StatPill(
                    label: 'Runway',
                    value: '${summary.ratios.runway.toInt()}d',
                    color: summary.ratios.runway < 30
                        ? AppColors.expense
                        : summary.ratios.runway < 90
                            ? AppColors.warning
                            : AppColors.income,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: 'Income',
                value: currency.format(summary.totalIncome, decimalDigits: 0),
                icon: AppIcons.arrow_downward_rounded,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                label: 'Expenses',
                value: currency.format(summary.totalExpenses, decimalDigits: 0),
                icon: AppIcons.arrow_upward_rounded,
                color: AppColors.expense,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppSpacing.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark
              ? AppColors.surfaceBorderDark
              : AppColors.surfaceBorderLight,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Forecast Chart ───────────────────────────────────────────────────────────

class _ForecastChartCard extends StatelessWidget {
  const _ForecastChartCard(
      {required this.forecast, required this.currency});
  final ForecastResult forecast;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPoints = [...forecast.history, ...forecast.forecast];
    if (allPoints.isEmpty) return const SizedBox.shrink();

    final histLen = forecast.history.length;

    // Build spots for net income
    final histSpots = forecast.history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.net))
        .toList();
    final forecastSpots = forecast.forecast
        .asMap()
        .entries
        .map((e) => FlSpot(
            (histLen + e.key).toDouble(), e.value.net))
        .toList();

    final allNets = allPoints.map((p) => p.net).toList();
    final minY =
        allNets.reduce((a, b) => a < b ? a : b) - forecast.confidenceBand;
    final maxY =
        allNets.reduce((a, b) => a > b ? a : b) + forecast.confidenceBand;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark
              ? AppColors.surfaceBorderDark
              : AppColors.surfaceBorderLight,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _LegendDot(
                  color: AppColors.brand, label: 'Historical'),
              const SizedBox(width: 12),
              _LegendDot(
                  color: AppColors.brand.withValues(alpha: 0.4),
                  label: 'Forecast',
                  dashed: true),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: (isDark
                            ? AppColors.surfaceBorderDark
                            : AppColors.surfaceBorderLight)
                        .withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= allPoints.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM').format(allPoints[idx].month),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      getTitlesWidget: (v, meta) => Text(
                        currency.format(v, decimalDigits: 0),
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  // Historical net line
                  LineChartBarData(
                    spots: histSpots,
                    isCurved: true,
                    color: AppColors.brand,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.brand.withValues(alpha: 0.07),
                    ),
                  ),
                  // Forecast dotted line
                  if (forecastSpots.isNotEmpty && histSpots.isNotEmpty)
                    LineChartBarData(
                      spots: [histSpots.last, ...forecastSpots],
                      isCurved: true,
                      color: AppColors.brand.withValues(alpha: 0.45),
                      barWidth: 2,
                      dashArray: const [6, 4],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, i) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.brand.withValues(alpha: 0.5),
                          strokeColor: Colors.transparent,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.brand.withValues(alpha: 0.04),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '± ${currency.format(forecast.confidenceBand, decimalDigits: 0)} confidence band (90%)',
            style: GoogleFonts.manrope(
              fontSize: 10,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(
      {required this.color, required this.label, this.dashed = false});
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            )),
      ],
    );
  }
}

// ─── Ratio Grid ───────────────────────────────────────────────────────────────

class _RatioGrid extends StatelessWidget {
  const _RatioGrid({required this.ratios, required this.currency});
  final ProfitabilityRatios ratios;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final items = [
      _RatioItem('Gross Margin',
          '${(ratios.grossMargin * 100).toStringAsFixed(1)}%',
          ratios.grossMargin > 0.35 ? AppColors.income : AppColors.warning),
      _RatioItem(
          'Operating Margin',
          '${(ratios.operatingMargin * 100).toStringAsFixed(1)}%',
          ratios.operatingMargin > 0.1
              ? AppColors.income
              : AppColors.expense),
      _RatioItem('Cash Velocity',
          '${currency.format(ratios.cashVelocity, decimalDigits: 0)}/d',
          AppColors.brand),
      _RatioItem('Burn Rate',
          '${currency.format(ratios.burnRate, decimalDigits: 0)}/d',
          AppColors.expense),
    ];

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.2,
      children: items.map((item) => _RatioTile(item: item)).toList(),
    );
  }
}

class _RatioItem {
  final String label;
  final String value;
  final Color color;
  const _RatioItem(this.label, this.value, this.color);
}

class _RatioTile extends StatelessWidget {
  const _RatioTile({required this.item});
  final _RatioItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark
              ? AppColors.surfaceBorderDark
              : AppColors.surfaceBorderLight,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.label,
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scenario Card ────────────────────────────────────────────────────────────

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard(
      {required this.scenarios, required this.currency});
  final ScenarioResult scenarios;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cases = [
      (scenarios.worst, AppColors.expense),
      (scenarios.base, AppColors.brand),
      (scenarios.best, AppColors.income),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark
              ? AppColors.surfaceBorderDark
              : AppColors.surfaceBorderLight,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: cases.map((entry) {
              final (sc, color) = entry;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.radiusFull,
                      ),
                      child: Text(
                        sc.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currency.format(sc.net3m, decimalDigits: 0),
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: sc.net3m >= 0
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ),
                    Text('3-mo net',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${sc.runway.toInt()}d runway',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24),
          Text('Revenue Sensitivity (3M)',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          ...scenarios.sensitivityNet.entries
              .where((e) => e.key != 'Base')
              .map((e) {
            final isPos = (e.value >= 0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: e.key.startsWith('+')
                                ? AppColors.income
                                : AppColors.expense)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (e.value.abs() /
                              (scenarios.sensitivityNet.values
                                      .reduce((a, b) => a.abs() > b.abs()
                                          ? a
                                          : b)
                                      .abs() +
                                  1))
                          .clamp(0, 1),
                      backgroundColor: (isDark
                              ? AppColors.surfaceElevatedDark
                              : AppColors.surfaceElevatedLight)
                          .withValues(alpha: 0.8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isPos ? AppColors.income : AppColors.expense),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currency.format(e.value, decimalDigits: 0),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPos ? AppColors.income : AppColors.expense),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Insight Card ─────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final AnalyticsInsight insight;

  Color _priorityColor() {
    switch (insight.priority) {
      case InsightPriority.critical:
        return AppColors.expense;
      case InsightPriority.warning:
        return AppColors.warning;
      case InsightPriority.opportunity:
        return AppColors.income;
      case InsightPriority.info:
        return AppColors.brand;
    }
  }

  IconData _priorityIcon() {
    switch (insight.priority) {
      case InsightPriority.critical:
        return AppIcons.error_outline_rounded;
      case InsightPriority.warning:
        return AppIcons.warning_amber_rounded;
      case InsightPriority.opportunity:
        return AppIcons.trending_up_rounded;
      case InsightPriority.info:
        return AppIcons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _priorityColor();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadows.subtle(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(_priorityIcon(), color: color, size: 17),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title,
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(insight.detail,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Anomaly Tile ─────────────────────────────────────────────────────────────

class _AnomalyTile extends StatelessWidget {
  const _AnomalyTile({required this.flag, required this.currency});
  final AnomalyFlag flag;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
        boxShadow: AppShadows.subtle(),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(AppIcons.warning_amber_rounded,
                color: AppColors.warning, size: 17),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flag.transaction.description.isEmpty
                      ? 'Transaction'
                      : flag.transaction.description,
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  flag.reasonLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(flag.transaction.amount, decimalDigits: 0),
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.warning),
              ),
              if (flag.zScore != 0)
                Text(
                  'z=${flag.zScore.toStringAsFixed(1)}',
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Trust Score Card ─────────────────────────────────────────────────────────

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.trust});
  final TrustScoreController trust;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = trust.result;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => const TrustScoreScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.radiusXl,
          border: Border.all(
            color: isDark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
          ),
          boxShadow: AppShadows.subtle(),
        ),
        child: trust.isLoading
            ? const Center(
                child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            : result == null
                ? Center(
                    child: Text('Trust score unavailable',
                        style: Theme.of(context).textTheme.bodySmall))
                : Row(
                    children: [
                      TrustScoreGauge(
                        score: result.totalScore,
                        riskBand: result.riskBand,
                        size: 130,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Business Trust Score',
                                style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to see full breakdown and improvement tips',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ScoreMini(
                                label: 'Health',
                                score: result.financialHealthScore,
                                max: 40,
                                color: AppColors.income),
                            const SizedBox(height: 4),
                            _ScoreMini(
                                label: 'Integrity',
                                score: result.integrityScore,
                                max: 30,
                                color: const Color(0xFF6366F1)),
                          ],
                        ),
                      ),
                      const Icon(AppIcons.chevron_right_rounded, size: 18),
                    ],
                  ),
      ),
    );
  }
}

class _ScoreMini extends StatelessWidget {
  const _ScoreMini(
      {required this.label,
      required this.score,
      required this.max,
      required this.color});
  final String label;
  final double score;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(label,
              style: TextStyle(fontSize: 10, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (score / max).clamp(0, 1),
              backgroundColor: isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.surfaceElevatedLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${score.toInt()}',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title, required this.icon, this.badge});
  final String title;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(badge!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error_outline_rounded,
                size: 48,
                color: AppColors.expense.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 14)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: Text('Retry', style: GoogleFonts.manrope()),
            ),
          ],
        ),
      ),
    );
  }
}
