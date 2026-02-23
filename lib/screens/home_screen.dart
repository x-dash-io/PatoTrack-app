import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../features/home/controllers/home_controller.dart';
import '../features/home/widgets/home_header.dart';
import '../features/home/widgets/recent_transactions_section.dart';
import '../features/home/widgets/sms_sync_card.dart';
import '../features/home/widgets/summary_cards_section.dart';
import '../features/home/widgets/upcoming_bills_card.dart';
import '../helpers/notification_helper.dart';
import '../models/bill.dart';
import '../models/transaction.dart' as model;
import '../providers/currency_provider.dart';
import '../styles/app_spacing.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';
import 'add_bill_screen.dart';
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen> {
  final HomeController _homeController = HomeController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _homeController.initialize(user.uid);
    }
  }

  @override
  void dispose() {
    _homeController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  Future<void> _openAddTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AddTransactionScreen(),
      ),
    );

    if (user != null && mounted) {
      await _homeController.refresh(user.uid);
    }
  }

  Future<void> _openAddBill() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AddBillScreen(),
      ),
    );

    if (user != null && mounted) {
      await _homeController.refresh(user.uid);
    }
  }

  Future<void> _openTransactionDetails(model.Transaction transaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );

    if (result == true && mounted) {
      await _homeController.refresh(user.uid);
    }
  }

  Future<void> _openAllTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AllTransactionsScreen(),
      ),
    );

    if (user != null && mounted) {
      await _homeController.refresh(user.uid);
    }
  }

  Future<void> _handlePayBill(Bill bill) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final error = await _homeController.markBillPaid(bill, user.uid);
    if (!mounted) {
      return;
    }

    if (error == null) {
      NotificationHelper.showSuccess(
        context,
        message: bill.isRecurring
            ? 'Bill paid. Next due date has been scheduled.'
            : 'Bill marked as paid.',
      );
    } else {
      NotificationHelper.showError(context, message: error);
    }
  }

  Future<void> _handleSmsImportAction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    if (_homeController.smsPermissionGranted) {
      await _homeController.syncMpesaMessages(user.uid);
      if (!mounted) {
        return;
      }
      _showSyncFeedback();
      return;
    }

    if (_homeController.smsPermissionPermanentlyDenied) {
      final opened = await openAppSettings();
      if (opened) {
        await _homeController.refreshPermissionState();
      }
      return;
    }

    final shouldContinue = await _showPermissionRationaleSheet();
    if (!shouldContinue) {
      return;
    }

    final status = await _homeController.requestSmsPermission();
    if (!mounted) {
      return;
    }

    if (!status.isGranted) {
      NotificationHelper.showWarning(
        context,
        message: status.isPermanentlyDenied
            ? 'SMS permission is blocked. Open app settings to enable it later.'
            : 'No problem. You can keep tracking manually from the add transaction flow.',
      );
      return;
    }

    await _homeController.syncMpesaMessages(user.uid);
    if (!mounted) {
      return;
    }
    _showSyncFeedback();
  }

  Future<bool> _showPermissionRationaleSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable SMS import?',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'PatoTrack reads only M-Pesa messages when you tap sync. We never read personal chats. You can skip this and add transactions manually.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Not now'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  void _showSyncFeedback() {
    final status = _homeController.syncStatus;
    final message = _homeController.syncMessage ??
        _homeController.syncStatusMessageFallback();

    switch (status) {
      case SyncStatus.success:
        NotificationHelper.showSuccess(context, message: message);
        return;
      case SyncStatus.error:
        NotificationHelper.showError(context, message: message);
        return;
      case SyncStatus.cancelled:
        NotificationHelper.showWarning(context, message: message);
        return;
      case SyncStatus.idle:
      case SyncStatus.syncing:
        NotificationHelper.showInfo(context, message: message);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Sign in to view your dashboard.'),
        ),
      );
    }

    return ChangeNotifierProvider<HomeController>.value(
      value: _homeController,
      child: Consumer2<HomeController, CurrencyProvider>(
        builder: (context, home, currency, _) {
          return Scaffold(
            body: AppScreenBackground(
              child: RefreshIndicator(
                onRefresh: () => home.refresh(user.uid),
                child: home.isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(
                            child: ModernLoadingIndicator(
                              message: 'Loading your dashboard…',
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: 96,
                        ),
                        children: [
                          HomeHeader(user: user, greeting: _greeting()),
                          const SizedBox(height: AppSpacing.sm),
                          SummaryCardsSection(
                            currency: currency,
                            income: home.totalIncome,
                            expenses: home.totalExpenses,
                            balance: home.balance,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SmsSyncCard(
                            permissionStatus: home.smsPermissionStatus,
                            syncStatus: home.syncStatus,
                            syncMessage: home.syncMessage,
                            lastSyncAt: home.lastSmsSyncAt,
                            onPrimaryAction: _handleSmsImportAction,
                            onRetry: _handleSmsImportAction,
                            onCancel: home.cancelSmsSync,
                            onOpenSettings: () async {
                              final opened = await openAppSettings();
                              if (opened) {
                                await home.refreshPermissionState();
                              }
                            },
                            onFallbackManual: _openAddTransaction,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          UpcomingBillsCard(
                            bills: home.bills,
                            currency: currency,
                            onAddBill: _openAddBill,
                            onPayBill: _handlePayBill,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openAddTransaction,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add transaction'),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          RecentTransactionsSection(
                            transactions: home.transactions,
                            currency: currency,
                            onViewAll: _openAllTransactions,
                            onOpenTransaction: _openTransactionDetails,
                            onAddTransaction: _openAddTransaction,
                          ),
                          if (home.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              child: Text(
                                home.errorMessage!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
