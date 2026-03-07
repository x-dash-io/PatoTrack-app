import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/trust_score_result.dart';
import '../../../styles/app_colors.dart';

class TrustScoreGauge extends StatefulWidget {
  const TrustScoreGauge({
    super.key,
    required this.score,
    required this.riskBand,
    this.size = 220,
  });

  final double score;
  final TrustRiskBand riskBand;
  final double size;

  @override
  State<TrustScoreGauge> createState() => _TrustScoreGaugeState();
}

class _TrustScoreGaugeState extends State<TrustScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _scoreAnim = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(TrustScoreGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _scoreAnim = Tween<double>(begin: old.score, end: widget.score).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _bandColor() {
    switch (widget.riskBand) {
      case TrustRiskBand.low:
        return AppColors.income;
      case TrustRiskBand.moderate:
        return const Color(0xFFF59E0B); // amber-500
      case TrustRiskBand.high:
        return AppColors.warning;
      case TrustRiskBand.critical:
        return AppColors.expense;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final arcColor = _bandColor();
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (context, _) {
        final displayScore = _scoreAnim.value;
        return SizedBox(
          width: widget.size,
          height: widget.size * 0.95,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arc painter
              CustomPaint(
                size: Size(widget.size, widget.size * 0.9),
                painter: _ArcPainter(
                  progress: displayScore / 100.0,
                  trackColor: trackColor,
                  arcColor: arcColor,
                  strokeWidth: widget.size * 0.09,
                ),
              ),
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: widget.size * 0.1),
                  Text(
                    displayScore.toInt().toString(),
                    style: GoogleFonts.manrope(
                      fontSize: widget.size * 0.22,
                      fontWeight: FontWeight.w800,
                      color: arcColor,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: widget.size * 0.03),
                  Text(
                    'out of 100',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: widget.size * 0.05),
                  _RiskBadge(band: widget.riskBand, color: arcColor),
                  SizedBox(height: widget.size * 0.02),
                  Text(
                    'Business Trust Score',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  static const _startAngle = 150.0; // degrees from 3-o'clock
  static const _sweepAngle = 240.0; // total arc sweep in degrees

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + strokeWidth * 0.3);
    final radius = (size.width - strokeWidth) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(
        rect, _deg(_startAngle), _deg(_sweepAngle), false, trackPaint);

    if (progress <= 0) return;

    // Value arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    canvas.drawArc(rect, _deg(_startAngle),
        _deg(_sweepAngle * progress.clamp(0, 1)), false, arcPaint);
  }

  double _deg(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.band, required this.color});
  final TrustRiskBand band;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        band.label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
