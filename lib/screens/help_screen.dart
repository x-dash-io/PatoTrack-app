import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'faq_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Help & Support'),
        backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
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
                  color: CupertinoColors.activeBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.question_circle_fill,
                  size: 60,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // FAQ Section
            _HelpSection(
              title: 'Frequently Asked Questions',
              description: 'Find answers to common questions',
              icon: CupertinoIcons.question_circle,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (context) => const FaqScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            // Contact Support
            _HelpSection(
              title: 'Contact Support',
              description: 'Get help via WhatsApp',
              icon: CupertinoIcons.chat_bubble_text,
              onTap: () => _launchWhatsApp(context),
            ),

            const SizedBox(height: 16),

            // Quick Start Guide
            _HelpSection(
              title: 'Quick Start Guide',
              description: 'Learn how to get started with PatoTrack',
              icon: CupertinoIcons.book,
              onTap: () => _showQuickStartGuide(context),
            ),

            const SizedBox(height: 32),

            // Help Articles
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Help Articles',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            _HelpArticleCard(
              title: 'Adding Your First Transaction',
              description: 'Learn how to record income and expenses',
              icon: CupertinoIcons.plus_circle,
            ),

            _HelpArticleCard(
              title: 'Setting Up Bill Reminders',
              description: 'Never miss a payment with automatic reminders',
              icon: CupertinoIcons.calendar,
            ),

            _HelpArticleCard(
              title: 'Managing Categories',
              description: 'Organize your transactions with custom categories',
              icon: CupertinoIcons.folder,
            ),

            _HelpArticleCard(
              title: 'Understanding Reports',
              description: 'Make sense of your spending with visual reports',
              icon: CupertinoIcons.chart_bar,
            ),

            const SizedBox(height: 32),

            // App Version Info
            Center(
              child: Text(
                'PatoTrack v1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
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
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Cannot Open WhatsApp'),
              content: const Text(
                'Please make sure WhatsApp is installed on your device.',
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showQuickStartGuide(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quick Start Guide',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? CupertinoColors.systemGrey6.darkColor
              : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: CupertinoColors.activeBlue,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 20,
              color: CupertinoColors.secondaryLabel,
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? CupertinoColors.systemGrey6.darkColor
            : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: CupertinoColors.activeBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel,
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


