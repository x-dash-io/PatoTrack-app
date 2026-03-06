import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../features/capture/services/sms_parser_service.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';
import '../styles/app_colors.dart';
import '../widgets/app_screen_background.dart';
import '../widgets/loading_widgets.dart';
import '../app_icons.dart';

class SmsCaptureScreen extends StatefulWidget {
  const SmsCaptureScreen({super.key});

  @override
  State<SmsCaptureScreen> createState() => _SmsCaptureScreenState();
}

enum _CaptureState { idle, loading, done, denied }

class _SmsCaptureScreenState extends State<SmsCaptureScreen> {
  final _smsParser = SmsParserService();
  final _dbHelper = DatabaseHelper();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  _CaptureState _state = _CaptureState.idle;

  int _imported = 0;
  int _skipped = 0;
  int _duplicates = 0;
  List<int> _lastBatchIds = [];

  @override
  void initState() {
    super.initState();
    _startCapture();
  }

  Future<void> _startCapture() async {
    setState(() => _state = _CaptureState.loading);

    final status = await Permission.sms.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _state = _CaptureState.denied);
      return;
    }

    if (_currentUser == null) {
      if (mounted) setState(() => _state = _CaptureState.idle);
      return;
    }

    await _importMessages();
  }

  Future<void> _importMessages() async {
    final query = SmsQuery();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    // Query only M-Pesa messages (matches SmsService approach) — avoids
    // reading the entire inbox.
    final mpesaMessages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      address: 'MPESA',
    );

    // Filter to last 30 days client-side (querySms doesn't support date filter)
    final recentMessages = mpesaMessages.where((msg) {
      final date = msg.dateSent ?? msg.date;
      return date != null && date.isAfter(cutoff);
    }).toList();


    int imported = 0;
    int skipped = 0;
    int duplicates = 0;
    final List<int> batchIds = [];

    for (final msg in recentMessages) {
      final body = msg.body;
      if (body == null || body.isEmpty) {
        skipped++;
        continue;
      }

      final date = msg.dateSent ?? msg.date ?? DateTime.now();
      final parsed = _smsParser.parseMpesa(body, date);

      if (parsed == null) {
        skipped++;
        continue;
      }

      // Duplicate detection: same amount + type within 24h
      final existing = await _dbHelper.getDuplicateSmsTransaction(
        _currentUser!.uid,
        parsed.amount,
        parsed.type,
        windowHours: 24,
      );

      if (existing != null) {
        duplicates++;
        continue;
      }

      // Save — M-Pesa SMS is always high confidence (auto-approved)
      final newId = await _dbHelper.addTransaction(
        parsed,
        _currentUser.uid,
      );
      batchIds.add(newId);
      imported++;
    }

    if (!mounted) return;

    setState(() {
      _imported = imported;
      _skipped = skipped;
      _duplicates = duplicates;
      _lastBatchIds = batchIds;
      _state = _CaptureState.done;
    });

    if (imported > 0) {
      // Offer undo for this import batch
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$imported transaction${imported == 1 ? '' : 's'} imported',
            style: GoogleFonts.manrope(),
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: _undoLastBatch,
          ),
        ),
      );
    }
  }

  Future<void> _undoLastBatch() async {
    if (_lastBatchIds.isEmpty || _currentUser == null) return;
    for (final id in _lastBatchIds) {
      await _dbHelper.deleteTransaction(id, _currentUser.uid);
    }
    if (!mounted) return;
    setState(() {
      _imported = 0;
      _lastBatchIds = [];
    });
    NotificationHelper.showSuccess(context, message: 'Import undone');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Import M-Pesa SMS',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      body: AppScreenBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildBody(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    switch (_state) {
      case _CaptureState.loading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModernLoadingIndicator(),
            const SizedBox(height: 20),
            Text(
              'Scanning your M-Pesa messages…',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case _CaptureState.denied:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.sms_failed_rounded,
                size: 64,
                color: AppColors.expense.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'SMS Permission Denied',
              style: GoogleFonts.manrope(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'PatoTrack needs SMS access to read your M-Pesa messages. Please grant permission in Settings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(AppIcons.settings_outlined),
              label: Text('Open Settings', style: GoogleFonts.manrope()),
            ),
          ],
        );

      case _CaptureState.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _imported > 0
                  ? AppIcons.check_circle_outline_rounded
                  : AppIcons.info_outline_rounded,
              size: 64,
              color: _imported > 0
                  ? AppColors.income
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              _imported > 0 ? 'Import Complete' : 'Nothing New',
              style: GoogleFonts.manrope(
                  fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _StatRow(
                label: 'Imported', value: _imported, color: AppColors.income),
            const SizedBox(height: 8),
            _StatRow(
                label: 'Duplicates (skipped)',
                value: _duplicates,
                color: AppColors.warning),
            const SizedBox(height: 8),
            _StatRow(
                label: 'Not M-Pesa (skipped)',
                value: _skipped,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary),
            if (_imported > 0) ...[
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _undoLastBatch,
                icon: const Icon(AppIcons.undo_rounded),
                label: Text('Undo Import', style: GoogleFonts.manrope()),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Done', style: GoogleFonts.manrope()),
            ),
          ],
        );

      case _CaptureState.idle:
        return const SizedBox.shrink();
    }
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          '$value',
          style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700, color: color, fontSize: 16),
        ),
      ],
    );
  }
}
