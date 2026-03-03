import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/input_fields.dart';
import '../helpers/notification_helper.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import '../widgets/app_screen_background.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  bool _isLoading = true;
  bool _isSavingCategory = false;

  final _nameController = TextEditingController();
  static const List<IconData> _selectableIcons = [
    AppIcons.shopping_cart_rounded,
    AppIcons.restaurant_rounded,
    AppIcons.home_rounded,
    AppIcons.flight_rounded,
    AppIcons.receipt_long_rounded,
    AppIcons.local_hospital_rounded,
    AppIcons.school_rounded,
    AppIcons.pets_rounded,
    AppIcons.phone_android_rounded,
    AppIcons.wifi_rounded,
    AppIcons.movie_rounded,
    AppIcons.spa_rounded,
    AppIcons.build_rounded,
    AppIcons.book_rounded,
    AppIcons.music_note_rounded,
    AppIcons.directions_car_rounded,
    AppIcons.attach_money_rounded,
    AppIcons.work_rounded,
    AppIcons.card_giftcard_rounded,
    AppIcons.savings_rounded,
    AppIcons.sports_esports_rounded,
    AppIcons.fitness_center_rounded,
    AppIcons.shopping_bag_rounded,
    AppIcons.local_gas_station_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refreshCategories() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);
    final expenseCats =
        await dbHelper.getCategories(currentUser!.uid, type: 'expense');
    final incomeCats =
        await dbHelper.getCategories(currentUser!.uid, type: 'income');
    if (mounted) {
      setState(() {
        _expenseCategories = expenseCats;
        _incomeCategories = incomeCats;
        _isLoading = false;
      });
    }
  }

  IconData _getIconForCategory(Category category) {
    if (category.iconCodePoint != null) {
      return IconData(category.iconCodePoint!, fontFamily: 'MaterialIcons');
    }
    return AppIcons.label_rounded;
  }

  void _showCategoryDialog({Category? category, required String type}) {
    _nameController.text = category?.name ?? '';
    IconData? selectedIcon = category?.iconCodePoint != null
        ? IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons')
        : (type == 'expense'
            ? AppIcons.category_rounded
            : AppIcons.account_balance_wallet_rounded);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final colorScheme = Theme.of(dialogContext).colorScheme;
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Text(
                    category == null
                        ? 'Add New ${type.capitalize()} Category'
                        : 'Edit Category',
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Category Name Field
                  StandardTextFormField(
                    controller: _nameController,
                    labelText: 'Category Name',
                    prefixIcon: AppIcons.label_rounded,
                  ),
                  const SizedBox(height: 24),
                  // Icon Selection
                  Text(
                    'Select Icon',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            selectedIcon,
                            color: colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Tap to change icon',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final IconData? newIcon =
                                await showModalBottomSheet<IconData>(
                              context: dialogContext,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _buildIconPickerDialog(),
                            );
                            if (newIcon != null) {
                              setDialogState(() => selectedIcon = newIcon);
                            }
                          },
                          icon: Icon(
                            AppIcons.arrow_forward_ios_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _isSavingCategory
                              ? null
                              : () async {
                                  if (_nameController.text.isNotEmpty &&
                                      currentUser != null) {
                                    setDialogState(
                                        () => _isSavingCategory = true);
                                    try {
                                      if (category == null) {
                                        final newCategory = Category(
                                          name: _nameController.text.trim(),
                                          iconCodePoint:
                                              selectedIcon?.codePoint,
                                          type: type,
                                        );
                                        await dbHelper.addCategory(
                                          newCategory,
                                          currentUser!.uid,
                                        );
                                      } else {
                                        final updatedCategory =
                                            category.copyWith(
                                          name: _nameController.text.trim(),
                                          iconCodePoint:
                                              selectedIcon?.codePoint,
                                        );
                                        await dbHelper.updateCategory(
                                          updatedCategory,
                                          currentUser!.uid,
                                        );
                                      }
                                      if (mounted) {
                                        setDialogState(
                                            () => _isSavingCategory = false);
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        await _refreshCategories();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                              () => _isSavingCategory = false);
                                        }
                                        NotificationHelper.showError(context,
                                            message:
                                                'Failed to save category: $e');
                                      }
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSavingCategory
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
                                  category == null ? 'Add' : 'Save',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height: MediaQuery.of(dialogContext).padding.bottom + 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIconPickerDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Select an Icon',
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _selectableIcons.length,
              itemBuilder: (context, index) {
                final icon = _selectableIcons[index];
                return InkWell(
                  onTap: () => Navigator.of(context).pop(icon),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: colorScheme.onSurface,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, String type) {
    if (_isLoading) {
      return const CategoryShimmerList(itemCount: 8);
    }
    if (categories.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.category_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No $type categories yet',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the "+" button to add one!',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: AppSpacing.radiusLg,
            border: Border.all(
              color: isDark
                  ? AppColors.surfaceBorderDark
                  : AppColors.surfaceBorderLight,
              width: 1,
            ),
            boxShadow: AppShadows.subtle(),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brandSoftDark : AppColors.brandSoft,
                  borderRadius: AppSpacing.radiusMd,
                ),
                child: Icon(
                  _getIconForCategory(category),
                  color: isDark ? AppColors.brandDark : AppColors.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              IconButton(
                icon: Icon(AppIcons.edit_rounded,
                    color: isDark ? AppColors.brandDark : AppColors.brand,
                    size: 20),
                onPressed: () => _showCategoryDialog(
                  category: category,
                  type: category.type,
                ),
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(AppIcons.delete_outline_rounded,
                    color: AppColors.expense, size: 20),
                onPressed: () async {
                  if (currentUser == null) return;
                  final bool? confirm = await showModernConfirmDialog(
                    context: context,
                    title: 'Confirm Deletion',
                    message:
                        'Are you sure you want to delete the "${category.name}" category?',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    isDestructive: true,
                  );
                  if (confirm == true) {
                    await dbHelper.deleteCategory(
                        category.id!, currentUser!.uid);
                    _refreshCategories();
                  }
                },
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Manage Categories',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? AppColors.bgDark : AppColors.bgLight,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
              icon: Icon(AppIcons.arrow_upward_rounded),
              text: 'Expenses',
            ),
            Tab(
              icon: Icon(AppIcons.arrow_downward_rounded),
              text: 'Income',
            ),
          ],
        ),
      ),
      body: AppScreenBackground(
        includeSafeArea: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCategoryList(_expenseCategories, 'expense'),
            _buildCategoryList(_incomeCategories, 'income'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final type = _tabController.index == 0 ? 'expense' : 'income';
          _showCategoryDialog(type: type);
        },
        icon: const Icon(AppIcons.add_rounded),
        label: Text(
          'Add Category',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
