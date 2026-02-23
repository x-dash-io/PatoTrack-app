import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern Material Design 3 dialog helpers

/// Shows a modern confirmation dialog with Material 3 design
Future<bool?> showModernConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
}) async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      ),
      content: Text(
        message,
        style: GoogleFonts.manrope(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelText,
            style: GoogleFonts.manrope(),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor:
                isDestructive ? colorScheme.error : colorScheme.primary,
            foregroundColor:
                isDestructive ? colorScheme.onError : colorScheme.onPrimary,
          ),
          child: Text(
            confirmText,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Shows a modern information dialog
Future<void> showModernInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String buttonText = 'OK',
}) async {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      ),
      content: Text(
        message,
        style: GoogleFonts.manrope(),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            buttonText,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Shows a modern alert dialog with custom actions
Future<T?> showModernAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  List<Widget>? actions,
}) async {
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      ),
      content: message != null
          ? Text(
              message,
              style: GoogleFonts.manrope(),
            )
          : null,
      actions: actions ??
          [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
    ),
  );
}

/// Shows a modern bottom sheet with Material 3 styling
Future<T?> showModernBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = false,
  double? height,
}) async {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Container(
      height: height,
      constraints: height == null
          ? BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            )
          : null,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: child,
    ),
  );
}

/// Shows an action sheet with options (Material 3 style)
Future<T?> showActionSheet<T>({
  required BuildContext context,
  required String title,
  required List<ActionSheetAction<T>> actions,
  String? cancelText,
}) async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ...actions.where((a) => !a.isCancel).map((action) => ListTile(
                      title: Text(
                        action.label,
                        style: GoogleFonts.manrope(
                          color:
                              action.isDestructive ? colorScheme.error : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(action.value),
                    )),
                if (cancelText != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: Text(
                      cancelText,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Action sheet action model
class ActionSheetAction<T> {
  final String label;
  final T value;
  final bool isDestructive;
  final bool isCancel;

  const ActionSheetAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
    this.isCancel = false,
  });
}
