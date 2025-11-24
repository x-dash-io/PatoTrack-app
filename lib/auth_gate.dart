import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  @override
  void initState() {
    super.initState();
    // Listen to auth state changes and force rebuilds when auth state changes
    // This ensures AuthGate rebuilds immediately when authentication state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        // Force a rebuild when auth state changes
        // This is necessary because the StreamBuilder might not rebuild immediately
        setState(() {});
      }
    });
  }

  Future<bool> _isPasscodeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('passcode') != null;
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
          return const WelcomeScreen();
        }

        // Once onboarding is done, check auth state
        // Use StreamBuilder for reactive updates, always check currentUser for immediate state
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Always check currentUser directly - it's the most reliable and immediate source
            // The stream might lag behind, so we prioritize currentUser
            final currentUser = FirebaseAuth.instance.currentUser;
            
            // Use currentUser if available (most reliable), otherwise use stream data
            final user = currentUser ?? snapshot.data;
            
            // While waiting for initial auth state and no current user, show a loading indicator
            if (snapshot.connectionState == ConnectionState.waiting && currentUser == null) {
              return const Scaffold(
                body: ModernLoadingIndicator(),
              );
            }

            // User is not signed in, show the login screen
            if (user == null) {
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
                    isAppUnlock: true, // A new flag to tell the screen it's for unlocking the app
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
      },
    );
  }
}
