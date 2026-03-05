import 'dart:convert';
import 'package:pato_track/app_icons.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../helpers/notification_helper.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import '../helpers/config.dart';
import '../helpers/database_helper.dart';
import '../helpers/passcode_service.dart';
import '../helpers/responsive_helper.dart';
import '../providers/currency_provider.dart';
import '../theme_provider.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/input_fields.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/profile/setting_list_tile.dart';
import '../services/google_sign_in_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_shadows.dart';
import '../styles/app_spacing.dart';
import 'passcode_screen.dart';
import 'help_screen.dart';
import 'faq_screen.dart';

enum CloudSyncStatus {
  idle,
  syncing,
  success,
  error,
  cancelled,
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _lastCloudRestorePreferenceKey = 'cloud_restore_last_epoch_ms';

  final dbHelper = DatabaseHelper();
  final PasscodeService _passcodeService = PasscodeService();
  final _auth = FirebaseAuth.instance;
  final _nameController = TextEditingController();

  User? get currentUser => _auth.currentUser;

  bool _isLoggingOut = false;
  bool _isUploading = false;
  bool _isSendingPasswordReset = false;
  bool _isDeletingAccount = false;
  bool _isPasscodeEnabled = false;
  DateTime? _lastCloudRestoreAt;
  CloudSyncStatus _cloudSyncStatus = CloudSyncStatus.idle;
  String? _cloudSyncMessage;
  bool _cancelCloudSyncRequested = false;

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
        debugPrint('Warning: Failed to reload user data: $e');
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

    if (!mounted || image == null || currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      if (AppConfig.cloudinaryUploadPreset ==
          'REPLACE_WITH_UNSIGNED_UPLOAD_PRESET') {
        if (!mounted) return;
        NotificationHelper.showError(
          context,
          message:
              'Cloudinary upload preset is not configured. Set AppConfig.cloudinaryUploadPreset first.',
        );
        return;
      }

      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload');
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final responseJson = json.decode(responseData) as Map<String, dynamic>;
        final imageUrl = responseJson['secure_url'] as String?;
        if (imageUrl == null || imageUrl.isEmpty) {
          throw Exception('Cloudinary response missing secure_url');
        }

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
          debugPrint(
              'Warning: Failed to reload user data after photo update: $e');
        }

