import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
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
import '../widgets/input_fields.dart';
import '../widgets/app_screen_background.dart';
import 'manage_categories_screen.dart';
import '../helpers/notification_helper.dart';
import '../styles/app_colors.dart';

class TransactionDetailScreen extends StatefulWidget {
  final model.Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _transactionType;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;

  int? _selectedCategoryId;
  late Future<List<Category>> _categoriesFuture;
  bool _isUpdating = false;
  bool _isDeleting = false;

  final dbHelper = DatabaseHelper();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _transactionType = widget.transaction.type;
    _amountController =
        TextEditingController(text: widget.transaction.amount.toString());
    _descriptionController =
        TextEditingController(text: widget.transaction.description);
    _selectedDate = DateTime.parse(widget.transaction.date);
    _selectedCategoryId = widget.transaction.categoryId;
    _categoriesFuture = _buildCategoriesFuture();
  }

  Future<List<Category>> _buildCategoriesFuture() {
    if (_currentUser == null) {
      return Future<List<Category>>.value(const <Category>[]);
    }
    return dbHelper.getCategories(_currentUser.uid, type: _transactionType);
  }

  void _loadCategories() {
    if (!mounted) {
      _categoriesFuture = _buildCategoriesFuture();
      return;
    }
    setState(() {
      _categoriesFuture = _buildCategoriesFuture();
    });
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

    if (_isUpdating) return; // Prevent double submission

    setState(() => _isUpdating = true);

    try {
      final navigator = Navigator.of(context);

      final updatedTransaction = widget.transaction.copyWith(
        type: _transactionType,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        date: _selectedDate.toIso8601String(),
        categoryId: _selectedCategoryId,
        tag: 'business', // Always business
      );

      final updatedRows = await dbHelper.updateTransaction(
          updatedTransaction, _currentUser.uid);
      if (updatedRows == 0) {
        throw StateError('Transaction no longer exists.');
      }

      if (mounted) {
        NotificationHelper.showSuccess(context, message: 'Transaction Updated');
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        NotificationHelper.showError(context,
            message: 'Error updating transaction: $e');
      }
    }
  }

  Future<void> _deleteTransaction() async {
    if (_currentUser == null) return;

    if (_isDeleting) return; // Prevent double submission

    final bool? confirm = await showModernConfirmDialog(
      context: context,
      title: 'Confirm Deletion',
      message: 'Are you sure you want to permanently delete this transaction?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      setState(() => _isDeleting = true);

      try {
        final deletedRows = await dbHelper.deleteTransaction(
            widget.transaction.id!, _currentUser.uid);
        if (deletedRows == 0) {
          throw StateError('Transaction no longer exists.');
        }
        if (mounted) {
          NotificationHelper.showSuccess(context,
              message: 'Transaction Deleted');
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          NotificationHelper.showError(context,
              message: 'Error deleting transaction: $e');
        }
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
          'Edit Transaction',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? AppColors.bgDark : AppColors.bgLight,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        elevation: 0,
        actions: [
          _isDeleting
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.error,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(AppIcons.delete_outline),
                  color: Colors.red,
                  onPressed: _isDeleting ? null : _deleteTransaction,
                  tooltip: 'Delete Transaction',
                ),
        ],
      ),
      body: AppScreenBackground(
        includeSafeArea: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (widget.transaction.source != 'manual')
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandSoftDark
                            : AppColors.brandSoft)
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandDark.withValues(alpha: 0.3)
                          : AppColors.brand.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.transaction.source == 'sms'
                            ? AppIcons.sms_rounded
                            : AppIcons.receipt_long_rounded,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandDark
                            : AppColors.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Captured via ${widget.transaction.source.toUpperCase()}',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.brandDark
                                    : AppColors.brand,
                              ),
                            ),
                            if (widget.transaction.confidence < 1.0)
                              Text(
                                'Confidence: ${(widget.transaction.confidence * 100).toInt()}%',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.brandDark
                                          .withValues(alpha: 0.7)
                                      : AppColors.brand.withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Transaction Type
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? colorScheme.surfaceContainerHighest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'expense',
                      label: Text(
                        'Expense',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w500),
                      ),
                      icon: const Icon(AppIcons.arrow_upward, size: 18),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text(
                        'Income',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w500),
                      ),
                      icon: const Icon(AppIcons.arrow_downward, size: 18),
                    ),
                  ],
                  selected: {_transactionType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _transactionType = newSelection.first;
                      _selectedCategoryId = null;
                      _categoriesFuture = _buildCategoriesFuture();
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
                prefixIcon: AppIcons.attach_money_rounded,
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const TransactionDetailShimmer();
                        }

                        final categories = snapshot.data ?? [];

                        // Check if the current value is valid for the list of items
                        final bool isValueValid = _selectedCategoryId != null &&
                            categories.any((c) => c.id == _selectedCategoryId);
                        // If the value isn't valid, we use null, otherwise we use the value
                        final int? dropdownValue =
                            isValueValid ? _selectedCategoryId : null;

                        return StandardDropdownFormField<int>(
                          value: dropdownValue,
                          labelText: 'Category',
                          prefixIcon: _transactionType == 'expense'
                              ? AppIcons.category_rounded
                              : AppIcons.account_balance_wallet_rounded,
                          items: categories.map((category) {
                            return DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(
                                category.name,
                                style: GoogleFonts.manrope(),
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
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(AppIcons.settings_outlined),
                      tooltip: 'Manage Categories',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const ManageCategoriesScreen(),
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
                prefixIcon: AppIcons.description_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Date Field
              StandardDateSelectorTile(
                label: 'Date',
                valueText: DateFormat('MMMM dd, yyyy').format(_selectedDate),
                helperText: 'Tap to change',
                onTap: _pickDate,
              ),
              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed:
                      (_isUpdating || _isDeleting) ? null : _updateTransaction,
                  child: _isUpdating
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
                          'Update Transaction',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
