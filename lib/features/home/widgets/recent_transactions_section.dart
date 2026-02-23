import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/transaction.dart' as model;
import '../../../providers/currency_provider.dart';
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
  final Future<void> Function(model.Transaction transaction) onOpenTransaction;
  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(5).toList();

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
                      'Recent transactions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: recent.isEmpty
                    ? _EmptyTransactions(onAddTransaction: onAddTransaction)
                    : ListView.builder(
                        key: ValueKey<int>(recent.length),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recent.length,
                        itemBuilder: (context, index) {
                          final transaction = recent[index];
                          final isIncome = transaction.type == 'income';
                          final amountColor =
                              isIncome ? Colors.green : Colors.red;

                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Semantics(
                              button: true,
                              label:
                                  '${transaction.description.isEmpty ? transaction.type : transaction.description}, ${currency.format(transaction.amount, decimalDigits: 0, includePositiveSign: isIncome)}, on ${DateFormat('MMM d').format(DateTime.tryParse(transaction.date) ?? DateTime.now())}',
                              child: ListTile(
                                onTap: () => onOpenTransaction(transaction),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                tileColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                leading: Icon(
                                  isIncome
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: amountColor,
                                ),
                                title: Text(
                                  transaction.description.isEmpty
                                      ? transaction.type
                                      : transaction.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  DateFormat('MMM d, yyyy').format(
                                    DateTime.tryParse(transaction.date) ??
                                        DateTime.now(),
                                  ),
                                ),
                                trailing: Text(
                                  currency.format(
                                    transaction.amount,
                                    decimalDigits: 0,
                                    includePositiveSign: isIncome,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: amountColor),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.onAddTransaction});

  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('no-transactions'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No transactions yet. Start by adding your first one.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onAddTransaction,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add transaction'),
          ),
        ],
      ),
    );
  }
}
