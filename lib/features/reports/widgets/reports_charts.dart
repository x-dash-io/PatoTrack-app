import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../providers/currency_provider.dart';
import '../../../styles/app_theme.dart';
import '../../../styles/app_colors.dart';
import '../../../styles/app_shadows.dart';
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
    final colorScheme = theme.colorScheme;

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
            color: isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Income vs Spending', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _LegendDot(color: AppColors.income, label: 'Income'),
                const SizedBox(width: AppSpacing.md),
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
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _axisInterval(points),
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: (isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight)
                            .withValues(alpha: 0.6),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedDark,
                        tooltipRoundedRadius: 10,
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
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          interval: _axisInterval(points),
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              currency.formatCompact(value),
                              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
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
                                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
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

  static double _axisInterval(List<TrendPoint> points) {
    if (points.isEmpty) return 1000;
    final maxVal = points.fold<double>(0, (m, p) => m < p.income ? p.income : (m < p.expense ? p.expense : m));
    if (maxVal <= 0) return 1000;
    return (maxVal / 4).ceilToDouble();
  }

  static double _xInterval(List<TrendPoint> points) {
    if (points.length <= 7) return 1;
    return (points.length / 6).ceilToDouble();
  }
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

    final maxVal = categories.fold<double>(0, (m, c) => m < c.total ? c.total : m);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
            color: isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight,
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
                            c.categoryName,
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
