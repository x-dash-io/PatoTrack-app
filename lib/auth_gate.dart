import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/passcode_service.dart';
import 'main.dart'; // Your MainScreen with the bottom nav bar
import 'screens/login_screen.dart';
import 'screens/passcode_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/loading_widgets.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _currentUser;
  final PasscodeService _passcodeService = PasscodeService();
  StreamSubscription<User?>? _authSubscription;

  bool? _isOnboardingDone;
  bool? _isPasscodeSet;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        _currentUser = user;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    if (_isOnboardingDone == null) {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingDone = prefs.getBool('onboarding_completed') ?? false;
    }
    if (_isPasscodeSet == null) {
      await _passcodeService.migrateLegacyPasscodeIfNeeded();
      _isPasscodeSet = await _passcodeService.isPasscodeSet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadState(),
      builder: (context, snapshot) {
        if (_isOnboardingDone == null) {
          return const Scaffold(
            body: ModernLoadingIndicator(),
          );
        }

        if (!_isOnboardingDone!) {
          return WelcomeScreen(
            onOnboardingCompleted: () {
              if (mounted) {
                _isOnboardingDone = true;
                setState(() {});
              }
            },
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser ?? _currentUser;

        if (currentUser == null) {
          return const LoginScreen();
        }

        // Passcode check
        if (_isPasscodeSet == null) {
          return const Scaffold(body: ModernLoadingIndicator());
        }

        if (_isPasscodeSet!) {
          return const PasscodeScreen(
            isSettingPasscode: false,
            isAppUnlock: true,
          );
        }

        return const MainScreen();
      },
    );
  }
}
