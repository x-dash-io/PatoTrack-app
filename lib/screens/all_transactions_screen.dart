import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../widgets/loading_widgets.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/input_fields.dart';
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
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  String _currencySymbol = 'KSh';

  // Pagination constants
  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  bool _hasMoreItems = true;

  // NEW: State variables to hold the current filter values
  int? _filterCategoryId;
  String? _filterType;
  DateTimeRange? _filterDateRange;

  @override
  void initState() {
    super.initState();
    _loadCurrencyPreference();
    _loadInitialData();
    _searchController.addListener(_applyAllFilters);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadCurrencyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currencySymbol = prefs.getString('currency') ?? 'KSh';
    });
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
          _applyAllFilters(); // Apply initial (empty) filters
        });
      }
    } catch (e) {
      // Handle any errors gracefully (e.g., database issues)
      print('Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allTransactions = [];
          _allCategories = [];
          _applyAllFilters(); // This will set _filteredTransactions to empty list
        });
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
        final dateMatch = _filterDateRange == null ||
            (DateTime.parse(transaction.date)
                    .isAfter(_filterDateRange!.start) &&
                DateTime.parse(transaction.date).isBefore(
                    _filterDateRange!.end.add(const Duration(days: 1))));

        return searchMatch && categoryMatch && typeMatch && dateMatch;
      }).toList();

      // Reset pagination when filters change
      _currentPage = 0;
      _hasMoreItems = true;
      _loadPaginatedTransactions();
    });
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
                    prefixIcon: Icons.category_rounded,
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
                    prefixIcon: Icons.label_rounded,
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
                    trailing: const Icon(Icons.calendar_today),
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
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_US', symbol: '$_currencySymbol ');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        actions: [
          // NEW: Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
            tooltip: 'Filter Transactions',
          ),
        ],
      ),
      body: _isLoading
          ? const TransactionShimmerList(itemCount: 8)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by description or amount',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_outlined,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions found',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your filters or search terms',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _paginatedTransactions.length +
                              (_hasMoreItems || _isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the bottom
                            if (index >= _paginatedTransactions.length) {
                              if (_isLoadingMore) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                );
                              } else if (!_hasMoreItems &&
                                  _paginatedTransactions.isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'No more transactions',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                );
                              }
                              // Return empty container if somehow we get here
                              return const SizedBox.shrink();
                            }

                            final transaction = _paginatedTransactions[index];
                            final isIncome = transaction.type == 'income';
                            final amountColor =
                                isIncome ? Colors.green : Colors.red;
                            final amountPrefix = isIncome ? '+' : '-';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              child: ListTile(
                                leading: Icon(
                                    isIncome
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: amountColor),
                                title: Text(
                                  transaction.description.isEmpty
                                      ? transaction.type.capitalize()
                                      : transaction.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  transaction.date.split('T')[0],
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                trailing: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.35,
                                  ),
                                  child: Text(
                                    '$amountPrefix${currencyFormatter.format(transaction.amount)}',
                                    style: TextStyle(
                                        color: amountColor,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                onTap: () async {
                                  final result =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            TransactionDetailScreen(
                                                transaction: transaction)),
                                  );
                                  if (result == true) {
                                    _loadInitialData(); // Use the full reload to get fresh data
                                  }
                                },
                              ),
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
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
