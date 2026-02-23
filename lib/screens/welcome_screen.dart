import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../widgets/app_screen_background.dart';
import '../styles/app_shadows.dart';
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

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'Track Your Expenses',
      description:
          'Easily record and categorize your daily expenses and income to stay on top of your finances.',
      icon: Icons.receipt_long_rounded,
      gradient: [const Color(0xFF007AFF), const Color(0xFF0051D5)],
    ),
    OnboardingSlide(
      title: 'Bill Reminders',
      description:
          'Never miss a payment again. Set up bill reminders and get notified before due dates.',
      icon: Icons.calendar_today_rounded,
      gradient: [const Color(0xFFFF9500), const Color(0xFFFF6B00)],
    ),
    OnboardingSlide(
      title: 'Manage Categories',
      description:
          'Organize your transactions with custom categories. Track business and personal expenses separately.',
      icon: Icons.category_rounded,
      gradient: [const Color(0xFFAF52DE), const Color(0xFF8E44AD)],
    ),
    OnboardingSlide(
      title: 'Reports & Analytics',
      description:
          'Visualize your spending patterns with charts and reports. Make informed financial decisions.',
      icon: Icons.bar_chart_rounded,
      gradient: [const Color(0xFF34C759), const Color(0xFF27AE60)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingCompleted({bool notifyParent = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (notifyParent && mounted) {
      widget.onOnboardingCompleted?.call();
    }
  }

  Future<void> _completeOnboarding() async {
    await _markOnboardingCompleted(notifyParent: true);
  }

  Future<void> _skipToLogin() async {
    await _completeOnboarding();
  }

  Future<void> _nextPage() async {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: AppScreenBackground(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skipToLogin,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(
                  'Skip',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _OnboardingSlideWidget(
                    slide: _slides[index],
                    colorScheme: colorScheme,
                  );
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => _PageIndicator(
                  isActive: index == _currentPage,
                  colorScheme: colorScheme,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  // Next/Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _nextPage,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  if (_currentPage == _slides.length - 1) ...[
                    const SizedBox(height: 12),
                    // Sign in button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await _markOnboardingCompleted(notifyParent: false);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Already have an account? Sign In',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    // Sign up button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await _markOnboardingCompleted(notifyParent: false);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

class _OnboardingSlideWidget extends StatelessWidget {
  final OnboardingSlide slide;
  final ColorScheme colorScheme;

  const _OnboardingSlideWidget({
    required this.slide,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with gradient background
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: slide.gradient,
              ),
              shape: BoxShape.circle,
              boxShadow: AppShadows.subtle(slide.gradient[0]),
            ),
            child: Icon(
              slide.icon,
              size: 70,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 56),

          // Title
          Text(
            slide.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            slide.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final bool isActive;
  final ColorScheme colorScheme;

  const _PageIndicator({
    required this.isActive,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
