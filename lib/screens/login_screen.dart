import 'package:flutter/material.dart';
import 'package:pato_track/app_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import '../widgets/input_fields.dart';
import '../services/google_sign_in_service.dart';
import '../helpers/notification_helper.dart';
import '../styles/app_colors.dart';
import '../styles/app_spacing.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  int _activeRequestToken = 0;

  void _returnToAuthRoot() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (!mounted) return;
    final token = ++_activeRequestToken;
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (token != _activeRequestToken) return;
      _returnToAuthRoot();
    } on FirebaseAuthException catch (e) {
      if (token != _activeRequestToken) return;
      if (mounted) {
        String msg;
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            msg = 'Email or password is incorrect.';
            break;
          case 'too-many-requests':
            msg = 'Too many attempts. Try again later.';
            break;
          default:
            msg = e.message ?? 'Login failed.';
        }
        NotificationHelper.showError(context, message: msg);
      }
    } finally {
      if (mounted && _activeRequestToken == token) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final userCredential = await GoogleSignInService.signInWithGoogle();
      if (userCredential == null) {
        if (mounted) {
          NotificationHelper.showInfo(
            context,
            message: 'Google sign-in was cancelled.',
          );
        }
        return;
      }
      _returnToAuthRoot();
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // Brand mark
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    AppIcons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome back',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your PatoTrack account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Email field
                StandardTextFormField(
                  controller: _emailController,
                  labelText: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: AppIcons.email_outlined,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Password field
                StandardTextFormField(
                  controller: _passwordController,
                  labelText: 'Password',
                  obscureText: !_isPasswordVisible,
                  prefixIcon: AppIcons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? AppIcons.visibility_off_outlined
                          : AppIcons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final email = _emailController.text.trim();
                      if (email.isEmpty) {
                        NotificationHelper.showWarning(context,
                            message: 'Enter your email first.');
                        return;
                      }
                      _auth.sendPasswordResetEmail(email: email);
                      NotificationHelper.showSuccess(context,
                          message: 'Password reset link sent.');
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark
                            ? AppColors.surfaceBorderDark
                            : AppColors.surfaceBorderLight,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text(
                        'or',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark
                            ? AppColors.surfaceBorderDark
                            : AppColors.surfaceBorderLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Google sign in
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                    child: _isGoogleLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? AppColors.brandDark : AppColors.brand,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/google_logo.png',
                                width: 20,
                                height: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              const Text('Continue with Google'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const SignupScreen()),
                      ),
                      child: Text(
                        'Create one',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.brandDark : AppColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
