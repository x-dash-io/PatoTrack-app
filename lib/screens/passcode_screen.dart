// lib/screens/passcode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_pin_code_fields/flutter_pin_code_fields.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import MainScreen to navigate to it

class PasscodeScreen extends StatefulWidget {
  final bool isSettingPasscode;
  // NEW: Flag to check if we're unlocking the app on startup
  final bool isAppUnlock;

  const PasscodeScreen({
    super.key,
    required this.isSettingPasscode,
    this.isAppUnlock = false, // Default to false for existing calls
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  String? _pinToConfirm;
  late String _title;
  late String _subtitle;
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _title = widget.isSettingPasscode ? 'Create a New Passcode' : 'Enter Passcode';
    _subtitle = widget.isSettingPasscode
        ? 'Enter a 4-digit passcode to secure your app'
        : 'Enter your passcode to continue';
    
    // Initialize shake animation for error feedback
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  void _onPinCompleted(String pin) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('passcode');
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // This block is for SETTING a new passcode
    if (widget.isSettingPasscode) {
      if (savedPin != null && savedPin == pin) {
        setState(() {
          _hasError = true;
        });
        _triggerShake();
        Fluttertoast.showToast(
          msg: 'New passcode cannot be the same as the old one.',
          backgroundColor: colorScheme.error,
          textColor: colorScheme.onError,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _pinController.hasListeners) {
            setState(() {
              _pinToConfirm = null;
              _title = 'Create a New Passcode';
              _subtitle = 'Enter a 4-digit passcode to secure your app';
              _hasError = false;
            });
            if (_pinController.hasListeners) {
              _pinController.clear();
            }
          }
        });
        return;
      }

      if (_pinToConfirm == null) {
        if (mounted) {
          setState(() {
            _pinToConfirm = pin;
            _title = 'Confirm your Passcode';
            _subtitle = 'Re-enter your passcode to confirm';
            _hasError = false;
          });
          if (_pinController.hasListeners) {
            _pinController.clear();
          }
        }
      } else {
        if (_pinToConfirm == pin) {
          await prefs.setString('passcode', pin);
          Fluttertoast.showToast(
            msg: 'Passcode Set Successfully',
            backgroundColor: colorScheme.primary,
            textColor: colorScheme.onPrimary,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          navigator.pop(true);
        } else {
          setState(() {
            _hasError = true;
          });
          _triggerShake();
          Fluttertoast.showToast(
            msg: 'Passcodes do not match. Please try again.',
            backgroundColor: colorScheme.error,
            textColor: colorScheme.onError,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _pinController.hasListeners) {
              setState(() {
                _pinToConfirm = null;
                _title = 'Create a New Passcode';
                _subtitle = 'Enter a 4-digit passcode to secure your app';
                _hasError = false;
              });
              if (_pinController.hasListeners) {
                _pinController.clear();
              }
            }
          });
        }
      }
    }
    // This block is for VERIFYING an existing passcode
    else {
      if (savedPin == pin) {
        // UPDATED: Check if we are unlocking the app
        if (widget.isAppUnlock) {
          // If yes, replace the current screen with the MainScreen
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          // If no (e.g., just verifying from settings), just pop back
          navigator.pop(true);
        }
      } else {
        setState(() {
          _hasError = true;
        });
        _triggerShake();
        Fluttertoast.showToast(
          msg: 'Incorrect Passcode',
          backgroundColor: colorScheme.error,
          textColor: colorScheme.onError,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _pinController.hasListeners) {
            setState(() {
              _hasError = false;
            });
            if (_pinController.hasListeners) {
              _pinController.clear();
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent layout resize when keyboard appears
      appBar: AppBar(
        title: Text(
          _title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        // UPDATED: Hide the back button only when unlocking the app on startup
        automaticallyImplyLeading: !widget.isAppUnlock,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Container(
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      kToolbarHeight -
                      64,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // Modern gradient lock icon container
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: Container(
                          width: 120,
                          height: 120,
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
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 60,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 48),

                  // Title
                  Text(
                    _title,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    _subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // PIN Input Fields with modern styling
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: Center(
                          child: PinCodeFields(
                            controller: _pinController,
                            length: 4,
                            fieldBorderStyle: FieldBorderStyle.square,
                            responsive: false,
                            fieldHeight: 64.0,
                            fieldWidth: 64.0,
                            borderWidth: 2.5,
                            activeBorderColor: _hasError
                                ? colorScheme.error
                                : colorScheme.primary,
                            borderRadius: BorderRadius.circular(16.0),
                            keyboardType: TextInputType.number,
                            autoHideKeyboard: true,
                            obscureText: true,
                            obscureCharacter: '●',
                            onComplete: _onPinCompleted,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  if (widget.isSettingPasscode && _pinToConfirm != null) ...[
                    const SizedBox(height: 24),
                    // Progress indicator showing we're on step 2
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Step 2 of 2',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Helper text
                  if (!_hasError)
                    Text(
                      widget.isSettingPasscode
                          ? 'Remember this passcode. You\'ll need it to unlock your app.'
                          : 'Enter your 4-digit passcode',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
