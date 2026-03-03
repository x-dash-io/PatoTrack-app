import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
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
import '../widgets/app_screen_background.dart';
import 'manage_categories_screen.dart';
import '../helpers/notification_helper.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import '../features/capture/services/ocr_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

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
  final _ocrService = OcrService();
  final _imagePicker = ImagePicker();
  bool _isScanning = false;
  String _currentSource = 'manual';

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
    _ocrService.dispose();
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
        source: _currentSource,
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

  Future<void> _showScanOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _scanReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.shopping_bag_rounded), // Using a bag/file icon for gallery
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _scanReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanReceipt(ImageSource source) async {
    // Explicitly request permissions to ensure system dialogs appear
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          NotificationHelper.showError(context, message: 'Camera permission is required');
        }
        return;
      }
    } else {
      // For gallery, handling varies by platform/version but explicit request helps visibility
      if (Platform.isAndroid) {
         // Try requesting both to cover different Android versions
         await Permission.photos.request();
         await Permission.storage.request();
      } else {
         await Permission.photos.request();
      }
    }

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isScanning = true);

    try {
      final result = await _ocrService.processReceipt(File(image.path));

      if (!mounted) return;

      if (!result.isReceipt) {
        setState(() => _isScanning = false);
        NotificationHelper.showWarning(context,
            message: result.error ?? 'This image doesn\'t look like a valid receipt.');
        return;
      }

      setState(() {
        if (result.amount != null) {
          _amountController.text = result.amount!.toStringAsFixed(2);
        }
        if (result.merchant != null) {
          _descriptionController.text = result.merchant!;
        }
        if (result.date != null) {
          _selectedDate = result.date!;
        }
        _currentSource = 'receipt';
        _isScanning = false;
      });

      NotificationHelper.showSuccess(context,
          message: 'Receipt scanned successfully');
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        NotificationHelper.showError(context,
            message: 'Error scanning receipt: $e');
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
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? AppColors.bgDark : AppColors.bgLight,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.camera_alt_rounded),
            onPressed: _isScanning ? null : _showScanOptions,
            tooltip: 'Scan Receipt',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppScreenBackground(
        includeSafeArea: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (_isScanning)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: ModernLoadingIndicator(
                      message: 'Analyzing receipt...'),
                ),
              // Transaction Type — fintech pill toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceElevatedDark
                      : AppColors.surfaceElevatedLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: ['expense', 'income'].map((type) {
                    final isSelected = _transactionType == type;
                    final color =
                        type == 'income' ? AppColors.income : AppColors.expense;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _transactionType = type;
                            _selectedCategoryId = null;
                            _currentSource = 'manual'; // Reset source when manually toggle
                            _loadCategories();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.surfaceDark
                                    : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected ? AppShadows.subtle() : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type == 'income'
                                    ? AppIcons.arrow_downward_rounded
                                    : AppIcons.arrow_upward_rounded,
                                size: 16,
                                color: isSelected
                                    ? color
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                type == 'income' ? 'Income' : 'Expense',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? color
                                      : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
                          return const ModernLoadingIndicator();
                        }

                        final categories = snapshot.data ?? [];

                        return StandardDropdownFormField<int>(
                          value: _selectedCategoryId,
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
                      color: colorScheme.surfaceContainerHighest,
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
