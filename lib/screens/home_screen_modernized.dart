import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../helpers/sms_service.dart';
import '../models/bill.dart';
import '../models/transaction.dart' as model;
import '../widgets/dialog_helpers.dart';
import '../widgets/loading_widgets.dart';
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'add_bill_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbHelper = DatabaseHelper();
  final SmsService _smsService = SmsService();
  List<model.Transaction> _transactions = [];
  List<Bill> _bills = [];
  bool _isLoading = true;
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _balance = 0.0;
  String _currencySymbol = 'KSh';

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initHome();
  }

  Future<void> _initHome() async {
    await _requestSmsPermission();
    if (!mounted) return;
    if (_currentUser != null) {
      // Sync M-Pesa messages first, then refresh data once
      await _smsService.syncMpesaMessages(_currentUser!.uid);
      if (mounted) {
        _refreshData();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestSmsPermission() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      await Permission.sms.request();
    }
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
  
  Future<void> _refreshData() async {
    if (!mounted) return;
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadCurrencyPreference(),
        _loadBills(_currentUser!.uid),
        _loadTransactions(_currentUser!.uid),
      ]);
    } catch (e) {
      print("Error refreshing data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadCurrencyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currencySymbol = prefs.getString('currency') ?? 'KSh';
      });
    }
  }

  void _calculateSummary(List<model.Transaction> transactions) {
    _totalIncome = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    _totalExpenses = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    _balance = _totalIncome - _totalExpenses;
  }

  Future<void> _loadTransactions(String userId) async {
    final allTransactions = await dbHelper.getTransactions(userId);
    if(mounted) {
      _calculateSummary(allTransactions);
      setState(() {
        _transactions = allTransactions;
      });
    }
  }

  Future<void> _loadBills(String userId) async {
    final bills = await dbHelper.getBills(userId);
    if (mounted) {
      setState(() {
        _bills = bills;
      });
    }
  }

  Future<void> _deleteTransaction(int id, String userId) async {
    await dbHelper.deleteTransaction(id, userId);
    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaction Deleted',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
    _refreshData();
  }
  
  ({IconData icon, Color color}) _getBillStyling(String billName) {
    final name = billName.toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;
    if (name.contains('rent')) return (icon: Icons.home_outlined, color: Colors.orange);
    if (name.contains('netflix') || name.contains('movie')) return (icon: Icons.movie_outlined, color: Colors.red);
    if (name.contains('wifi') || name.contains('internet')) return (icon: Icons.wifi_outlined, color: Colors.blue);
    if (name.contains('electricity') || name.contains('power')) return (icon: Icons.lightbulb_outline, color: Colors.amber);
    if (name.contains('water')) return (icon: Icons.water_drop_outlined, color: Colors.lightBlue);
    if (name.contains('loan') || name.contains('debt')) return (icon: Icons.credit_card_outlined, color: Colors.purple);
    return (icon: Icons.receipt_long_outlined, color: colorScheme.onSurfaceVariant);
  }

  ({String text, Color color}) _getBillStatus(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final daysLeft = dueDay.difference(today).inDays;
    final colorScheme = Theme.of(context).colorScheme;

    if (daysLeft < 0) {
      return (text: 'Overdue', color: Colors.red);
    } else if (daysLeft == 0) {
      return (text: 'Due Today', color: Colors.orange);
    } else if (daysLeft <= 7) {
      return (text: 'Due in $daysLeft days', color: Colors.amber.shade700);
    } else {
      return (text: '$daysLeft days left', color: colorScheme.onSurfaceVariant);
    }
  }
  
  DateTime _calculateNextDueDate(Bill bill) {
    if (bill.recurrenceType == 'monthly') {
      return DateTime(bill.dueDate.year, bill.dueDate.month + 1, bill.dueDate.day);
    } else if (bill.recurrenceType == 'weekly') {
      return bill.dueDate.add(const Duration(days: 7));
    }
    return bill.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final currentUser = snapshot.data;

        return Scaffold(
          body: SafeArea(
            child: _isLoading
                ? _buildLoadingState()
                : RefreshIndicator(
                    onRefresh: _refreshData,
                    child: CustomScrollView(
                      slivers: [
                        // Modern Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_getGreeting()} 👋',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentUser?.displayName ?? 'User',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Summary Cards
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ModernSummaryCard(
                                    title: 'Income',
                                    amount: _totalIncome,
                                    icon: Icons.trending_up_rounded,
                                    color: Colors.green,
                                    currencySymbol: _currencySymbol,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ModernSummaryCard(
                                    title: 'Expenses',
                                    amount: _totalExpenses,
                                    icon: Icons.trending_down_rounded,
                                    color: Colors.red,
                                    currencySymbol: _currencySymbol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: _ModernSummaryCard(
                              title: 'Balance',
                              amount: _balance,
                              icon: Icons.account_balance_wallet_rounded,
                              color: _balance >= 0 ? Colors.blue : Colors.orange,
                              currencySymbol: _currencySymbol,
                              isFullWidth: true,
                            ),
                          ),
                        ),
                        // Upcoming Bills Section
                        SliverToBoxAdapter(
                          child: _buildUpcomingBillsSection(currentUser),
                        ),
                        // Recent Transactions Section
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Transactions',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (currentUser == null) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AllTransactionsScreen(),
                                      ),
                                    ).then((_) => _refreshData());
                                  },
                                  child: Text(
                                    'See All',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Transaction List
                        _buildTransactionList(currentUser),
                      ],
                    ),
                  ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen(),
                ),
              );
              if (currentUser != null) {
                _refreshData();
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Add Transaction',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: CustomScrollView(
        slivers: [
          // Header shimmer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 32,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Summary cards shimmer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _ShimmerCard(height: 120)),
                  const SizedBox(width: 12),
                  Expanded(child: _ShimmerCard(height: 120)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _ShimmerCard(height: 100),
            ),
          ),
          // Transactions shimmer
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: _ShimmerCard(height: 80),
              ),
              childCount: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBillsSection(User? currentUser) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Bills',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddBillScreen(),
                    ),
                  ).then((_) {
                    if (currentUser != null) {
                      _refreshData();
                    }
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Add Bill',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        _bills.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 64,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No upcoming bills',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add a bill to track payments',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _bills.length,
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final styling = _getBillStyling(bill.name);
                    final status = _getBillStatus(bill.dueDate);

                    return Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: status.color.withOpacity(0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: styling.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      styling.icon,
                                      size: 24,
                                      color: styling.color,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (bill.isRecurring)
                                    Icon(
                                      Icons.sync_rounded,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                bill.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_currencySymbol${bill.amount.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.text,
                                  style: GoogleFonts.inter(
                                    color: status.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonal(
                                  onPressed: () async {
                                    if (currentUser == null) return;
                                    
                                    final billTransaction = model.Transaction(
                                      type: 'expense',
                                      amount: bill.amount,
                                      description: 'Paid bill: ${bill.name}',
                                      date: DateTime.now().toIso8601String(),
                                      categoryId: await dbHelper.getOrCreateCategory(
                                        'Bills',
                                        currentUser.uid,
                                        type: 'expense',
                                      ),
                                    );
                                    await dbHelper.addTransaction(
                                      billTransaction,
                                      currentUser.uid,
                                    );

                                    if (bill.isRecurring) {
                                      final nextDueDate = _calculateNextDueDate(bill);
                                      final updatedBill = bill.copyWith(
                                        dueDate: nextDueDate,
                                      );
                                      await dbHelper.updateBill(
                                        updatedBill,
                                        currentUser.uid,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Recurring bill "${bill.name}" paid. Next due date set.',
                                              style: GoogleFonts.inter(),
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      await dbHelper.deleteBill(bill.id!, currentUser.uid);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Bill "${bill.name}" marked as paid.',
                                              style: GoogleFonts.inter(),
                                            ),
                                          ),
                                        );
                                      }
                                    }

                                    _refreshData();
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: Text(
                                    'Pay Bill',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
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
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildTransactionList(User? currentUser) {
    if (_transactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                ),
                const SizedBox(height: 24),
                Text(
                  'No transactions yet',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the button below to add your first transaction',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '');
    final recentTransactions = _transactions.take(10).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final transaction = recentTransactions[index];
          final isIncome = transaction.type == 'income';
          final amountColor = isIncome ? Colors.green : Colors.red;
          final amountPrefix = isIncome ? '+' : '-';

          final isMpesa = RegExp(r'\([A-Z0-9]{10}\)').hasMatch(transaction.description);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Dismissible(
              key: ValueKey(transaction.id),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (context) => TransactionDetailScreen(
                        transaction: transaction,
                      ),
                    ),
                  );
                  if (result == true) {
                    _refreshData();
                  }
                  return false;
                } else {
                  return await showModernConfirmDialog(
                    context: context,
                    title: 'Confirm Deletion',
                    message: 'Are you sure you want to delete this transaction?',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    isDestructive: true,
                  );
                }
              },
              onDismissed: (direction) {
                if (direction == DismissDirection.endToStart && currentUser != null) {
                  _deleteTransaction(transaction.id!, currentUser.uid);
                }
              },
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: isMpesa
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/mpesa_logo.png',
                            width: 32,
                            height: 32,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: amountColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: amountColor,
                            size: 24,
                          ),
                        ),
                  title: Text(
                    transaction.description.isNotEmpty
                        ? transaction.description
                        : transaction.type.capitalize(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          transaction.tag == 'business'
                              ? Icons.business_center_rounded
                              : Icons.person_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${transaction.tag.capitalize()} · ${transaction.date.split('T')[0]}',
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Text(
                    '$amountPrefix$_currencySymbol ${currencyFormatter.format(transaction.amount)}',
                    style: GoogleFonts.inter(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: recentTransactions.length,
      ),
    );
  }
}

class _ModernSummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final String currencySymbol;
  final bool isFullWidth;

  const _ModernSummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.currencySymbol,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$currencySymbol ${currencyFormatter.format(amount)}',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double height;

  const _ShimmerCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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

