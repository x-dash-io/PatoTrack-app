import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../models/bill.dart';
import '../../../providers/currency_provider.dart';
import '../../../styles/app_colors.dart';
import '../../../styles/app_shadows.dart';
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
    final visible =
        _showAll || bills.length <= 3 ? bills : bills.take(3).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          // Section header
          Row(
            children: [
              Text(
                'Upcoming Bills',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onAddBill,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.brandSoftDark : AppColors.brandSoft,
                    borderRadius: AppSpacing.radiusFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.add_rounded,
                        size: 14,
                        color: isDark ? AppColors.brandDark : AppColors.brand,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add bill',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.brandDark : AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (bills.isEmpty)
            _EmptyBills(onAddBill: widget.onAddBill)
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey<String>('bills-$_showAll-${visible.length}'),
                children: visible
                    .map((bill) => _BillRow(
                          key: ValueKey<int?>(bill.id),
                          bill: bill,
                          currency: widget.currency,
                          onPay: () => widget.onPayBill(bill),
                        ))
                    .toList(),
              ),
            ),

          if (bills.length > 3)
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                  _showAll ? 'Show less' : 'Show ${bills.length - 3} more'),
            ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (statusLabel, statusColor) = days < 0
        ? ('Overdue', AppColors.expense)
        : days == 0
            ? ('Due today', AppColors.warning)
            : days <= 3
                ? ('Due in $days day${days == 1 ? '' : 's'}', AppColors.warning)
                : (
                    'Due ${DateFormat('MMM d').format(bill.dueDate)}',
                    isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary
                  );

    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight;

    return Semantics(
      label:
          '${bill.name}, ${currency.format(bill.amount, decimalDigits: 0)}, $statusLabel',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppSpacing.radiusLg,
          border: Border.all(
            color: days < 0
                ? AppColors.expense.withValues(alpha: 0.25)
                : borderColor,
            width: 1,
          ),
          boxShadow: AppShadows.subtle(),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: days < 0
                    ? AppColors.expenseSoft
                    : days <= 3
                        ? AppColors.warningSoft
                        : (isDark
                            ? AppColors.surfaceElevatedDark
                            : AppColors.surfaceElevatedLight),
                borderRadius: AppSpacing.radiusMd,
              ),
              child: Icon(
                days < 0
                    ? AppIcons.warning_amber_rounded
                    : AppIcons.receipt_outlined,
                color: statusColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Amount + Pay button column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(bill.amount, decimalDigits: 0),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    onPressed: onPay,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(62, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Pay'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills({required this.onAddBill});
  final VoidCallback onAddBill;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.warningSoft.withValues(alpha: 0.15)
                  : AppColors.warningSoft,
              borderRadius: AppSpacing.radiusMd,
            ),
            child: const Icon(
              AppIcons.calendar_today_outlined,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No upcoming bills. Tap Add bill to track due dates.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
