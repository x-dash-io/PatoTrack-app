import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../helpers/mpesa_transaction_helper.dart';
import '../../../models/category.dart';
import '../../../models/transaction.dart' as model;
import '../../../providers/currency_provider.dart';
import '../../../styles/app_colors.dart';
import '../../../styles/app_shadows.dart';
import '../../../styles/app_spacing.dart';
import '../../../widgets/transaction_card.dart';

class RecentTransactionsSection extends StatelessWidget {
  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    required this.categories,
    required this.currency,
    required this.onViewAll,
    required this.onOpenTransaction,
    required this.onAddTransaction,
  });

  final List<model.Transaction> transactions;
  final List<Category> categories;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.brandSoftDark : AppColors.brandSoft,
                    borderRadius: AppSpacing.radiusFull,
                  ),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.brandDark : AppColors.brand,
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
                        .map((tx) {
                          final cat = categories.isEmpty 
                              ? null 
                              : categories.cast<Category?>().firstWhere(
                                  (c) => c?.id == tx.categoryId, 
                                  orElse: () => null
                                );
                          return TransactionCard(
                            transaction: tx,
                            category: cat,
                            currency: currency,
                            onTap: () => onOpenTransaction(tx),
                          );
                        })
                        .toList(),
                  ),
          ),
        ],
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
              AppIcons.receipt_long_rounded,
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
            icon: const Icon(AppIcons.add_rounded, size: 18),
            label: const Text('Add transaction'),
          ),
        ],
      ),
    );
  }
}
