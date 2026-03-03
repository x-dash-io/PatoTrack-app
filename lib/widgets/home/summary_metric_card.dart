import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../helpers/responsive_helper.dart';
import '../../styles/app_shadows.dart';

class SummaryMetricCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final String currencySymbol;
  final double? percentage;
  final bool showTrend;
  final bool? isPositive;

  const SummaryMetricCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.currencySymbol,
    this.percentage,
    this.showTrend = false,
    this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_US', symbol: '');

    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(ResponsiveHelper.radius(context, 24)),
        color: color.withValues(alpha: 0.10),
        boxShadow: const [AppShadows.card],
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.radius(context, 24)),
          onTap: () {},
          child: Padding(
            padding: ResponsiveHelper.edgeInsetsAll(context, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: ResponsiveHelper.edgeInsetsAll(context, 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.radius(context, 12),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: ResponsiveHelper.iconSize(context, 22),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: ResponsiveHelper.fontSize(context, 13),
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (percentage != null && percentage! > 0)
                            Padding(
                              padding: EdgeInsets.only(
                                top: ResponsiveHelper.spacing(context, 2),
                              ),
                              child: Text(
                                '${percentage!.toStringAsFixed(1)}%',
                                style: GoogleFonts.manrope(
                                  fontSize:
                                      ResponsiveHelper.fontSize(context, 10),
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showTrend && isPositive != null)
                      Container(
                        padding:
                            ResponsiveHelper.edgeInsetsSymmetric(context, 6, 8),
                        decoration: BoxDecoration(
                          color: (isPositive! ? Colors.green : Colors.orange)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.radius(context, 8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive!
                                  ? AppIcons.arrow_upward_rounded
                                  : AppIcons.arrow_downward_rounded,
                              size: ResponsiveHelper.iconSize(context, 14),
                              color: isPositive! ? Colors.green : Colors.orange,
                            ),
                            SizedBox(
                              width: ResponsiveHelper.spacing(context, 2),
                            ),
                            Text(
                              isPositive! ? 'Good' : 'Low',
                              style: GoogleFonts.manrope(
                                fontSize:
                                    ResponsiveHelper.fontSize(context, 10),
                                color:
                                    isPositive! ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$currencySymbol ${currencyFormatter.format(amount)}',
                    style: GoogleFonts.manrope(
                      fontSize: ResponsiveHelper.fontSize(context, 20),
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
