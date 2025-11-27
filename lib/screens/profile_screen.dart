import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../helpers/notification_helper.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import '../helpers/config.dart';
import '../helpers/database_helper.dart';
import '../helpers/responsive_helper.dart';
import '../models/category.dart';
import '../theme_provider.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/input_fields.dart';
import '../services/google_sign_in_service.dart';
import 'passcode_screen.dart';
import 'help_screen.dart';
import 'faq_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final dbHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  final _nameController = TextEditingController();

  User? get currentUser => _auth.currentUser;

  bool _isLoggingOut = false;
  bool _isUploading = false;
  bool _isRestoring = false;
  bool _isSendingPasswordReset = false;
  bool _isDeletingAccount = false;
  String _selectedCurrency = 'KSh';
  bool _isPasscodeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _reloadUserData();
  }

  Future<void> _reloadUserData() async {
    // Reload user profile data to ensure photoURL and other fields are up-to-date
    final user = currentUser;
    if (user != null) {
      try {
        await user.reload();
        // Get the refreshed user data
        final refreshedUser = _auth.currentUser;
        if (refreshedUser != null && mounted) {
          setState(() {
            // Force rebuild to show updated photoURL
          });
        }
      } catch (e) {
        print('Warning: Failed to reload user data: $e');
        // Continue even if reload fails
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final imagePicker = ImagePicker();
    final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);

    if (image == null || currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload');
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final stringToSign =
          'timestamp=$timestamp${AppConfig.cloudinaryApiSecret}';
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();

      request.fields['api_key'] = AppConfig.cloudinaryApiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final responseJson = json.decode(responseData);
        final imageUrl = responseJson['secure_url'];

        await currentUser!.updatePhotoURL(imageUrl);
        
        // Reload user data to ensure photoURL is immediately available
        try {
          await currentUser!.reload();
          // Get the refreshed user data
          final refreshedUser = _auth.currentUser;
          if (refreshedUser != null && mounted) {
            setState(() {
              // Force rebuild to show updated photoURL
            });
          }
        } catch (e) {
          print('Warning: Failed to reload user data after photo update: $e');
        }
        
        NotificationHelper.showSuccess(context, message: 'Profile picture updated!');
      } else {
        final errorData = await response.stream.bytesToString();
        print('Cloudinary Error: $errorData');
        NotificationHelper.showError(context, message: 'Failed to upload image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      NotificationHelper.showError(context, message: 'Failed to upload image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedCurrency = prefs.getString('currency') ?? 'KSh';
        _isPasscodeEnabled = prefs.getString('passcode') != null;
      });
    }
  }

  Future<void> _saveCurrencyPreference(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    setState(() => _selectedCurrency = currency);
  }

  void _showUpdateNameDialog() {
    _nameController.text = currentUser?.displayName ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Your Name'),
        content: StandardTextFormField(
          controller: _nameController,
          labelText: 'Full Name',
          prefixIcon: Icons.person_outline,
          autofocus: true,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                await currentUser?.updateDisplayName(_nameController.text.trim());
                Navigator.pop(context);
                if (mounted) {
                  NotificationHelper.showSuccess(context, message: 'Name updated successfully!');
                  setState(() {});
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    if (currentUser?.email == null) return;
    if (_isSendingPasswordReset) return;
    
    setState(() => _isSendingPasswordReset = true);
    try {
      await _auth.sendPasswordResetEmail(email: currentUser!.email!);
      if (mounted) {
        NotificationHelper.showSuccess(context, message: 'Password reset link sent to your email.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, message: e.message ?? 'An error occurred.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingPasswordReset = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    
    final bool? confirm = await showModernConfirmDialog(
      context: context,
      title: 'DELETE ACCOUNT',
      message: 'This is irreversible. All your data will be permanently deleted. Are you sure?',
      confirmText: 'DELETE',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      setState(() => _isDeletingAccount = true);
      try {
        await currentUser?.delete();
        if (mounted) {
          NotificationHelper.showSuccess(context, message: 'Account deleted successfully.');
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          setState(() => _isDeletingAccount = false);
          NotificationHelper.showError(context, message: e.message ?? 'Failed to delete account.');
        }
      }
    }
  }

  Future<void> _logout() async {
    final bool? confirm = await showModernConfirmDialog(
      context: context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      setState(() => _isLoggingOut = true);
      try {
        // Always sign out from Firebase Auth first to ensure logout happens
        // Then sign out from Google if applicable
        final user = currentUser;
        bool isGoogleUser = false;
        
        if (user != null) {
          // Check if user has a Google provider
          isGoogleUser = user.providerData
              .any((provider) => provider.providerId == 'google.com');
        }
        
        // Always sign out from Firebase Auth
        await _auth.signOut();
        
        // Also sign out from Google Sign-In if applicable (non-blocking)
        if (isGoogleUser) {
          try {
            await GoogleSignInService.signOut();
          } catch (e) {
            // Ignore Google sign out errors - Firebase sign out already succeeded
            print('Google sign out error (non-critical): $e');
          }
        }
        
        // Small delay to ensure auth state change propagates
        await Future.delayed(const Duration(milliseconds: 300));
        
        // AuthGate's StreamBuilder will automatically detect the sign out
        // and navigate to LoginScreen. No manual navigation needed.
        // Clear loading state after delay
        if (mounted) {
          setState(() => _isLoggingOut = false);
        }
      } catch (e, stackTrace) {
        // Log the error for debugging
        print('Logout error: $e');
        print('Stack trace: $stackTrace');
        
        if (mounted) {
          setState(() => _isLoggingOut = false);
          
          // Try to sign out anyway, even if there was an error
          try {
            await _auth.signOut();
          } catch (signOutError) {
            print('Secondary sign out attempt also failed: $signOutError');
          }
          
          final theme = Theme.of(context);
          NotificationHelper.showSuccess(context, message: 'Signed out successfully');
        }
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    const phoneNumber = '+254717880017';
    const message = 'Hello, I have a question about the PatoTrack app.';
    final whatsappUrl = Uri.parse(
        "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        NotificationHelper.showWarning(context, message: 'Could not launch WhatsApp. Is it installed?');
      }
    } catch (e) {
      NotificationHelper.showError(context, message: 'An error occurred.');
    }
  }

  void _showFaqScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FaqScreen()),
    );
  }

  Future<void> _handleRestore() async {
    if (currentUser == null) return;

    final bool? confirm = await showModernConfirmDialog(
      context: context,
      title: 'Restore from Cloud',
      message: 'This will replace all local data with your cloud backup. Are you sure?',
      confirmText: 'Restore',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirm == true && mounted) {
      setState(() => _isRestoring = true);
      try {
        await dbHelper.restoreFromFirestore(currentUser!.uid);
        NotificationHelper.showSuccess(context, message: "Data restored successfully! Please restart the app to see all changes.", duration: const Duration(seconds: 5));
      } catch (e) {
        NotificationHelper.showError(context, message: "Error restoring data: $e");
      } finally {
        if (mounted) setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (currentUser != null)
                Container(
                  width: double.infinity,
                  padding: ResponsiveHelper.edgeInsets(context, 32, 24, 32, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withOpacity(0.8),
                        colorScheme.primaryContainer.withOpacity(0.6),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                      // Modern Profile Image with Edit Badge
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer ring with gradient
                            Container(
                              width: ResponsiveHelper.width(context, 120),
                              height: ResponsiveHelper.width(context, 120),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.9),
                                    Colors.white.withOpacity(0.7),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(4),
                              child: CircleAvatar(
                                radius: ResponsiveHelper.width(context, 56),
                                backgroundImage: (currentUser!.photoURL != null)
                                    ? NetworkImage(currentUser!.photoURL!)
                                    : null,
                                backgroundColor: colorScheme.primary,
                                child: (currentUser!.photoURL == null)
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: ResponsiveHelper.iconSize(context, 60),
                                        color: colorScheme.onPrimary,
                                      )
                                    : null,
                              ),
                            ),
                            // Camera icon badge
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: ResponsiveHelper.edgeInsetsAll(context, 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: ResponsiveHelper.iconSize(context, 18),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Uploading overlay
                            if (_isUploading)
                              Container(
                                width: ResponsiveHelper.width(context, 120),
                                height: ResponsiveHelper.width(context, 120),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.6),
                                ),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                      // Name with Edit Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              currentUser!.displayName ?? 'User',
                              style: GoogleFonts.inter(
                                fontSize: ResponsiveHelper.fontSize(context, 28),
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showUpdateNameDialog,
                              borderRadius: BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
                              child: Container(
                                padding: ResponsiveHelper.edgeInsetsAll(context, 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.radius(context, 12)),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: ResponsiveHelper.iconSize(context, 18),
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                      // Email with icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: ResponsiveHelper.iconSize(context, 16),
                            color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                          Flexible(
                            child: Text(
                              currentUser!.email ?? 'No email',
                              style: GoogleFonts.inter(
                                fontSize: ResponsiveHelper.fontSize(context, 14),
                                color: colorScheme.onPrimaryContainer.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'App Settings',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildModernListTile(
                        context: context,
                        icon: Icons.dark_mode_rounded,
                        title: 'Dark Mode',
                        trailing: Switch(
                          value: themeProvider.themeMode == ThemeMode.dark,
                          onChanged: (value) => themeProvider.toggleTheme(value),
                        ),
                      ),
                      Divider(height: 1, indent: 60, color: colorScheme.outline.withOpacity(0.1)),
                      _buildModernListTile(
                        context: context,
                        icon: Icons.lock_rounded,
                        title: 'Passcode Lock',
                        subtitle: 'Secure your app with a passcode',
                        trailing: Switch(
                          value: _isPasscodeEnabled,
                          onChanged: (value) async {
                            final prefs = await SharedPreferences.getInstance();
                            if (value) {
                              final success = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const PasscodeScreen(isSettingPasscode: true)));
                              if (success == true && mounted) {
                                setState(() => _isPasscodeEnabled = true);
                              }
                            } else {
                              final success = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                      builder: (context) => const PasscodeScreen(
                                          isSettingPasscode: false)));
                              if (success == true && mounted) {
                                await prefs.remove('passcode');
                                setState(() => _isPasscodeEnabled = false);
                              }
                            }
                          },
                        ),
                      ),
                      if (_isPasscodeEnabled) ...[
                        Divider(height: 1, indent: 60, color: colorScheme.outline.withOpacity(0.1)),
                        _buildModernListTile(
                          context: context,
                          icon: Icons.phonelink_lock_rounded,
                          title: 'Change Passcode',
                          onTap: () async {
                            final verified = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PasscodeScreen(isSettingPasscode: false)));
                            if (verified == true && mounted) {
                              await Navigator.of(context).push<bool>(MaterialPageRoute(
                                  builder: (context) =>
                                      const PasscodeScreen(isSettingPasscode: true)));
                            }
                          },
                        ),
                      ],
                      Divider(height: 1, indent: 60, color: colorScheme.outline.withOpacity(0.1)),
                      _buildModernListTile(
                        context: context,
                        icon: Icons.currency_exchange_rounded,
                        title: 'Currency',
                        trailing: DropdownButton<String>(
                          value: _selectedCurrency,
                          underline: const SizedBox(),
                          dropdownColor: theme.brightness == Brightness.dark
                              ? colorScheme.surfaceContainerHighest
                              : Colors.white,
                          icon: Icon(
                            Icons.arrow_drop_down_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          iconSize: 24,
                          borderRadius: BorderRadius.circular(12),
                          menuMaxHeight: 200,
                          items: <String>['KSh', 'USD', 'EUR', 'GBP']
                              .map<DropdownMenuItem<String>>((String value) =>
                                  DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                        ),
                                      )))
                              .toList(),
                          selectedItemBuilder: (BuildContext context) {
                            return <String>['KSh', 'USD', 'EUR', 'GBP']
                                .map<Widget>((String value) {
                              return Text(
                                value,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              );
                            }).toList();
                          },
                          onChanged: (String? newValue) {
                            if (newValue != null && mounted) {
                              _saveCurrencyPreference(newValue);
                              NotificationHelper.showSuccess(context, message: 'Currency updated!');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'Account',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildModernListTile(
                        context: context,
                        icon: Icons.password_rounded,
                        title: 'Change Password',
                        trailing: _isSendingPasswordReset
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                        onTap: _isSendingPasswordReset ? null : _sendPasswordResetEmail,
                      ),
                      Divider(height: 1, indent: 60, color: colorScheme.outline.withOpacity(0.1)),
                      _buildModernListTile(
                        context: context,
                        icon: Icons.delete_forever_rounded,
                        title: 'Delete Account',
                        titleColor: Colors.red,
                        iconColor: Colors.red,
                        trailing: _isDeletingAccount
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.red,
                                  ),
                                ),
                              )
                            : null,
                        onTap: _isDeletingAccount ? null : _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'Data & Sync',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _buildModernListTile(
                    context: context,
                    icon: Icons.cloud_download_rounded,
                    title: 'Restore from Cloud',
                    subtitle: 'Download your backup on a new device',
                    trailing: _isRestoring
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 24),
                    onTap: _isRestoring ? null : _handleRestore,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'Help & Support',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildModernListTile(
                        context: context,
                        icon: Icons.question_answer_rounded,
                        title: 'FAQ',
                        onTap: _showFaqScreen,
                      ),
                      Divider(height: 1, indent: 60, color: colorScheme.outline.withOpacity(0.1)),
                      _buildModernListTile(
                        context: context,
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const HelpScreen()),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 60, color: colorScheme.outline.withOpacity(0.1)),
                      _buildModernListTile(
                        context: context,
                        icon: Icons.support_agent_rounded,
                        title: 'Contact via WhatsApp',
                        onTap: _launchWhatsApp,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoggingOut ? null : _logout,
                    icon: _isLoggingOut
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildModernListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? colorScheme.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor ?? colorScheme.primary,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: titleColor ?? colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                )
              : null),
      onTap: onTap,
    );
  }
}

