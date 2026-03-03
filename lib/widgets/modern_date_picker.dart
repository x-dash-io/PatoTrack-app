import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dialog_helpers.dart';

/// Modern Material Design 3 date picker

/// Shows a modern date picker with preset options
Future<DateTime?> showModernDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
  bool showPresets = true,
}) async {
  firstDate ??= DateTime(2020);
  lastDate ??= DateTime(2030);
  final effectiveFirstDate = firstDate;
  final effectiveLastDate = lastDate;

  DateTime selectedDate = initialDate;

  return showModernBottomSheet<DateTime>(
    context: context,
    height: showPresets ? 450 : 400,
    child: _ModernDatePickerBottomSheet(
      initialDate: initialDate,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      title: title ?? 'Select Date',
      showPresets: showPresets,
      onDateSelected: (date) {
        selectedDate = date;
      },
      onConfirm: () {
        Navigator.of(context).pop(selectedDate);
      },
    ),
  );
}

/// Shows a modern date range picker
Future<DateTimeRange?> showModernDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
}) async {
  firstDate ??= DateTime(2020);
  lastDate ??= DateTime(2030);
  final effectiveFirstDate = firstDate;
  final effectiveLastDate = lastDate;
  final effectiveInitialRange = initialDateRange ??
      DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      );

  DateTime startDate = effectiveInitialRange.start;
  DateTime endDate = effectiveInitialRange.end;

  return showModernBottomSheet<DateTimeRange>(
    context: context,
    height: 500,
    child: _ModernDateRangePickerBottomSheet(
      initialRange: effectiveInitialRange,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      title: title ?? 'Select Date Range',
      onRangeSelected: (start, end) {
        startDate = start;
        endDate = end;
      },
      onConfirm: () {
        if (endDate.isBefore(startDate)) {
          final temp = startDate;
          startDate = endDate;
          endDate = temp;
        }
        Navigator.of(context).pop(DateTimeRange(
          start: startDate,
          end: endDate,
        ));
      },
    ),
  );
}

/// Modern Date Picker Bottom Sheet
class _ModernDatePickerBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final bool showPresets;
  final Function(DateTime) onDateSelected;
  final VoidCallback onConfirm;

  const _ModernDatePickerBottomSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.showPresets,
    required this.onDateSelected,
    required this.onConfirm,
  });

  @override
  State<_ModernDatePickerBottomSheet> createState() =>
      _ModernDatePickerBottomSheetState();
}

class _ModernDatePickerBottomSheetState
    extends State<_ModernDatePickerBottomSheet> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
  }

  void _selectPreset(DateTime preset) {
    setState(() {
      selectedDate = preset;
    });
    widget.onDateSelected(preset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final lastMonth = DateTime(now.year, now.month - 1, now.day);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: widget.onConfirm,
                  child: Text(
                    'Done',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.showPresets) ...[
            // Preset buttons
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _PresetButton(
                    label: 'Today',
                    date: today,
                    isSelected: _isSameDay(selectedDate, today),
                    onTap: () => _selectPreset(today),
                  ),
                  const SizedBox(width: 8),
                  _PresetButton(
                    label: 'Yesterday',
                    date: yesterday,
                    isSelected: _isSameDay(selectedDate, yesterday),
                    onTap: () => _selectPreset(yesterday),
                  ),
                  const SizedBox(width: 8),
                  _PresetButton(
                    label: 'Last Week',
                    date: lastWeek,
                    isSelected: _isSameDay(selectedDate, lastWeek),
                    onTap: () => _selectPreset(lastWeek),
                  ),
                  const SizedBox(width: 8),
                  _PresetButton(
                    label: 'Last Month',
                    date: lastMonth,
                    isSelected: _isSameDay(selectedDate, lastMonth),
                    onTap: () => _selectPreset(lastMonth),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          // Date picker
          SizedBox(
            height: 220,
            child: CalendarDatePicker(
              initialDate: selectedDate,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              currentDate: selectedDate,
              onDateChanged: (date) {
                setState(() {
                  selectedDate = date;
                });
                widget.onDateSelected(date);
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

/// Preset button widget
class _PresetButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Modern Date Range Picker Bottom Sheet
class _ModernDateRangePickerBottomSheet extends StatefulWidget {
  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final Function(DateTime, DateTime) onRangeSelected;
  final VoidCallback onConfirm;

  const _ModernDateRangePickerBottomSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.onRangeSelected,
    required this.onConfirm,
  });

  @override
  State<_ModernDateRangePickerBottomSheet> createState() =>
      _ModernDateRangePickerBottomSheetState();
}

class _ModernDateRangePickerBottomSheetState
    extends State<_ModernDateRangePickerBottomSheet> {
  late DateTime startDate;
  late DateTime endDate;
  bool selectingStart = true;

  @override
  void initState() {
    super.initState();
    startDate = widget.initialRange.start;
    endDate = widget.initialRange.end;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title and Done button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: widget.onConfirm,
                  child: Text(
                    'Done',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Date display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Start Date',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        setState(() => selectingStart = true);
                      },
                      child: Text(
                        DateFormat('MMM d, yyyy').format(startDate),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: selectingStart
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selectingStart
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  AppIcons.arrow_forward,
                  color: colorScheme.onSurfaceVariant,
                ),
                Column(
                  children: [
                    Text(
                      'End Date',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        setState(() => selectingStart = false);
                      },
                      child: Text(
                        DateFormat('MMM d, yyyy').format(endDate),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: !selectingStart
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: !selectingStart
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Date picker
          SizedBox(
            height: 220,
            child: CalendarDatePicker(
              initialDate: selectingStart ? startDate : endDate,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              currentDate: selectingStart ? startDate : endDate,
              onDateChanged: (date) {
                setState(() {
                  if (selectingStart) {
                    startDate = date;
                  } else {
                    endDate = date;
                  }
                });
                widget.onRangeSelected(startDate, endDate);
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
