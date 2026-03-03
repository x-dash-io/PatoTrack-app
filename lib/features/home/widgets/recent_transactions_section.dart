import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/transaction.dart' as model;
import '../../../providers/currency_provider.dart';
import '../../../styles/app_colors.dart';
import '../../../styles/app_shadows.dart';
import '../../../styles/app_spacing.dart';

class RecentTransactionsSection extends StatelessWidget {
  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    required this.currency,
    required this.onViewAll,
    required this.onOpenTransaction,
    required this.onAddTransaction,
  });

  final List<model.Transaction> transactions;
  final CurrencyProvider currency;
  final VoidCallback onViewAll;
  final Future<void> Function(model.Transaction) onOpenTransaction;
  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          // Section header
          Row(
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.brandSoftDark
                        : AppColors.brandSoft,
                    borderRadius: AppSpacing.radiusFull,
                  ),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.brandDark
                          : AppColors.brand,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Transaction list
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: recent.isEmpty
                ? _EmptyState(onAddTransaction: onAddTransaction)
                : Column(
                    key: ValueKey<int>(recent.length),
                    children: recent
                        .map((tx) => _TransactionRow(
                              transaction: tx,
                              currency: currency,
                              onTap: () => onOpenTransaction(tx),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.currency,
    required this.onTap,
  });

  final model.Transaction transaction;
  final CurrencyProvider currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final bgColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight;

    final date = DateTime.tryParse(transaction.date) ?? DateTime.now();
    final dateLabel = DateFormat('MMM d').format(date);
    final desc = transaction.description.isEmpty
        ? transaction.type
        : transaction.description;

    return Semantics(
      button: true,
      label:
          '$desc, ${currency.format(transaction.amount, decimalDigits: 0)}, $dateLabel',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppSpacing.radiusLg,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: AppShadows.subtle(),
          ),
          child: Row(
            children: [
              // Icon pill
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? amountColor.withValues(alpha: 0.18)
                      : (isIncome
                          ? AppColors.incomeSoft
                          : AppColors.expenseSoft),
                  borderRadius: AppSpacing.radiusMd,
                ),
                child: Icon(
                  isIncome
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: amountColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Description + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                currency.format(
                  transaction.amount,
                  decimalDigits: 0,
                  includePositiveSign: isIncome,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTransaction});
  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey<String>('no-transactions'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppColors.brandSoftDark : AppColors.brandSoft,
              borderRadius: AppSpacing.radiusXl,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: isDark ? AppColors.brandDark : AppColors.brand,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first transaction to get started.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onAddTransaction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add transaction'),
          ),
        ],
      ),
    );
  }
}
