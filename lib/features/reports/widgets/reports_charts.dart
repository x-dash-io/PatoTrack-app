import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../providers/currency_provider.dart';
import '../../../styles/app_colors.dart';
import '../../../styles/app_spacing.dart';
import '../models/reports_view_data.dart';

class SpendingTrendChartCard extends StatelessWidget {
  const SpendingTrendChartCard({
    super.key,
    required this.points,
    required this.currency,
  });

  final List<TrendPoint> points;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final axis = _axisScale(points);

    final expenseSpots =
        points.map((p) => FlSpot(p.x, p.expense)).toList(growable: false);
    final incomeSpots =
        points.map((p) => FlSpot(p.x, p.income)).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
            color: isDark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Income vs Spending', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            const Row(
              children: [
                _LegendDot(color: AppColors.income, label: 'Income'),
                SizedBox(width: AppSpacing.md),
                _LegendDot(color: AppColors.expense, label: 'Expenses'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: 'Line chart: income vs spending trend',
              child: SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minY: axis.min,
                    maxY: axis.max,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: axis.interval,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: (isDark
                                ? AppColors.surfaceBorderDark
                                : AppColors.surfaceBorderLight)
                            .withValues(alpha: 0.6),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => isDark
                            ? AppColors.surfaceElevatedDark
                            : AppColors.surfaceElevatedDark,
                        tooltipBorderRadius: BorderRadius.circular(10),
                        getTooltipItems: (spots) => spots.map((spot) {
                          final label = points[spot.x.toInt()].label;
                          return LineTooltipItem(
                            '$label\n${currency.format(spot.y, decimalDigits: 0)}',
                            theme.textTheme.labelSmall!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 96,
                          interval: axis.interval,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                currency.format(value, decimalDigits: 0),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _xInterval(points),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                points[index].label,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: incomeSpots,
                        isCurved: true,
                        color: AppColors.income,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          applyCutOffY: true,
                          cutOffY: 0,
                          color: AppColors.income.withValues(alpha: 0.08),
                        ),
                      ),
                      LineChartBarData(
                        spots: expenseSpots,
                        isCurved: true,
                        color: AppColors.expense,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          applyCutOffY: true,
                          cutOffY: 0,
                          color: AppColors.expense.withValues(alpha: 0.06),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _YAxisScale _axisScale(List<TrendPoint> points) {
    if (points.isEmpty) {
      return const _YAxisScale(min: 0, max: 1000, interval: 250);
    }

    double minValue = 0;
    double maxValue = 0;
    for (final point in points) {
      minValue = math.min(minValue, math.min(point.income, point.expense));
      maxValue = math.max(maxValue, math.max(point.income, point.expense));
    }

    if (minValue == maxValue) {
      if (maxValue == 0) {
        maxValue = 1000;
      } else {
        final pad = (maxValue.abs() * 0.2).clamp(1.0, double.infinity);
        minValue -= pad;
        maxValue += pad;
      }
    }

    final range = maxValue - minValue;
    final interval = _niceInterval(range / 4);

    final scaledMin = minValue < 0
        ? (minValue / interval).floorToDouble() * interval
        : 0.0;
    final scaledMax = maxValue > 0
        ? (maxValue / interval).ceilToDouble() * interval
        : 0.0;

    return _YAxisScale(
      min: scaledMin,
      max: scaledMax,
      interval: interval,
    );
  }

  static double _niceInterval(double rawStep) {
    if (rawStep <= 0) return 1;
    final exponent = (math.log(rawStep) / math.ln10).floor();
    final magnitude = math.pow(10.0, exponent).toDouble();
    final normalized = rawStep / magnitude;

    if (normalized <= 1) return magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  static double _xInterval(List<TrendPoint> points) {
    if (points.length <= 7) return 1;
    return (points.length / 6).ceilToDouble();
  }
}

class _YAxisScale {
  const _YAxisScale({
    required this.min,
    required this.max,
    required this.interval,
  });

  final double min;
  final double max;
  final double interval;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class CategoryBarChartCard extends StatelessWidget {
  const CategoryBarChartCard({
    super.key,
    required this.categories,
    required this.currency,
  });

  final List<CategoryTotal> categories;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (categories.isEmpty) return const SizedBox.shrink();

    final maxVal =
        categories.fold<double>(0, (m, c) => m < c.total ? c.total : m);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
            color: isDark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            ...categories.take(6).map((c) {
              final pct = maxVal > 0 ? c.total / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          currency.format(c.total, decimalDigits: 0),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? AppColors.surfaceElevatedDark
                            : AppColors.surfaceElevatedLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brand.withValues(alpha: 0.7 + pct * 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
