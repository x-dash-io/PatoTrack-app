import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../widgets/modern_date_picker.dart';
import 'manage_categories_screen.dart';

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

  String _selectedTag = 'business';

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
            dbHelper.getCategories(_currentUser!.uid, type: _transactionType);
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

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final newTransaction = model.Transaction(
      type: _transactionType,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text,
      date: _selectedDate.toIso8601String(),
      categoryId: _selectedCategoryId,
      tag: _selectedTag,
    );

    await dbHelper.addTransaction(newTransaction, _currentUser!.uid);

    messenger.showSnackBar(
      const SnackBar(content: Text('Transaction Saved')),
    );
    navigator.pop();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'expense',
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward)),
                ButtonSegment(
                    value: 'income',
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward)),
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
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'business',
                    label: Text('Business'),
                    icon: Icon(Icons.business_center)),
                ButtonSegment(
                    value: 'personal',
                    label: Text('Personal'),
                    icon: Icon(Icons.person)),
              ],
              selected: {_selectedTag},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedTag = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FutureBuilder<List<Category>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final categories = snapshot.data ?? [];

                      return DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            _transactionType == 'expense'
                                ? Icons.category
                                : Icons.source,
                          ),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(category.name),
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
                IconButton.filledTonal(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Manage Categories',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) =>
                              const ManageCategoriesScreen()),
                    );
                    _loadCategories();
                  },
                )
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description / Note (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(
                    text: DateFormat('yyyy-MM-dd').format(_selectedDate),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saveTransaction,
              child: const Text('Save Transaction',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

