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
      style: GoogleFonts.inter(),
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: GoogleFonts.inter(),
        hintStyle: GoogleFonts.inter(),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 22,
              )
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? Colors.transparent
                : colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? Colors.transparent
                : colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
        errorStyle: GoogleFonts.inter(
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
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      style: GoogleFonts.inter(
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
      borderRadius: BorderRadius.circular(16),
      menuMaxHeight: 300,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.inter(),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 22,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? Colors.transparent
                : colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.dark
                ? Colors.transparent
                : colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: colorScheme.error,
        ),
      ),
    );
  }
}
