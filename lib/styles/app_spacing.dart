import 'package:flutter/material.dart';

/// Shared spacing scale to remove ad-hoc hard-coded values.
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pageHorizontalCompact =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(lg);

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(28));
}
