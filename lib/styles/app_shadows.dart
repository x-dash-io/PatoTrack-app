import 'package:flutter/material.dart';

/// Centralized shadow tokens for a clean, consistent elevation style.
class AppShadows {
  static const BoxShadow card = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  static const BoxShadow elevated = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 6,
    offset: Offset(0, 3),
  );

  static const BoxShadow nav = BoxShadow(
    color: Color(0x16000000),
    blurRadius: 6,
    offset: Offset(0, 4),
  );

  static List<BoxShadow> subtle([Color? tint]) {
    final color = tint ?? Colors.black;
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.08),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ];
  }
}
