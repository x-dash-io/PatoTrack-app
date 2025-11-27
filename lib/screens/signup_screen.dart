import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/input_fields.dart';
import '../services/google_sign_in_service.dart';
import '../helpers/notification_helper.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
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
      // Create the user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create user account');
      }

      // Update the user's display name
      try {
        await userCredential.user?.updateDisplayName(_nameController.text.trim());
      } catch (e) {
        print('Warning: Failed to update display name: $e');
        // Continue even if display name update fails
      }

      // Verify user is actually authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User authentication failed');
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
      
      // Clear loading state first
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show success feedback
        final theme = Theme.of(context);
        NotificationHelper.showSuccess(context, message: "Account Created Successfully!");
        
        // Pop SignUpScreen to return to AuthGate
        // AuthGate's StreamBuilder will automatically detect the auth state change
        // via authStateChanges() stream and rebuild to show MainScreen or PasscodeScreen
        // instead of LoginScreen
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final theme = Theme.of(context);
        NotificationHelper.showError(context, message: e.message ?? 'Sign up failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final theme = Theme.of(context);
        NotificationHelper.showError(context, message: 'Error: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
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
          
          // Clear loading state first
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            // Show success message
            final theme = Theme.of(context);
            NotificationHelper.showSuccess(context, message: 'Account created with Google successfully!');
            
            // Pop SignUpScreen to return to AuthGate
            // AuthGate's StreamBuilder will automatically detect the auth state change
            // via authStateChanges() stream and rebuild to show MainScreen or PasscodeScreen
            // instead of LoginScreen
            Navigator.of(context).pop();
          }
        } else {
          // User not properly authenticated
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            final theme = Theme.of(context);
            NotificationHelper.showError(context, message: 'Authentication failed. Please try again.');
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
        NotificationHelper.showError(context, message: e.toString().replaceAll('Exception: ', ''));
      }
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
            message: 'Creating account...',
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
                          Icons.person_add_alt_1,
                          size: 50,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Modern title section
                    Text(
                      'Get Started',
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
                      'Create your account to start tracking',
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
                            // Name field
                            StandardTextFormField(
                              controller: _nameController,
                              labelText: 'Full Name',
                              keyboardType: TextInputType.name,
                              prefixIcon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

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
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 32),

                            // Sign up button
                            FilledButton(
                              onPressed: _isLoading ? null : _signUp,
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
                                      'Create Account',
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
                              onPressed: _isLoading ? null : _signUpWithGoogle,
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

                    // Sign in link with modern design
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign In',
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
