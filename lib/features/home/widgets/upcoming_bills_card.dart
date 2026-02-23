import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/bill.dart';
import '../../../providers/currency_provider.dart';
import '../../../styles/app_spacing.dart';

class UpcomingBillsCard extends StatefulWidget {
  const UpcomingBillsCard({
    super.key,
    required this.bills,
    required this.currency,
    required this.onAddBill,
    required this.onPayBill,
  });

  final List<Bill> bills;
  final CurrencyProvider currency;
  final VoidCallback onAddBill;
  final Future<void> Function(Bill bill) onPayBill;

  @override
  State<UpcomingBillsCard> createState() => _UpcomingBillsCardState();
}

class _UpcomingBillsCardState extends State<UpcomingBillsCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final bills = widget.bills;
    final visibleBills =
        _showAll || bills.length <= 3 ? bills : bills.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upcoming bills',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onAddBill,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (bills.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'No upcoming bills yet. Add one to keep due dates visible.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Column(
                    key: ValueKey<String>(
                        'bills-$_showAll-${visibleBills.length}'),
                    children: [
                      for (final bill in visibleBills)
                        _BillRow(
                          key: ValueKey<int?>(bill.id),
                          bill: bill,
                          currency: widget.currency,
                          onPay: () {
                            widget.onPayBill(bill);
                          },
                        ),
                    ],
                  ),
                ),
              if (bills.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll ? 'Show less' : 'Show more'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    super.key,
    required this.bill,
    required this.currency,
    required this.onPay,
  });

  final Bill bill;
  final CurrencyProvider currency;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueDay =
        DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = dueDay.difference(today).inDays;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    final status = days < 0
        ? 'Overdue'
        : days == 0
            ? 'Due today'
            : 'Due in $days day${days == 1 ? '' : 's'}';

    final statusColor = days < 0
        ? Colors.red
        : days == 0
            ? Colors.orange
            : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        label:
            '${bill.name}, ${currency.format(bill.amount, decimalDigits: 0)}, due ${DateFormat('MMM d').format(bill.dueDate)}',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useStackedLayout =
                  constraints.maxWidth < 360 || textScale > 1.15;

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${currency.format(bill.amount, decimalDigits: 0)} • $status',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusColor,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );

              final payButton = FilledButton(
                onPressed: onPay,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(88, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Pay'),
              );

              if (useStackedLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: payButton,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AppSpacing.sm),
                  payButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
