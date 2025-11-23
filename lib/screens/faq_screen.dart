import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FAQItem> _filteredFAQs = [];

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
      question: 'What\'s the difference between business and personal tags?',
      answer:
          'Business and personal tags help you separate your transactions. When creating a transaction, you can choose whether it\'s business or personal. This helps you track your spending patterns separately.',
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
          'Yes! The app can automatically detect M-Pesa transactions from your SMS messages (with your permission). Make sure to grant SMS permission when prompted. The app will sync the latest 50 M-Pesa messages.',
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
          'Yes! Your data is automatically synced to the cloud using Firebase. To restore your data on a new device, go to Settings → Restore from Cloud. This will download your backup.',
    ),
    FAQItem(
      category: 'Reports',
      question: 'How do I view my spending reports?',
      answer:
          'Go to the Reports tab at the bottom of the screen. You can view charts showing your income vs expenses, spending by category, and monthly summaries.',
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
          'Unfortunately, passcodes cannot be recovered for security reasons. You\'ll need to sign out and sign back in, which will reset the passcode. You can then set a new one in Settings.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _filteredFAQs = _allFAQs;
    _searchController.addListener(_filterFAQs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFAQs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFAQs = _allFAQs;
      } else {
        _filteredFAQs = _allFAQs
            .where((faq) =>
                faq.question.toLowerCase().contains(query) ||
                faq.answer.toLowerCase().contains(query) ||
                faq.category.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _allFAQs.map((e) => e.category).toSet().toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('FAQ'),
        backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search FAQ...',
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Category filter (optional)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: 'All',
                    isSelected: true,
                    onTap: () {
                      setState(() => _filteredFAQs = _allFAQs);
                      _searchController.clear();
                    },
                  ),
                  const SizedBox(width: 8),
                  ...categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: category,
                        isSelected: false,
                        onTap: () {
                          setState(() {
                            _filteredFAQs = _allFAQs
                                .where((faq) => faq.category == category)
                                .toList();
                          });
                          _searchController.clear();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FAQ List
            Expanded(
              child: _filteredFAQs.isEmpty
                  ? Center(
                      child: Text(
                        'No FAQs found',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 17,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? CupertinoColors.systemGrey6.darkColor : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.faq.question,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            trailing: Icon(
              _isExpanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 20,
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.faq.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.faq.answer,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : CupertinoColors.label,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

