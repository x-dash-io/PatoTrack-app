import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/reports/controllers/reports_controller.dart';
import '../features/reports/widgets/reports_charts.dart';
import '../helpers/notification_helper.dart';
import '../providers/currency_provider.dart';
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
    if (user != null) {
      _reportsController.initialize(user.uid);
    }
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
    if (user == null) {
      return;
    }

    final error = await controller.exportReportPdf(
      userName: user.displayName ?? 'User',
      currencySymbol: currency.symbol,
    );

    if (!mounted) {
      return;
    }

    if (error == null) {
      NotificationHelper.showSuccess(
        context,
        message: 'Report exported. Check your share options.',
      );
    } else {
      NotificationHelper.showError(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Sign in to view reports.'),
        ),
      );
    }

    return ChangeNotifierProvider<ReportsController>.value(
      value: _reportsController,
      child: Consumer2<ReportsController, CurrencyProvider>(
        builder: (context, reports, currency, child) {
          final viewData = reports.viewData;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Reports'),
              actions: [
                IconButton(
                  onPressed: () => reports.refresh(user.uid),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh reports',
                ),
              ],
            ),
            body: AppScreenBackground(
              includeSafeArea: false,
              child: RefreshIndicator(
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
                          top: AppSpacing.sm,
                          bottom: 96,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: SegmentedButton<ReportsRange>(
                              segments: const [
                                ButtonSegment(
                                  value: ReportsRange.week,
                                  label: Text('Week'),
                                ),
                                ButtonSegment(
                                  value: ReportsRange.month,
                                  label: Text('Month'),
                                ),
                                ButtonSegment(
                                  value: ReportsRange.year,
                                  label: Text('Year'),
                                ),
                              ],
                              selected: {reports.selectedRange},
                              onSelectionChanged: (selection) {
                                reports.setRange(selection.first, user.uid);
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ScopeCard(
                            start: viewData?.periodStart,
                            end: viewData?.periodEnd,
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
                            _PerformanceSummaryCard(
                              income: viewData.totalIncome,
                              expenses: viewData.totalExpenses,
                              net: viewData.net,
                              currency: currency,
                            ),
                            const SizedBox(height: AppSpacing.sm),
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
                                  const SizedBox(height: AppSpacing.sm),
                                  CategoryBarChartCard(
                                    categories: viewData.categoryTotals,
                                    currency: currency,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Export PDF report',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Export includes business transactions only for the selected period.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: reports.isExporting
                                              ? null
                                              : () => _exportCurrentReport(
                                                    reports,
                                                    currency,
                                                  ),
                                          icon: reports.isExporting
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.picture_as_pdf_rounded,
                                                ),
                                          label: Text(
                                            reports.isExporting
                                                ? 'Generating…'
                                                : 'Generate report',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({required this.start, required this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final periodText = (start == null || end == null)
        ? 'Business transactions only'
        : 'Business transactions only • ${DateFormat('MMM d').format(start!)} - ${DateFormat('MMM d, yyyy').format(end!)} (inclusive)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  periodText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceSummaryCard extends StatelessWidget {
  const _PerformanceSummaryCard({
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
    final trendColor = net >= 0 ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net performance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                currency.format(net, decimalDigits: 0),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: trendColor,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ExpansionTile(
                title: const Text('Details'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                children: [
                  _SummaryRow(
                    label: 'Income',
                    value: currency.format(income, decimalDigits: 0),
                    color: Colors.green,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _SummaryRow(
                    label: 'Expenses',
                    value: currency.format(expenses, decimalDigits: 0),
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports unavailable',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No data for this period',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add business transactions to unlock spending and trend insights.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: onAddData,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
