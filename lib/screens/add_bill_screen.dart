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
import '../widgets/modern_date_picker.dart';
import '../widgets/input_fields.dart';

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
  String _recurrenceType = 'monthly'; // Default recurrence type

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBill() async {
    try {
      if (_formKey.currentState!.validate() && _currentUser != null) {
        final dbHelper = DatabaseHelper();
        final billName = _nameController.text.trim();

        // Check for duplicate bill names
        final existingBills = await dbHelper.getBills(_currentUser.uid);
        final isDuplicate = existingBills.any((bill) => bill.name.toLowerCase() == billName.toLowerCase());

        if (isDuplicate) {
          Fluttertoast.showToast(msg: 'A bill with this name already exists.');
          return;
        }

        // UPDATED: Create a Bill object with the new recurring properties
        final newBill = Bill(
          name: billName,
          amount: double.parse(_amountController.text),
          dueDate: _selectedDate,
          isRecurring: _isRecurring,
          recurrenceType: _isRecurring ? _recurrenceType : null,
          recurrenceValue: _isRecurring
              ? (_recurrenceType == 'weekly' ? _selectedDate.weekday : _selectedDate.day)
              : null,
        );

        final newBillId = await dbHelper.addBill(newBill, _currentUser.uid);

        // Schedule notification for the new bill
        final notificationService = NotificationService();
        await notificationService.scheduleBillNotification(newBill.copyWith(id: newBillId));

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('--- ERROR SAVING BILL: $e ---');
      Fluttertoast.showToast(
        msg: 'An error occurred while saving the bill.',
        backgroundColor: Colors.red,
      );
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
      body: Form(
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

            // Recurring bill toggle
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: Text(
                  'Make this a recurring bill',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                subtitle: _isRecurring
                    ? Text(
                        _recurrenceType == 'weekly'
                            ? 'Repeats every ${DateFormat('EEEE').format(_selectedDate)}'
                            : 'Repeats on the ${_selectedDate.day}th of every month',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                value: _isRecurring,
                onChanged: (bool value) {
                  setState(() {
                    _isRecurring = value;
                  });
                },
              ),
            ),

            // Show dropdown only if the bill is recurring
            if (_isRecurring) ...[
              const SizedBox(height: 16),
              StandardDropdownFormField<String>(
                value: _recurrenceType,
                labelText: 'Frequency',
                prefixIcon: Icons.repeat_rounded,
                items: const [
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text('Weekly'),
                  ),
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text('Monthly'),
                  ),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _recurrenceType = newValue;
                    });
                  }
                },
              ),
            ],

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saveBill,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
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
    );
  }
}