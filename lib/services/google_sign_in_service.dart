import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service for handling Google Sign-In authentication
class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _isInitialized = false;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }
    await _googleSignIn.initialize();
    _isInitialized = true;
  }

  /// Signs in with Google and returns a UserCredential
  /// Returns null if sign-in is cancelled or fails
  static Future<UserCredential?> signInWithGoogle() async {
    await _ensureInitialized();

    try {
      // Trigger the Google Sign-In flow with account selection
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          'Google Sign-In timed out. Please try again.',
        ),
      );

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Verify we have valid tokens
      if (googleAuth.idToken == null) {
        throw Exception(
          'Could not get a Google ID token. Check your Google Sign-In setup in Firebase and try again.',
        );
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential =
          await _auth.signInWithCredential(credential).timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception(
                  'Firebase authentication timed out. Please try again.',
                ),
              );

      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw Exception('Google Sign-In failed: ${e.description}');
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth errors
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Signs out from Google
  static Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Checks if user is currently signed in with Google
  static bool isSignedIn() {
    return _auth.currentUser != null &&
        _auth.currentUser!.providerData.any(
          (info) => info.providerId == 'google.com',
        );
  }

  /// Handles Firebase Auth exceptions and returns user-friendly messages
  static Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return Exception(
          'An account already exists with the same email address but different sign-in credentials.',
        );
      case 'invalid-credential':
        return Exception('The credential is invalid or has expired.');
      case 'operation-not-allowed':
        return Exception('Google Sign-In is not enabled.');
      case 'user-disabled':
        return Exception('This user account has been disabled.');
      case 'user-not-found':
        return Exception('No user found with this email.');
      case 'wrong-password':
        return Exception('Wrong password provided.');
      case 'network-request-failed':
        return Exception(
            'Network error. Please check your internet connection.');
      case 'too-many-requests':
        return Exception(
          'Too many requests. Please try again later.',
        );
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }
}
