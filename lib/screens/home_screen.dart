import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../helpers/sms_service.dart';
import '../helpers/responsive_helper.dart';
import '../helpers/notification_service.dart';
import '../models/bill.dart';
import '../models/transaction.dart' as model;
import '../widgets/dialog_helpers.dart';
import '../widgets/loading_widgets.dart';
import '../helpers/notification_helper.dart';
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'add_bill_screen.dart';
import 'transaction_detail_screen.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

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
      // Sync M-Pesa messages to add any new transactions.
      try {
        print('Starting M-Pesa message sync...');
        await _smsService.syncMpesaMessages(_currentUser.uid);
        print('M-Pesa message sync completed');
      } catch (e) {
        print('Error syncing M-Pesa messages: $e');
        // Continue even if sync fails
      }

      // Finally, refresh the UI with all data (Firestore + local)
      if (mounted) {
        await _refreshData();
        print(
            'Data refresh completed. Transactions: ${_transactions.length}, Income: $_totalIncome, Expenses: $_totalExpenses');
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
        _loadBills(_currentUser.uid),
        _loadTransactions(_currentUser.uid),
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
    _totalIncome = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    _totalExpenses = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    _balance = _totalIncome - _totalExpenses;
  }

  Future<void> _loadTransactions(String userId) async {
    final allTransactions = await dbHelper.getTransactions(userId);
    if (mounted) {
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
    if (mounted) {
      NotificationHelper.showSuccess(context, message: 'Transaction Deleted');
    }
    _refreshData();
  }

  ({IconData icon, Color color}) _getBillStyling(String billName) {
    final name = billName.toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;
    if (name.contains('rent'))
      return (icon: Icons.home_outlined, color: Colors.orange);
    if (name.contains('netflix') || name.contains('movie'))
      return (icon: Icons.movie_outlined, color: Colors.red);
    if (name.contains('wifi') || name.contains('internet'))
      return (icon: Icons.wifi_outlined, color: Colors.blue);
    if (name.contains('electricity') || name.contains('power'))
      return (icon: Icons.lightbulb_outline, color: Colors.amber);
    if (name.contains('water'))
      return (icon: Icons.water_drop_outlined, color: Colors.lightBlue);
    if (name.contains('loan') || name.contains('debt'))
      return (icon: Icons.credit_card_outlined, color: Colors.purple);
    return (
      icon: Icons.receipt_long_outlined,
      color: colorScheme.onSurfaceVariant
    );
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

  void _showBillOptions(BuildContext context, Bill bill, User? currentUser) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parentContext = context; // Store parent context

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveHelper.radius(context, 28)),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin:
                    EdgeInsets.only(top: ResponsiveHelper.spacing(context, 12)),
                width: ResponsiveHelper.width(context, 40),
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(
                      ResponsiveHelper.radius(context, 2)),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              // Bill info
              Padding(
                padding: ResponsiveHelper.edgeInsetsSymmetric(context, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: ResponsiveHelper.edgeInsetsAll(context, 12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                            ResponsiveHelper.radius(context, 12)),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: ResponsiveHelper.iconSize(context, 24),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.name,
                            style: GoogleFonts.inter(
                              fontSize: ResponsiveHelper.fontSize(context, 18),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                              height: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            '$_currencySymbol${bill.amount.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: ResponsiveHelper.fontSize(context, 16),
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              // Action buttons
              ListTile(
                leading: Container(
                  padding: ResponsiveHelper.edgeInsetsAll(context, 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                        ResponsiveHelper.radius(context, 10)),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: ResponsiveHelper.iconSize(context, 22),
                  ),
                ),
                title: Text(
                  'Edit Bill',
                  style: GoogleFonts.inter(
                    fontSize: ResponsiveHelper.fontSize(context, 16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (context) => AddBillScreen(billToEdit: bill),
                    ),
                  ).then((_) {
                    if (currentUser != null) {
                      _refreshData();
                    }
                  });
                },
              ),
              Divider(height: 1, indent: 70, endIndent: 20),
              ListTile(
                leading: Container(
                  padding: ResponsiveHelper.edgeInsetsAll(context, 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                        ResponsiveHelper.radius(context, 10)),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: ResponsiveHelper.iconSize(context, 22),
                  ),
                ),
                title: Text(
                  'Delete Bill',
                  style: GoogleFonts.inter(
                    fontSize: ResponsiveHelper.fontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);

                  // Wait a bit for bottom sheet to close
                  await Future.delayed(const Duration(milliseconds: 200));

                  if (!parentContext.mounted) return;

                  final confirm = await showModernConfirmDialog(
                    context: parentContext,
                    title: 'Delete Bill',
                    message: 'Are you sure you want to delete "${bill.name}"?',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    isDestructive: true,
                  );

                  if (confirm == true && currentUser != null) {
                    if (!parentContext.mounted) return;

                    // Show loading dialog
                    showDialog(
                      context: parentContext,
                      barrierDismissible: false,
                      builder: (dialogContext) => WillPopScope(
                        onWillPop: () async => false,
                        child: Dialog(
                          backgroundColor: Colors.transparent,
                          child: Container(
                            padding: ResponsiveHelper.edgeInsetsAll(
                                parentContext, 24),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                  ResponsiveHelper.radius(parentContext, 20)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ModernLoadingIndicator(
                                  message: 'Deleting bill...',
                                  size: 40,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    try {
                      // Delete from database
                      final result =
                          await dbHelper.deleteBill(bill.id!, currentUser.uid);

                      if (result > 0) {
                        // Cancel notification if it exists
                        try {
                          final notificationService = NotificationService();
                          await notificationService
                              .cancelNotification(bill.id!);
                        } catch (e) {
                          print('Error canceling notification: $e');
                        }

                        if (parentContext.mounted) {
                          // Close loading dialog
                          Navigator.of(parentContext).pop();

                          // Refresh data
                          _refreshData();

                          // Show success message
                          NotificationHelper.showSuccess(parentContext,
                              message:
                                  'Bill "${bill.name}" deleted successfully');
                        }
                      } else {
                        throw Exception('Bill not found or already deleted');
                      }
                    } catch (e) {
                      if (parentContext.mounted) {
                        // Close loading dialog
                        Navigator.of(parentContext).pop();

                        // Show error message
                        NotificationHelper.showError(parentContext,
                            message: 'Error deleting bill: ${e.toString()}');
                      }
                    }
                  }
                },
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _calculateNextDueDate(Bill bill) {
    switch (bill.recurrenceType) {
      case 'weekly':
        return bill.dueDate.add(const Duration(days: 7));
      case 'biweekly':
        return bill.dueDate.add(const Duration(days: 14));
      case 'monthly':
        return _addMonthsPreservingDay(bill.dueDate, 1);
      case 'quarterly':
        return _addMonthsPreservingDay(bill.dueDate, 3);
      case 'yearly':
        return _addMonthsPreservingDay(bill.dueDate, 12);
      default:
        return bill.dueDate;
    }
  }

  DateTime _addMonthsPreservingDay(DateTime source, int monthsToAdd) {
    final targetMonthBase = DateTime(
      source.year,
      source.month + monthsToAdd,
      1,
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
    final lastDayOfTargetMonth =
        DateTime(targetMonthBase.year, targetMonthBase.month + 1, 0).day;
    final clampedDay =
        source.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : source.day;
    return DateTime(
      targetMonthBase.year,
      targetMonthBase.month,
      clampedDay,
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
  }

  IconData _getStatusIcon(String statusText) {
    if (statusText.contains('Overdue')) {
      return Icons.warning_rounded;
    } else if (statusText.contains('Today')) {
      return Icons.event_available_rounded;
    } else {
      return Icons.calendar_today_rounded;
    }
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
                            padding: ResponsiveHelper.edgeInsets(
                                context, 24, 20, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_getGreeting()} 👋',
                                  style: GoogleFonts.inter(
                                    fontSize:
                                        ResponsiveHelper.fontSize(context, 16),
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(
                                    height:
                                        ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  currentUser?.displayName ?? 'User',
                                  style: GoogleFonts.inter(
                                    fontSize:
                                        ResponsiveHelper.fontSize(context, 28),
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Enhanced Summary Cards Section
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: ResponsiveHelper.edgeInsets(
                                context, 16, 20, 12, 20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _EnhancedSummaryCard(
                                        title: 'Income',
                                        amount: _totalIncome,
                                        icon: Icons.trending_up_rounded,
                                        color: Colors.green,
                                        currencySymbol: _currencySymbol,
                                        percentage: _totalIncome > 0 &&
                                                _totalExpenses > 0
                                            ? (_totalIncome /
                                                (_totalIncome +
                                                    _totalExpenses) *
                                                100)
                                            : 0,
                                      ),
                                    ),
                                    SizedBox(
                                        width: ResponsiveHelper.spacing(
                                            context, 12)),
                                    Expanded(
                                      child: _EnhancedSummaryCard(
                                        title: 'Expenses',
                                        amount: _totalExpenses,
                                        icon: Icons.trending_down_rounded,
                                        color: Colors.red,
                                        currencySymbol: _currencySymbol,
                                        percentage: _totalIncome > 0 &&
                                                _totalExpenses > 0
                                            ? (_totalExpenses /
                                                (_totalIncome +
                                                    _totalExpenses) *
                                                100)
                                            : 0,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height:
                                        ResponsiveHelper.spacing(context, 12)),
                                _EnhancedSummaryCard(
                                  title: 'Balance',
                                  amount: _balance,
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: _balance >= 0
                                      ? Colors.blue
                                      : Colors.orange,
                                  currencySymbol: _currencySymbol,
                                  isFullWidth: true,
                                  showTrend: true,
                                  isPositive: _balance >= 0,
                                ),
                              ],
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
                            padding: ResponsiveHelper.edgeInsets(
                                context, 16, 20, 8, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Recent Transactions',
                                        style: GoogleFonts.inter(
                                          fontSize: ResponsiveHelper.fontSize(
                                              context, 20),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        if (currentUser == null) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AllTransactionsScreen(),
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
                                SizedBox(
                                    height:
                                        ResponsiveHelper.spacing(context, 6)),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.swipe_rounded,
                                      size: ResponsiveHelper.iconSize(
                                          context, 14),
                                      color: colorScheme.onSurfaceVariant
                                          .withOpacity(0.6),
                                    ),
                                    SizedBox(
                                        width: ResponsiveHelper.spacing(
                                            context, 6)),
                                    Text(
                                      'Swipe right to edit, swipe left to delete',
                                      style: GoogleFonts.inter(
                                        fontSize: ResponsiveHelper.fontSize(
                                            context, 12),
                                        color: colorScheme.onSurfaceVariant
                                            .withOpacity(0.7),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
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
          floatingActionButton: Container(
            margin: ResponsiveHelper.edgeInsets(context, 0, 20, 16, 20),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(ResponsiveHelper.radius(context, 20)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
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
              icon: Icon(
                Icons.add_rounded,
                size: ResponsiveHelper.iconSize(context, 26),
              ),
              label: Text(
                'Add Transaction',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: ResponsiveHelper.fontSize(context, 16),
                  letterSpacing: 0.3,
                ),
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(ResponsiveHelper.radius(context, 20)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
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
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 32,
                    width: 200,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
          padding: ResponsiveHelper.edgeInsetsSymmetric(context, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Upcoming Bills',
                  style: GoogleFonts.inter(
                    fontSize: ResponsiveHelper.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                icon: Icon(Icons.add_rounded,
                    size: ResponsiveHelper.iconSize(context, 18)),
                label: Text(
                  'Add Bill',
                  style: GoogleFonts.inter(
                    fontSize: ResponsiveHelper.fontSize(context, 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        _bills.isEmpty
            ? Padding(
                padding: ResponsiveHelper.edgeInsetsSymmetric(context, 20, 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: ResponsiveHelper.iconSize(context, 64),
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                      Text(
                        'No upcoming bills',
                        style: GoogleFonts.inter(
                          fontSize: ResponsiveHelper.fontSize(context, 18),
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        'Add a bill to track payments',
                        style: GoogleFonts.inter(
                          fontSize: ResponsiveHelper.fontSize(context, 14),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate card width dynamically based on screen size - MUCH more compact
                  final screenWidth = MediaQuery.of(context).size.width;
                  // Very compact cards for small screens
                  final cardWidth = screenWidth <= 380
                      ? screenWidth * 0.58 // 58% for very small screens
                      : screenWidth <= 400
                          ? screenWidth * 0.62 // 62% for 400 DPI screens
                          : screenWidth * 0.68; // 68% for larger screens
                  final cardWidthClamped = cardWidth.clamp(140.0, 220.0);
                  final cardHeight = screenWidth <= 380
                      ? 155.0 // Increased for better spacing
                      : screenWidth <= 400
                          ? 165.0 // Increased for better spacing
                          : ResponsiveHelper.height(
                              context, 180); // Increased for better spacing

                  return SizedBox(
                    height: cardHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          ResponsiveHelper.edgeInsetsSymmetric(context, 20, 0),
                      itemCount: _bills.length,
                      itemBuilder: (context, index) {
                        final bill = _bills[index];
                        final styling = _getBillStyling(bill.name);
                        final status = _getBillStatus(bill.dueDate);

                        return Container(
                          width: cardWidthClamped,
                          margin: EdgeInsets.only(
                              right: ResponsiveHelper.spacing(context, 16)),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  _showBillOptions(context, bill, currentUser),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveHelper.radius(context, 20)),
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: status.color.withOpacity(0.2),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.radius(context, 20)),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        colorScheme.surfaceContainerHighest
                                            .withOpacity(0.5),
                                        colorScheme.surface,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.radius(context, 20)),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                        ResponsiveHelper.padding(
                                            context,
                                            (cardWidth * 0.05)
                                                .clamp(6.0, 10.0))),
                                    child: LayoutBuilder(
                                      builder: (context, cardConstraints) {
                                        // Calculate responsive sizes based on card width - VERY compact
                                        final screenWidth =
                                            MediaQuery.of(context).size.width;
                                        final isSmall = screenWidth <= 400;
                                        final isVerySmall = screenWidth <= 380;

                                        final availableHeight = cardHeight -
                                            (isVerySmall
                                                ? 16.0
                                                : isSmall
                                                    ? 18.0
                                                    : 20.0);
                                        final iconSize = isVerySmall
                                            ? 16.0
                                            : isSmall
                                                ? 17.0
                                                : ResponsiveHelper.iconSize(
                                                    context, 20);
                                        final fontSizeName = isVerySmall
                                            ? ResponsiveHelper.fontSize(
                                                context, 12)
                                            : isSmall
                                                ? ResponsiveHelper.fontSize(
                                                    context, 13)
                                                : ResponsiveHelper.fontSize(
                                                    context, 14);
                                        final fontSizeAmount = isVerySmall
                                            ? ResponsiveHelper.fontSize(
                                                context, 16)
                                            : isSmall
                                                ? ResponsiveHelper.fontSize(
                                                    context, 17)
                                                : ResponsiveHelper.fontSize(
                                                    context, 19);
                                        final fontSizeStatus = isVerySmall
                                            ? ResponsiveHelper.fontSize(
                                                context, 9)
                                            : ResponsiveHelper.fontSize(
                                                context, 10);
                                        // Increased spacing for better layout
                                        final verticalSpacing = isVerySmall
                                            ? 6.0
                                            : isSmall
                                                ? 7.0
                                                : 8.0;
                                        final horizontalSpacing = isVerySmall
                                            ? 4.0
                                            : isSmall
                                                ? 5.0
                                                : 6.0;
                                        final buttonHeight = isVerySmall
                                            ? 28.0
                                            : isSmall
                                                ? 30.0
                                                : ResponsiveHelper.buttonHeight(
                                                    context, 32);

                                        return SizedBox(
                                          height: availableHeight,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Icon and recurring indicator row - with better spacing
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(
                                                        ResponsiveHelper
                                                            .padding(
                                                                context,
                                                                iconSize *
                                                                    0.35)),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                        colors: [
                                                          styling.color,
                                                          styling.color
                                                              .withOpacity(0.8),
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              ResponsiveHelper
                                                                  .radius(
                                                                      context,
                                                                      10)),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: styling.color
                                                              .withOpacity(
                                                                  0.35),
                                                          blurRadius: 4,
                                                          offset: Offset(
                                                              0,
                                                              ResponsiveHelper
                                                                  .spacing(
                                                                      context,
                                                                      2)),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      styling.icon,
                                                      size: iconSize,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (bill.isRecurring)
                                                    Container(
                                                      padding: EdgeInsets.all(
                                                          ResponsiveHelper
                                                              .padding(
                                                                  context,
                                                                  iconSize *
                                                                      0.25)),
                                                      decoration: BoxDecoration(
                                                        color: colorScheme
                                                            .primaryContainer
                                                            .withOpacity(0.6),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: colorScheme
                                                              .primaryContainer
                                                              .withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.sync_rounded,
                                                        size: iconSize * 0.6,
                                                        color: colorScheme
                                                            .onPrimaryContainer,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              SizedBox(
                                                  height: verticalSpacing + 2),
                                              // Bill name - with better spacing
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    bill.name,
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: fontSizeName,
                                                      color:
                                                          colorScheme.onSurface,
                                                      height: 1.2,
                                                      letterSpacing: 0.1,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: verticalSpacing),
                                              // Amount - better aligned
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  '$_currencySymbol${bill.amount.toStringAsFixed(0)}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: fontSizeAmount,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        colorScheme.onSurface,
                                                    letterSpacing: -0.5,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                              ),
                                              SizedBox(height: verticalSpacing),
                                              // Status badge - improved design with better spacing
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      ResponsiveHelper.spacing(
                                                          context,
                                                          horizontalSpacing),
                                                  vertical:
                                                      ResponsiveHelper.spacing(
                                                          context,
                                                          verticalSpacing *
                                                              0.5),
                                                ),
                                                decoration: BoxDecoration(
                                                  color: status.color
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          ResponsiveHelper
                                                              .radius(
                                                                  context, 8)),
                                                  border: Border.all(
                                                    color: status.color
                                                        .withOpacity(0.4),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _getStatusIcon(
                                                          status.text),
                                                      size: ResponsiveHelper
                                                          .iconSize(
                                                              context,
                                                              fontSizeStatus +
                                                                  1),
                                                      color: status.color,
                                                    ),
                                                    SizedBox(
                                                        width: ResponsiveHelper
                                                            .spacing(
                                                                context,
                                                                horizontalSpacing *
                                                                    0.5)),
                                                    Flexible(
                                                      child: Text(
                                                        status.text,
                                                        style:
                                                            GoogleFonts.inter(
                                                          color: status.color,
                                                          fontSize:
                                                              fontSizeStatus,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          letterSpacing: 0.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                  height:
                                                      verticalSpacing * 0.8),
                                              const Spacer(),
                                              // Pay button - better sized and spaced
                                              SizedBox(
                                                width: double.infinity,
                                                child: FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: ResponsiveHelper
                                                          .spacing(context,
                                                              horizontalSpacing),
                                                      vertical: ResponsiveHelper
                                                          .spacing(
                                                              context,
                                                              verticalSpacing *
                                                                  0.6),
                                                    ),
                                                    minimumSize:
                                                        Size(0, buttonHeight),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              ResponsiveHelper
                                                                  .radius(
                                                                      context,
                                                                      12)),
                                                    ),
                                                    backgroundColor:
                                                        styling.color,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  onPressed: () async {
                                                    // Stop event propagation to prevent card tap
                                                    if (currentUser == null)
                                                      return;

                                                    final billTransaction =
                                                        model.Transaction(
                                                      type: 'expense',
                                                      amount: bill.amount,
                                                      description:
                                                          'Paid bill: ${bill.name}',
                                                      date: DateTime.now()
                                                          .toIso8601String(),
                                                      categoryId: await dbHelper
                                                          .getOrCreateCategory(
                                                        'Bills',
                                                        currentUser.uid,
                                                        type: 'expense',
                                                      ),
                                                    );
                                                    await dbHelper
                                                        .addTransaction(
                                                      billTransaction,
                                                      currentUser.uid,
                                                    );

                                                    if (bill.isRecurring) {
                                                      final nextDueDate =
                                                          _calculateNextDueDate(
                                                              bill);
                                                      final updatedBill =
                                                          bill.copyWith(
                                                        dueDate: nextDueDate,
                                                      );
                                                      await dbHelper.updateBill(
                                                        updatedBill,
                                                        currentUser.uid,
                                                      );
                                                      if (!mounted) return;
                                                      NotificationHelper
                                                          .showSuccess(
                                                        this.context,
                                                        message:
                                                            'Recurring bill "${bill.name}" paid. Next due date set.',
                                                      );
                                                    } else {
                                                      await dbHelper.deleteBill(
                                                          bill.id!,
                                                          currentUser.uid);
                                                      if (!mounted) return;
                                                      NotificationHelper
                                                          .showSuccess(
                                                        this.context,
                                                        message:
                                                            'Bill "${bill.name}" marked as paid.',
                                                      );
                                                    }

                                                    _refreshData();
                                                  },
                                                  child: Text(
                                                    'Pay Bill',
                                                    style: GoogleFonts.inter(
                                                      fontSize: ResponsiveHelper
                                                          .fontSize(
                                                              context, 14),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
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

    final currencyFormatter =
        NumberFormat.currency(locale: 'en_US', symbol: '');
    final recentTransactions = _transactions.take(10).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final transaction = recentTransactions[index];
          final isIncome = transaction.type == 'income';
          final amountColor = isIncome ? Colors.green : Colors.red;
          final amountPrefix = isIncome ? '+' : '-';

          final isMpesa =
              RegExp(r'\([A-Z0-9]{10}\)').hasMatch(transaction.description);

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
                    message:
                        'Are you sure you want to delete this transaction?',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    isDestructive: true,
                  );
                }
              },
              onDismissed: (direction) {
                if (direction == DismissDirection.endToStart &&
                    currentUser != null) {
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Leading icon
                      isMpesa
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
                      const SizedBox(width: 12),
                      // Title and subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
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
                            const SizedBox(height: 4),
                            Text(
                              transaction.date.split('T')[0],
                              style: GoogleFonts.inter(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount
                      Flexible(
                        child: Text(
                          '$amountPrefix$_currencySymbol ${currencyFormatter.format(transaction.amount)}',
                          style: GoogleFonts.inter(
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
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

class _EnhancedSummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final String currencySymbol;
  final bool isFullWidth;
  final double? percentage;
  final bool showTrend;
  final bool? isPositive;

  const _EnhancedSummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.currencySymbol,
    this.isFullWidth = false,
    this.percentage,
    this.showTrend = false,
    this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_US', symbol: '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(ResponsiveHelper.radius(context, 24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.25 : 0.15),
            color.withOpacity(isDark ? 0.15 : 0.08),
            color.withOpacity(isDark ? 0.10 : 0.05),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Could add navigation to detailed view
          },
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.radius(context, 24)),
          child: Container(
            padding: ResponsiveHelper.edgeInsetsAll(context, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: ResponsiveHelper.edgeInsetsAll(context, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color,
                            color.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                            ResponsiveHelper.radius(context, 12)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: ResponsiveHelper.iconSize(context, 22),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: ResponsiveHelper.fontSize(context, 13),
                              color:
                                  colorScheme.onSurfaceVariant.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (percentage != null && percentage! > 0)
                            Padding(
                              padding: EdgeInsets.only(
                                  top: ResponsiveHelper.spacing(context, 2)),
                              child: Text(
                                '${percentage!.toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(
                                  fontSize:
                                      ResponsiveHelper.fontSize(context, 10),
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showTrend && isPositive != null)
                      Container(
                        padding:
                            ResponsiveHelper.edgeInsetsSymmetric(context, 6, 8),
                        decoration: BoxDecoration(
                          color: (isPositive! ? Colors.green : Colors.orange)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                              ResponsiveHelper.radius(context, 8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive!
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: ResponsiveHelper.iconSize(context, 14),
                              color: isPositive! ? Colors.green : Colors.orange,
                            ),
                            SizedBox(
                                width: ResponsiveHelper.spacing(context, 2)),
                            Text(
                              isPositive! ? 'Good' : 'Low',
                              style: GoogleFonts.inter(
                                fontSize:
                                    ResponsiveHelper.fontSize(context, 10),
                                color:
                                    isPositive! ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$currencySymbol ${currencyFormatter.format(amount)}',
                    style: GoogleFonts.inter(
                      fontSize: ResponsiveHelper.fontSize(context, 20),
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
