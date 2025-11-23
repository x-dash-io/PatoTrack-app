import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Modern iOS-style date picker wrapper

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

  DateTime selectedDate = initialDate;

  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => _iOSDatePickerBottomSheet(
        initialDate: initialDate,
        firstDate: firstDate!,
        lastDate: lastDate!,
        title: title ?? 'Select Date',
        showPresets: showPresets,
        onDateSelected: (date) {
          selectedDate = date;
        },
      ),
    );
  } else {
    // Android - Use Material date picker but with modern styling
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate!,
      lastDate: lastDate!,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }
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
  final effectiveInitialRange = initialDateRange ?? DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  if (Theme.of(context).platform == TargetPlatform.iOS) {
    final range = effectiveInitialRange;
    DateTime startDate = range.start;
    DateTime endDate = range.end;

    final result = await showCupertinoModalPopup<DateTimeRange>(
      context: context,
      builder: (context) => _iOSDateRangePickerBottomSheet(
        initialRange: range,
        firstDate: firstDate!,
        lastDate: lastDate!,
        title: title ?? 'Select Date Range',
        onRangeSelected: (start, end) {
          startDate = start;
          endDate = end;
        },
      ),
    );

    return result;
  } else {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate!,
      lastDate: lastDate!,
      initialDateRange: effectiveInitialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }
}

/// iOS Date Picker Bottom Sheet
class _iOSDatePickerBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final bool showPresets;
  final Function(DateTime) onDateSelected;

  const _iOSDatePickerBottomSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.showPresets,
    required this.onDateSelected,
  });

  @override
  State<_iOSDatePickerBottomSheet> createState() =>
      _iOSDatePickerBottomSheetState();
}

class _iOSDatePickerBottomSheetState extends State<_iOSDatePickerBottomSheet> {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final lastMonth = DateTime(now.year, now.month - 1, now.day);

    return Container(
      height: 400,
      padding: const EdgeInsets.only(top: 6.0),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.separator,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(selectedDate),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            if (widget.showPresets) ...[
              // Preset buttons
              SizedBox(
                height: 44,
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
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: widget.initialDate,
                minimumDate: widget.firstDate,
                maximumDate: widget.lastDate,
                mode: CupertinoDatePickerMode.date,
                onDateTimeChanged: (date) {
                  setState(() {
                    selectedDate = date;
                  });
                  widget.onDateSelected(date);
                },
              ),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue
              : CupertinoColors.secondarySystemFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : CupertinoColors.label,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// iOS Date Range Picker Bottom Sheet
class _iOSDateRangePickerBottomSheet extends StatefulWidget {
  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final Function(DateTime, DateTime) onRangeSelected;

  const _iOSDateRangePickerBottomSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.onRangeSelected,
  });

  @override
  State<_iOSDateRangePickerBottomSheet> createState() =>
      _iOSDateRangePickerBottomSheetState();
}

class _iOSDateRangePickerBottomSheetState
    extends State<_iOSDateRangePickerBottomSheet> {
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
    return Container(
      height: 500,
      padding: const EdgeInsets.only(top: 6.0),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.separator,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (endDate.isBefore(startDate)) {
                        // Swap if end is before start
                        final temp = startDate;
                        startDate = endDate;
                        endDate = temp;
                      }
                      Navigator.of(context).pop(DateTimeRange(
                        start: startDate,
                        end: endDate,
                      ));
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            // Date display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Start Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => selectingStart = true);
                        },
                        child: Text(
                          DateFormat('MMM d, yyyy').format(startDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: selectingStart
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selectingStart
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.label,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text('→', style: TextStyle(fontSize: 20)),
                  Column(
                    children: [
                      Text(
                        'End Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => selectingStart = false);
                        },
                        child: Text(
                          DateFormat('MMM d, yyyy').format(endDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: !selectingStart
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: !selectingStart
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.label,
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
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime:
                    selectingStart ? startDate : endDate,
                minimumDate: widget.firstDate,
                maximumDate: widget.lastDate,
                mode: CupertinoDatePickerMode.date,
                onDateTimeChanged: (date) {
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
          ],
        ),
      ),
    );
  }
}


