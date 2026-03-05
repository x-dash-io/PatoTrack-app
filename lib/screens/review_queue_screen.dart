import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/database_helper.dart';
import '../models/transaction.dart' as model;
import '../models/category.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';
import '../styles/app_colors.dart';
import '../app_icons.dart';
import '../features/categorization/categorization_service.dart';
import 'transaction_detail_screen.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final dbHelper = DatabaseHelper();
  final _categorizationService = CategorizationService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late Future<List<model.Transaction>> _unreviewedFuture;
  List<Category> _categories = [];
  List<Map<String, dynamic>> _userCorrections = [];

  @override
  void initState() {
    super.initState();
    _refreshQueue();
    _loadSupport();
  }

  Future<void> _loadSupport() async {
    if (_currentUser == null) return;
    final uid = _currentUser.uid;
    final cats = await dbHelper.getCategories(uid);
    final corrections = await dbHelper.getUserCategoryCorrections(uid);
    if (mounted) {
      setState(() {
        _categories = cats;
        _userCorrections = corrections;
      });
    }
  }

  void _refreshQueue() {
    if (_currentUser != null) {
      setState(() {
        _unreviewedFuture =
            dbHelper.getUnreviewedTransactions(_currentUser.uid);
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
                        size: 64,
                        color: AppColors.income.withValues(alpha: 0.5)),
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
                final suggestions = _categorizationService.suggest(
                  tx.description,
                  corrections: _userCorrections,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                (tx.source == 'receipt' || tx.source == 'sms')
                                    ? (Theme.of(context).brightness ==
                                            Brightness.dark
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
                                  color: (tx.source == 'receipt' ||
                                          tx.source == 'sms')
                                      ? (Theme.of(context).brightness ==
                                              Brightness.dark
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
                          style:
                              GoogleFonts.manrope(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Confidence: ${(tx.confidence * 100).toInt()}% • ${tx.source.toUpperCase()}',
                              style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                            Text(
                              'Ksh ${tx.amount.toStringAsFixed(0)}',
                              style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: tx.type == 'income'
                                      ? AppColors.income
                                      : AppColors.expense),
                            ),
                          ],
                        ),
                        trailing:
                            const Icon(AppIcons.chevron_right_rounded),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  TransactionDetailScreen(transaction: tx),
                            ),
                          );
                          _refreshQueue();
                        },
                      ),

                      // Tier 2: Category suggestion chips
                      if (suggestions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Suggested categories:',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: suggestions.map((s) {
                                  final match = _categories
                                      .where((c) =>
                                          c.name.toLowerCase() ==
                                          s.categoryName.toLowerCase())
                                      .firstOrNull;
                                  return ActionChip(
                                    avatar: Icon(
                                      AppIcons.auto_awesome_rounded,
                                      size: 12,
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? AppColors.brandDark
                                              : AppColors.brand,
                                    ),
                                    label: Text(
                                      '${s.categoryName} ${(s.confidence * 100).toInt()}%',
                                      style: GoogleFonts.manrope(fontSize: 11),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.brandSoftDark
                                            : AppColors.brandSoft,
                                    onPressed: () async {
                                      if (_currentUser == null) return;
                                      final uid = _currentUser.uid;
                                      final messenger = ScaffoldMessenger.of(context);
                                      if (match != null) {
                                        // Apply category and mark reviewed
                                        final updated = tx.copyWith(
                                          categoryId: match.id,
                                          isReviewed: true,
                                        );
                                        await dbHelper.updateTransaction(
                                            updated, uid);
                                        await dbHelper
                                            .addUserCategoryCorrection(
                                          userId: uid,
                                          description: tx.description,
                                          categoryId: match.id!,
                                          categoryName: match.name,
                                        );
                                        _refreshQueue();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Categorized as ${match.name}',
                                              style: GoogleFonts.manrope(),
                                            ),
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '"${s.categoryName}" not found — create it in Manage Categories',
                                              style: GoogleFonts.manrope(),
                                            ),
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                    ],
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
