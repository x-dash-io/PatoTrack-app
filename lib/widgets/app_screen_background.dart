import 'package:flutter/material.dart';
import '../styles/app_colors.dart';

/// Fintech-grade screen background.
/// Light: pure white page with a very subtle top gradient tint.
/// Dark: deep navy page.
class AppScreenBackground extends StatelessWidget {
  final Widget child;
  final bool includeSafeArea;
  final bool avoidBottomInset;
  final bool showTopAccent;

  const AppScreenBackground({
    super.key,
    required this.child,
    this.includeSafeArea = true,
    this.avoidBottomInset = true,
    this.showTopAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

    final content = includeSafeArea
        ? SafeArea(bottom: avoidBottomInset, child: child)
        : child;

    return ColoredBox(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showTopAccent)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark
                              ? AppColors.brand.withValues(alpha: 0.08)
                              : AppColors.brand.withValues(alpha: 0.04)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          content,
        ],
      ),
    );
  }
}
