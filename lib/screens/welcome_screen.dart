import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../styles/app_colors.dart';
import '../styles/app_spacing.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback? onOnboardingCompleted;
  const WelcomeScreen({super.key, this.onOnboardingCompleted});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardSlide> _slides = const [
    _OnboardSlide(
      title: 'Track every shilling',
      description:
          'Record income and expenses in seconds. See exactly where your money goes.',
      icon: AppIcons.account_balance_wallet_rounded,
      color: AppColors.brand,
    ),
    _OnboardSlide(
      title: 'Auto-import from M-Pesa',
      description:
          'Connect your M-Pesa SMS and transactions sync automatically. No manual entry needed.',
      icon: AppIcons.phone_android_rounded,
      color: AppColors.income,
    ),
    _OnboardSlide(
      title: 'Never miss a payment',
      description:
          'Set bill reminders and get notified before due dates. Stay on top of every obligation.',
      icon: AppIcons.calendar_month_rounded,
      color: AppColors.warning,
    ),
    _OnboardSlide(
      title: 'Reports that make sense',
      description:
          'Visual spending charts and exportable PDF reports for your business.',
      icon: AppIcons.bar_chart_rounded,
      color: AppColors.brand,
    ),
  ];

  Future<void> _markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onOnboardingCompleted?.call();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    0, AppSpacing.sm, AppSpacing.md, 0),
                child: TextButton(
                  onPressed: _markDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _SlidePage(slide: slide);
                },
              ),
            ),
            // Dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? (isDark ? AppColors.brandDark : AppColors.brand)
                          : (isDark
                              ? AppColors.surfaceBorderDark
                              : AppColors.surfaceBorderLight),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                children: [
                  if (isLast) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () async {
                          await _markDone();
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const SignUpScreen()),
                          );
                        },
                        child: const Text('Create free account'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () async {
                          await _markDone();
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen()),
                          );
                        },
                        child: const Text('I already have an account'),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Next'),
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

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _OnboardSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: slide.color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: slide.color.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(slide.icon, color: slide.color, size: 44),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const _OnboardSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
