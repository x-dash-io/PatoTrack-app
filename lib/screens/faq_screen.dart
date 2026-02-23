import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_screen_background.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<FAQItem> _filteredFAQs = [];
  String? _selectedCategory;

  final List<FAQItem> _allFAQs = [
    FAQItem(
      category: 'Getting Started',
      question: 'How do I add a transaction?',
      answer:
          'Tap the "+" button on the home screen, select whether it\'s an income or expense, enter the amount, choose a category, and save. You can also swipe right on a transaction in the list to edit it.',
    ),
    FAQItem(
      category: 'Getting Started',
      question: 'How do I create categories?',
      answer:
          'Go to Settings → Manage Categories. Tap the "+" button, enter a category name, select an icon, and choose whether it\'s for income or expenses. You can edit or delete categories by tapping the icons next to each category.',
    ),
    FAQItem(
      category: 'Getting Started',
      question: 'Are all transactions tracked as business?',
      answer:
          'Yes, all transactions in PatoTrack are automatically categorized as business transactions. This ensures your reports are suitable for loan applications and investor presentations.',
    ),
    FAQItem(
      category: 'Bills',
      question: 'How do I set up bill reminders?',
      answer:
          'On the home screen, tap "Add Bill" in the Upcoming Bills section. Enter the bill name, amount, and due date. You can make it recurring by toggling the switch and selecting how often it repeats (weekly or monthly).',
    ),
    FAQItem(
      category: 'Bills',
      question: 'What happens when I pay a bill?',
      answer:
          'When you tap "Pay Bill" on a bill card, it creates a transaction automatically. If the bill is recurring, it will update to the next due date. If it\'s a one-time bill, it will be removed after payment.',
    ),
    FAQItem(
      category: 'Transactions',
      question: 'How do I edit or delete a transaction?',
      answer:
          'On the home screen, swipe right on a transaction to edit it, or swipe left to delete it. You can also tap on a transaction in the "All Transactions" screen to view and edit details.',
    ),
    FAQItem(
      category: 'Transactions',
      question: 'Can I filter my transactions?',
      answer:
          'Yes! In the "All Transactions" screen, tap the filter icon. You can filter by type (income/expense), category, and date range. You can also search by description or amount.',
    ),
    FAQItem(
      category: 'Transactions',
      question: 'Does the app sync with M-Pesa?',
      answer:
          'Yes. On the Home screen, use the "M-Pesa SMS Import" card to enable SMS access and run sync on demand. The app will only import when you tap sync, and shows your last sync time.',
    ),
    FAQItem(
      category: 'Security',
      question: 'How do I set up a passcode?',
      answer:
          'Go to Settings → Passcode Lock and toggle it on. You\'ll be prompted to enter a 4-digit passcode. You can change or disable it later in the same settings.',
    ),
    FAQItem(
      category: 'Security',
      question: 'Is my data backed up?',
      answer:
          'Your data is backed up to Firebase. To restore on a new device, go to Settings → Data & Sync → Restore from Cloud. The app shows the last restore timestamp for transparency.',
    ),
    FAQItem(
      category: 'Reports',
      question: 'How do I view my spending reports?',
      answer:
          'Go to the Reports tab and choose Week, Month, or Year. Reports use business transactions only, with inclusive date ranges shown in the scope banner.',
    ),
    FAQItem(
      category: 'Settings',
      question: 'Can I change the currency?',
      answer:
          'Yes! Go to Settings → Currency and select from the available options (KSh, USD, EUR, GBP). Your existing transactions will be displayed with the new currency symbol.',
    ),
    FAQItem(
      category: 'Settings',
      question: 'How do I change my profile picture?',
      answer:
          'On the Settings screen, tap on your profile picture. You\'ll be able to select a photo from your gallery. The image will be uploaded and saved to your account.',
    ),
    FAQItem(
      category: 'Troubleshooting',
      question: 'The app is not syncing M-Pesa transactions',
      answer:
          'Make sure you\'ve granted SMS permission. Go to your device settings → Apps → PatoTrack → Permissions, and enable SMS access. Also ensure you have M-Pesa SMS messages in your inbox.',
    ),
    FAQItem(
      category: 'Troubleshooting',
      question: 'I forgot my passcode',
      answer:
          'Passcodes cannot be recovered for security reasons. If you forget it, clear the app data (or reinstall the app), then sign in again and set a new passcode. Make sure your data is backed up before clearing local data.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _filteredFAQs = List<FAQItem>.from(_allFAQs);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterFAQs() {
    final query = _searchController.text.toLowerCase();
    final filtered = _allFAQs.where((faq) {
      final matchesQuery = query.isEmpty ||
          faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          faq.category.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == null || faq.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    if (!mounted) return;
    setState(() {
      _filteredFAQs = filtered;
    });
  }

  void _onSearchChanged(String _) {
    if (mounted) {
      setState(() {});
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _filterFAQs);
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterFAQs();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _allFAQs.map((e) => e.category).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: AppScreenBackground(
        includeSafeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              // Modern Search bar
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [AppShadows.card],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.manrope(),
                    decoration: InputDecoration(
                      hintText: 'Search FAQ...',
                      hintStyle: GoogleFonts.manrope(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.6),
                        size: 24,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _filterFAQs();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // Modern Category filter
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      isSelected: _selectedCategory == null,
                      onTap: () => _selectCategory(null),
                    ),
                    const SizedBox(width: 10),
                    ...categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _CategoryChip(
                          label: category,
                          isSelected: _selectedCategory == category,
                          onTap: () => _selectCategory(category),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // FAQ List
              Expanded(
                child: _filteredFAQs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No FAQs Found',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: _filteredFAQs.length,
                        itemBuilder: (context, index) {
                          final faq = _filteredFAQs[index];
                          return _FAQCard(faq: faq);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FAQItem {
  final String category;
  final String question;
  final String answer;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class _FAQCard extends StatefulWidget {
  final FAQItem faq;

  const _FAQCard({required this.faq});

  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _isExpanded
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isExpanded
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: _isExpanded ? AppShadows.subtle(colorScheme.primary) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isExpanded
                          ? Icons.help_rounded
                          : Icons.help_outline_rounded,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: _isExpanded ? null : 2,
                      overflow: _isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.label_rounded,
                          size: 14,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.faq.category.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.faq.answer,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        height: 1.7,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: isSelected
                ? Colors.white
                : isDark
                    ? Colors.white.withValues(alpha: 0.87)
                    : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
