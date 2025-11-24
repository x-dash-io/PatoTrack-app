import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/input_fields.dart';

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
    Icons.shopping_cart_rounded,
    Icons.restaurant_rounded,
    Icons.home_rounded,
    Icons.flight_rounded,
    Icons.receipt_long_rounded,
    Icons.local_hospital_rounded,
    Icons.school_rounded,
    Icons.pets_rounded,
    Icons.phone_android_rounded,
    Icons.wifi_rounded,
    Icons.movie_rounded,
    Icons.spa_rounded,
    Icons.build_rounded,
    Icons.book_rounded,
    Icons.music_note_rounded,
    Icons.directions_car_rounded,
    Icons.attach_money_rounded,
    Icons.work_rounded,
    Icons.card_giftcard_rounded,
    Icons.savings_rounded,
    Icons.sports_esports_rounded,
    Icons.fitness_center_rounded,
    Icons.shopping_bag_rounded,
    Icons.local_gas_station_rounded,
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
    final expenseCats = await dbHelper.getCategories(currentUser!.uid, type: 'expense');
    final incomeCats = await dbHelper.getCategories(currentUser!.uid, type: 'income');
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
    return Icons.label_rounded;
  }

  void _showCategoryDialog({Category? category, required String type}) {
    _nameController.text = category?.name ?? '';
    IconData? selectedIcon = category?.iconCodePoint != null
        ? IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons')
        : (type == 'expense' ? Icons.category_rounded : Icons.account_balance_wallet_rounded);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
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
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Text(
                    category == null
                        ? 'Add New ${type.capitalize()} Category'
                        : 'Edit Category',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Category Name Field
                  StandardTextFormField(
                    controller: _nameController,
                    labelText: 'Category Name',
                    prefixIcon: Icons.label_rounded,
                  ),
                  const SizedBox(height: 24),
                  // Icon Selection
                  Text(
                    'Select Icon',
                    style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final IconData? newIcon =
                                await showModalBottomSheet<IconData>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _buildIconPickerDialog(),
                            );
                            if (newIcon != null) {
                              setDialogState(() => selectedIcon = newIcon);
                            }
                          },
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
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
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
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
                                    setDialogState(() => _isSavingCategory = true);
                                    try {
                                      if (category == null) {
                                        final newCategory = Category(
                                          name: _nameController.text.trim(),
                                          iconCodePoint: selectedIcon?.codePoint,
                                          type: type,
                                        );
                                        await dbHelper.addCategory(
                                          newCategory,
                                          currentUser!.uid,
                                        );
                                      } else {
                                        final updatedCategory = category.copyWith(
                                          name: _nameController.text.trim(),
                                          iconCodePoint: selectedIcon?.codePoint,
                                        );
                                        await dbHelper.updateCategory(
                                          updatedCategory,
                                          currentUser!.uid,
                                        );
                                      }
                                      if (mounted) {
                                        Navigator.pop(context);
                                        _refreshCategories();
                                      }
                                    } catch (e) {
                                      setDialogState(() => _isSavingCategory = false);
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
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
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
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Select an Icon',
            style: GoogleFonts.inter(
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: ModernLoadingIndicator(),
        ),
      );
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
                Icons.category_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No $type categories yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the "+" button to add one!',
                style: GoogleFonts.inter(
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
      padding: const EdgeInsets.all(20),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final colorScheme = Theme.of(context).colorScheme;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForCategory(category),
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            title: Text(
              category.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    color: colorScheme.primary,
                  ),
                  onPressed: () => _showCategoryDialog(
                    category: category,
                    type: category.type,
                  ),
                  tooltip: 'Edit Category',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
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
                      await dbHelper.deleteCategory(category.id!, currentUser!.uid);
                      _refreshCategories();
                    }
                  },
                  tooltip: 'Delete Category',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Manage Categories',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
              icon: Icon(Icons.arrow_upward_rounded),
              text: 'Expenses',
            ),
            Tab(
              icon: Icon(Icons.arrow_downward_rounded),
              text: 'Income',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(_expenseCategories, 'expense'),
          _buildCategoryList(_incomeCategories, 'income'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final type = _tabController.index == 0 ? 'expense' : 'income';
          _showCategoryDialog(type: type);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Category',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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

