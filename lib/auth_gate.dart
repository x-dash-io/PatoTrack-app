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

  @override
  void initState() {
    super.initState();
    // Get initial user state
    _currentUser = FirebaseAuth.instance.currentUser;

    // Listen to auth state changes and force rebuilds immediately
    // This is critical - it ensures AuthGate rebuilds as soon as login happens
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        _currentUser = user;
        // Force immediate rebuild when auth state changes
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _isPasscodeEnabled() async {
    await _passcodeService.migrateLegacyPasscodeIfNeeded();
    return _passcodeService.isPasscodeSet();
  }

  Future<bool> _isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isOnboardingCompleted(),
      builder: (context, onboardingSnapshot) {
        // Check onboarding first
        if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: ModernLoadingIndicator(),
          );
        }

        // Show welcome screen if onboarding not completed
        if (!(onboardingSnapshot.data ?? false)) {
          return WelcomeScreen(
            onOnboardingCompleted: () {
              if (mounted) {
                setState(() {});
              }
            },
          );
        }

        // Once onboarding is done, check auth state
        // The listener in initState will trigger setState when auth changes
        // Check currentUser directly (most reliable and immediate)
        final currentUser = FirebaseAuth.instance.currentUser ?? _currentUser;

        // User is not signed in, show the login screen
        if (currentUser == null) {
          return const LoginScreen();
        }

        // User is signed in, now check for passcode
        return FutureBuilder<bool>(
          future: _isPasscodeEnabled(),
          builder: (context, passcodeSnapshot) {
            // While checking for passcode, show a loading indicator
            if (passcodeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: ModernLoadingIndicator(),
              );
            }

            final bool passcodeEnabled = passcodeSnapshot.data ?? false;

            // If passcode is enabled, show the passcode screen for verification
            if (passcodeEnabled) {
              return const PasscodeScreen(
                isSettingPasscode: false, // We are verifying, not setting
                isAppUnlock:
                    true, // A new flag to tell the screen it's for unlocking the app
              );
            }

            // If no passcode, go directly to the main screen
            // Don't use a key based on user ID - this causes MainScreen to reset
            // its state (like _selectedIndex) every time user data changes
            return const MainScreen();
          },
        );
      },
    );
  }
}
