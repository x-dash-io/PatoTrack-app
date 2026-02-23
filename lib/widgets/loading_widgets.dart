import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Loading widgets and skeleton placeholders.
///
/// Set [LoadingConfig.enableShimmer] to true if subtle shimmer is desired.
class LoadingConfig {
  static bool enableShimmer = false;
}

Color _skeletonBaseColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? Colors.grey[800]! : Colors.grey[300]!;
}

Color _skeletonHighlightColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? Colors.grey[700]! : Colors.grey[100]!;
}

Widget _withOptionalShimmer({
  required BuildContext context,
  required Widget child,
}) {
  if (!LoadingConfig.enableShimmer) {
    return child;
  }
  return Shimmer(
    baseColor: _skeletonBaseColor(context),
    highlightColor: _skeletonHighlightColor(context),
    child: child,
  );
}

/// Shimmer effect widget
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const Shimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Shimmer loading card for transactions
class TransactionShimmerCard extends StatelessWidget {
  const TransactionShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = _skeletonBaseColor(context);
    return _withOptionalShimmer(
      context: context,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          title: Container(
            height: 16,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              height: 12,
              width: 100,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          trailing: Container(
            height: 16,
            width: 80,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern loading indicator (Cupertino style)
class ModernLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const ModernLoadingIndicator({
    super.key,
    this.message,
    this.size = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    Widget indicator = isIOS
        ? const CupertinoActivityIndicator(radius: 12)
        : SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          );

    if (message != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          indicator,
          const SizedBox(height: 12),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Center(child: indicator);
  }
}

/// Full screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final VoidCallback? onCancel;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.08),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 200,
                  maxHeight: 120,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ModernLoadingIndicator(message: message),
              ),
            ),
          ),
        if (isLoading && onCancel != null)
          Positioned(
            top: 48,
            right: 16,
            child: FilledButton.tonalIcon(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
            ),
          ),
      ],
    );
  }
}

/// Shimmer list view for transaction lists
class TransactionShimmerList extends StatelessWidget {
  final int itemCount;

  const TransactionShimmerList({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const TransactionShimmerCard(),
    );
  }
}

/// Shimmer card widget (reusable)
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final skeletonColor = _skeletonBaseColor(context);
    return _withOptionalShimmer(
      context: context,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: skeletonColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer for category cards/list
class CategoryShimmerCard extends StatelessWidget {
  const CategoryShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = _skeletonBaseColor(context);
    return _withOptionalShimmer(
      context: context,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          title: Container(
            height: 16,
            width: 150,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: skeletonColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer list for categories
class CategoryShimmerList extends StatelessWidget {
  final int itemCount;

  const CategoryShimmerList({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const CategoryShimmerCard(),
    );
  }
}

/// Shimmer for reports screen - profit/loss card
class ReportsProfitLossShimmer extends StatelessWidget {
  const ReportsProfitLossShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = _skeletonBaseColor(context);
    return _withOptionalShimmer(
      context: context,
      child: Card(
        margin: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 16,
                width: 120,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 32,
                width: 200,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                width: 250,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer for charts
class ChartShimmer extends StatelessWidget {
  final double height;
  final double? width;

  const ChartShimmer({
    super.key,
    required this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final skeletonColor = _skeletonBaseColor(context);
    return _withOptionalShimmer(
      context: context,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: skeletonColor,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Shimmer for frequency/bill frequency items
class FrequencyShimmerCard extends StatelessWidget {
  const FrequencyShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = _skeletonBaseColor(context);
    return _withOptionalShimmer(
      context: context,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: skeletonColor,
              shape: BoxShape.circle,
            ),
          ),
          title: Container(
            height: 16,
            width: 120,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              height: 12,
              width: 100,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer list for frequencies
class FrequencyShimmerList extends StatelessWidget {
  final int itemCount;

  const FrequencyShimmerList({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const FrequencyShimmerCard(),
    );
  }
}

/// Shimmer for transaction detail screen
class TransactionDetailShimmer extends StatelessWidget {
  const TransactionDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = _skeletonBaseColor(context);
    return _withOptionalShimmer(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 200,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < 4; i++) ...[
              Container(
                height: 14,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
