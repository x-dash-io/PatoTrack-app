import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_icons.dart';
import '../features/advice/controllers/advice_controller.dart';
import '../features/advice/models/advice_models.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';

class AdviceScreen extends StatefulWidget {
  const AdviceScreen({super.key});

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  final AdviceController _ctrl = AdviceController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _ctrl.initialize(user.uid);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Consumer<AdviceController>(builder: (context, ctrl, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Financial Advice',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            actions: [
              if (user != null)
                IconButton(
                  icon: const Icon(AppIcons.refresh_rounded),
                  onPressed: () => ctrl.refresh(user.uid),
                ),
            ],
          ),
          body: AppScreenBackground(
            includeSafeArea: false,
            child: RefreshIndicator(
              color: AppColors.brand,
              onRefresh: () async {
                if (user != null) await ctrl.refresh(user.uid);
              },
              child: ctrl.isLoading
                  ? ListView(children: const [
                      SizedBox(height: 200),
                      Center(
                          child: ModernLoadingIndicator(
                              message: 'Generating advice…')),
                    ])
                  : ctrl.errorMessage != null
                      ? _ErrorView(
                          message: ctrl.errorMessage!,
                          onRetry: () {
                            if (user != null) ctrl.refresh(user.uid);
                          },
                        )
                      : _Body(ctrl: ctrl),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.ctrl});
  final AdviceController ctrl;

  @override
  Widget build(BuildContext context) {
    final summary = ctrl.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
      children: [
        // Insights
        if (summary != null && summary.insights.isNotEmpty) ...[
          _SectionTitle(
              title: 'AI Recommendations', icon: AppIcons.auto_awesome_rounded),
          const SizedBox(height: AppSpacing.sm),
          ...summary.insights
              .map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _InsightCard(insight: i),
                  ))
              ,
          const SizedBox(height: AppSpacing.md),
        ],

        // What-If modeler
        _SectionTitle(title: 'What-If Modeler', icon: AppIcons.lightbulb_rounded),
        const SizedBox(height: AppSpacing.sm),
        _WhatIfPanel(ctrl: ctrl),
      ],
    );
  }
}

// ─── Insight Card ─────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final AdviceInsight insight;

  (Color, IconData) _categoryStyle() {
    switch (insight.category) {
      case AdviceCategory.performance:
        return (AppColors.brand, AppIcons.bar_chart_rounded);
      case AdviceCategory.risk:
        return (AppColors.expense, AppIcons.warning_amber_rounded);
      case AdviceCategory.opportunity:
        return (AppColors.income, AppIcons.trending_up_rounded);
      case AdviceCategory.complianceLite:
        return (AppColors.warning, AppIcons.verified_rounded);
    }
  }

  String get _categoryLabel {
    switch (insight.category) {
      case AdviceCategory.performance:
        return 'Performance';
      case AdviceCategory.risk:
        return 'Risk';
      case AdviceCategory.opportunity:
        return 'Opportunity';
      case AdviceCategory.complianceLite:
        return 'Compliance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, icon) = _categoryStyle();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: AppShadows.subtle(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(insight.title,
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.radiusFull,
                      ),
                      child: Text(_categoryLabel,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(insight.body,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.45,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── What-If Panel ────────────────────────────────────────────────────────────

class _WhatIfPanel extends StatelessWidget {
  const _WhatIfPanel({required this.ctrl});
  final AdviceController ctrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const types = WhatIfType.values;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(
          color: isDark
              ? AppColors.surfaceBorderDark
              : AppColors.surfaceBorderLight,
        ),
        boxShadow: AppShadows.subtle(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a scenario:',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),

          // Type selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((t) {
              final selected = t == ctrl.selectedType;
              return GestureDetector(
                onTap: () => ctrl.setWhatIfType(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brand
                        : (isDark
                            ? AppColors.surfaceElevatedDark
                            : AppColors.surfaceElevatedLight),
                    borderRadius: AppSpacing.radiusFull,
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Scenario description
          Text(
            ctrl.selectedType.description,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Slider
          Text(ctrl.selectedType.paramLabel,
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          _WhatIfSlider(ctrl: ctrl),
          const SizedBox(height: AppSpacing.md),

          // Result card
          if (ctrl.whatIfResult != null) _WhatIfResult(result: ctrl.whatIfResult!),
        ],
      ),
    );
  }
}

class _WhatIfSlider extends StatelessWidget {
  const _WhatIfSlider({required this.ctrl});
  final AdviceController ctrl;

  (double, double) _range() {
    switch (ctrl.selectedType) {
      case WhatIfType.hireStaff:
        return (10000, 500000);
      case WhatIfType.priceChange:
        return (-30, 50);
      case WhatIfType.loanProceeds:
        return (10000, 2000000);
      case WhatIfType.majorClient:
        return (5000, 1000000);
    }
  }

  String _display(double v) {
    if (ctrl.selectedType == WhatIfType.priceChange) {
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}%';
    }
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final (min, max) = _range();
    final value = ctrl.whatIfParam.clamp(min, max);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_display(min),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              _display(value),
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.brand),
            ),
            Text(_display(max),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ctrl.selectedType == WhatIfType.priceChange ? 80 : 100,
          activeColor: AppColors.brand,
          inactiveColor: AppColors.brand.withValues(alpha: 0.2),
          onChanged: (v) => ctrl.setWhatIfParam(v),
        ),
      ],
    );
  }
}

class _WhatIfResult extends StatelessWidget {
  const _WhatIfResult({required this.result});
  final WhatIfResult result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netDelta = result.deltaNet3m;
    final runwayDelta = result.newRunway - result.baseRunway;
    final netColor = netDelta >= 0 ? AppColors.income : AppColors.expense;
    final runwayColor =
        runwayDelta >= 0 ? AppColors.income : AppColors.expense;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceElevatedDark
            : AppColors.surfaceElevatedLight,
        borderRadius: AppSpacing.radiusXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('3-Month Impact',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ImpactTile(
                  label: 'Net Change',
                  value: '${netDelta >= 0 ? '+' : ''}${_fmt(netDelta)}',
                  color: netColor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ImpactTile(
                  label: 'Runway',
                  value:
                      '${runwayDelta >= 0 ? '+' : ''}${runwayDelta.toInt()}d',
                  color: runwayColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.summary,
            style: GoogleFonts.manrope(
              fontSize: 12,
              height: 1.45,
              color:
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          if (result.breakEvenNote != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.info_outline_rounded,
                    size: 13,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    result.breakEvenNote!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v.abs() >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }
}

class _ImpactTile extends StatelessWidget {
  const _ImpactTile(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        ],
      ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color:
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(title,
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error_outline_rounded,
                size: 48,
                color: AppColors.expense.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 14)),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: onRetry,
                child: Text('Retry', style: GoogleFonts.manrope())),
          ],
        ),
      ),
    );
  }
}
