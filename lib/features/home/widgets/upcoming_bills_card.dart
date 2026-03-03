import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pato_track/app_icons.dart';

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
    required this.onEditBill,
  });

  final List<Bill> bills;
  final CurrencyProvider currency;
  final VoidCallback onAddBill;
  final Future<void> Function(Bill bill) onPayBill;
  final Future<void> Function(Bill bill) onEditBill;

  @override
  State<UpcomingBillsCard> createState() => _UpcomingBillsCardState();
}

class _UpcomingBillsCardState extends State<UpcomingBillsCard> {
  bool _showAll = false;
  final Set<int> _payingBillIds = <int>{};

  Future<void> _handlePay(Bill bill) async {
    final billKey = bill.id ?? bill.hashCode;
    if (_payingBillIds.contains(billKey)) return;

    setState(() => _payingBillIds.add(billKey));
    try {
      await widget.onPayBill(bill);
    } finally {
      if (mounted) {
        setState(() => _payingBillIds.remove(billKey));
      }
    }
  }

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
                          onPay: () => _handlePay(bill),
                          onEdit: () => widget.onEditBill(bill),
                          isPaying:
                              _payingBillIds.contains(bill.id ?? bill.hashCode),
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
    required this.onEdit,
    required this.isPaying,
  });

  final Bill bill;
  final CurrencyProvider currency;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final bool isPaying;

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

            // Amount + actions column
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        onPressed: isPaying ? null : onEdit,
                        icon: const Icon(AppIcons.edit_rounded, size: 14),
                        tooltip: 'Edit bill',
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.surfaceElevatedDark
                              : AppColors.surfaceElevatedLight,
                          foregroundColor: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 30,
                      child: FilledButton(
                        onPressed: isPaying ? null : onPay,
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
                        child: isPaying
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Pay'),
                      ),
                    ),
                  ],
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
