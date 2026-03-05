import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../helpers/database_helper.dart';
import '../helpers/config.dart';
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
import '../features/capture/services/ocr_service.dart';
import '../features/categorization/categorization_service.dart';

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

  final _dbHelper = DatabaseHelper();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _ocrService = OcrService();
  final _categorizationService = CategorizationService();
  final _imagePicker = ImagePicker();
  bool _isScanning = false;
  String _currentSource = 'manual';
  String? _receiptImageUrl;

  // Tier 2 – category suggestions
  List<CategorySuggestion> _suggestions = [];
  List<Map<String, dynamic>> _userCorrections = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUserCorrections();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  void _loadCategories() {
    if (_currentUser != null) {
      setState(() {
        _categoriesFuture =
            _dbHelper.getCategories(_currentUser!.uid, type: _transactionType);
      });
    }
  }

  Future<void> _loadUserCorrections() async {
    if (_currentUser == null) return;
    final corrections =
        await _dbHelper.getUserCategoryCorrections(_currentUser!.uid);
    if (mounted) setState(() => _userCorrections = corrections);
  }

  void _onDescriptionChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final text = _descriptionController.text;
      if (text.isEmpty) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      final suggestions = _categorizationService.suggest(
        text,
        corrections: _userCorrections,
      );
      if (mounted) setState(() => _suggestions = suggestions);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction({
    double? overrideConfidence,
    bool autoSaved = false,
  }) async {
    if (!_formKey.currentState!.validate() || _currentUser == null) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final navigator = Navigator.of(context);
      final confidence = overrideConfidence ?? 1.0;
      // confidence < 0.7 → goes to review queue (is_reviewed = false)
      final isReviewed = confidence >= 0.7;

      final newTransaction = model.Transaction(
        type: _transactionType,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        date: _selectedDate.toIso8601String(),
        categoryId: _selectedCategoryId,
        tag: 'business',
        source: _currentSource,
        confidence: confidence,
        isReviewed: isReviewed,
        receiptImageUrl: _receiptImageUrl,
      );

      final newId =
          await _dbHelper.addTransaction(newTransaction, _currentUser!.uid);

      // Record category correction for Tier 2 learning
      if (_selectedCategoryId != null &&
          _descriptionController.text.isNotEmpty) {
        final cats = await _dbHelper.getCategories(_currentUser!.uid);
        final selected =
            cats.where((c) => c.id == _selectedCategoryId).firstOrNull;
        if (selected != null) {
          await _dbHelper.addUserCategoryCorrection(
            userId: _currentUser!.uid,
            description: _descriptionController.text,
            categoryId: _selectedCategoryId!,
            categoryName: selected.name,
          );
        }
      }

      if (mounted) {
        if (autoSaved) {
          // Offer undo for auto-saved transactions
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Receipt auto-saved (${(confidence * 100).toInt()}% confidence)',
                style: GoogleFonts.manrope(),
              ),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  await _dbHelper.deleteTransaction(newId, _currentUser!.uid);
                  if (mounted) {
                    NotificationHelper.showSuccess(context,
                        message: 'Transaction removed');
                  }
                },
              ),
            ),
          );
        } else {
          NotificationHelper.showSuccess(context,
              message: isReviewed
                  ? 'Transaction Saved'
                  : 'Saved to review queue (low confidence)');
        }
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
              leading: const Icon(AppIcons.shopping_bag_rounded),
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

  Future<String?> _uploadToCloudinary(File imageFile) async {
    if (AppConfig.cloudinaryUploadPreset ==
        'REPLACE_WITH_UNSIGNED_UPLOAD_PRESET') {
      return null; // Cloudinary not configured — skip upload silently
    }
    try {
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path))
        ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      final response = await request.send();
      if (response.statusCode == 200) {
        final json = jsonDecode(await response.stream.bytesToString())
            as Map<String, dynamic>;
        return json['secure_url'] as String?;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
    return null;
  }

  Future<void> _scanReceipt(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          NotificationHelper.showError(context,
              message: 'Camera permission is required');
        }
        return;
      }
    } else {
      if (Platform.isAndroid) {
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
      final imageFile = File(image.path);
      final result = await _ocrService.processReceipt(imageFile);

      if (!mounted) return;

      if (!result.isReceipt) {
        setState(() => _isScanning = false);
        NotificationHelper.showWarning(context,
            message: result.error ?? 'This image doesn\'t look like a valid receipt.');
        return;
      }

      // Upload receipt image to Cloudinary in background
      final uploadedUrl = await _uploadToCloudinary(imageFile);

      if (!mounted) return;

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
        _receiptImageUrl = uploadedUrl;
        _isScanning = false;
      });

      // Confidence routing
      if (result.confidence >= 0.7) {
        // High confidence → auto-save immediately
        if (_selectedCategoryId == null) {
          // Can't auto-save without a category — show form instead
          NotificationHelper.showSuccess(context,
              message:
                  'Receipt scanned (${(result.confidence * 100).toInt()}% confidence) — pick a category to save');
        } else {
          await _saveTransaction(
            overrideConfidence: result.confidence,
            autoSaved: true,
          );
        }
      } else {
        // Low confidence → pre-fill form, save to review queue on submit
        NotificationHelper.showWarning(context,
            message:
                'Low confidence (${(result.confidence * 100).toInt()}%) — please review and save');
      }
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
      setState(() => _selectedDate = picked);
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
                  child:
                      ModernLoadingIndicator(message: 'Analyzing receipt...'),
                ),

              // Receipt image indicator
              if (_receiptImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(AppIcons.receipt_long_rounded,
                          size: 16,
                          color: isDark ? AppColors.brandDark : AppColors.brand),
                      const SizedBox(width: 6),
                      Text(
                        'Receipt image attached',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: isDark ? AppColors.brandDark : AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),

              // Transaction Type pill toggle
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
                            _currentSource = 'manual';
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
                            boxShadow:
                                isSelected ? AppShadows.subtle() : null,
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
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
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
                            setState(() => _selectedCategoryId = newValue);
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

              // Tier 2 – Category suggestion chips
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                FutureBuilder<List<Category>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    return Wrap(
                      spacing: 8,
                      children: _suggestions.map((s) {
                        // Try to match suggestion to existing category
                        final match = categories
                            .where((c) =>
                                c.name.toLowerCase() ==
                                s.categoryName.toLowerCase())
                            .firstOrNull;
                        return ActionChip(
                          avatar: Icon(
                            AppIcons.auto_awesome_rounded,
                            size: 14,
                            color: isDark
                                ? AppColors.brandDark
                                : AppColors.brand,
                          ),
                          label: Text(
                            '${s.categoryName} (${(s.confidence * 100).toInt()}%)',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.brandDark
                                  : AppColors.brand,
                            ),
                          ),
                          backgroundColor: isDark
                              ? AppColors.brandSoftDark
                              : AppColors.brandSoft,
                          onPressed: () async {
                            if (match != null) {
                              setState(() =>
                                  _selectedCategoryId = match.id);
                              // Record correction for learning
                              if (_currentUser != null) {
                                _dbHelper.addUserCategoryCorrection(
                                  userId: _currentUser!.uid,
                                  description:
                                      _descriptionController.text,
                                  categoryId: match.id!,
                                  categoryName: match.name,
                                );
                              }
                            } else {
                              // Auto-create missing category
                              if (_currentUser != null) {
                                final newCat = Category(
                                  name: s.categoryName,
                                  type: _transactionType, // Assign to current tab type
                                );
                                final newId = await _dbHelper.insertCategory(
                                    _currentUser!.uid, newCat);
                                await _loadCategories(); // Reload dropdown
                                setState(() => _selectedCategoryId = newId);
                                
                                // Record correction for learning
                                _dbHelper.addUserCategoryCorrection(
                                  userId: _currentUser!.uid,
                                  description: _descriptionController.text,
                                  categoryId: newId,
                                  categoryName: s.categoryName,
                                );
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Auto-created category "${s.categoryName}"'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),

              // Date Field
              StandardDateSelectorTile(
                label: 'Date',
                valueText:
                    DateFormat('MMMM dd, yyyy').format(_selectedDate),
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
                  onPressed: _isSaving ? null : () => _saveTransaction(),
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
