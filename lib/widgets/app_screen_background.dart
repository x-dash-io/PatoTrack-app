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
    final colorScheme = Theme.of(context).colorScheme;

    final background = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: _GlowOrb(
              size: 200,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -50,
            child: _GlowOrb(
              size: 150,
              color: colorScheme.tertiary.withValues(alpha: 0.05),
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
