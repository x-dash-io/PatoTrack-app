import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/responsive_helper.dart';

/// Unified notification system for the entire app
/// Uses Material Design SnackBar for consistent UI
class NotificationHelper {
  /// Show a success notification
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.check_circle_rounded,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context, 20),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.fontSize(context, 15),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
        ),
        margin: ResponsiveHelper.edgeInsets(context, 16, 16, 16, 16),
        duration: duration,
      ),
    );
  }

  /// Show an error notification
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.error_rounded,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context, 20),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.fontSize(context, 15),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
        ),
        margin: ResponsiveHelper.edgeInsets(context, 16, 16, 16, 16),
        duration: duration,
      ),
    );
  }

  /// Show an info notification
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.info_rounded,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context, 20),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.fontSize(context, 15),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
        ),
        margin: ResponsiveHelper.edgeInsets(context, 16, 16, 16, 16),
        duration: duration,
      ),
    );
  }

  /// Show a warning notification
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.warning_rounded,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context, 20),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.fontSize(context, 15),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
        ),
        margin: ResponsiveHelper.edgeInsets(context, 16, 16, 16, 16),
        duration: duration,
      ),
    );
  }

  /// Show a custom notification with icon and color
  static void showCustom(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context, 20),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.fontSize(context, 15),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
        ),
        margin: ResponsiveHelper.edgeInsets(context, 16, 16, 16, 16),
        duration: duration,
      ),
    );
  }
}
