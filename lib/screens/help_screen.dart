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

    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.2),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 16),

              // Modern Help Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
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
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            _HelpArticleCard(
              title: 'Adding Your First Transaction',
              description: 'Learn how to record income and expenses',
              icon: Icons.add_circle_rounded,
            ),

            _HelpArticleCard(
              title: 'Setting Up Bill Reminders',
              description: 'Never miss a payment with automatic reminders',
              icon: Icons.calendar_today_rounded,
            ),

            _HelpArticleCard(
              title: 'Managing Categories',
              description: 'Organize your transactions with custom categories',
              icon: Icons.folder_rounded,
            ),

            _HelpArticleCard(
              title: 'Understanding Reports',
              description: 'Make sense of your spending with visual reports',
              icon: Icons.bar_chart_rounded,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHighest.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: GoogleFonts.inter(
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
                    color: colorScheme.primaryContainer.withOpacity(0.3),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
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
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.inter(
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
