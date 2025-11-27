import 'package:flutter/material.dart';

/// Responsive helper class to handle dynamic sizing based on screen dimensions
class ResponsiveHelper {
  // Base screen dimensions (design reference - typically for a standard phone)
  static const double _baseWidth = 360.0;
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
  
  // Calculate responsive width factor (0.8 to 1.2 range for most screens)
  static double _getWidthFactor(BuildContext context) {
    final width = _getWidth(context);
    final factor = width / _baseWidth;
    // Clamp between 0.8 and 1.3 for reasonable scaling
    return factor.clamp(0.8, 1.3);
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
    final widthFactor = _getWidthFactor(context);
    final textScale = _getTextScaleFactor(context);
    // Use the smaller factor to prevent oversized text
    final factor = (widthFactor < 1.0) ? widthFactor : 1.0 + (widthFactor - 1.0) * 0.5;
    return (baseSize * factor * textScale).clamp(baseSize * 0.85, baseSize * 1.15);
  }
  
  // Get responsive icon size
  static double iconSize(BuildContext context, double baseSize) {
    final widthFactor = _getWidthFactor(context);
    final factor = (widthFactor < 1.0) ? widthFactor : 1.0 + (widthFactor - 1.0) * 0.6;
    return (baseSize * factor).clamp(baseSize * 0.8, baseSize * 1.2);
  }
  
  // Get responsive padding
  static double padding(BuildContext context, double basePadding) {
    final widthFactor = _getWidthFactor(context);
    final factor = (widthFactor < 1.0) ? widthFactor : 1.0 + (widthFactor - 1.0) * 0.5;
    return (basePadding * factor).clamp(basePadding * 0.75, basePadding * 1.25);
  }
  
  // Get responsive spacing
  static double spacing(BuildContext context, double baseSpacing) {
    final widthFactor = _getWidthFactor(context);
    final factor = (widthFactor < 1.0) ? widthFactor : 1.0 + (widthFactor - 1.0) * 0.5;
    return (baseSpacing * factor).clamp(baseSpacing * 0.8, baseSpacing * 1.2);
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
    final widthFactor = _getWidthFactor(context);
    final factor = (widthFactor < 1.0) ? widthFactor : 1.0 + (widthFactor - 1.0) * 0.3;
    return (baseRadius * factor).clamp(baseRadius * 0.85, baseRadius * 1.15);
  }
  
  // Get responsive button height
  static double buttonHeight(BuildContext context, double baseHeight) {
    final widthFactor = _getWidthFactor(context);
    final factor = (widthFactor < 1.0) ? widthFactor : 1.0 + (widthFactor - 1.0) * 0.4;
    return (baseHeight * factor).clamp(baseHeight * 0.85, baseHeight * 1.15);
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

