import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/input_fields.dart';
import '../services/google_sign_in_service.dart';

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

      // Ensure the auth state change has been processed
      // Wait for the stream to emit and AuthGate to rebuild
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Double-check that user is still authenticated after the delay
      final verifyUser = FirebaseAuth.instance.currentUser;
      if (verifyUser == null) {
        throw Exception('Authentication state lost');
      }
      
      // Clear loading state - AuthGate's StreamBuilder will automatically
      // detect the auth state change via authStateChanges() stream and rebuild
      // to show MainScreen or PasscodeScreen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show success feedback
        final theme = Theme.of(context);
        Fluttertoast.showToast(
          msg: "Login Successful!",
          backgroundColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onPrimary,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final theme = Theme.of(context);
        Fluttertoast.showToast(
          msg: e.message ?? 'Login failed',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: theme.colorScheme.error,
          textColor: theme.colorScheme.onError,
          fontSize: 16.0,
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
          
          // Ensure the auth state change has been processed
          // Wait for the stream to emit and AuthGate to rebuild
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Double-check that user is still authenticated after the delay
          final verifyUser = FirebaseAuth.instance.currentUser;
          if (verifyUser == null) {
            throw Exception('Authentication state lost');
          }
          
          // Clear loading state - AuthGate's StreamBuilder will automatically
          // detect the auth state change via authStateChanges() stream and rebuild
          // to show MainScreen or PasscodeScreen
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            // Show success message
            final theme = Theme.of(context);
            Fluttertoast.showToast(
              msg: 'Signed in with Google successfully!',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
            );
          }
        } else {
          // User not properly authenticated
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            final theme = Theme.of(context);
            Fluttertoast.showToast(
              msg: 'Authentication failed. Please try again.',
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: theme.colorScheme.error,
              textColor: theme.colorScheme.onError,
              fontSize: 16.0,
            );
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
        final theme = Theme.of(context);
        Fluttertoast.showToast(
          msg: e.toString().replaceAll('Exception: ', ''),
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: theme.colorScheme.error,
          textColor: theme.colorScheme.onError,
          fontSize: 16.0,
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            bool isSendingReset = false;
            
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                            color: colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                                if (resetFormKey.currentState?.validate() ?? false) {
                                  setDialogState(() {
                                    isSendingReset = true;
                                  });

                                  try {
                                    await _auth.sendPasswordResetEmail(
                                      email: resetEmailController.text.trim(),
                                    );

                                    if (mounted) {
                                      Navigator.of(dialogContext).pop();
                                      Fluttertoast.showToast(
                                        msg: 'Password reset email sent! Please check your inbox.',
                                        backgroundColor: colorScheme.primary,
                                        textColor: colorScheme.onPrimary,
                                        toastLength: Toast.LENGTH_LONG,
                                        gravity: ToastGravity.BOTTOM,
                                        fontSize: 16.0,
                                      );
                                    }
                                  } on FirebaseAuthException catch (e) {
                                    if (mounted) {
                                      String errorMessage = 'Failed to send reset email';
                                      if (e.code == 'user-not-found') {
                                        errorMessage = 'No account found with this email address.';
                                      } else if (e.code == 'invalid-email') {
                                        errorMessage = 'Invalid email address.';
                                      } else if (e.code == 'too-many-requests') {
                                        errorMessage = 'Too many requests. Please try again later.';
                                      } else {
                                        errorMessage = e.message ?? errorMessage;
                                      }
                                      
                                      setDialogState(() {
                                        isSendingReset = false;
                                      });
                                      
                                      Fluttertoast.showToast(
                                        msg: errorMessage,
                                        backgroundColor: colorScheme.error,
                                        textColor: colorScheme.onError,
                                        toastLength: Toast.LENGTH_LONG,
                                        gravity: ToastGravity.BOTTOM,
                                        fontSize: 16.0,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setDialogState(() {
                                        isSendingReset = false;
                                      });
                                      Fluttertoast.showToast(
                                        msg: 'An error occurred. Please try again.',
                                        backgroundColor: colorScheme.error,
                                        textColor: colorScheme.onError,
                                        toastLength: Toast.LENGTH_LONG,
                                        gravity: ToastGravity.BOTTOM,
                                        fontSize: 16.0,
                                      );
                                    }
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
                      
                    SizedBox(height: MediaQuery.of(dialogContext).padding.bottom + 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Dispose controller after dialog closes completely
      if (!resetEmailController.hasListeners) {
        resetEmailController.dispose();
      } else {
        // Delay disposal if controller is still attached
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!resetEmailController.hasListeners) {
            resetEmailController.dispose();
          }
        });
      }
    });
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // App logo/icon with modern design
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
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
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          size: 50,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Modern title section
                    Text(
                      'Welcome Back',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Sign in to continue tracking your expenses',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Modern card container for form
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
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

                            const SizedBox(height: 20),

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

                            const SizedBox(height: 12),

                            // Forgot password link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Login button
                            FilledButton(
                              onPressed: _isLoading ? null : _login,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
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
                                      'Sign In',
                                      style: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),

                            const SizedBox(height: 24),

                            // Divider with "OR"
                            Row(
                              children: [
                                Expanded(child: Divider(color: colorScheme.outline)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: colorScheme.outline)),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Google Sign-In button
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
