import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Modern dialog helpers using Cupertino design language

/// Shows a modern confirmation dialog with iOS-style design
Future<bool?> showModernConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  } else {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? Colors.red : null,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

/// Shows a modern information dialog
Future<void> showModernInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String buttonText = 'OK',
}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  } else {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

/// Shows a modern alert dialog with custom actions
Future<T?> showModernAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  List<CupertinoDialogAction>? actions,
  List<Widget>? materialActions,
}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: actions ?? [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } else {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: materialActions ?? [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Shows a modern bottom sheet (action sheet on iOS)
Future<T?> showModernBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
  bool enableDrag = true,
}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => child,
    );
  } else {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => child,
    );
  }
}

/// Shows an action sheet with options (iOS-style)
Future<T?> showActionSheet<T>({
  required BuildContext context,
  required String title,
  required List<ActionSheetAction<T>> actions,
  String? cancelText,
}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: actions
            .where((a) => !a.isCancel)
            .map((action) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(action.value),
                  child: Text(action.label),
                  isDestructiveAction: action.isDestructive,
                ))
            .toList(),
        cancelButton: cancelText != null
            ? CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(cancelText),
              )
            : null,
      ),
    );
  } else {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ...actions
              .where((a) => !a.isCancel)
              .map((action) => ListTile(
                    title: Text(
                      action.label,
                      style: TextStyle(
                        color: action.isDestructive ? Colors.red : null,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(action.value),
                  )),
          if (cancelText != null)
            ListTile(
              title: Text(
                cancelText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
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


