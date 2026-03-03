import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';

import '../../../providers/currency_provider.dart';
import '../../../styles/app_colors.dart';
import '../../../styles/app_shadows.dart';
import '../../../styles/app_spacing.dart';

class SummaryCardsSection extends StatelessWidget {
  const SummaryCardsSection({
    super.key,
    required this.currency,
    required this.income,
    required this.expenses,
    required this.balance,
  });

  final CurrencyProvider currency;
  final double income;
  final double expenses;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: 'Income',
              value: currency.format(income, decimalDigits: 0),
              icon: AppIcons.arrow_downward_rounded,
              accentColor: AppColors.income,
              softColor: AppColors.incomeSoft,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _MetricCard(
              label: 'Expenses',
              value: currency.format(expenses, decimalDigits: 0),
              icon: AppIcons.arrow_upward_rounded,
              accentColor: AppColors.expense,
              softColor: AppColors.expenseSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.softColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: AppShadows.subtle(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon pill
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? accentColor.withValues(alpha: 0.18) : softColor,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
