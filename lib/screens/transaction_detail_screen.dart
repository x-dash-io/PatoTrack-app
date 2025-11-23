import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../widgets/dialog_helpers.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/loading_widgets.dart';
import 'manage_categories_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final model.Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _transactionType;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  
  int? _selectedCategoryId;
  late Future<List<Category>> _categoriesFuture;
  
  late String _selectedTag;

  final dbHelper = DatabaseHelper();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _transactionType = widget.transaction.type;
    _amountController = TextEditingController(text: widget.transaction.amount.toString());
    _descriptionController = TextEditingController(text: widget.transaction.description);
    _selectedDate = DateTime.parse(widget.transaction.date);
    _selectedCategoryId = widget.transaction.categoryId;
    _selectedTag = widget.transaction.tag;
    
    _loadCategories();
  }

  void _loadCategories() {
    if (_currentUser != null) {
      setState(() {
        _categoriesFuture = dbHelper.getCategories(_currentUser!.uid, type: _transactionType);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final updatedTransaction = widget.transaction.copyWith(
      type: _transactionType,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text,
      date: _selectedDate.toIso8601String(),
      categoryId: _selectedCategoryId,
      tag: _selectedTag,
    );

    await dbHelper.updateTransaction(updatedTransaction, _currentUser!.uid);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Transaction Updated',
          style: GoogleFonts.inter(),
        ),
      ),
    );
    navigator.pop(true);
  }

  Future<void> _deleteTransaction() async {
    if (_currentUser == null) return;

    final bool? confirm = await showModernConfirmDialog(
      context: context,
      title: 'Confirm Deletion',
      message: 'Are you sure you want to permanently delete this transaction?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      await dbHelper.deleteTransaction(widget.transaction.id!, _currentUser!.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaction Deleted',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      Navigator.of(context).pop(true);
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

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Transaction',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
            onPressed: _deleteTransaction,
            tooltip: 'Delete Transaction',
          ),
        ],
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
                color: isDark
                    ? colorScheme.surfaceContainerHighest,
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
            const SizedBox(height: 16),

            // Tag Type
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'business',
                    label: Text(
                      'Business',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(Icons.business_center, size: 18),
                  ),
                  ButtonSegment(
                    value: 'personal',
                    label: Text(
                      'Personal',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(Icons.person, size: 18),
                  ),
                ],
                selected: {_selectedTag},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedTag = newSelection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Amount Field
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: GoogleFonts.inter(),
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
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

                      // Check if the current value is valid for the list of items
                      final bool isValueValid = _selectedCategoryId != null &&
                          categories.any((c) => c.id == _selectedCategoryId);
                      // If the value isn't valid, we use null, otherwise we use the value
                      final int? dropdownValue =
                          isValueValid ? _selectedCategoryId : null;

                      return DropdownButtonFormField<int>(
                        value: dropdownValue,
                        style: GoogleFonts.inter(),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: GoogleFonts.inter(),
                          prefixIcon: Icon(
                            _transactionType == 'expense'
                                ? Icons.category
                                : Icons.source,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? cupertino.CupertinoColors.systemGrey6.darkColor
                              : cupertino.CupertinoColors.systemGrey6,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(
                              category.name,
                              style: GoogleFonts.inter(),
                              overflow: TextOverflow.ellipsis,
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
                    color: isDark
                        ? cupertino.CupertinoColors.systemGrey6.darkColor
                        : cupertino.CupertinoColors.systemGrey6,
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
            TextFormField(
              controller: _descriptionController,
              style: GoogleFonts.inter(),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description / Note (Optional)',
                labelStyle: GoogleFonts.inter(),
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // Date Field
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(
                    text: DateFormat('MMMM dd, yyyy').format(_selectedDate),
                  ),
                  style: GoogleFonts.inter(),
                  decoration: InputDecoration(
                    labelText: 'Date',
                    labelStyle: GoogleFonts.inter(),
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? cupertino.CupertinoColors.systemGrey6.darkColor
                        : cupertino.CupertinoColors.systemGrey6,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Update Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: _updateTransaction,
                child: Text(
                  'Update Transaction',
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

