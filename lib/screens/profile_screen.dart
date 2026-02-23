import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          prefixIcon: Icons.person_outline,
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

    return Scaffold(
      body: AppScreenBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (currentUser != null)
              Container(
                width: double.infinity,
                padding: ResponsiveHelper.edgeInsets(context, 32, 24, 32, 24),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  boxShadow: AppShadows.subtle(colorScheme.primary),
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
                              color: colorScheme.surface,
                              boxShadow: const [AppShadows.elevated],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              radius: ResponsiveHelper.width(context, 56),
                              backgroundImage: (currentUser!.photoURL != null)
                                  ? CachedNetworkImageProvider(
                                      currentUser!.photoURL!,
                                    )
                                  : null,
                              backgroundColor: colorScheme.primary,
                              child: (currentUser!.photoURL == null)
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: ResponsiveHelper.iconSize(
                                          context, 60),
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
                              padding:
                                  ResponsiveHelper.edgeInsetsAll(context, 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [AppShadows.card],
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
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                              child: const CircularProgressIndicator(
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
                            style: GoogleFonts.manrope(
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
                            borderRadius: BorderRadius.circular(
                                ResponsiveHelper.radius(context, 12)),
                            child: Container(
                              padding:
                                  ResponsiveHelper.edgeInsetsAll(context, 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.radius(context, 12)),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: const [AppShadows.card],
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
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                        Flexible(
                          child: Text(
                            currentUser!.email ?? 'No email',
                            style: GoogleFonts.manrope(
                              fontSize: ResponsiveHelper.fontSize(context, 14),
                              color: colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.85),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'App Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SettingListTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      trailing: Switch(
                        value: themeProvider.themeMode == ThemeMode.dark,
                        onChanged: (value) => themeProvider.toggleTheme(value),
                      ),
                    ),
                    Divider(
                        height: 1,
                        indent: 60,
                        color: colorScheme.outline.withValues(alpha: 0.1)),
                    SettingListTile(
                      icon: Icons.lock_rounded,
                      title: 'Passcode Lock',
                      subtitle: 'Secure your app with a passcode',
                      trailing: Switch(
                        value: _isPasscodeEnabled,
                        onChanged: (value) async {
                          if (value) {
                            final navigator = Navigator.of(context);
                            final success =
                                await navigator.push<bool>(MaterialPageRoute(
                              builder: (context) =>
                                  const PasscodeScreen(isSettingPasscode: true),
                            ));
                            if (success == true && mounted) {
                              setState(() => _isPasscodeEnabled = true);
                            }
                          } else {
                            final navigator = Navigator.of(context);
                            final success =
                                await navigator.push<bool>(MaterialPageRoute(
                              builder: (context) => const PasscodeScreen(
                                isSettingPasscode: false,
                              ),
                            ));
                            if (success == true && mounted) {
                              await _passcodeService.clearPasscode();
                              setState(() => _isPasscodeEnabled = false);
                            }
                          }
                        },
                      ),
                    ),
                    if (_isPasscodeEnabled) ...[
                      Divider(
                          height: 1,
                          indent: 60,
                          color: colorScheme.outline.withValues(alpha: 0.1)),
                      SettingListTile(
                        icon: Icons.phonelink_lock_rounded,
                        title: 'Change Passcode',
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final verified =
                              await navigator.push<bool>(MaterialPageRoute(
                            builder: (context) =>
                                const PasscodeScreen(isSettingPasscode: false),
                          ));
                          if (verified != true || !mounted) return;
                          await navigator.push<bool>(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PasscodeScreen(isSettingPasscode: true),
                            ),
                          );
                        },
                      ),
                    ],
                    Divider(
                        height: 1,
                        indent: 60,
                        color: colorScheme.outline.withValues(alpha: 0.1)),
                    SettingListTile(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Currency',
                      trailing: DropdownButton<String>(
                        value: currencyProvider.code,
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
                        items: currencyProvider.options
                            .map<DropdownMenuItem<String>>(
                                (option) => DropdownMenuItem<String>(
                                      value: option.code,
                                      child: Text(
                                        '${option.symbol} · ${option.code}',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ))
                            .toList(),
                        selectedItemBuilder: (BuildContext context) {
                          return currencyProvider.options.map<Widget>((option) {
                            return Text(
                              option.symbol,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            );
                          }).toList();
                        },
                        onChanged: (String? newValue) {
                          if (newValue != null && mounted) {
                            currencyProvider.setCurrency(newValue);
                            NotificationHelper.showSuccess(
                              context,
                              message: 'Currency updated app-wide.',
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'Account',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SettingListTile(
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
                      onTap: _isSendingPasswordReset
                          ? null
                          : _sendPasswordResetEmail,
                    ),
                    Divider(
                        height: 1,
                        indent: 60,
                        color: colorScheme.outline.withValues(alpha: 0.1)),
                    SettingListTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete Account',
                      titleColor: Colors.red,
                      iconColor: Colors.red,
                      trailing: _isDeletingAccount
                          ? const SizedBox(
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'Data & Sync',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.cloud_sync_rounded,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Cloud Sync',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _cloudSyncStatusColor(colorScheme)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _cloudSyncStatusLabel(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _cloudSyncStatusColor(colorScheme),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _cloudRestoreSubtitle(),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                _cloudSyncStatus == CloudSyncStatus.syncing
                                    ? null
                                    : _handleRestore,
                            icon: const Icon(Icons.sync_rounded),
                            label: Text(
                              _cloudSyncStatus == CloudSyncStatus.error
                                  ? 'Retry'
                                  : 'Sync now',
                            ),
                          ),
                          if (_cloudSyncStatus == CloudSyncStatus.syncing)
                            OutlinedButton.icon(
                              onPressed: _cancelRestore,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'Help & Support',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SettingListTile(
                      icon: Icons.question_answer_rounded,
                      title: 'FAQ',
                      onTap: _showFaqScreen,
                    ),
                    Divider(
                        height: 1,
                        indent: 60,
                        color: colorScheme.outline.withValues(alpha: 0.1)),
                    SettingListTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const HelpScreen()),
                        );
                      },
                    ),
                    Divider(
                        height: 1,
                        indent: 60,
                        color: colorScheme.outline.withValues(alpha: 0.1)),
                    SettingListTile(
                      icon: Icons.support_agent_rounded,
                      title: 'Contact via WhatsApp',
                      onTap: _launchWhatsApp,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
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
                    style: GoogleFonts.manrope(
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
    );
  }
}
