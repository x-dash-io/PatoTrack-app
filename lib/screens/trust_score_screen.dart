import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/trust_score/controllers/trust_score_controller.dart';
import '../features/trust_score/models/trust_score_result.dart';
import '../features/trust_score/widgets/score_pillar_card.dart';
import '../features/trust_score/widgets/trust_score_gauge.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';
import '../app_icons.dart';

class TrustScoreScreen extends StatefulWidget {
  const TrustScoreScreen({super.key});

  @override
  State<TrustScoreScreen> createState() => _TrustScoreScreenState();
}

class _TrustScoreScreenState extends State<TrustScoreScreen>
    with AutomaticKeepAliveClientMixin<TrustScoreScreen> {
  final TrustScoreController _controller = TrustScoreController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _controller.initialize(user.uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to view your Trust Score.')));
    }

    return ChangeNotifierProvider<TrustScoreController>.value(
      value: _controller,
      child: Consumer<TrustScoreController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Trust Score',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              actions: [
                IconButton(
                  icon: const Icon(AppIcons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: () => controller.refresh(user.uid),
                ),
              ],
            ),
            body: AppScreenBackground(
              includeSafeArea: false,
              child: RefreshIndicator(
                color: AppColors.brand,
                onRefresh: () => controller.refresh(user.uid),
                child: controller.isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: ModernLoadingIndicator(
                              message: 'Computing your Trust Score…',
                            ),
                          ),
                        ],
                      )
                    : controller.errorMessage != null
                        ? _ErrorState(
                            message: controller.errorMessage!,
                            onRetry: () => controller.refresh(user.uid),
                          )
                        : _TrustScoreBody(result: controller.result!),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _TrustScoreBody extends StatelessWidget {
  const _TrustScoreBody({required this.result});
  final TrustScoreResult result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: 96,
      ),
      children: [
        // ── Gauge ─────────────────────────────────────────────────────
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: TrustScoreGauge(
              score: result.totalScore,
              riskBand: result.riskBand,
              size: 230,
            ),
          ),
        ),

        // ── Last computed ──────────────────────────────────────────────
        Center(
          child: Text(
            'Updated ${DateFormat('d MMM, h:mm a').format(result.computedAt)}',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── 4 Pillar cards ─────────────────────────────────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Score Breakdown',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _PillarGrid(result: result),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Factor detail ──────────────────────────────────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Factor Details',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _FactorSection(result: result),
        const SizedBox(height: AppSpacing.lg),

        // ── Improvement tips ───────────────────────────────────────────
        if (result.insights.isNotEmpty) ...[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'How to Improve',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InsightsList(insights: result.insights),
        ],
      ],
    );
  }
}

// ─── Pillar Grid ──────────────────────────────────────────────────────────────

