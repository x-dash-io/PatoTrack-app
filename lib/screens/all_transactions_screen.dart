import 'dart:async';
import 'package:pato_track/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../providers/currency_provider.dart';
import '../styles/app_spacing.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/input_fields.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final dbHelper = DatabaseHelper();
  List<model.Transaction> _allTransactions = [];
  List<model.Transaction> _filteredTransactions = [];
  List<model.Transaction> _paginatedTransactions =
      []; // Paginated subset to display
  List<Category> _allCategories = []; // NEW: To hold categories for the filter
  bool _isLoading = true;
  bool _isLoadingMore = false; // For pagination loading indicator
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  // Pagination constants
  static const int _itemsPerPage = 15;
  int _currentPage = 0;
  bool _hasMoreItems = true;

  // NEW: State variables to hold the current filter values
  int? _filterCategoryId;
  String? _filterType;
  DateTimeRange? _filterDateRange;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Load more when user scrolls near the bottom (80% of scroll extent)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadInitialData() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      // Load both transactions and categories from local database (works offline)
      final transactions = await dbHelper.getTransactions(_currentUser.uid);
      final categories = await dbHelper.getCategories(_currentUser.uid);

      if (mounted) {
        setState(() {
          _allTransactions = transactions;
          _allCategories = categories;
          _isLoading = false;
          _currentPage = 0; // Reset pagination
          _hasMoreItems = true;
        });
        _applyAllFilters(); // Apply initial (empty) filters
      }
    } catch (e) {
      // Handle any errors gracefully (e.g., database issues)
      debugPrint('Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allTransactions = [];
          _allCategories = [];
        });
        _applyAllFilters(); // This sets empty filtered lists.
      }
    }
  }

  // UPDATED: This function now applies ALL filters, not just search
  void _applyAllFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredTransactions = _allTransactions.where((transaction) {
        // Search filter
        final descriptionMatch =
            transaction.description.toLowerCase().contains(query);
        final amountMatch = transaction.amount.toString().contains(query);
        final searchMatch = query.isEmpty || descriptionMatch || amountMatch;

        // Category filter
        final categoryMatch = _filterCategoryId == null ||
            transaction.categoryId == _filterCategoryId;

        // Type filter
        final typeMatch =
            _filterType == null || transaction.type == _filterType;

        // Date range filter
        DateTime? transactionDate;
        if (_filterDateRange != null) {
          transactionDate = DateTime.tryParse(transaction.date);
          if (transactionDate == null) {
            return false;
          }
        }
        final dateMatch = _filterDateRange == null ||
            (!transactionDate!.isBefore(_filterDateRange!.start) &&
                transactionDate.isBefore(
                  _filterDateRange!.end.add(const Duration(days: 1)),
                ));

        return searchMatch && categoryMatch && typeMatch && dateMatch;
      }).toList();

      // Reset pagination when filters change
      _currentPage = 0;
      _hasMoreItems = true;
      _loadPaginatedTransactions();
    });
  }

  void _onSearchChanged(String _) {
    if (mounted) {
      setState(() {});
    }
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 250), _applyAllFilters);
  }

  // Load paginated transactions based on current page
  void _loadPaginatedTransactions() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= _filteredTransactions.length) {
      _hasMoreItems = false;
      return;
    }

    final nextPageItems = _filteredTransactions.sublist(
      startIndex,
      endIndex > _filteredTransactions.length
          ? _filteredTransactions.length
          : endIndex,
    );

    setState(() {
      if (_currentPage == 0) {
        // First page - replace existing items
        _paginatedTransactions = nextPageItems;
      } else {
        // Subsequent pages - append items
        _paginatedTransactions.addAll(nextPageItems);
      }
      _hasMoreItems = endIndex < _filteredTransactions.length;
    });
  }

  // Load more transactions when scrolling
  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate slight delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 300));

    _currentPage++;
    _loadPaginatedTransactions();

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // NEW: Function to show the filter bottom sheet
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Use StatefulBuilder to manage the state within the bottom sheet
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter Transactions',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),

                  // Filter by Type
                  StandardDropdownFormField<String>(
                    value: _filterType,
                    labelText: 'Filter by Type',
                    prefixIcon: AppIcons.category_rounded,
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                      DropdownMenuItem(
                          value: 'expense', child: Text('Expense')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => _filterType = value),
                  ),
                  const SizedBox(height: 16),

                  // Filter by Category
                  StandardDropdownFormField<int>(
                    value: _filterCategoryId,
                    labelText: 'Filter by Category',
                    prefixIcon: AppIcons.label_rounded,
                    items: _allCategories
                        .map((cat) => DropdownMenuItem(
                            value: cat.id, child: Text(cat.name)))
                        .toList(),
                    onChanged: (value) =>
                        setModalState(() => _filterCategoryId = value),
                  ),
                  const SizedBox(height: 16),

                  // Filter by Date Range
                  ListTile(
                    title: Text(_filterDateRange == null
                        ? 'Filter by Date Range'
                        : '${DateFormat.yMd().format(_filterDateRange!.start)} - ${DateFormat.yMd().format(_filterDateRange!.end)}'),
                    trailing: const Icon(AppIcons.calendar_today),
                    onTap: () async {
                      final picked = await showModernDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        title: 'Select Date Range',
                      );
                      if (picked != null) {
                        setModalState(() => _filterDateRange = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _filterCategoryId = null;
                            _filterType = null;
                            _filterDateRange = null;
                          });
                          // Also clear the main state
                          setState(() {
                            _filterCategoryId = null;
                            _filterType = null;
                            _filterDateRange = null;
                          });
                          _applyAllFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Apply the filters to the main screen's state
                          setState(() {});
                          _applyAllFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.tune_rounded),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: _isLoading
          ? const TransactionShimmerList(itemCount: 8)
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search transactions…',
                      prefixIcon: const Icon(AppIcons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon:
                                  const Icon(AppIcons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                // Active filters chip row
                if (_filterType != null ||
                    _filterCategoryId != null ||
                    _filterDateRange != null)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        if (_filterType != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text(_filterType!.capitalize()),
                              onDeleted: () {
                                setState(() => _filterType = null);
                                _applyAllFilters();
                              },
                              deleteIcon:
                                  const Icon(AppIcons.close_rounded, size: 14),
                            ),
                          ),
                        if (_filterCategoryId != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text(
                                _allCategories
                                    .firstWhere(
                                        (c) => c.id == _filterCategoryId,
                                        orElse: () => Category(
                                            id: 0, name: 'Category', type: ''))
                                    .name,
                              ),
                              onDeleted: () {
                                setState(() => _filterCategoryId = null);
                                _applyAllFilters();
                              },
                              deleteIcon:
                                  const Icon(AppIcons.close_rounded, size: 14),
                            ),
                          ),
                        if (_filterDateRange != null)
                          Chip(
                            label: const Text(
                              '\${DateFormat.MMMd().format(_filterDateRange!.start)} – \${DateFormat.MMMd().format(_filterDateRange!.end)}',
                            ),
                            onDeleted: () {
                              setState(() => _filterDateRange = null);
                              _applyAllFilters();
                            },
                            deleteIcon:
                                const Icon(AppIcons.close_rounded, size: 14),
                          ),
                      ],
                    ),
                  ),
                if (_allTransactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _filteredTransactions.isEmpty
                          ? 'No transactions found matching your search'
                          : 'Showing ${_filteredTransactions.length} ${_filteredTransactions.length == 1 ? "transaction" : "transactions"}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                AppIcons.search_off_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              Text('No transactions found',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Try adjusting your search or filters',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: _paginatedTransactions.length +
                              (_hasMoreItems || _isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            if (index >= _paginatedTransactions.length) {
                              return _isLoadingMore
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                    )
                                  : const SizedBox.shrink();
                            }

                            final tx = _paginatedTransactions[index];
                            final cat = _allCategories.isEmpty 
                                ? null 
                                : _allCategories.cast<Category?>().firstWhere(
                                    (c) => c?.id == tx.categoryId, 
                                    orElse: () => null
                                  );

                            return TransactionCard(
                              transaction: tx,
                              category: cat,
                              currency: currency,
                              onTap: () async {
                                final result = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(transaction: tx),
                                  ),
                                );
                                if (result == true) _loadInitialData();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "\${this[0].toUpperCase()}\${substring(1).toLowerCase()}";
  }
}
