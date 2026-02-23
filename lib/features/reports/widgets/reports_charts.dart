import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../providers/currency_provider.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final expenseSpots = points
        .map((point) => FlSpot(point.x, point.expense))
        .toList(growable: false);
    final incomeSpots = points
        .map((point) => FlSpot(point.x, point.income))
        .toList(growable: false);

    final labels = points
        .map((point) =>
            '${point.label}: income ${currency.format(point.income, decimalDigits: 0)}, expenses ${currency.format(point.expense, decimalDigits: 0)}')
        .join('. ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Income vs spending trend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap points to inspect values.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: 'Line chart showing income and spending trend. $labels',
                child: SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => colorScheme.surface,
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              final label = points[spot.x.toInt()].label;
                              return LineTooltipItem(
                                '$label\n${currency.format(spot.y, decimalDigits: 0)}',
                                Theme.of(context).textTheme.labelSmall!,
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            interval: _axisInterval(points),
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                currency.formatCompact(value),
                                style: Theme.of(context).textTheme.labelSmall,
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
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.25),
                          ),
                          bottom: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: _axisInterval(points),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                          strokeWidth: 1,
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: incomeSpots,
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: expenseSpots,
                          isCurved: true,
                          color: colorScheme.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const _LegendDot(color: Colors.green, label: 'Income'),
                  const SizedBox(width: AppSpacing.md),
                  _LegendDot(color: colorScheme.primary, label: 'Expenses'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _axisInterval(List<TrendPoint> points) {
    var maxY = 0.0;
    for (final point in points) {
      if (point.expense > maxY) {
        maxY = point.expense;
      }
      if (point.income > maxY) {
        maxY = point.income;
      }
    }

    if (maxY <= 0) {
      return 20;
    }

    return (maxY / 4).clamp(1, double.infinity);
  }

  static double _xInterval(List<TrendPoint> points) {
    if (points.length <= 8) {
      return 1;
    }
    if (points.length <= 16) {
      return 2;
    }
    return 4;
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
    final colorScheme = Theme.of(context).colorScheme;
    final topCategories = categories.take(6).toList(growable: false);

    if (topCategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'No expense categories to chart in this period yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final labels = topCategories
        .map((category) =>
            '${category.name}: ${currency.format(category.total, decimalDigits: 0)}')
        .join('. ');

    final maxY = topCategories
        .map((category) => category.total)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending by category',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Interactive bar chart for the current range.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: 'Bar chart showing category spending. $labels',
                child: SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY == 0 ? 100 : maxY * 1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => colorScheme.surface,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final category = topCategories[group.x.toInt()];
                            return BarTooltipItem(
                              '${category.name}\n${currency.format(rod.toY, decimalDigits: 0)}',
                              Theme.of(context).textTheme.labelSmall!,
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            interval: (maxY / 4).clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                currency.formatCompact(value),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= topCategories.length) {
                                return const SizedBox.shrink();
                              }
                              final name = topCategories[index].name;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  name.length > 8
                                      ? '${name.substring(0, 8)}…'
                                      : name,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.25),
                          ),
                          bottom: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval:
                            (maxY / 4).clamp(1, double.infinity),
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                          strokeWidth: 1,
                        ),
                      ),
                      barGroups: topCategories.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.total,
                              color: colorScheme.primary,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
