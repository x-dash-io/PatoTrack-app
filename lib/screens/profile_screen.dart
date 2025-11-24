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
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import '../helpers/config.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../theme_provider.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/input_fields.dart';
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
        
        Fluttertoast.showToast(msg: 'Profile picture updated!');
      } else {
        final errorData = await response.stream.bytesToString();
        print('Cloudinary Error: $errorData');
        Fluttertoast.showToast(
            msg: 'Failed to upload image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      Fluttertoast.showToast(msg: 'Failed to upload image: $e');
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name updated successfully!')),
                  );
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
        Fluttertoast.showToast(msg: 'Password reset link sent to your email.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: e.message ?? 'An error occurred.');
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
          Fluttertoast.showToast(msg: 'Account deleted successfully.');
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          setState(() => _isDeletingAccount = false);
          Fluttertoast.showToast(msg: e.message ?? 'Failed to delete account.');
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

    if (confirm == true) {
      setState(() => _isLoggingOut = true);
      await _auth.signOut();
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
        Fluttertoast.showToast(
            msg: 'Could not launch WhatsApp. Is it installed?');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'An error occurred.');
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
        Fluttertoast.showToast(
            msg:
                "Data restored successfully! Please restart the app to see all changes.",
            toastLength: Toast.LENGTH_LONG);
      } catch (e) {
        Fluttertoast.showToast(
            msg: "Error restoring data: $e",
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG);
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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: (currentUser!.photoURL != null)
                                    ? NetworkImage(currentUser!.photoURL!)
                                    : null,
                                backgroundColor: colorScheme.primary,
                                child: (currentUser!.photoURL == null)
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: 50,
                                        color: colorScheme.onPrimary,
                                      )
                                    : null,
                              ),
                            ),
                            if (_isUploading)
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.5),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              currentUser!.displayName ?? 'User',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showUpdateNameDialog,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentUser!.email ?? 'No email',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Currency updated!',
                                      style: GoogleFonts.inter(),
                                    ),
                                  ));
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

