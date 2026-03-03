import '../styles/app_colors.dart';
import '../styles/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized input fields for the app

/// Standardized TextFormField with consistent Material 3 styling
class StandardTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final void Function()? onTap;

  const StandardTextFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.validator,
    this.inputFormatters,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      onTap: onTap,
      style: GoogleFonts.manrope(),
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: GoogleFonts.manrope(),
        hintStyle: GoogleFonts.manrope(),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 22,
              )
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines == null || maxLines! > 1 ? 16 : 16,
        ),
        errorStyle: GoogleFonts.manrope(
          fontSize: 12,
          color: colorScheme.error,
        ),
      ),
    );
  }
}

/// Standardized DropdownButtonFormField with consistent styling
class StandardDropdownFormField<T> extends StatelessWidget {
  final T? value;
  final String? labelText;
  final IconData? prefixIcon;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  const StandardDropdownFormField({
    super.key,
    required this.value,
    this.labelText,
    this.prefixIcon,
    required this.items,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      style: GoogleFonts.manrope(
        color: colorScheme.onSurface,
      ),
      dropdownColor: theme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHighest
          : Colors.white,
      icon: Icon(
        Icons.arrow_drop_down_rounded,
        color: colorScheme.onSurfaceVariant,
        size: 28,
      ),
      iconSize: 28,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      menuMaxHeight: 300,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.manrope(),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 22,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppColors.surfaceBorderDark
                : AppColors.surfaceBorderLight,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorStyle: GoogleFonts.manrope(
          fontSize: 12,
          color: colorScheme.error,
        ),
      ),
    );
  }
}

class StandardDateSelectorTile extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;
  final String? helperText;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticsLabel;

  const StandardDateSelectorTile({
    super.key,
    required this.label,
    required this.valueText,
    this.icon = Icons.calendar_today_rounded,
    this.helperText,
    this.onTap,
    this.enabled = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: enabled,
      label: semanticsLabel ?? '$label: $valueText',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InputDecorator(
          isFocused: false,
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            prefixIcon: Icon(icon),
            suffixIcon: Icon(
              Icons.expand_more_rounded,
              color: enabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            enabled: enabled,
          ),
          child: Text(
            valueText,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
