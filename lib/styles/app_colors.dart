import 'package:flutter/material.dart';

/// PatoTrack Design Tokens
/// Clean-light fintech palette — Monzo / N26 inspired
///
/// Primary brand: deep indigo-blue (#1A1F71 → #4F59E8)
/// Accent: vibrant coral (#FF5A5F) for CTAs and income highlights
/// Surface system: cloud white to warm gray scale
/// Semantic: fresh green (income), coral-red (expense), amber (warning)

class AppColors {
  AppColors._();

  // ─── Brand ───────────────────────────────────────────────────────────────
  static const Color brand = Color(0xFF3D5AFE);        // Primary action blue
  static const Color brandDeep = Color(0xFF1A237E);    // Deep navy for headers
  static const Color brandSoft = Color(0xFFE8EAFF);    // Tinted bg / chips
  static const Color brandMid = Color(0xFF7986FF);     // Lighter brand for icons

  // Dark-mode brand
  static const Color brandDark = Color(0xFF7986FF);
  static const Color brandSoftDark = Color(0xFF1A237E);

  // ─── Income / Expense Semantic ────────────────────────────────────────────
  static const Color income = Color(0xFF00C896);       // Emerald green
  static const Color incomeSoft = Color(0xFFE0FAF3);
  static const Color incomeDark = Color(0xFF00C896);

  static const Color expense = Color(0xFFFF4757);      // Vivid red
  static const Color expenseSoft = Color(0xFFFFECEE);
  static const Color expenseDark = Color(0xFFFF6B81);

  // ─── Warning / neutral semantic ──────────────────────────────────────────
  static const Color warning = Color(0xFFFFB300);
  static const Color warningSoft = Color(0xFFFFF8E1);

  static const Color neutral = Color(0xFF78909C);
  static const Color neutralSoft = Color(0xFFF0F2F5);

  // ─── Surface & Background (Light) ────────────────────────────────────────
  static const Color bgLight = Color(0xFFF7F8FC);      // Page background
  static const Color surfaceLight = Color(0xFFFFFFFF); // Card surface
  static const Color surfaceElevatedLight = Color(0xFFF0F2FA); // Elevated cards
  static const Color surfaceBorderLight = Color(0xFFE8EAF0); // Dividers & borders

  // ─── Surface & Background (Dark) ─────────────────────────────────────────
  static const Color bgDark = Color(0xFF0F1117);
  static const Color surfaceDark = Color(0xFF1A1D2E);
  static const Color surfaceElevatedDark = Color(0xFF222540);
  static const Color surfaceBorderDark = Color(0xFF2E3155);

  // ─── Text (Light) ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0D0F1A);
  static const Color textSecondary = Color(0xFF5A5F7A);
  static const Color textTertiary = Color(0xFF9398B2);
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // ─── Text (Dark) ─────────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF1F3FF);
  static const Color textSecondaryDark = Color(0xFF9DA3C8);
  static const Color textTertiaryDark = Color(0xFF5A5F7A);

  // ─── Dividers ────────────────────────────────────────────────────────────
  static const Color dividerLight = Color(0xFFEBEDF5);
  static const Color dividerDark = Color(0xFF2A2D45);

  // ─── Card Gradient Stops ─────────────────────────────────────────────────
  /// Hero balance card gradient (light)
  static const List<Color> heroGradientLight = [
    Color(0xFF3D5AFE),
    Color(0xFF1A237E),
  ];

  /// Hero balance card gradient (dark)
  static const List<Color> heroGradientDark = [
    Color(0xFF3949AB),
    Color(0xFF1A237E),
  ];

  /// Income card tint
  static const List<Color> incomeGradient = [
    Color(0xFF00C896),
    Color(0xFF00A67E),
  ];

  /// Expense card tint
  static const List<Color> expenseGradient = [
    Color(0xFFFF4757),
    Color(0xFFE53935),
  ];

  // ─── Category Icon Palette ────────────────────────────────────────────────
  static const Color cat1 = Color(0xFF5C6BC0); // indigo
  static const Color cat2 = Color(0xFFEF5350); // red
  static const Color cat3 = Color(0xFF26A69A); // teal
  static const Color cat4 = Color(0xFFFF7043); // deep orange
  static const Color cat5 = Color(0xFF7E57C2); // deep purple
  static const Color cat6 = Color(0xFF29B6F6); // light blue
  static const Color cat7 = Color(0xFF66BB6A); // green
  static const Color cat8 = Color(0xFFFFA726); // orange
}
