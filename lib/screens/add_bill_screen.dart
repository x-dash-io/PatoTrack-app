// lib/screens/add_bill_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_service.dart';
import '../helpers/notification_helper.dart';
import '../models/bill.dart';
import '../models/frequency.dart';
import '../providers/currency_provider.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/input_fields.dart';
import '../widgets/app_screen_background.dart';
import 'manage_frequencies_screen.dart';

class AddBillScreen extends StatefulWidget {
  final Bill? billToEdit;

  const AddBillScreen({super.key, this.billToEdit});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // NEW: State variables for recurring bills
  bool _isRecurring = false;
  Frequency? _selectedFrequency;
  List<Frequency> _frequencies = [];
  bool _isLoadingFrequencies = true;
  bool _isSaving = false;
  bool _enableReminder = true;

  @override
  void initState() {
    super.initState();
    _loadFrequencies();
    _initializeFromBill();
  }

  void _initializeFromBill() {
    if (widget.billToEdit != null) {
      final bill = widget.billToEdit!;
      _nameController.text = bill.name;
      _amountController.text = bill.amount.toStringAsFixed(2);
      _selectedDate = bill.dueDate;
      _isRecurring = bill.isRecurring;
      _enableReminder = true;
      // We'll set the frequency after frequencies are loaded
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadFrequencies() async {
    if (_currentUser == null) return;

    setState(() => _isLoadingFrequencies = true);
    try {
      final dbHelper = DatabaseHelper();
      final frequencies = await dbHelper.getFrequencies(_currentUser.uid);
      if (mounted) {
        setState(() {
          _frequencies = frequencies;
          // Set frequency from bill if editing, otherwise default to monthly
          if (widget.billToEdit != null &&
              widget.billToEdit!.recurrenceType != null) {
            _selectedFrequency = frequencies.firstWhere(
              (f) => f.type == widget.billToEdit!.recurrenceType,
              orElse: () => frequencies.isNotEmpty
                  ? frequencies.first
                  : Frequency(
                      id: 1,
                      name: 'Monthly',
                      type: 'monthly',
                      value: 30,
                      displayName: 'Monthly',
                      userId: _currentUser.uid,
                    ),
            );
          } else {
            _selectedFrequency = frequencies.isNotEmpty
                ? frequencies.firstWhere(
                    (f) => f.type == 'monthly',
                    orElse: () => frequencies.first,
                  )
                : null;
          }
          _isLoadingFrequencies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFrequencies = false);
      }
    }
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }

    if (_isSaving) return; // Prevent double submission

    setState(() => _isSaving = true);

    try {
      final currencySymbol = context.read<CurrencyProvider>().symbol;
      final dbHelper = DatabaseHelper();
      final billName = _nameController.text.trim();

      // Check for duplicate bill names (excluding current bill if editing)
      final existingBills = await dbHelper.getBills(_currentUser.uid);
      final isDuplicate = existingBills.any((bill) =>
          bill.name.toLowerCase() == billName.toLowerCase() &&
          bill.id != widget.billToEdit?.id);

      if (isDuplicate && mounted) {
        setState(() => _isSaving = false);
        NotificationHelper.showWarning(context,
            message: 'A bill with this name already exists.');
        return;
      }

      // Create or update Bill object
      final bill = Bill(
        id: widget.billToEdit?.id,
        name: billName,
        amount: double.parse(_amountController.text),
        dueDate: _selectedDate,
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring && _selectedFrequency != null
            ? _selectedFrequency!.type
            : null,
        recurrenceValue: _isRecurring && _selectedFrequency != null
            ? (_selectedFrequency!.type == 'weekly'
                ? _selectedDate.weekday
                : _selectedDate.day)
            : null,
      );

      final notificationService = NotificationService();
      final canScheduleReminder = _enableReminder
          ? await _ensureNotificationPermissionWithRationale()
          : false;

      if (widget.billToEdit != null) {
        // Updating existing bill
        await dbHelper.updateBill(bill, _currentUser.uid);
        // Reschedule notification - cancel old one if it had an ID
        if (widget.billToEdit!.id != null) {
          await notificationService.cancelNotification(widget.billToEdit!.id!);
        }
        if (canScheduleReminder) {
          await notificationService.scheduleBillNotification(
            bill,
            currencySymbol: currencySymbol,
          );
        }
      } else {
        // Adding new bill
        final newBillId = await dbHelper.addBill(bill, _currentUser.uid);
        if (canScheduleReminder) {
          await notificationService.scheduleBillNotification(
            bill.copyWith(id: newBillId),
            currencySymbol: currencySymbol,
          );
        }
      }

      if (mounted) {
        if (_enableReminder && !canScheduleReminder) {
          NotificationHelper.showWarning(
            context,
            message:
                'Bill saved, but reminder notifications are off. You can enable them later in app settings.',
          );
        }
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        NotificationHelper.showError(
          context,
          message: 'Failed to save bill: $e',
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showModernDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      title: 'Select Due Date',
      showPresets: false,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<bool> _ensureNotificationPermissionWithRationale() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        NotificationHelper.showWarning(
          context,
          message:
              'Notification permission is blocked. Open device settings to enable bill reminders.',
        );
      }
      return false;
    }

    if (!mounted) {
      return false;
    }

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable bill reminders?'),
        content: const Text(
          'We use notification permission to remind you one day before your bill is due. You can skip this and still save the bill.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) {
      return false;
    }

    final requestedStatus = await Permission.notification.request();
    return requestedStatus.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        elevation: 0,
        title: Text(
          widget.billToEdit != null ? 'Edit Bill' : 'Add New Bill',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      body: AppScreenBackground(
        includeSafeArea: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              StandardTextFormField(
                controller: _nameController,
                labelText: 'Bill Name',
                hintText: 'e.g., Rent, Netflix, Internet',
                prefixIcon: Icons.receipt_long_rounded,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 20),
              StandardTextFormField(
                controller: _amountController,
                labelText: 'Amount',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.attach_money_rounded,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              StandardDateSelectorTile(
                label: 'Due Date',
                valueText: DateFormat('MMMM dd, yyyy').format(_selectedDate),
                helperText: 'Tap to select a due date',
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: _enableReminder,
                onChanged: (value) => setState(() => _enableReminder = value),
                title: const Text('Enable bill reminder notification'),
                subtitle: const Text(
                  'Sends a reminder one day before the due date.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // Modern Recurring bill toggle card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surfaceContainerHighest,
                      colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.repeat_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Make this a recurring bill',
                                  style: GoogleFonts.manrope(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_isRecurring && _selectedFrequency != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _getRecurrenceDescription(),
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isRecurring,
                            onChanged: (bool value) {
                              setState(() {
                                _isRecurring = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Show dropdown only if the bill is recurring
              if (_isRecurring) ...[
                const SizedBox(height: 16),
                _isLoadingFrequencies
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: StandardDropdownFormField<Frequency>(
                              value: _selectedFrequency,
                              labelText: 'Frequency',
                              prefixIcon: Icons.repeat_rounded,
                              items: _frequencies.map((frequency) {
                                return DropdownMenuItem<Frequency>(
                                  value: frequency,
                                  child: Text(frequency.displayName),
                                );
                              }).toList(),
                              onChanged: (Frequency? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedFrequency = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ManageFrequenciesScreen(),
                                ),
                              );
                              if (result == true) {
                                await _loadFrequencies();
                              }
                            },
                            icon: const Icon(Icons.settings_rounded),
                            tooltip: 'Manage Frequencies',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              foregroundColor: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
              ],

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isSaving ? null : _saveBill,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Text(
                        widget.billToEdit != null ? 'Update Bill' : 'Save Bill',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRecurrenceDescription() {
    if (_selectedFrequency == null) return '';

    switch (_selectedFrequency!.type) {
      case 'weekly':
        return 'Repeats every ${DateFormat('EEEE').format(_selectedDate)}';
      case 'biweekly':
        return 'Repeats every 2 weeks on ${DateFormat('EEEE').format(_selectedDate)}';
      case 'monthly':
        return 'Repeats on the ${_selectedDate.day}${_getDaySuffix(_selectedDate.day)} of every month';
      case 'quarterly':
        return 'Repeats on the ${_selectedDate.day}${_getDaySuffix(_selectedDate.day)} every 3 months';
      case 'yearly':
        return 'Repeats on ${DateFormat('MMMM dd').format(_selectedDate)} every year';
      default:
        return 'Repeats ${_selectedFrequency!.displayName.toLowerCase()}';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
