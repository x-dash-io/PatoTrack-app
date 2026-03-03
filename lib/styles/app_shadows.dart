import 'package:flutter/material.dart';

/// Centralized shadow tokens for a clean fintech elevation style.
class AppShadows {
  AppShadows._();

  static const BoxShadow card = BoxShadow(
    color: Color(0x0D1A237E),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const BoxShadow cardMd = BoxShadow(
    color: Color(0x141A237E),
    blurRadius: 20,
    offset: Offset(0, 6),
  );

  static const BoxShadow elevated = BoxShadow(
    color: Color(0x1A1A237E),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  static const BoxShadow nav = BoxShadow(
    color: Color(0x181A237E),
    blurRadius: 20,
    offset: Offset(0, -2),
  );

  static const BoxShadow button = BoxShadow(
    color: Color(0x3D3D5AFE),
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  /// Brand-tinted shadow for hero surfaces
  static const BoxShadow heroCard = BoxShadow(
    color: Color(0x4D1A237E),
    blurRadius: 32,
    offset: Offset(0, 12),
  );

  static List<BoxShadow> subtle([Color? tint]) {
    final color = tint ?? const Color(0xFF1A237E);
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.07),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static List<BoxShadow> brand = const [button];
}
