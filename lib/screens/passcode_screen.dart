// lib/screens/passcode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class PasscodeScreen extends StatefulWidget {
  final bool isSettingPasscode;
  final bool isAppUnlock;

  const PasscodeScreen({
    super.key,
    required this.isSettingPasscode,
    this.isAppUnlock = false,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _pinToConfirm;
  String _title = '';
  String _subtitle = '';
  bool _hasError = false;
  bool _isDisposed = false;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _updateUI();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );
    
    // Focus first field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _updateUI() {
    if (widget.isSettingPasscode) {
      if (_pinToConfirm == null) {
        _title = 'Create a New Passcode';
        _subtitle = 'Enter a 4-digit passcode to secure your app';
      } else {
        _title = 'Confirm your Passcode';
        _subtitle = 'Re-enter your passcode to confirm';
      }
    } else {
      _title = 'Enter Passcode';
      _subtitle = 'Enter your passcode to continue';
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _onPinChanged() {
    String pin = _pinControllers.map((c) => c.text).join();
    if (pin.length == 4) {
      _onPinCompleted(pin);
    }
  }

  void _clearPin() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _triggerShake() {
    if (_isDisposed) return;
    _shakeController.forward(from: 0).then((_) {
      if (!_isDisposed) {
        _shakeController.reverse();
      }
    });
  }

  Future<void> _onPinCompleted(String pin) async {
    if (_isDisposed || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('passcode');
    
    if (_isDisposed || !mounted) return;
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Setting a new passcode
    if (widget.isSettingPasscode) {
      // Check if new passcode is same as old one
      if (savedPin != null && savedPin == pin) {
        _showError('New passcode cannot be the same as the old one.');
        return;
      }

      // First entry
      if (_pinToConfirm == null) {
        if (!mounted || _isDisposed) return;
        setState(() {
          _pinToConfirm = pin;
          _hasError = false;
          _updateUI();
        });
        if (!_isDisposed) {
          _clearPin();
        }
      }
      // Confirmation entry
      else {
        if (_pinToConfirm == pin) {
          await prefs.setString('passcode', pin);
          
          if (!mounted || _isDisposed) return;
          
          final navigator = Navigator.of(context);
          Fluttertoast.showToast(
            msg: 'Passcode Set Successfully',
            backgroundColor: colorScheme.primary,
            textColor: colorScheme.onPrimary,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          navigator.pop(true);
        } else {
          _showError('Passcodes do not match. Please try again.');
        }
      }
    }
    // Verifying existing passcode
    else {
      if (savedPin == pin) {
        if (widget.isAppUnlock) {
          if (!mounted || _isDisposed) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          if (!mounted || _isDisposed) return;
          Navigator.of(context).pop(true);
        }
      } else {
        _showError('Incorrect Passcode');
      }
    }
  }

  void _showError(String message) {
    if (_isDisposed || !mounted) return;
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    setState(() {
      _hasError = true;
      if (widget.isSettingPasscode && _pinToConfirm != null) {
        _pinToConfirm = null;
        _updateUI();
      }
    });
    
    _triggerShake();
    
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed && mounted) {
        setState(() {
          _hasError = false;
        });
        _clearPin();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: widget.isAppUnlock
          ? null
          : AppBar(
              title: Text(
                _title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              ),
            ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.3),
                colorScheme.surface,
                colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Lock Icon
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: Container(
                            width: 100,
                            height: 100,
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
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 50,
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

                    // PIN Input Fields - Individual fields without wrapper container
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  width: 68,
                                  height: 68,
                                  child: TextField(
                                    controller: _pinControllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                    maxLength: 1,
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _hasError
                                              ? colorScheme.error
                                              : colorScheme.outline.withValues(alpha: 0.3),
                                          width: 2.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _hasError
                                              ? colorScheme.error.withValues(alpha: 0.5)
                                              : colorScheme.outline.withValues(alpha: 0.3),
                                          width: 2.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _hasError
                                              ? colorScheme.error
                                              : colorScheme.primary,
                                          width: 2.5,
                                        ),
                                      ),
                                      filled: false,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 3) {
                                        _focusNodes[index + 1].requestFocus();
                                      }
                                      _onPinChanged();
                                    },
                                    onTap: () {
                                      _pinControllers[index].selection = TextSelection.fromPosition(
                                        TextPosition(offset: _pinControllers[index].text.length),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),

                    // Progress Indicator
                    if (widget.isSettingPasscode && _pinToConfirm != null) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
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

                    const SizedBox(height: 48),

                    // Helper Text
                    if (!_hasError)
                      Text(
                        widget.isSettingPasscode
                            ? 'Remember this passcode. You\'ll need it to unlock your app.'
                            : 'Enter your 4-digit passcode',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),

                    if (_hasError)
                      Text(
                        'Please try again',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 40),
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
