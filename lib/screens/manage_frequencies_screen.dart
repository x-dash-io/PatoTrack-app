import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../models/frequency.dart';
import '../widgets/input_fields.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/loading_widgets.dart';
import '../helpers/notification_helper.dart';

class ManageFrequenciesScreen extends StatefulWidget {
  const ManageFrequenciesScreen({super.key});

  @override
  State<ManageFrequenciesScreen> createState() => _ManageFrequenciesScreenState();
}

class _ManageFrequenciesScreenState extends State<ManageFrequenciesScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  List<Frequency> _frequencies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFrequencies();
  }

  Future<void> _loadFrequencies() async {
    if (_currentUser == null) return;
    
    setState(() => _isLoading = true);
    try {
      final dbHelper = DatabaseHelper();
      final frequencies = await dbHelper.getFrequencies(_currentUser!.uid);
      if (mounted) {
        setState(() {
          _frequencies = frequencies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addFrequency() async {
    final nameController = TextEditingController();
    final displayNameController = TextEditingController();
    final valueController = TextEditingController();
    String selectedType = 'weekly';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Add Frequency',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              StandardTextFormField(
                controller: nameController,
                labelText: 'Name (internal)',
                hintText: 'e.g., weekly, monthly',
                prefixIcon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: 16),
              StandardTextFormField(
                controller: displayNameController,
                labelText: 'Display Name',
                hintText: 'e.g., Weekly, Monthly',
                prefixIcon: Icons.text_fields_rounded,
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    children: [
                      StandardDropdownFormField<String>(
                        value: selectedType,
                        labelText: 'Type',
                        prefixIcon: Icons.category_rounded,
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                          DropdownMenuItem(value: 'custom', child: Text('Custom')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              selectedType = value;
                              // Auto-fill value based on type
                              switch (value) {
                                case 'weekly':
                                  valueController.text = '7';
                                  break;
                                case 'biweekly':
                                  valueController.text = '14';
                                  break;
                                case 'monthly':
                                  valueController.text = '30';
                                  break;
                                case 'quarterly':
                                  valueController.text = '90';
                                  break;
                                case 'yearly':
                                  valueController.text = '365';
                                  break;
                                default:
                                  valueController.clear();
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      StandardTextFormField(
                        controller: valueController,
                        labelText: 'Value (days)',
                        hintText: 'e.g., 7 for weekly',
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        prefixIcon: Icons.numbers_rounded,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (nameController.text.isEmpty ||
                      displayNameController.text.isEmpty ||
                      valueController.text.isEmpty) {
                    NotificationHelper.showWarning(context, message: 'Please fill all fields');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Add Frequency',
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

    if (result == true && _currentUser != null && mounted) {
      try {
        final newFrequency = Frequency(
          name: nameController.text.trim(),
          type: selectedType,
          value: int.parse(valueController.text.trim()),
          displayName: displayNameController.text.trim(),
          userId: _currentUser!.uid,
        );
        final dbHelper = DatabaseHelper();
        await dbHelper.addFrequency(newFrequency, _currentUser!.uid);
        await _loadFrequencies();
        NotificationHelper.showSuccess(context, message: 'Frequency added successfully');
      } catch (e) {
        NotificationHelper.showError(context, message: 'Error adding frequency: $e');
      }
    }
  }

  Future<void> _deleteFrequency(Frequency frequency) async {
    if (_currentUser == null) return;

    final confirm = await showModernConfirmDialog(
      context: context,
      title: 'Delete Frequency',
      message: 'Are you sure you want to delete "${frequency.displayName}"? This cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteFrequency(frequency.id!, _currentUser!.uid);
        await _loadFrequencies();
        NotificationHelper.showSuccess(context, message: 'Frequency deleted successfully');
      } catch (e) {
        NotificationHelper.showError(context, message: 'Error deleting frequency: $e');
      }
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
          'Manage Frequencies',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addFrequency,
            tooltip: 'Add Frequency',
          ),
        ],
      ),
      body: _isLoading
          ? const FrequencyShimmerList(itemCount: 8)
          : _frequencies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 64,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Frequencies',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add a frequency',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _frequencies.length,
                  itemBuilder: (context, index) {
                    final frequency = _frequencies[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
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
                        title: Text(
                          frequency.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${frequency.value} days · ${frequency.type}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: Colors.red,
                          onPressed: () => _deleteFrequency(frequency),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

