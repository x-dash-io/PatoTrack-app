import 'package:flutter/material.dart';

/// Shared spacing scale to remove ad-hoc hard-coded values.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ─── Semantic padding shortcuts ──────────────────────────────────────────
  static const EdgeInsets pageHorizontal =
      EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pageHorizontalCompact =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(lg);
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  // ─── Border radius tokens ─────────────────────────────────────────────────
  static const BorderRadius radiusXs   = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusSm   = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusMd   = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusLg   = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusXl   = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusXxl  = BorderRadius.all(Radius.circular(32));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(999));

  // Legacy aliases
  static const BorderRadius cardRadius = radiusLg;
  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(28));
}
