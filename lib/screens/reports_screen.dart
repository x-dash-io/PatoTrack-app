import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/reports/controllers/reports_controller.dart';
import '../features/reports/widgets/reports_charts.dart';
import '../helpers/notification_helper.dart';
import '../providers/currency_provider.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';
import 'add_transaction_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with AutomaticKeepAliveClientMixin<ReportsScreen> {
  final ReportsController _reportsController = ReportsController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _reportsController.initialize(user.uid);
  }

  @override
  void dispose() {
    _reportsController.dispose();
    super.dispose();
  }

  Future<void> _exportCurrentReport(
    ReportsController controller,
    CurrencyProvider currency,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final error = await controller.exportReportPdf(
      userName: user.displayName ?? 'User',
      currencySymbol: currency.symbol,
    );

    if (!mounted) return;

    if (error == null) {
      NotificationHelper.showSuccess(context,
          message: 'Report exported. Check your share options.');
    } else {
      NotificationHelper.showError(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in to view reports.')));
    }

    return ChangeNotifierProvider<ReportsController>.value(
      value: _reportsController,
      child: Consumer2<ReportsController, CurrencyProvider>(
        builder: (context, reports, currency, child) {
          final viewData = reports.viewData;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Reports'),
              actions: [
                IconButton(
                  onPressed: () => reports.refresh(user.uid),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            body: AppScreenBackground(
              includeSafeArea: false,
              child: RefreshIndicator(
                color: AppColors.brand,
                onRefresh: () => reports.refresh(user.uid),
                child: reports.isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(
                            child: ModernLoadingIndicator(
                              message: 'Building your reports…',
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.md,
                          bottom: 96,
                        ),
                        children: [
                          // Period selector
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            child: _PeriodSelector(
                              selected: reports.selectedRange,
                              onChanged: (r) =>
                                  reports.setRange(r, user.uid),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Scope notice
                          if (viewData != null)
                            _ScopeNotice(
                              start: viewData.periodStart,
                              end: viewData.periodEnd,
                            ),
                          const SizedBox(height: AppSpacing.sm),

                          if (reports.errorMessage != null)
                            _ErrorState(
                              message: reports.errorMessage!,
                              onRetry: () => reports.refresh(user.uid),
                            )
                          else if (viewData == null || !viewData.hasData)
                            _EmptyState(
                              onAddData: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const AddTransactionScreen(),
                                  ),
                                );
                                if (context.mounted) {
                                  reports.refresh(user.uid);
                                }
                              },
                            )
                          else ...[
                            // KPI row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              child: _KpiRow(
                                income: viewData.totalIncome,
                                expenses: viewData.totalExpenses,
                                net: viewData.net,
                                currency: currency,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              child: Column(
                                key: ValueKey<String>(
                                  'charts-${reports.selectedRange.name}-${viewData.businessTransactions.length}',
                                ),
                                children: [
                                  SpendingTrendChartCard(
                                    points: viewData.trendPoints,
                                    currency: currency,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  CategoryBarChartCard(
                                    categories: viewData.categoryTotals,
                                    currency: currency,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Export card
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              child: _ExportCard(
                                isExporting: reports.isExporting,
                                onExport: () => _exportCurrentReport(
                                    reports, currency),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final ReportsRange selected;
  final ValueChanged<ReportsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [
      (ReportsRange.week, 'Week'),
      (ReportsRange.month, 'Month'),
      (ReportsRange.year, 'Year'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Row(
        children: options.map((opt) {
          final (range, label) = opt;
          final isSelected = selected == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.surfaceDark : Colors.white)
                      : Colors.transparent,
                  borderRadius: AppSpacing.radiusSm,
                  boxShadow: isSelected ? AppShadows.subtle() : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

// ─── Scope Notice ─────────────────────────────────────────────────────────────

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice({required this.start, required this.end});
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = (start == null || end == null)
        ? 'Business transactions only'
        : 'Business only · ${DateFormat('MMM d').format(start!)} – ${DateFormat('MMM d, yyyy').format(end!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.income,
    required this.expenses,
    required this.net,
    required this.currency,
  });

  final double income;
  final double expenses;
  final double net;
  final CurrencyProvider currency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netColor = net >= 0 ? AppColors.income : AppColors.expense;
    final netBg = net >= 0 ? AppColors.incomeSoft : AppColors.expenseSoft;

    return Column(
      children: [
        // Net performance — full width hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark ? AppColors.heroGradientDark : AppColors.heroGradientLight,
            ),
            borderRadius: AppSpacing.radiusXl,
            boxShadow: const [AppShadows.cardMd],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net Performance',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  currency.format(net, decimalDigits: 0),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.radiusFull,
                ),
                child: Text(
                  net >= 0 ? 'In the green this period' : 'Spending exceeds income',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
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
                value: currency.format(income, decimalDigits: 0),
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
                softColor: AppColors.incomeSoft,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                label: 'Expenses',
                value: currency.format(expenses, decimalDigits: 0),
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
                softColor: AppColors.expenseSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.softColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight,
          width: 1,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? color.withValues(alpha: 0.18) : softColor,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Export Card ──────────────────────────────────────────────────────────────

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.isExporting, required this.onExport});
  final bool isExporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight,
          width: 1,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
              borderRadius: AppSpacing.radiusMd,
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export Report', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Business transactions for this period',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: isExporting ? null : onExport,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: isExporting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Export'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error / Empty states ─────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: _StateCard(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.expense,
        title: 'Reports unavailable',
        subtitle: message,
        buttonLabel: 'Retry',
        onAction: onRetry,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddData});
  final VoidCallback onAddData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: _StateCard(
        icon: Icons.bar_chart_rounded,
        iconColor: AppColors.brand,
        title: 'No data for this period',
        subtitle:
            'Add business transactions to unlock spending and trend insights.',
        buttonLabel: 'Add transaction',
        onAction: onAddData,
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: AppSpacing.radiusMd,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