class _PillarGrid extends StatelessWidget {
  const _PillarGrid({required this.result});
  final TrustScoreResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ScorePillarCard(
                label: 'Financial Health',
                score: result.financialHealthScore,
                maxScore: 40,
                icon: AppIcons.savings_rounded,
                color: AppColors.income,
                onTap: () {},
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ScorePillarCard(
                label: 'Integrity',
                score: result.integrityScore,
                maxScore: 30,
                icon: AppIcons.verified_rounded,
                color: const Color(0xFF6366F1), // indigo
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: ScorePillarCard(
                label: 'Compliance',
                score: result.complianceScore,
                maxScore: 20,
                icon: AppIcons.shield_check_rounded,
                color: AppColors.brand,
                onTap: () {},
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ScorePillarCard(
                label: 'Behavior',
                score: result.behaviorScore,
                maxScore: 10,
                icon: AppIcons.trending_up_rounded,
                color: const Color(0xFF0EA5E9), // sky-500
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Factor Section ───────────────────────────────────────────────────────────

class _FactorSection extends StatelessWidget {
  const _FactorSection({required this.result});
  final TrustScoreResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ExpandablePillar(
          title: 'Financial Health',
          score: result.financialHealthScore,
          maxScore: 40,
          color: AppColors.income,
          icon: AppIcons.savings_rounded,
          factors: [
            _Factor('Cash Flow Ratio', result.cashFlowPoints, 30,
                'Income vs expenses ratio'),
            _Factor('Expense Stability', result.expenseStabilityPoints, 7,
                'Month-to-month expense variance'),
            _Factor('Growth Trend', result.growthTrendPoints, 3,
                'Income growth vs previous month'),
          ],
        ),
        _ExpandablePillar(
          title: 'Transaction Integrity',
          score: result.integrityScore,
          maxScore: 30,
          color: const Color(0xFF6366F1),
          icon: AppIcons.verified_rounded,
          factors: [
            _Factor('Data Accuracy', result.dataAccuracyPoints, 15,
                'Transactions with all fields complete'),
            _Factor('Source Diversity', result.sourceDiversityPoints, 10,
                'Number of capture sources (manual, receipt, SMS)'),
            _Factor('Record Consistency', result.consistencyPoints, 5,
                'Max gap between transaction dates'),
          ],
        ),
        _ExpandablePillar(
          title: 'Compliance Readiness',
          score: result.complianceScore,
          maxScore: 20,
          color: AppColors.brand,
          icon: AppIcons.shield_check_rounded,
          factors: [
            _Factor('Documentation', result.documentationPoints, 10,
                'Expenses with attached receipt images'),
            _Factor('Record Notes', result.recordCompletenessPoints, 5,
                'Transactions with description / notes'),
            _Factor('Categorization', result.categorizationPoints, 5,
                'Transactions with a category assigned'),
          ],
        ),
        _ExpandablePillar(
          title: 'Financial Behavior',
          score: result.behaviorScore,
          maxScore: 10,
          color: const Color(0xFF0EA5E9),
          icon: AppIcons.trending_up_rounded,
          factors: [
            _Factor('Payment Timeliness', result.timelinessPoints, 5,
                'Bills paid on time'),
            _Factor('Budget Adherence', result.budgetAdherencePoints, 3,
                'Spending as % of income'),
            _Factor('Anomaly Detection', result.anomalyPoints, 2,
                'Unusual transactions flagged'),
          ],
        ),
      ],
    );
  }
}

class _Factor {
  final String name;
  final double points;
  final double maxPoints;
  final String description;
  _Factor(this.name, this.points, this.maxPoints, this.description);
}

class _ExpandablePillar extends StatefulWidget {
  const _ExpandablePillar({
    required this.title,
    required this.score,
    required this.maxScore,
    required this.color,
    required this.icon,
    required this.factors,
  });

  final String title;
  final double score;
  final double maxScore;
  final Color color;
  final IconData icon;
  final List<_Factor> factors;

  @override
  State<_ExpandablePillar> createState() => _ExpandablePillarState();
}

class _ExpandablePillarState extends State<_ExpandablePillar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Container(
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
          children: [
            // Header row
            InkWell(
              borderRadius: AppSpacing.radiusXl,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.color
                            .withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: AppSpacing.radiusSm,
                      ),
                      child: Icon(widget.icon,
                          color: widget.color, size: 17),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.score.toInt()}/${widget.maxScore.toInt()}',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: widget.color,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        AppIcons.expand_more_rounded,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded factor rows
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.surfaceBorderDark
                        : AppColors.surfaceBorderLight,
                  ),
                  ...widget.factors.map(
                    (f) => _FactorRow(
                      factor: f,
                      accentColor: widget.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor, required this.accentColor});
  final _Factor factor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress =
        factor.maxPoints > 0 ? (factor.points / factor.maxPoints).clamp(0, 1) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factor.name,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      factor.description,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${factor.points.toInt()}/${factor.maxPoints.toInt()}',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              backgroundColor: isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.surfaceElevatedLight,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Insights List ────────────────────────────────────────────────────────────

class _InsightsList extends StatelessWidget {
  const _InsightsList({required this.insights});
  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
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
          children: insights.asMap().entries.map((entry) {
            final idx = entry.key;
            final tip = entry.value;
            final isLast = idx == insights.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          tip,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: isDark
                        ? AppColors.surfaceBorderDark
                        : AppColors.surfaceBorderLight,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
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
              child: Text('Retry', style: GoogleFonts.manrope()),
            ),
          ],
        ),
      ),
    );
  }
}
