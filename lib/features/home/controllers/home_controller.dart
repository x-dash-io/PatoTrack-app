import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/database_helper.dart';
import '../../../helpers/sms_service.dart';
import '../../../models/bill.dart';
import '../../../models/transaction.dart' as model;

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  cancelled,
}

class HomeController extends ChangeNotifier {
  HomeController({
    DatabaseHelper? dbHelper,
    SmsService? smsService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _smsService = smsService ?? SmsService();

  static const String _smsLastSyncPreferenceKey = 'sms_last_sync_epoch_ms';

  final DatabaseHelper _dbHelper;
  final SmsService _smsService;

  bool _isLoading = true;
  String? _errorMessage;
  bool _isInitialized = false;

  List<model.Transaction> _transactions = <model.Transaction>[];
  List<Bill> _bills = <Bill>[];

  PermissionStatus _smsPermissionStatus = PermissionStatus.denied;
  DateTime? _lastSmsSyncAt;

  SyncStatus _syncStatus = SyncStatus.idle;
  String? _syncMessage;
  int _lastImportedCount = 0;
  bool _cancelSyncRequested = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<model.Transaction> get transactions =>
      List<model.Transaction>.unmodifiable(_transactions);

  List<Bill> get bills => List<Bill>.unmodifiable(_bills);

  PermissionStatus get smsPermissionStatus => _smsPermissionStatus;
  DateTime? get lastSmsSyncAt => _lastSmsSyncAt;

  SyncStatus get syncStatus => _syncStatus;
  String? get syncMessage => _syncMessage;
  int get lastImportedCount => _lastImportedCount;

  bool get smsPermissionGranted => _smsPermissionStatus.isGranted;
  bool get smsPermissionPermanentlyDenied =>
      _smsPermissionStatus.isPermanentlyDenied;

  double get totalIncome => _transactions
      .where((transaction) => transaction.type == 'income')
      .fold(0.0, (sum, transaction) => sum + transaction.amount);

  double get totalExpenses => _transactions
      .where((transaction) => transaction.type == 'expense')
      .fold(0.0, (sum, transaction) => sum + transaction.amount);

  double get balance => totalIncome - totalExpenses;

  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    await refresh(userId);
  }

  Future<void> refresh(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait(<Future<void>>[
        _loadSmsState(),
        _loadTransactions(userId),
        _loadBills(userId),
      ]);
    } catch (_) {
      _errorMessage =
          'Could not load your dashboard. Pull down to retry in a moment.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPermissionState() async {
    final status = await Permission.sms.status;
    _smsPermissionStatus = status;
    notifyListeners();
  }

  Future<PermissionStatus> requestSmsPermission() async {
    final status = await Permission.sms.request();
    _smsPermissionStatus = status;
    notifyListeners();
    return status;
  }

  Future<void> cancelSmsSync() async {
    if (_syncStatus != SyncStatus.syncing) {
      return;
    }
    _cancelSyncRequested = true;
    _syncStatus = SyncStatus.cancelled;
    _syncMessage = 'Cancel requested. Stopping sync…';
    notifyListeners();
  }

  Future<void> syncMpesaMessages(String userId) async {
    if (_syncStatus == SyncStatus.syncing) {
      return;
    }

    _cancelSyncRequested = false;
    _syncStatus = SyncStatus.syncing;
    _syncMessage = 'Syncing your latest M-Pesa messages…';
    notifyListeners();

    try {
      final status = await Permission.sms.status;
      _smsPermissionStatus = status;
      if (!status.isGranted) {
        _syncStatus = SyncStatus.error;
        _syncMessage = status.isPermanentlyDenied
            ? 'SMS permission is blocked. Open settings to enable import.'
            : 'SMS permission is required to import M-Pesa messages.';
        notifyListeners();
        return;
      }

      final importedCount = await _smsService.syncMpesaMessages(
        userId,
        shouldCancel: () => _cancelSyncRequested,
      );

      if (_cancelSyncRequested) {
        _syncStatus = SyncStatus.cancelled;
        _syncMessage = 'Sync cancelled. You can retry anytime.';
        notifyListeners();
        return;
      }

      _lastImportedCount = importedCount;

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_smsLastSyncPreferenceKey, now.millisecondsSinceEpoch);
      _lastSmsSyncAt = now;

      await Future.wait(<Future<void>>[
        _loadTransactions(userId),
        _loadBills(userId),
      ]);

      _syncStatus = SyncStatus.success;
      _syncMessage = importedCount == 0
          ? 'Sync complete. No new messages were found.'
          : 'Sync complete. Imported $importedCount new transactions.';
      notifyListeners();
    } on SmsSyncCancelledException {
      _syncStatus = SyncStatus.cancelled;
      _syncMessage = 'Sync cancelled. You can retry anytime.';
      notifyListeners();
    } catch (_) {
      _syncStatus = SyncStatus.error;
      _syncMessage =
          'Sync failed. Check SMS permission and try again from this card.';
      notifyListeners();
    }
  }

  Future<String?> deleteTransaction(int id, String userId) async {
    try {
      await _dbHelper.deleteTransaction(id, userId);
      await _loadTransactions(userId);
      return null;
    } catch (error) {
      return 'Could not delete that transaction. Please retry.';
    }
  }

  Future<String?> markBillPaid(Bill bill, String userId) async {
    try {
      final billCategoryId = await _dbHelper.getOrCreateCategory(
        'Bills',
        userId,
        type: 'expense',
      );

      final expenseTransaction = model.Transaction(
        type: 'expense',
        amount: bill.amount,
        description: 'Paid bill: ${bill.name}',
        date: DateTime.now().toIso8601String(),
        categoryId: billCategoryId,
      );

      await _dbHelper.addTransaction(expenseTransaction, userId);

      if (bill.isRecurring) {
        final updatedBill = bill.copyWith(
          dueDate: _calculateNextDueDate(bill),
        );
        await _dbHelper.updateBill(updatedBill, userId);
      } else if (bill.id != null) {
        await _dbHelper.deleteBill(bill.id!, userId);
      }

      await Future.wait(<Future<void>>[
        _loadBills(userId),
        _loadTransactions(userId),
      ]);
      return null;
    } catch (_) {
      return 'Could not mark the bill as paid. Please try again.';
    }
  }

  String syncStatusMessageFallback() {
    switch (_syncStatus) {
      case SyncStatus.syncing:
        return 'Syncing…';
      case SyncStatus.success:
        return 'Sync complete';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.cancelled:
        return 'Sync cancelled';
      case SyncStatus.idle:
        return 'Ready to sync';
    }
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

  Future<void> _loadSmsState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncEpoch = prefs.getInt(_smsLastSyncPreferenceKey);

    _smsPermissionStatus = await Permission.sms.status;
    _lastSmsSyncAt = lastSyncEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncEpoch)
        : null;
  }

  Future<void> _loadTransactions(String userId) async {
    _transactions = await _dbHelper.getTransactions(userId);
  }

  Future<void> _loadBills(String userId) async {
    _bills = await _dbHelper.getBills(userId);
  }
}
