import 'package:flutter/material.dart';

/// Responsive helper class to handle dynamic sizing based on screen dimensions
class ResponsiveHelper {
  // Base screen dimensions (design reference - typically for a standard phone)
  // Increased base to make smaller screens scale down more aggressively
  static const double _baseWidth = 420.0;
  static const double _baseHeight = 800.0;

  // Get screen dimensions
  static double _getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double _getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double _getTextScaleFactor(BuildContext context) {
    return MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2);
  }

  // Calculate responsive width factor (much more aggressive scaling for small screens)
  static double _getWidthFactor(BuildContext context) {
    final width = _getWidth(context);
    // Very aggressive scaling for small screens (400 DPI typically has logical width ~360-400)
    if (width <= 400) {
      // For 400px and below, scale much more aggressively
      return (width / _baseWidth) *
          0.75; // This will give ~0.71 for 400px screen
    } else if (width <= 480) {
      return (width / _baseWidth) * 0.85;
    } else if (width <= 600) {
      return (width / _baseWidth) * 0.95;
    }
    return (width / _baseWidth).clamp(0.9, 1.15);
  }

  // Calculate responsive height factor
  static double _getHeightFactor(BuildContext context) {
    final height = _getHeight(context);
    final factor = height / _baseHeight;
    // Clamp between 0.8 and 1.2 for reasonable scaling
    return factor.clamp(0.8, 1.2);
  }

  // Get responsive font size
  static double fontSize(BuildContext context, double baseSize) {
    final width = _getWidth(context);
    final textScale = _getTextScaleFactor(context);

    // Balanced scaling - keep text readable while still being responsive
    double factor;
    if (width <= 380) {
      // Very small screens - scale down moderately
      factor = 0.80; // 20% reduction
    } else if (width <= 400) {
      // 400 DPI screens - scale down moderately
      factor = 0.82; // 18% reduction
    } else if (width <= 480) {
      factor = 0.88; // 12% reduction
    } else if (width <= 600) {
      factor = 0.94; // 6% reduction
    } else {
      factor = 1.0;
    }
    return (baseSize * factor * textScale)
        .clamp(baseSize * 0.7, baseSize * 1.0);
  }

  // Get responsive icon size
  static double iconSize(BuildContext context, double baseSize) {
    final width = _getWidth(context);

    // Fixed scaling factors for more predictable behavior
    double factor;
    if (width <= 380) {
      factor = 0.70; // 30% smaller
    } else if (width <= 400) {
      factor = 0.75; // 25% smaller
    } else if (width <= 480) {
      factor = 0.85; // 15% smaller
    } else if (width <= 600) {
      factor = 0.92; // 8% smaller
    } else {
      factor = 1.0;
    }
    return (baseSize * factor).clamp(baseSize * 0.65, baseSize * 1.05);
  }

  // Get responsive padding
  static double padding(BuildContext context, double basePadding) {
    final width = _getWidth(context);

    // MUCH more aggressive scaling - use fixed factors
    double factor;
    if (width <= 380) {
      factor = 0.65; // 35% reduction
    } else if (width <= 400) {
      factor = 0.70; // 30% reduction
    } else if (width <= 480) {
      factor = 0.80; // 20% reduction
    } else if (width <= 600) {
      factor = 0.88; // 12% reduction
    } else {
      factor = 1.0;
    }
    return (basePadding * factor).clamp(basePadding * 0.55, basePadding * 1.05);
  }

  // Get responsive spacing
  static double spacing(BuildContext context, double baseSpacing) {
    final width = _getWidth(context);

    // Fixed scaling factors
    double factor;
    if (width <= 380) {
      factor = 0.65;
    } else if (width <= 400) {
      factor = 0.70;
    } else if (width <= 480) {
      factor = 0.80;
    } else if (width <= 600) {
      factor = 0.88;
    } else {
      factor = 1.0;
    }
    return (baseSpacing * factor).clamp(baseSpacing * 0.6, baseSpacing * 1.05);
  }

  // Get responsive width
  static double width(BuildContext context, double baseWidth) {
    final widthFactor = _getWidthFactor(context);
    return baseWidth * widthFactor;
  }

  // Get responsive height
  static double height(BuildContext context, double baseHeight) {
    final heightFactor = _getHeightFactor(context);
    return baseHeight * heightFactor;
  }

  // Get responsive border radius
  static double radius(BuildContext context, double baseRadius) {
    final width = _getWidth(context);
    double factor;
    if (width <= 400) {
      factor = 0.85;
    } else if (width <= 480) {
      factor = 0.92;
    } else {
      factor = 1.0;
    }
    return (baseRadius * factor).clamp(baseRadius * 0.8, baseRadius * 1.1);
  }

  // Get responsive button height
  static double buttonHeight(BuildContext context, double baseHeight) {
    final width = _getWidth(context);
    double factor;
    if (width <= 400) {
      factor = 0.85;
    } else if (width <= 480) {
      factor = 0.92;
    } else {
      factor = 1.0;
    }
    return (baseHeight * factor).clamp(baseHeight * 0.8, baseHeight * 1.1);
  }

  // Check if screen is small
  static bool isSmallScreen(BuildContext context) {
    return _getWidth(context) < 400;
  }

  // Check if screen is medium
  static bool isMediumScreen(BuildContext context) {
    final width = _getWidth(context);
    return width >= 400 && width < 600;
  }

  // Check if screen is large
  static bool isLargeScreen(BuildContext context) {
    return _getWidth(context) >= 600;
  }

  // Get responsive EdgeInsets
  static EdgeInsets edgeInsets(
    BuildContext context,
    double top,
    double right,
    double bottom,
    double left,
  ) {
    return EdgeInsets.only(
      top: padding(context, top),
      right: padding(context, right),
      bottom: padding(context, bottom),
      left: padding(context, left),
    );
  }

  // Get responsive EdgeInsets symmetric
  static EdgeInsets edgeInsetsSymmetric(
    BuildContext context,
    double horizontal,
    double vertical,
  ) {
    return EdgeInsets.symmetric(
      horizontal: padding(context, horizontal),
      vertical: padding(context, vertical),
    );
  }

  // Get responsive EdgeInsets all
  static EdgeInsets edgeInsetsAll(BuildContext context, double value) {
    return EdgeInsets.all(padding(context, value));
  }
}
