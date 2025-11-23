import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'faq_screen.dart';
import '../widgets/dialog_helpers.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 24),

            // Help Icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline,
                  size: 60,
                  color: colorScheme.primary,
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

            const SizedBox(height: 16),

            // Quick Start Guide
            _HelpSection(
              title: 'Quick Start Guide',
              description: 'Learn how to get started with PatoTrack',
              icon: Icons.menu_book_outlined,
              onTap: () => _showQuickStartGuide(context),
            ),

            const SizedBox(height: 32),

            // Help Articles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                'Help Articles',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            _HelpArticleCard(
              title: 'Adding Your First Transaction',
              description: 'Learn how to record income and expenses',
              icon: Icons.add_circle_outline,
            ),

            _HelpArticleCard(
              title: 'Setting Up Bill Reminders',
              description: 'Never miss a payment with automatic reminders',
              icon: Icons.calendar_today_outlined,
            ),

            _HelpArticleCard(
              title: 'Managing Categories',
              description: 'Organize your transactions with custom categories',
              icon: Icons.folder_outlined,
            ),

            _HelpArticleCard(
              title: 'Understanding Reports',
              description: 'Make sense of your spending with visual reports',
              icon: Icons.bar_chart_outlined,
            ),

            const SizedBox(height: 32),

            // App Version Info
            Center(
              child: Text(
                'PatoTrack v1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Start Guide',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(
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

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
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
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 24,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpArticleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _HelpArticleCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.inter(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
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
