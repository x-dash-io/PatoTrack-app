import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/input_fields.dart';
import '../services/google_sign_in_service.dart';
import '../helpers/responsive_helper.dart';
import '../helpers/notification_helper.dart';
import '../widgets/app_screen_background.dart';
import '../styles/app_shadows.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validate form first - don't proceed if validation fails
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      // Ensure loading state is false when validation fails
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Only set loading state after validation passes
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user == null ||
          FirebaseAuth.instance.currentUser == null) {
        throw Exception('Login failed - user not authenticated');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed. Please try again.';

        // Provide user-friendly error messages
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            errorMessage = 'Incorrect email or password. Please try again.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address. Please check and try again.';
            break;
          case 'user-disabled':
            errorMessage =
                'This account has been disabled. Please contact support.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed attempts. Please try again later.';
            break;
          case 'network-request-failed':
            errorMessage =
                'Network error. Please check your connection and try again.';
            break;
          default:
            // Use the default message for unknown errors
            errorMessage = 'Incorrect email or password. Please try again.';
        }

        NotificationHelper.showError(context, message: errorMessage);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(
          context,
          message: 'Login failed. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await GoogleSignInService.signInWithGoogle();

      if (userCredential == null) {
        return;
      }

      if (userCredential.user == null ||
          FirebaseAuth.instance.currentUser == null) {
        throw Exception('Authentication failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();
    final colorScheme = Theme.of(context).colorScheme;
    bool isSendingReset = false;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: resetFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Title
                      Text(
                        'Reset Password',
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Description
                      Text(
                        'Enter your email address and we\'ll send you a link to reset your password.',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Email input
                      StandardTextFormField(
                        controller: resetEmailController,
                        labelText: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        enabled: !isSendingReset,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Send reset email button
                      FilledButton(
                        onPressed: isSendingReset
                            ? null
                            : () async {
                                if (resetFormKey.currentState?.validate() ??
                                    false) {
                                  setDialogState(() {
                                    isSendingReset = true;
                                  });

                                  try {
                                    await _auth.sendPasswordResetEmail(
                                      email: resetEmailController.text.trim(),
                                    );

                                    if (!dialogContext.mounted) return;
                                    Navigator.of(dialogContext).pop();
                                    if (!mounted) return;
                                    NotificationHelper.showSuccess(
                                      context,
                                      message:
                                          'Password reset email sent! Please check your inbox.',
                                    );
                                  } on FirebaseAuthException catch (e) {
                                    var errorMessage =
                                        'Failed to send reset email';
                                    if (e.code == 'user-not-found') {
                                      errorMessage =
                                          'No account found with this email address.';
                                    } else if (e.code == 'invalid-email') {
                                      errorMessage = 'Invalid email address.';
                                    } else if (e.code == 'too-many-requests') {
                                      errorMessage =
                                          'Too many requests. Please try again later.';
                                    } else {
                                      errorMessage = e.message ?? errorMessage;
                                    }

                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        isSendingReset = false;
                                      });
                                    }
                                    if (!mounted) return;
                                    NotificationHelper.showError(
                                      context,
                                      message: errorMessage,
                                    );
                                  } catch (_) {
                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        isSendingReset = false;
                                      });
                                    }
                                    if (!mounted) return;
                                    NotificationHelper.showError(
                                      context,
                                      message:
                                          'An error occurred. Please try again.',
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSendingReset
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                'Send Reset Link',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      // Cancel button
                      TextButton(
                        onPressed: isSendingReset
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      SizedBox(
                          height:
                              MediaQuery.of(dialogContext).padding.bottom + 8),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      resetEmailController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: AppScreenBackground(
        child: LoadingOverlay(
          isLoading: _isLoading,
          message: 'Signing in...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: ResponsiveHelper.spacing(context, 20)),

                  // App logo/icon with modern design
                  Center(
                    child: Container(
                      width: ResponsiveHelper.width(context, 100),
                      height: ResponsiveHelper.height(context, 100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.subtle(colorScheme.primary),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        size: ResponsiveHelper.iconSize(context, 50),
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.spacing(context, 48)),

                  // Modern title section
                  Text(
                    'Welcome Back',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),

                  Text(
                    'Sign in to continue tracking your expenses',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: ResponsiveHelper.spacing(context, 48)),

                  // Modern card container for form
                  Card(
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.cardRadius,
                    ),
                    child: Padding(
                      padding: AppSpacing.cardPaddingLarge,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email field
                          StandardTextFormField(
                            controller: _emailController,
                            labelText: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),

                          SizedBox(
                              height: ResponsiveHelper.spacing(context, 20)),

                          // Password field
                          StandardTextFormField(
                            controller: _passwordController,
                            labelText: 'Password',
                            obscureText: !_isPasswordVisible,
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          SizedBox(
                              height: ResponsiveHelper.spacing(context, 12)),

                          // Forgot password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _isLoading ? null : _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: ResponsiveHelper.edgeInsetsSymmetric(
                                    context, 8, 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.manrope(
                                  fontSize:
                                      ResponsiveHelper.fontSize(context, 14),
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                              height: ResponsiveHelper.spacing(context, 20)),

                          // Login button
                          FilledButton(
                            onPressed: _isLoading ? null : _login,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveHelper.buttonHeight(
                                      context, 16)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.radius(context, 16)),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height:
                                        ResponsiveHelper.iconSize(context, 20),
                                    width:
                                        ResponsiveHelper.iconSize(context, 20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Sign In',
                                    style: GoogleFonts.manrope(
                                      fontSize: ResponsiveHelper.fontSize(
                                          context, 17),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),

                          SizedBox(
                              height: ResponsiveHelper.spacing(context, 24)),

                          // Divider with "OR"
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(color: colorScheme.outline)),
                              Padding(
                                padding: ResponsiveHelper.edgeInsetsSymmetric(
                                    context, 16, 0),
                                child: Text(
                                  'OR',
                                  style: GoogleFonts.manrope(
                                    fontSize:
                                        ResponsiveHelper.fontSize(context, 14),
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(color: colorScheme.outline)),
                            ],
                          ),

                          SizedBox(
                              height: ResponsiveHelper.spacing(context, 24)),

                          // Google Sign-In button
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveHelper.buttonHeight(
                                      context, 16)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.radius(context, 16)),
                              ),
                              side: BorderSide(
                                color: colorScheme.outline,
                                width: 1.5,
                              ),
                            ),
                            icon: Image.asset(
                              'assets/google_logo.png',
                              height: 20,
                              width: 20,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback if Google logo asset doesn't exist
                                return const Icon(Icons.g_mobiledata, size: 24);
                              },
                            ),
                            label: Text(
                              'Continue with Google',
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sign up link with modern design
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
