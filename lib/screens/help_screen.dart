import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'faq_screen.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/app_screen_background.dart';
import '../models/help_article.dart';
import 'help_article_detail_screen.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 16),

              // Modern Help Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.subtle(colorScheme.primary),
                  ),
                  child: Icon(
                    Icons.help_rounded,
                    size: 64,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // FAQ Section
              _HelpSection(
                title: 'Frequently Asked Questions',
                description: 'Find answers to common questions',
                icon: Icons.question_answer_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FaqScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Contact Support
              _HelpSection(
                title: 'Contact Support',
                description: 'Get help via WhatsApp',
                icon: Icons.chat_outlined,
                onTap: () => _launchWhatsApp(context),
              ),

              const SizedBox(height: 8),

              // Quick Start Guide
              _HelpSection(
                title: 'Quick Start Guide',
                description: 'Learn how to get started with PatoTrack',
                icon: Icons.menu_book_rounded,
                onTap: () => _showQuickStartGuide(context),
              ),

              const SizedBox(height: 32),

              // Help Articles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.article_rounded,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Help Articles',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              ..._getHelpArticles().map((article) {
                return _HelpArticleCard(
                  article: article,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => HelpArticleDetailScreen(
                          article: article,
                        ),
                      ),
                    );
                  },
                );
              }),

              const SizedBox(height: 32),

              // App Version Info
              Center(
                child: Text(
                  'PatoTrack v1.0.0',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<HelpArticle> _getHelpArticles() {
    return [
      HelpArticle(
        id: 'adding-transaction',
        title: 'Adding Your First Transaction',
        description: 'Learn how to record income and expenses',
        icon: Icons.add_circle_rounded,
        content:
            'Adding transactions is the core feature of PatoTrack. Here\'s everything you need to know about recording your business income and expenses.',
        steps: [
          'Tap the "+" button on the home screen to open the Add Transaction screen.',
          'Select whether this is an "Income" or "Expense" using the toggle at the top.',
          'Enter the amount in the Amount field. You can use decimal numbers (e.g., 15000.50).',
          'Choose a category from the dropdown. If you don\'t see the category you need, tap the settings icon to create a new one.',
          'Optionally, add a description or note to provide more context about this transaction.',
          'Select the date using the date picker. You can choose any past or current date.',
          'Tap "Save Transaction" to complete. Your transaction will appear on the home screen immediately.',
        ],
        tips: [
          'Use clear descriptions to make it easier to find transactions later when searching.',
          'Create specific categories for different types of expenses (e.g., "Office Supplies", "Marketing", "Utilities").',
          'You can edit or delete transactions later by swiping on them in the transaction list.',
          'All transactions are automatically tagged as "business" for reporting purposes.',
        ],
      ),
      HelpArticle(
        id: 'bill-reminders',
        title: 'Setting Up Bill Reminders',
        description: 'Never miss a payment with automatic reminders',
        icon: Icons.calendar_today_rounded,
        content:
            'Bill reminders help you stay on top of recurring payments like rent, subscriptions, and utilities. Set them up once, and PatoTrack will remind you before they\'re due.',
        steps: [
          'On the home screen, scroll to the "Upcoming Bills" section and tap "Add Bill".',
          'Enter the bill name (e.g., "Rent", "Netflix", "Internet").',
          'Enter the amount you need to pay.',
          'Select the due date using the date picker.',
          'Toggle on "Make this a recurring bill" if this payment repeats regularly.',
          'If recurring, select the frequency (Weekly, Bi-weekly, Monthly, Quarterly, or Yearly).',
          'You can manage custom frequencies by tapping the settings icon next to the frequency dropdown.',
          'Tap "Save Bill" to create the reminder. You\'ll receive a notification before the due date.',
        ],
        tips: [
          'Set up reminders 3-5 days before the actual due date to give yourself time to pay.',
          'Use clear bill names so you can easily identify them in the list.',
          'For recurring bills, the app will automatically update to the next due date after payment.',
          'You can tap on a bill card to mark it as paid, which will create a corresponding transaction.',
        ],
      ),
      HelpArticle(
        id: 'managing-categories',
        title: 'Managing Categories',
        description: 'Organize your transactions with custom categories',
        icon: Icons.folder_rounded,
        content:
            'Categories help you organize and analyze your business transactions. Create custom categories that match your business needs, and use them consistently for better reporting.',
        steps: [
          'Navigate to the "Manage Categories" screen from Settings or when adding a transaction.',
          'Tap the "+" button in the top right corner to add a new category.',
          'Enter a descriptive category name (e.g., "Office Rent", "Marketing Expenses", "Sales Revenue").',
          'Tap the icon container to choose from a variety of icons that represent your category.',
          'Select whether this category is for "Expense" or "Income" transactions.',
          'Tap "Add" to save the category. It will immediately be available in transaction forms.',
          'To edit a category, tap the settings icon in the category card and modify the name or icon.',
          'To delete a category, tap the delete icon. Note: Transactions using this category will remain, but you won\'t be able to use this category for new transactions.',
        ],
        tips: [
          'Create categories that match your business accounting structure for easier tax preparation.',
          'Use specific names instead of generic ones (e.g., "Online Marketing" instead of just "Marketing").',
          'Choose icons that are visually distinct to make category selection faster.',
          'Review and consolidate categories periodically to keep your list manageable.',
          'Income and expense categories are separate, so create appropriate ones for each type.',
        ],
      ),
      HelpArticle(
        id: 'understanding-reports',
        title: 'Understanding Reports',
        description: 'Make sense of your spending with visual reports',
        icon: Icons.bar_chart_rounded,
        content:
            'PatoTrack provides detailed visual reports to help you understand your business finances. Use these insights to make informed decisions and track your financial performance.',
        steps: [
          'Navigate to the "Reports" tab at the bottom of the screen.',
          'Use the time filter buttons (Week, Month, Year) to view different time periods.',
          'View the Profit/Loss card at the top to see your net income for the selected period.',
          'Examine the Income vs Expenses bar chart to compare your revenue and spending.',
          'Check the Expense Breakdown pie chart to see where your money is going by category.',
          'Tap the "Generate PDF Report" button to export a professional business report.',
          'The PDF report includes all business transactions and can be used for loan applications or investor presentations.',
          'Share the PDF report via email, messaging apps, or save it to your device.',
        ],
        tips: [
          'Review reports monthly to identify spending patterns and opportunities for cost savings.',
          'Export PDF reports regularly and keep them for your records and tax purposes.',
          'The reports only include business transactions, making them suitable for official use.',
          'Use the year view to see annual trends and plan for the future.',
          'The pie chart helps you quickly identify your largest expense categories.',
        ],
      ),
      HelpArticle(
        id: 'managing-frequencies',
        title: 'Managing Bill Frequencies',
        description: 'Create custom recurring bill schedules',
        icon: Icons.repeat_rounded,
        content:
            'Customize bill frequencies to match your actual payment schedules. Create frequencies that don\'t come standard, like every 2 weeks or quarterly payments.',
        steps: [
          'When adding or editing a bill, toggle on "Make this a recurring bill".',
          'Tap the settings icon next to the frequency dropdown to manage frequencies.',
          'In the Manage Frequencies screen, tap the "+" button to add a new frequency.',
          'Enter an internal name (e.g., "weekly", "monthly") for the frequency type.',
          'Enter a display name (e.g., "Weekly", "Monthly") that users will see.',
          'Select the type from the dropdown (Weekly, Bi-weekly, Monthly, Quarterly, Yearly, or Custom).',
          'Enter the value in days (e.g., 7 for weekly, 30 for monthly, 90 for quarterly).',
          'Tap "Add Frequency" to save. Your custom frequency will now be available when creating bills.',
          'To delete a frequency, tap the delete icon next to it in the list.',
        ],
        tips: [
          'Default frequencies (Weekly, Monthly, etc.) are pre-populated for convenience.',
          'Use custom frequencies for bills that don\'t follow standard schedules (e.g., every 10 days).',
          'The value in days determines how often the bill repeats.',
          'You cannot delete frequencies that are currently being used by bills.',
        ],
      ),
    ];
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phoneNumber = '+254717880017';
    const message = 'Hello, I need help with the PatoTrack app.';
    final whatsappUrl = Uri.parse(
      "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}",
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          await showModernInfoDialog(
            context: context,
            title: 'Cannot Open WhatsApp',
            message: 'Please make sure WhatsApp is installed on your device.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        await showModernAlertDialog(
          context: context,
          title: 'Error',
          message: 'An error occurred: $e',
        );
      }
    }
  }

  void _showQuickStartGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Start Guide',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Done',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    _GuideStep(
                      number: 1,
                      title: 'Create Your Account',
                      description:
                          'Sign up with your email to get started. Your data will be securely synced to the cloud.',
                    ),
                    _GuideStep(
                      number: 2,
                      title: 'Add Your First Transaction',
                      description:
                          'Tap the "+" button on the home screen to add an income or expense. Choose a category or create a new one.',
                    ),
                    _GuideStep(
                      number: 3,
                      title: 'Set Up Bill Reminders',
                      description:
                          'Add recurring bills like rent or subscriptions. The app will remind you before they\'re due.',
                    ),
                    _GuideStep(
                      number: 4,
                      title: 'Explore Reports',
                      description:
                          'Visit the Reports tab to see charts and insights about your spending patterns.',
                    ),
                    _GuideStep(
                      number: 5,
                      title: 'Enable M-Pesa Sync',
                      description:
                          'Grant SMS permission to automatically import M-Pesa transactions from your messages.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _HelpSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: const [AppShadows.card],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.subtle(colorScheme.primary),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.primary,
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

class _HelpArticleCard extends StatelessWidget {
  final HelpArticle article;
  final VoidCallback? onTap;

  const _HelpArticleCard({
    required this.article,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: const [AppShadows.card],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.subtle(colorScheme.primary),
                  ),
                  child: Icon(
                    article.icon,
                    size: 26,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.description,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.primary,
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

class _GuideStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: AppShadows.subtle(colorScheme.primary),
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.manrope(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.6,
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
