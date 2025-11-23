import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import '../widgets/loading_widgets.dart';

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
    // Basic validation
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter your name',
        backgroundColor: CupertinoColors.systemRed,
        textColor: CupertinoColors.white,
      );
      return;
    }
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
      // Create the user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Update the user's display name
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        Fluttertoast.showToast(
          msg: "Account Created Successfully!",
          backgroundColor: CupertinoColors.systemGreen,
          textColor: CupertinoColors.white,
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: e.message ?? 'Sign up failed',
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

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _isLoading,
          message: 'Creating account...',
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
                        CupertinoIcons.person_add,
                        size: 50,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Title
                  Text(
                    'Get Started',
                    style: GoogleFonts.inter(
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
                    'Create your account to start tracking',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      color: isDark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Name field
                  _buildTextField(
                    controller: _nameController,
                    placeholder: 'Full Name',
                    keyboardType: TextInputType.name,
                    prefix: const Icon(CupertinoIcons.person, size: 20),
                    validator: Theme.of(context).platform != TargetPlatform.iOS
                        ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          }
                        : null,
                  ),

                  // Email field
                  _buildTextField(
                    controller: _emailController,
                    placeholder: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(CupertinoIcons.mail, size: 20),
                    validator: Theme.of(context).platform != TargetPlatform.iOS
                        ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          }
                        : null,
                  ),

                  // Password field
                  _buildTextField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    obscureText: !_isPasswordVisible,
                    prefix: const Icon(CupertinoIcons.lock, size: 20),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _isPasswordVisible
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        size: 20,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    validator: Theme.of(context).platform != TargetPlatform.iOS
                        ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          }
                        : null,
                  ),

                  const SizedBox(height: 32),

                  // Sign up button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CupertinoColors.activeBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: CupertinoColors.systemGrey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign in link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isDark
                              ? Colors.white70
                              : Colors.black87,
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
                            color: CupertinoColors.activeBlue,
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
          style: GoogleFonts.inter(),
          placeholderStyle: GoogleFonts.inter(
            color: CupertinoColors.placeholderText,
          ),
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
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: GoogleFonts.inter(),
          decoration: InputDecoration(
            labelText: placeholder,
            labelStyle: GoogleFonts.inter(),
            prefixIcon: prefix,
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: CupertinoColors.activeBlue, width: 2),
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? CupertinoColors.systemGrey6.darkColor
                : CupertinoColors.systemGrey6,
          ),
          validator: validator,
        ),
      );
    }
  }
}
