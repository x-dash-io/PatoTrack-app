import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'signup_screen.dart';
import '../widgets/loading_widgets.dart';

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
    // Basic validation
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.trim().contains('@')) {
      Fluttertoast.showToast(
        msg: 'Please enter a valid email',
        backgroundColor: CupertinoColors.systemRed,
        textColor: CupertinoColors.white,
      );
      return;
    }
    if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
      Fluttertoast.showToast(
        msg: 'Password must be at least 6 characters',
        backgroundColor: CupertinoColors.systemRed,
        textColor: CupertinoColors.white,
      );
      return;
    }

    // Android form validation
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // The AuthGate will handle navigation on success
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: e.message ?? 'Login failed',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: CupertinoColors.systemRed,
          textColor: CupertinoColors.white,
          fontSize: 16.0,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Sign In'),
        backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: LoadingOverlay(
          isLoading: _isLoading,
          message: 'Signing in...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // App logo/icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.money_dollar_circle_fill,
                        size: 50,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Title
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 17,
                      color: isDark
                          ? CupertinoColors.secondaryLabel
                          : CupertinoColors.secondaryLabel.darkColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Email field
                  _buildTextField(
                    controller: _emailController,
                    placeholder: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(CupertinoIcons.mail, size: 20),
                    validator: isIOS
                        ? null
                        : (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                  ),

                  // Password field
                  _buildTextField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    obscureText: !_isPasswordVisible,
                    prefix: const Icon(CupertinoIcons.lock, size: 20),
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                      child: Icon(
                        _isPasswordVisible
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        size: 20,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    validator: isIOS
                        ? null
                        : (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                  ),

                  const SizedBox(height: 32),

                  // Login button
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _login,
                    borderRadius: BorderRadius.circular(12),
                    disabledColor: CupertinoColors.systemGrey,
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark
                              ? CupertinoColors.secondaryLabel
                              : CupertinoColors.secondaryLabel.darkColor,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? prefix,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          obscureText: obscureText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: prefix,
                )
              : null,
          suffix: suffix,
          decoration: null,
        ),
      );
    } else {
      // Android fallback with validation
      return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: placeholder,
          prefixIcon: prefix,
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: validator,
      );
    }
  }
}