        if (!mounted) return;
        NotificationHelper.showSuccess(context,
            message: 'Profile picture updated!');
      } else {
        final errorData = await response.stream.bytesToString();
        debugPrint('Cloudinary Error: $errorData');
        if (!mounted) return;
        NotificationHelper.showError(
          context,
          message:
              'Failed to upload image. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      if (!mounted) return;
      NotificationHelper.showError(context,
          message: 'Failed to upload image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await _passcodeService.migrateLegacyPasscodeIfNeeded();
    final isPasscodeEnabled = await _passcodeService.isPasscodeSet();
    if (mounted) {
      setState(() {
        _isPasscodeEnabled = isPasscodeEnabled;
        final lastRestoreEpoch = prefs.getInt(_lastCloudRestorePreferenceKey);
        _lastCloudRestoreAt = lastRestoreEpoch == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastRestoreEpoch);
      });
    }
  }

  void _showUpdateNameDialog() {
    _nameController.text = currentUser?.displayName ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Your Name'),
        content: StandardTextFormField(
          controller: _nameController,
          labelText: 'Full Name',
          prefixIcon: AppIcons.person_outline,
          autofocus: true,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                final navigator = Navigator.of(dialogContext);
                await currentUser
                    ?.updateDisplayName(_nameController.text.trim());
                navigator.pop();
                if (!mounted) return;
                NotificationHelper.showSuccess(
                  context,
                  message: 'Name updated successfully!',
                );
                setState(() {});
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
        NotificationHelper.showSuccess(context,
            message: 'Password reset link sent to your email.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        NotificationHelper.showError(context,
            message: e.message ?? 'An error occurred.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingPasswordReset = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    final user = currentUser;
    if (user == null) return;

    final bool? confirm = await showModernConfirmDialog(
      context: context,
      title: 'DELETE ACCOUNT',
      message:
          'This is irreversible. All your data will be permanently deleted. Are you sure?',
      confirmText: 'DELETE',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      setState(() => _isDeletingAccount = true);

      final lastSignInAt = user.metadata.lastSignInTime;
      final hasRecentSignIn = lastSignInAt != null &&
          DateTime.now().difference(lastSignInAt) <= const Duration(minutes: 5);
      if (!hasRecentSignIn) {
        if (mounted) {
          setState(() => _isDeletingAccount = false);
          NotificationHelper.showWarning(
            context,
            message:
                'For security, please log in again before deleting your account.',
          );
        }
        return;
      }

      try {
        // Delete user data first while auth credentials are still valid.
        await dbHelper.deleteUserDataFromFirestore(user.uid);
        await dbHelper.deleteAllUserData(user.uid);
        await user.delete();

        if (mounted) {
          NotificationHelper.showSuccess(
            context,
            message: 'Account and data deleted successfully.',
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          final message = e.code == 'requires-recent-login'
              ? 'Please log in again, then retry account deletion.'
              : (e.message ?? 'Failed to delete account.');
          NotificationHelper.showError(context, message: message);
        }
      } catch (e) {
        if (mounted) {
          NotificationHelper.showError(
            context,
            message: 'Failed to delete account data: $e',
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeletingAccount = false);
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
            debugPrint('Google sign out error (non-critical): $e');
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
        debugPrint('Logout error: $e');
        debugPrint('Stack trace: $stackTrace');

        if (mounted) {
          setState(() => _isLoggingOut = false);

          bool recoveredSignOut = false;
          try {
            await _auth.signOut();
            recoveredSignOut = true;
          } catch (signOutError) {
            debugPrint('Secondary sign out attempt also failed: $signOutError');
          }
          if (!mounted) return;
          if (recoveredSignOut) {
            NotificationHelper.showWarning(
              context,
              message:
                  'Signed out, but there was a cleanup issue. You may need to sign in again if this repeats.',
            );
          } else {
            NotificationHelper.showError(
              context,
              message: 'Unable to sign out right now. Please try again.',
            );
          }
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
        if (!mounted) return;
        NotificationHelper.showWarning(
          context,
          message: 'Could not launch WhatsApp. Is it installed?',
        );
      }
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showError(context, message: 'An error occurred.');
    }
  }

  void _showFaqScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FaqScreen()),
    );
  }

  Future<void> _handleRestore({bool skipConfirmation = false}) async {
    final user = currentUser;
    if (user == null || _cloudSyncStatus == CloudSyncStatus.syncing) {
      return;
    }

    if (!skipConfirmation) {
      final bool? confirm = await showModernConfirmDialog(
        context: context,
        title: 'Sync from Cloud',
        message:
            'This will replace local data with your latest cloud backup. Continue?',
        confirmText: 'Sync now',
        cancelText: 'Cancel',
        isDestructive: false,
      );
      if (confirm != true || !mounted) {
        return;
      }
    }

    setState(() {
      _cancelCloudSyncRequested = false;
      _cloudSyncStatus = CloudSyncStatus.syncing;
      _cloudSyncMessage = 'Syncing your cloud backup…';
    });

    try {
      await dbHelper.restoreFromFirestore(
        user.uid,
        shouldCancel: () => _cancelCloudSyncRequested,
      );

      if (_cancelCloudSyncRequested) {
        if (!mounted) return;
        setState(() {
          _cloudSyncStatus = CloudSyncStatus.cancelled;
          _cloudSyncMessage = 'Cloud sync cancelled.';
        });
        return;
      }

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastCloudRestorePreferenceKey,
        now.millisecondsSinceEpoch,
      );

      if (!mounted) return;
      setState(() {
        _lastCloudRestoreAt = now;
        _cloudSyncStatus = CloudSyncStatus.success;
        _cloudSyncMessage = 'Cloud sync completed successfully.';
      });
      NotificationHelper.showSuccess(
        context,
        message: 'Cloud sync complete. Local data is now up to date.',
      );
    } on CloudRestoreCancelledException {
      if (!mounted) return;
      setState(() {
        _cloudSyncStatus = CloudSyncStatus.cancelled;
        _cloudSyncMessage = 'Cloud sync cancelled.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cloudSyncStatus = CloudSyncStatus.error;
        _cloudSyncMessage =
            'Cloud sync failed. Check your internet connection and retry.';
      });
      NotificationHelper.showError(
        context,
        message: 'Cloud sync failed. Please retry in a moment.',
      );
      debugPrint('Cloud sync error: $e');
    }
  }

  Future<void> _clearReceiptCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Receipt Images?'),
        content: const Text('This will permanently delete all locally saved receipt photos to free up storage space. Your actual transaction data (amounts, dates, categories) will NOT be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete Images')
          ),
        ],
      )
    );

    if (confirmed != true) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${directory.path}/receipts');
      if (await receiptsDir.exists()) {
        await receiptsDir.delete(recursive: true);
      }
      
      if (currentUser != null) {
        final db = await DatabaseHelper().database;
        await db.update(
          'transactions', 
          {'receipt_image_url': null},
          where: 'userId = ? AND receipt_image_url IS NOT NULL',
          whereArgs: [currentUser!.uid],
        );
      }
      
      if (mounted) NotificationHelper.showSuccess(context, message: 'Receipt image cache cleared safely');
    } catch (e) {
      if (mounted) NotificationHelper.showError(context, message: 'Error clearing cache: $e');
    }
  }

  void _cancelRestore() {
    if (_cloudSyncStatus != CloudSyncStatus.syncing) {
      return;
    }
    setState(() {
      _cancelCloudSyncRequested = true;
      _cloudSyncStatus = CloudSyncStatus.cancelled;
      _cloudSyncMessage = 'Cancelling cloud sync…';
    });
  }

  String _cloudRestoreSubtitle() {
    final timestamp = _lastCloudRestoreAt == null
        ? 'Last sync: never.'
        : 'Last sync: ${DateFormat('MMM d, yyyy h:mm a').format(_lastCloudRestoreAt!)}.';
    final status = _cloudSyncMessage ?? 'Sync when you need to refresh data.';
    return '$status $timestamp';
  }

  String _cloudSyncStatusLabel() {
    switch (_cloudSyncStatus) {
      case CloudSyncStatus.syncing:
        return 'Syncing';
      case CloudSyncStatus.success:
        return 'Synced';
      case CloudSyncStatus.error:
        return 'Failed';
      case CloudSyncStatus.cancelled:
        return 'Cancelled';
      case CloudSyncStatus.idle:
        return 'Idle';
    }
  }

  Color _cloudSyncStatusColor(ColorScheme colorScheme) {
    switch (_cloudSyncStatus) {
      case CloudSyncStatus.syncing:
        return colorScheme.primary;
      case CloudSyncStatus.success:
        return Colors.green;
      case CloudSyncStatus.error:
        return colorScheme.error;
      case CloudSyncStatus.cancelled:
        return Colors.orange;
      case CloudSyncStatus.idle:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Profile header ────────────────────────────────────────────────
          if (currentUser != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF192236) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF243050)
                        : const Color(0xFFE8EDF7),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: colorScheme.primary,
                          backgroundImage: currentUser!.photoURL != null
                              ? CachedNetworkImageProvider(
                                  currentUser!.photoURL!)
                              : null,
                          child: currentUser!.photoURL == null
                              ? Icon(AppIcons.person_rounded,
                                  size: 36, color: Colors.white)
                              : null,
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF192236)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: _isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(AppIcons.camera_alt_rounded,
                                  size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentUser!.displayName ?? 'User',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: _showUpdateNameDialog,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E2A40)
                                      : const Color(0xFFF0F3FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(AppIcons.edit_outlined,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentUser!.email ?? '',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── App Settings ──────────────────────────────────────────────────
          _SectionHeader(title: 'App Settings'),
          _SettingsCard(
            children: [
              SettingListTile(
                icon: AppIcons.dark_mode_rounded,
                title: 'Dark Mode',
                trailing: Switch(
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (v) => themeProvider.toggleTheme(v),
                ),
              ),
              _SettingDivider(),
              SettingListTile(
                icon: AppIcons.lock_rounded,
                title: 'Passcode Lock',
                subtitle: 'Secure your app with a PIN',
                trailing: Switch(
                  value: _isPasscodeEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final success = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) =>
                                const PasscodeScreen(isSettingPasscode: true)),
                      );
                      if (success == true && mounted) {
                        setState(() => _isPasscodeEnabled = true);
                      }
                    } else {
                      final success = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) =>
                                const PasscodeScreen(isSettingPasscode: false)),
                      );
                      if (success == true && mounted) {
                        await _passcodeService.clearPasscode();
                        setState(() => _isPasscodeEnabled = false);
                      }
                    }
                  },
                ),
              ),
              if (_isPasscodeEnabled) ...[
                _SettingDivider(),
                SettingListTile(
                  icon: AppIcons.phonelink_lock_rounded,
                  title: 'Change Passcode',
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final verified = await navigator.push<bool>(
                      MaterialPageRoute(
                          builder: (_) =>
                              const PasscodeScreen(isSettingPasscode: false)),
                    );
                    if (verified != true || !mounted) return;
                    await navigator.push<bool>(
                      MaterialPageRoute(
                          builder: (_) =>
                              const PasscodeScreen(isSettingPasscode: true)),
                    );
                  },
                ),
              ],
              _SettingDivider(),
              SettingListTile(
                icon: AppIcons.currency_exchange_rounded,
                title: 'Currency',
                trailing: DropdownButton<String>(
                  value: currencyProvider.code,
                  underline: const SizedBox(),
                  dropdownColor:
                      isDark ? const Color(0xFF1E2A40) : Colors.white,
                  icon: Icon(AppIcons.arrow_drop_down_rounded,
                      color: colorScheme.onSurfaceVariant, size: 24),
                  borderRadius: BorderRadius.circular(12),
                  menuMaxHeight: 200,
                  items: currencyProvider.options
                      .map((o) => DropdownMenuItem(
                          value: o.code,
                          child: Text('${o.symbol} · ${o.code}')))
                      .toList(),
                  selectedItemBuilder: (_) => currencyProvider.options
                      .map((o) => Text(o.symbol,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          )))
                      .toList(),
                  onChanged: (v) {
                    if (v != null && mounted) {
                      currencyProvider.setCurrency(v);
                      NotificationHelper.showSuccess(context,
                          message: 'Currency updated.');
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Account ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          _SettingsCard(
            children: [
              SettingListTile(
                icon: AppIcons.password_rounded,
                title: 'Change Password',
                trailing: _isSendingPasswordReset
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _isSendingPasswordReset ? null : _sendPasswordResetEmail,
              ),
              _SettingDivider(),
              SettingListTile(
                icon: AppIcons.delete_forever_rounded,
                title: 'Delete Account',
                titleColor: colorScheme.error,
                iconColor: colorScheme.error,
                trailing: _isDeletingAccount
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.error)))
                    : null,
                onTap: _isDeletingAccount ? null : _deleteAccount,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Data & Sync ───────────────────────────────────────────────────
          _SectionHeader(title: 'Data & Sync'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF192236) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF243050)
                      : const Color(0xFFE8EDF7),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(AppIcons.cloud_sync_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cloud Sync',
                                style: theme.textTheme.titleSmall),
                            Text(_cloudRestoreSubtitle(),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _cloudSyncStatusColor(colorScheme)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _cloudSyncStatusLabel(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _cloudSyncStatusColor(colorScheme),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _cloudSyncStatus == CloudSyncStatus.syncing
                              ? null
                              : _handleRestore,
                          icon: const Icon(AppIcons.sync_rounded, size: 16),
                          label: Text(_cloudSyncStatus == CloudSyncStatus.error
                              ? 'Retry'
                              : 'Sync now'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38)),
                        ),
                      ),
                      if (_cloudSyncStatus == CloudSyncStatus.syncing) ...[
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: _cancelRestore,
                          icon: const Icon(AppIcons.close_rounded, size: 18),
                          style: IconButton.styleFrom(
                              minimumSize: const Size(38, 38),
                              fixedSize: const Size(38, 38)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          
          _SettingsCard(
            children: [
              SettingListTile(
                icon: AppIcons.cleaning_services_rounded, // fallback or exists
                title: 'Clear Local Receipts',
                titleColor: colorScheme.error,
                iconColor: colorScheme.error,
                onTap: _clearReceiptCache,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Help & Support ────────────────────────────────────────────────
          _SectionHeader(title: 'Help & Support'),
          _SettingsCard(
            children: [
              SettingListTile(
                icon: AppIcons.question_answer_rounded,
                title: 'FAQ',
                onTap: _showFaqScreen,
              ),
              _SettingDivider(),
              SettingListTile(
                icon: AppIcons.help_outline_rounded,
                title: 'Help & Support',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
              _SettingDivider(),
              SettingListTile(
                icon: AppIcons.support_agent_rounded,
                title: 'Contact via WhatsApp',
                onTap: _launchWhatsApp,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Logout ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoggingOut ? null : _logout,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.logout_rounded),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF192236) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF243050) : const Color(0xFFE8EDF7),
            width: 1,
          ),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 60,
      color: isDark ? const Color(0xFF243050) : const Color(0xFFE8EDF7),
    );
  }
}
