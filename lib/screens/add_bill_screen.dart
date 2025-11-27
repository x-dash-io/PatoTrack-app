// lib/screens/add_bill_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_service.dart';
import '../models/bill.dart';
import '../models/frequency.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/input_fields.dart';
import 'manage_frequencies_screen.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadFrequencies();
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
      final frequencies = await dbHelper.getFrequencies(_currentUser!.uid);
      if (mounted) {
        setState(() {
          _frequencies = frequencies;
          _selectedFrequency = frequencies.isNotEmpty ? frequencies.firstWhere(
            (f) => f.type == 'monthly',
            orElse: () => frequencies.first,
          ) : null;
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
      final dbHelper = DatabaseHelper();
      final billName = _nameController.text.trim();

      // Check for duplicate bill names
      final existingBills = await dbHelper.getBills(_currentUser!.uid);
      final isDuplicate = existingBills.any((bill) => bill.name.toLowerCase() == billName.toLowerCase());

      if (isDuplicate && mounted) {
        setState(() => _isSaving = false);
        Fluttertoast.showToast(msg: 'A bill with this name already exists.');
        return;
      }

      // UPDATED: Create a Bill object with the new recurring properties
      final newBill = Bill(
        name: billName,
        amount: double.parse(_amountController.text),
        dueDate: _selectedDate,
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring && _selectedFrequency != null ? _selectedFrequency!.type : null,
        recurrenceValue: _isRecurring && _selectedFrequency != null
            ? (_selectedFrequency!.type == 'weekly' ? _selectedDate.weekday : _selectedDate.day)
            : null,
      );

      final newBillId = await dbHelper.addBill(newBill, _currentUser!.uid);

      // Schedule notification for the new bill
      final notificationService = NotificationService();
      await notificationService.scheduleBillNotification(newBill.copyWith(id: newBillId));

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        // Show success message even if Firestore sync fails (offline mode)
        // The bill is saved locally and will sync when online
        final theme = Theme.of(context);
        Fluttertoast.showToast(
          msg: 'Bill saved successfully. Will sync when online.',
          backgroundColor: theme.colorScheme.primary,
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
          'Add New Bill',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.2),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
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
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 20),
            StandardTextFormField(
              controller: _amountController,
              labelText: 'Amount',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            StandardTextFormField(
              controller: TextEditingController(
                text: DateFormat('MMMM dd, yyyy').format(_selectedDate),
              ),
              labelText: 'Due Date',
              prefixIcon: Icons.calendar_today_rounded,
              readOnly: true,
              onTap: _pickDate,
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
                    colorScheme.surfaceContainerHighest.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
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
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_isRecurring && _selectedFrequency != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _getRecurrenceDescription(),
                                    style: GoogleFonts.inter(
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
                                builder: (context) => const ManageFrequenciesScreen(),
                              ),
                            );
                            if (result == true) {
                              await _loadFrequencies();
                            }
                          },
                          icon: const Icon(Icons.settings_rounded),
                          tooltip: 'Manage Frequencies',
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surfaceContainerHighest,
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
                      'Save Bill',
                      style: GoogleFonts.inter(
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