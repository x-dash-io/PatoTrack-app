import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';

/// PatoTrack Design System — Clean-light fintech theme (Monzo / N26 inspired)
///
/// Typography:
///   Display / Headlines : DM Sans  — geometric, confident, modern
///   Body / UI labels    : Inter    — legible, neutral workhorse
///
/// Colour system defined in AppColors.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark ? _darkScheme : _lightScheme;
    final textTheme   = _textTheme(isDark, colorScheme);

    final fieldRadius    = BorderRadius.circular(14);
    final fieldBorderSide = BorderSide(
      color: isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight,
      width: 1.2,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: fieldBorderSide,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.bgDark : AppColors.bgLight,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      dividerColor: isDark
          ? AppColors.dividerDark
          : AppColors.dividerLight,

      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusXl,
          side: BorderSide(
            color: isDark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shadowColor: Colors.transparent,
      ),

      // ── Input fields ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceElevatedDark
            : AppColors.surfaceElevatedLight,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(
            color: AppColors.brand,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.expense, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.expense, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColors.brand,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor:
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          size: 22,
        ),
      ),

      // ── Navigation Bar ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        indicatorColor: AppColors.brandSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.brand
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppColors.brand
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary),
            size: 22,
          );
        }),
      ),

      // ── Buttons ──────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 15,
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          minimumSize: const Size(0, 50),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.brandDark : AppColors.brand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
            color: isDark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1.4,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 15,
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(0, 50),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.brandDark : AppColors.brand,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        ),
      ),

      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
      ),

      // ── Bottom Sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        elevation: 0,
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.sheetRadius,
        ),
        dragHandleColor: isDark
            ? AppColors.surfaceBorderDark
            : AppColors.surfaceBorderLight,
        dragHandleSize: const Size(40, 4),
      ),

      // ── Dialogs ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          height: 1.5,
        ),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(
          color: isDark
              ? AppColors.surfaceBorderDark
              : AppColors.surfaceBorderLight,
          width: 1,
        ),
        backgroundColor:
            isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Segmented button ─────────────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // ── List tiles ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        tileColor: Colors.transparent,
      ),

      // ── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : (isDark ? AppColors.textSecondaryDark : AppColors.textTertiary);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.brand
              : (isDark
                  ? AppColors.surfaceBorderDark
                  : AppColors.surfaceBorderLight);
        }),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),

      extensions: const [],
      shadowColor: const Color(0x0D1A237E),
    );
  }

  // ─── Color Schemes ────────────────────────────────────────────────────────

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brand,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brandSoft,
    onPrimaryContainer: AppColors.brandDeep,
    secondary: AppColors.income,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.incomeSoft,
    onSecondaryContainer: Color(0xFF004D3A),
    tertiary: AppColors.expense,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.expenseSoft,
    onTertiaryContainer: Color(0xFF7A0000),
    error: AppColors.expense,
    onError: Colors.white,
    errorContainer: AppColors.expenseSoft,
    onErrorContainer: Color(0xFF7A0000),
    surface: AppColors.surfaceLight,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceElevatedLight,
    surfaceContainerHigh: AppColors.neutralSoft,
    surfaceContainer: AppColors.bgLight,
    surfaceContainerLow: Colors.white,
    surfaceContainerLowest: Colors.white,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.surfaceBorderLight,
    outlineVariant: Color(0xFFDDE0EC),
    shadow: Color(0x0D1A237E),
    scrim: Color(0x52000000),
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.brandMid,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.brandDark,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brandSoftDark,
    onPrimaryContainer: AppColors.brandMid,
    secondary: AppColors.incomeDark,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF003D2E),
    onSecondaryContainer: AppColors.incomeDark,
    tertiary: AppColors.expenseDark,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF4A0010),
    onTertiaryContainer: AppColors.expenseDark,
    error: AppColors.expenseDark,
    onError: Colors.white,
    errorContainer: Color(0xFF4A0010),
    onErrorContainer: AppColors.expenseDark,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.textPrimaryDark,
    surfaceContainerHighest: AppColors.surfaceElevatedDark,
    surfaceContainerHigh: Color(0xFF1E2235),
    surfaceContainer: AppColors.bgDark,
    surfaceContainerLow: Color(0xFF141629),
    surfaceContainerLowest: AppColors.bgDark,
    onSurfaceVariant: AppColors.textSecondaryDark,
    outline: AppColors.surfaceBorderDark,
    outlineVariant: Color(0xFF1E2235),
    shadow: Color(0x4D000000),
    scrim: Color(0x73000000),
    inverseSurface: AppColors.textPrimaryDark,
    onInverseSurface: AppColors.bgDark,
    inversePrimary: AppColors.brand,
  );

  // ─── Text Theme ───────────────────────────────────────────────────────────

  static TextTheme _textTheme(bool isDark, ColorScheme scheme) {
    final primary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final tertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiary;

    return TextTheme(
      // Display
      displayLarge: GoogleFonts.dmSans(
        fontSize: 56, fontWeight: FontWeight.w700,
        letterSpacing: -1.2, color: primary,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 44, fontWeight: FontWeight.w700,
        letterSpacing: -0.8, color: primary,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 36, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: primary,
      ),

      // Headlines
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 32, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: primary,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 28, fontWeight: FontWeight.w700,
        letterSpacing: -0.4, color: primary,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 24, fontWeight: FontWeight.w700,
        letterSpacing: -0.3, color: primary,
      ),

      // Titles
      titleLarge: GoogleFonts.dmSans(
        fontSize: 20, fontWeight: FontWeight.w700,
        letterSpacing: -0.2, color: primary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600,
        letterSpacing: -0.1, color: primary,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: primary,
      ),

      // Body
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        height: 1.5, color: primary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        height: 1.45, color: primary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400,
        height: 1.4, color: secondary,
      ),

      // Labels
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: primary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w600, color: secondary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w500, color: tertiary,
      ),
    );
  }
}


