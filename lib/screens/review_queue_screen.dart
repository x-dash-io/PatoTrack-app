import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../models/transaction.dart' as model;
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';
import '../styles/app_colors.dart';
import '../app_icons.dart';
import 'transaction_detail_screen.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final dbHelper = DatabaseHelper();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late Future<List<model.Transaction>> _unreviewedFuture;

  @override
  void initState() {
    super.initState();
    _refreshQueue();
  }

  void _refreshQueue() {
    if (_currentUser != null) {
      setState(() {
        _unreviewedFuture = dbHelper.getUnreviewedTransactions(_currentUser.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review Queue',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      body: AppScreenBackground(
        child: FutureBuilder<List<model.Transaction>>(
          future: _unreviewedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: ModernLoadingIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final transactions = snapshot.data ?? [];

            if (transactions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.check_circle_outline_rounded,
                        size: 64, color: AppColors.income.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'All caught up!',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (tx.source == 'receipt' || tx.source == 'sms')
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.brandSoftDark
                                : AppColors.brandSoft)
                            : (tx.type == 'income'
                                ? AppColors.incomeSoft
                                : AppColors.expenseSoft),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: tx.source == 'sms'
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                'assets/mpesa_logo.png',
                                fit: BoxFit.contain,
                              ),
                            )
                          : Icon(
                              tx.source == 'receipt'
                                  ? AppIcons.receipt_long_rounded
                                  : (tx.type == 'income'
                                      ? AppIcons.arrow_downward_rounded
                                      : AppIcons.arrow_upward_rounded),
                              color: (tx.source == 'receipt' || tx.source == 'sms')
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.brandDark
                                      : AppColors.brand)
                                  : (tx.type == 'income'
                                      ? AppColors.income
                                      : AppColors.expense),
                              size: 20,
                            ),
                    ),
                    title: Text(
                      tx.description.isEmpty ? tx.type : tx.description,
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Confidence: ${(tx.confidence * 100).toInt()}% • \${tx.source.toUpperCase()}',
                          style: GoogleFonts.manrope(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          'Ksh \${tx.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: tx.type == 'income'
                                  ? AppColors.income
                                  : AppColors.expense),
                        ),
                      ],
                    ),
                    trailing: const Icon(AppIcons.chevron_right_rounded),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TransactionDetailScreen(
                            transaction: tx,
                          ),
                        ),
                      );
                      _refreshQueue();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
