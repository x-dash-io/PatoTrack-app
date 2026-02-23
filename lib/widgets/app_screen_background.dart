import 'package:flutter/material.dart';

class AppScreenBackground extends StatelessWidget {
  final Widget child;
  final bool includeSafeArea;
  final bool avoidBottomInset;

  const AppScreenBackground({
    super.key,
    required this.child,
    this.includeSafeArea = true,
    this.avoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final background = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                : colorScheme.primaryContainer.withValues(alpha: 0.44),
            colorScheme.surfaceContainerLowest,
            colorScheme.surface,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              size: 280,
              color: colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.2),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _GlowOrb(
              size: 240,
              color:
                  colorScheme.tertiary.withValues(alpha: isDark ? 0.12 : 0.18),
            ),
          ),
          if (includeSafeArea)
            SafeArea(
              bottom: avoidBottomInset,
              child: child,
            )
          else
            child,
        ],
      ),
    );

    return background;
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
