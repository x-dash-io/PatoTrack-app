import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../widgets/modern_date_picker.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/input_fields.dart';
import 'manage_categories_screen.dart';
import '../helpers/notification_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  String _transactionType = 'expense';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  int? _selectedCategoryId;
  late Future<List<Category>> _categoriesFuture;
  bool _isSaving = false;

  final dbHelper = DatabaseHelper();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    if (_currentUser != null) {
      setState(() {
        _categoriesFuture =
            dbHelper.getCategories(_currentUser.uid, type: _transactionType);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }

    if (_isSaving) return; // Prevent double submission

    setState(() => _isSaving = true);

    try {
      final navigator = Navigator.of(context);

      final newTransaction = model.Transaction(
        type: _transactionType,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        date: _selectedDate.toIso8601String(),
        categoryId: _selectedCategoryId,
        tag: 'business', // Always business
      );

      await dbHelper.addTransaction(newTransaction, _currentUser.uid);

      if (mounted) {
        NotificationHelper.showSuccess(context, message: 'Transaction Saved');
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        NotificationHelper.showError(context,
            message: 'Error saving transaction: $e');
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showModernDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      title: 'Select Date',
      showPresets: true,
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
        title: Text(
          'Add Transaction',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Transaction Type
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'expense',
                    label: Text(
                      'Expense',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text(
                      'Income',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(Icons.arrow_downward, size: 18),
                  ),
                ],
                selected: {_transactionType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _transactionType = newSelection.first;
                    _selectedCategoryId = null;
                    _loadCategories();
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Amount Field
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
            const SizedBox(height: 16),

            // Category Field
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FutureBuilder<List<Category>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const ModernLoadingIndicator();
                      }

                      final categories = snapshot.data ?? [];

                      return StandardDropdownFormField<int>(
                        value: _selectedCategoryId,
                        labelText: 'Category',
                        prefixIcon: _transactionType == 'expense'
                            ? Icons.category_rounded
                            : Icons.account_balance_wallet_rounded,
                        items: categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(
                              category.name,
                              style: GoogleFonts.inter(),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            _selectedCategoryId = newValue;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Please select a category' : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Manage Categories',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ManageCategoriesScreen(),
                        ),
                      );
                      _loadCategories();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description Field
            StandardTextFormField(
              controller: _descriptionController,
              labelText: 'Description / Note (Optional)',
              prefixIcon: Icons.description_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Date Field
            StandardTextFormField(
              controller: TextEditingController(
                text: DateFormat('MMMM dd, yyyy').format(_selectedDate),
              ),
              labelText: 'Date',
              prefixIcon: Icons.calendar_today_rounded,
              readOnly: true,
              onTap: _pickDate,
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _saveTransaction,
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
                        'Save Transaction',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
