import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_icons.dart';
import '../features/compliance/controllers/compliance_controller.dart';
import '../features/compliance/models/compliance_result.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  final ComplianceController _ctrl = ComplianceController();

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
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Consumer<ComplianceController>(builder: (context, ctrl, _) {
        final user = FirebaseAuth.instance.currentUser;
        return Scaffold(
          appBar: AppBar(
            title: Text('Compliance Check',
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
                              message: 'Checking compliance…')),
                    ])
                  : ctrl.result == null
                      ? const Center(child: Text('No data available'))
                      : _Body(result: ctrl.result!),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.result});
  final ComplianceResult result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
      children: [
        // Score donut
        Center(child: _ScoreDonut(result: result)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Bookkeeping Checklist (Last 90 Days)',
          style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...result.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ChecklistCard(item: item),
            )),
        const SizedBox(height: AppSpacing.md),
        _DisclaimerBox(),
      ],
    );
  }
}

// ─── Score Donut ──────────────────────────────────────────────────────────────

class _ScoreDonut extends StatelessWidget {
  const _ScoreDonut({required this.result});
  final ComplianceResult result;

  Color get _color {
    switch (result.overallStatus) {
      case ComplianceStatus.pass:
        return AppColors.income;
      case ComplianceStatus.warn:
        return AppColors.warning;
      case ComplianceStatus.fail:
        return AppColors.expense;
    }
  }

  String get _label {
    switch (result.overallStatus) {
      case ComplianceStatus.pass:
        return 'Compliant';
      case ComplianceStatus.warn:
        return 'Needs Work';
      case ComplianceStatus.fail:
        return 'Non-Compliant';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _DonutPainter(
              score: result.score,
              color: _color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${result.score.toInt()}%',
                style: GoogleFonts.manrope(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _color,
                  height: 1,
                ),
              ),
              Text(
                _label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double score;
  final Color color;

  const _DonutPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 18.0;
    const startAngle = -math.pi / 2;

    // Track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * (score / 100).clamp(0, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.score != score || old.color != color;
}

// ─── Checklist Card ───────────────────────────────────────────────────────────

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.item});
  final ComplianceItem item;

  IconData get _icon {
    switch (item.status) {
      case ComplianceStatus.pass:
        return AppIcons.check_circle_outline_rounded;
      case ComplianceStatus.warn:
        return AppIcons.warning_amber_rounded;
      case ComplianceStatus.fail:
        return AppIcons.error_outline_rounded;
    }
  }

  Color get _color {
    switch (item.status) {
      case ComplianceStatus.pass:
        return AppColors.income;
      case ComplianceStatus.warn:
        return AppColors.warning;
      case ComplianceStatus.fail:
        return AppColors.expense;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.radiusXl,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadows.subtle(),
      ),
      child: Row(
        children: [
          Icon(_icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(item.detail,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(item.pct * 100).toInt()}%',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800, fontSize: 14, color: color),
              ),
              Text('${(item.weight * 100).toInt()}% weight',
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Disclaimer ───────────────────────────────────────────────────────────────

class _DisclaimerBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceElevatedDark
            : AppColors.surfaceElevatedLight,
        borderRadius: AppSpacing.radiusXl,
      ),
      child: Row(
        children: [
          Icon(AppIcons.info_outline_rounded,
              size: 16,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This checklist reflects bookkeeping completeness only. It does not include tax computations, VAT, CRB scores, or legal compliance advice.',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
