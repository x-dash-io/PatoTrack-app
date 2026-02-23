import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/input_fields.dart';
import '../services/google_sign_in_service.dart';
import '../helpers/responsive_helper.dart';
import '../helpers/notification_helper.dart';

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
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Verify user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Login failed - user not authenticated');
      }

      // Reload user profile data to ensure photoURL and other fields are up-to-date
      try {
        await currentUser.reload();
        // Get the refreshed user data
        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser == null) {
          throw Exception('Failed to reload user data');
        }
      } catch (e) {
        print('Warning: Failed to reload user data: $e');
        // Continue even if reload fails
      }

      // Verify user is authenticated
      final verifyUser = FirebaseAuth.instance.currentUser;
      if (verifyUser == null) {
        throw Exception('Authentication state lost');
      }

      // AuthGate will automatically detect the auth state change via its listener
      // No need to wait or clear loading - AuthGate will rebuild and navigate
      // The widget tree will be replaced by AuthGate, so this widget may be disposed

      // Just verify and let AuthGate handle the navigation
      // Keep loading state until AuthGate navigates away (which will dispose this widget)
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        setState(() {
          _isLoading = false;
        });
        NotificationHelper.showError(
          context,
          message: 'Login failed. Please try again.',
        );
      }
    }
    // Don't clear loading state in finally - let AuthGate handle it on success
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await GoogleSignInService.signInWithGoogle();

      if (userCredential != null && userCredential.user != null && mounted) {
        // Verify user is authenticated
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // Reload user profile data to ensure photoURL and other fields are up-to-date
          try {
            await currentUser.reload();
            // Get the refreshed user data
            final refreshedUser = FirebaseAuth.instance.currentUser;
            if (refreshedUser == null) {
              throw Exception('Failed to reload user data');
            }
          } catch (e) {
            print('Warning: Failed to reload user data: $e');
            // Continue even if reload fails
          }

          // Verify user is authenticated
          final verifyUser = FirebaseAuth.instance.currentUser;
          if (verifyUser == null) {
            throw Exception('Authentication state lost');
          }

          // AuthGate will automatically detect the auth state change via its listener
          // No need to wait or clear loading - AuthGate will rebuild and navigate
          // The widget tree will be replaced by AuthGate, so this widget may be disposed

          // Just verify and let AuthGate handle the navigation
          // Keep loading state until AuthGate navigates away (which will dispose this widget)
        } else {
          // User not properly authenticated
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            NotificationHelper.showError(context,
                message: 'Authentication failed. Please try again.');
          }
        }
      } else {
        // User cancelled or sign-in returned null
        // No need to show error - user intentionally cancelled
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        NotificationHelper.showError(context,
            message: e.toString().replaceAll('Exception: ', ''));
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
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Title
                      Text(
                        'Reset Password',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Description
                      Text(
                        'Enter your email address and we\'ll send you a link to reset your password.',
                        style: GoogleFonts.inter(
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
                                      this.context,
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
                                      this.context,
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
                                      this.context,
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
                                style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LoadingOverlay(
            isLoading: _isLoading,
            message: 'Signing in...',
            child: SingleChildScrollView(
              padding: ResponsiveHelper.edgeInsetsSymmetric(context, 24.0, 16),
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
                              colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: ResponsiveHelper.spacing(context, 20),
                              offset: Offset(
                                  0, ResponsiveHelper.spacing(context, 10)),
                            ),
                          ],
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
                      style: GoogleFonts.inter(
                        fontSize: ResponsiveHelper.fontSize(context, 36),
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),

                    Text(
                      'Sign in to continue tracking your expenses',
                      style: GoogleFonts.inter(
                        fontSize: ResponsiveHelper.fontSize(context, 16),
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: ResponsiveHelper.spacing(context, 48)),

                    // Modern card container for form
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            ResponsiveHelper.radius(context, 24)),
                      ),
                      child: Padding(
                        padding: ResponsiveHelper.edgeInsetsAll(context, 24),
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
                                onPressed: _isLoading
                                    ? null
                                    : _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: ResponsiveHelper.edgeInsetsSymmetric(
                                      context, 8, 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.inter(
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
                                      height: ResponsiveHelper.iconSize(
                                          context, 20),
                                      width: ResponsiveHelper.iconSize(
                                          context, 20),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          colorScheme.onPrimary,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: GoogleFonts.inter(
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
                                    style: GoogleFonts.inter(
                                      fontSize: ResponsiveHelper.fontSize(
                                          context, 14),
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
                                  return const Icon(Icons.g_mobiledata,
                                      size: 24);
                                },
                              ),
                              label: Text(
                                'Continue with Google',
                                style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
      ),
    );
  }
}
