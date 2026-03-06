import 'package:firebase_auth/firebase_auth.dart';
import 'package:pato_track/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../styles/app_colors.dart';
import '../styles/app_spacing.dart';
import '../widgets/loading_widgets.dart';
import 'add_bill_screen.dart';
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'transaction_detail_screen.dart';
import 'review_queue_screen.dart';

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
    if (user != null) _homeController.initialize(user.uid);
  }

  @override
  void dispose() {
    _homeController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _openAddTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AddTransactionScreen()),
    );
    if (user != null && mounted) await _homeController.refresh(user.uid);
  }

  Future<void> _openAddBill() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AddBillScreen()),
    );
    if (user != null && mounted) await _homeController.refresh(user.uid);
  }

  Future<void> _openEditBill(Bill bill) async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddBillScreen(billToEdit: bill),
      ),
    );
    if (user != null && mounted) await _homeController.refresh(user.uid);
  }

  Future<void> _openTransactionDetails(model.Transaction transaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
    if (result == true && mounted) await _homeController.refresh(user.uid);
  }

  Future<void> _openAllTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AllTransactionsScreen()),
    );
    if (user != null && mounted) await _homeController.refresh(user.uid);
  }

  Future<void> _openReviewQueue() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReviewQueueScreen()),
    );
    if (user != null && mounted) await _homeController.refresh(user.uid);
  }

  Future<void> _handlePayBill(Bill bill) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final error = await _homeController.markBillPaid(bill, user.uid);
    if (!mounted) return;
    if (error == null) {
      NotificationHelper.showSuccess(
        context,
        message: bill.isRecurring
            ? 'Bill paid. Next due date scheduled.'
            : 'Bill marked as paid.',
      );
    } else {
      NotificationHelper.showError(context, message: error);
    }
  }

  Future<void> _handleSmsImportAction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_homeController.smsPermissionGranted) {
      await _homeController.syncMpesaMessages(user.uid);
      if (!mounted) return;
      _showSyncFeedback();
      return;
    }

    if (_homeController.smsPermissionPermanentlyDenied) {
      final opened = await openAppSettings();
      if (opened) await _homeController.refreshPermissionState();
      return;
    }

    final shouldContinue = await _showPermissionRationaleSheet();
    if (!shouldContinue) return;

    final status = await _homeController.requestSmsPermission();
    if (!mounted) return;

    if (!status.isGranted) {
      NotificationHelper.showWarning(
        context,
        message: status.isPermanentlyDenied
            ? 'SMS permission blocked. Open settings to enable it.'
            : 'No problem — add transactions manually.',
      );
      return;
    }

    await _homeController.syncMpesaMessages(user.uid);
    if (!mounted) return;
    _showSyncFeedback();
  }

  Future<bool> _showPermissionRationaleSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enable M-Pesa import?',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'PatoTrack only reads M-Pesa messages when you tap Sync. Personal chats are never accessed.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        break;
      case SyncStatus.error:
        NotificationHelper.showError(context, message: message);
        break;
      case SyncStatus.cancelled:
        NotificationHelper.showWarning(context, message: message);
        break;
      default:
        NotificationHelper.showInfo(context, message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your dashboard.')),
      );
    }

    return ChangeNotifierProvider<HomeController>.value(
      value: _homeController,
      child: Consumer2<HomeController, CurrencyProvider>(
        builder: (context, home, currency, _) {
          return Scaffold(
            body: RefreshIndicator(
              onRefresh: () => home.refresh(user.uid),
              child: home.isLoading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: ModernLoadingIndicator(
                            message: 'Loading your dashboard…',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        // Safe area top
                        SizedBox(
                          height: MediaQuery.of(context).padding.top + 8,
                        ),
                        HomeHeader(
                            user: user,
                            greeting: _greeting(),
                            balance: home.balance,
                            currency: currency),
                        if (home.unreviewedTransactions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            child: _ReviewQueueBanner(
                                count: home.unreviewedTransactions.length,
                                onTap: _openReviewQueue),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SummaryCardsSection(
                          currency: currency,
                          income: home.totalIncome,
                          expenses: home.totalExpenses,
                          balance: home.balance,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Quick action row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          child: _QuickActionsRow(
                            onAddTransaction: _openAddTransaction,
                            onAddBill: _openAddBill,
                            onViewAll: _openAllTransactions,
                          ),
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
                          onEditBill: _openEditBill,
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
                                horizontal: AppSpacing.lg),
                            child: Text(
                              home.errorMessage!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onAddTransaction,
    required this.onAddBill,
    required this.onViewAll,
  });

  final VoidCallback onAddTransaction;
  final VoidCallback onAddBill;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: AppIcons.add_rounded,
            label: 'Add',
            onTap: onAddTransaction,
            isPrimary: true,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
            icon: AppIcons.receipt_long_rounded,
            label: 'Transactions',
            onTap: onViewAll,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
            icon: AppIcons.calendar_month_rounded,
            label: 'Add Bill',
            onTap: onAddBill,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brand = isDark ? AppColors.brandDark : AppColors.brand;

    final bg = isPrimary
        ? brand
        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final fg = isPrimary
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(
                  color: isDark
                      ? AppColors.surfaceBorderDark
                      : AppColors.surfaceBorderLight,
                  width: 1,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: brand.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewQueueBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ReviewQueueBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.priority_high_rounded,
                  color: AppColors.expense, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count Pending Reviews',
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Some transactions need your attention.',
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
