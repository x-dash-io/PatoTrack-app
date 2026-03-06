import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as model;
import '../models/category.dart';
import '../providers/currency_provider.dart';
import '../styles/app_colors.dart';
import '../styles/app_spacing.dart';
import '../app_icons.dart';
import '../helpers/mpesa_transaction_helper.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.category,
    required this.currency,
    required this.onTap,
    this.margin,
  });

  final model.Transaction transaction;
  final Category? category;
  final CurrencyProvider currency;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    
    // Card styling – slightly better than plain white
    final bgColor = isDark 
        ? AppColors.surfaceDark 
        : AppColors.surfaceLight;
    final borderColor = isDark 
        ? AppColors.surfaceBorderDark 
        : AppColors.surfaceBorderLight;

    final date = DateTime.tryParse(transaction.date) ?? DateTime.now();
    final dateLabel = DateFormat('MMM d, yyyy').format(date);
    
    final desc = transaction.description.isEmpty
        ? (isIncome ? 'Income' : 'Expense')
        : transaction.description;
        
    final categoryName = category?.name ?? '';
    final isMpesa = isMpesaTransaction(
      description: desc,
      categoryName: categoryName,
    );
    final isReceipt = transaction.source == 'receipt';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.1) 
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          // Subtle gradient for "better than plain white"
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark ? [
              AppColors.surfaceDark,
              AppColors.surfaceElevatedDark.withValues(alpha: 0.8),
            ] : [
              AppColors.surfaceLight,
              AppColors.bgLight.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Row(
          children: [
            // Icon section
            _buildIconPill(context, isDark, isMpesa, isReceipt, isIncome, amountColor),
            const SizedBox(width: 14),

            // Description + date + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                        ),
                      ),
                      if (category != null && category!.name.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category!.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.brandDark : AppColors.brand,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(
                    transaction.amount,
                    decimalDigits: 0,
                    includePositiveSign: isIncome,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                    letterSpacing: -0.4,
                  ),
                ),
                if (transaction.confidence < 0.9 && !transaction.isReviewed)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      AppIcons.priority_high_rounded,
                      size: 12,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPill(
    BuildContext context, 
    bool isDark, 
    bool isMpesa, 
    bool isReceipt, 
    bool isIncome,
    Color amountColor,
  ) {
    // Dynamic icon selection
    Widget iconWidget;
    Color pillBg;
    Color iconColor;

    if (isMpesa) {
      pillBg = const Color(0xFFE8F5E9); // Success-ish green for M-Pesa
      iconWidget = Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset('assets/mpesa_logo.png', fit: BoxFit.contain),
      );
    } else if (isReceipt) {
      pillBg = isDark ? AppColors.brandSoftDark : AppColors.brandSoft;
      iconColor = isDark ? AppColors.brandDark : AppColors.brand;
      iconWidget = Icon(AppIcons.receipt_long_rounded, color: iconColor, size: 20);
    } else if (category != null && category!.iconCodePoint != null) {
      pillBg = isDark ? AppColors.brandSoftDark : AppColors.brandSoft;
      iconColor = isDark ? AppColors.brandDark : AppColors.brand;
      iconWidget = Icon(
        IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons'), 
        color: iconColor, 
        size: 20
      );
    } else {
      // Fallback based on type
      pillBg = isDark 
          ? amountColor.withValues(alpha: 0.15) 
          : (isIncome ? AppColors.incomeSoft : AppColors.expenseSoft);
      iconColor = amountColor;
      iconWidget = Icon(
        isIncome ? AppIcons.arrow_downward_rounded : AppIcons.arrow_upward_rounded, 
        color: iconColor, 
        size: 20
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(child: iconWidget),
    );
  }
}
