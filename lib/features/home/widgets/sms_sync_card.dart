import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../styles/app_colors.dart';
import '../../../styles/app_shadows.dart';
import '../../../styles/app_spacing.dart';
import '../controllers/home_controller.dart';

class SmsSyncCard extends StatelessWidget {
  const SmsSyncCard({
    super.key,
    required this.permissionStatus,
    required this.syncStatus,
    required this.syncMessage,
    required this.lastSyncAt,
    required this.onPrimaryAction,
    required this.onRetry,
    required this.onCancel,
    required this.onOpenSettings,
    required this.onFallbackManual,
  });

  final PermissionStatus permissionStatus;
  final SyncStatus syncStatus;
  final String? syncMessage;
  final DateTime? lastSyncAt;
  final VoidCallback onPrimaryAction;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onOpenSettings;
  final VoidCallback onFallbackManual;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGranted = permissionStatus.isGranted;
    final isPermanentlyDenied = permissionStatus.isPermanentlyDenied;
    final isSyncing = syncStatus == SyncStatus.syncing;

    final primaryLabel = isGranted
        ? 'Sync now'
        : isPermanentlyDenied
            ? 'Open settings'
            : 'Enable import';

    final bgColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppSpacing.radiusXl,
          border: Border.all(color: borderColor, width: 1),
          boxShadow: AppShadows.subtle(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // M-Pesa icon badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.brandSoftDark
                        : AppColors.brandSoft,
                    borderRadius: AppSpacing.radiusMd,
                  ),
                  child: Icon(
                    Icons.sms_rounded,
                    color: isDark ? AppColors.brandDark : AppColors.brand,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'M-Pesa SMS Import',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        lastSyncAt == null
                            ? 'Never synced'
                            : 'Last sync ${DateFormat('MMM d, h:mm a').format(lastSyncAt!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: syncStatus),
              ],
            ),

            if (syncMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                syncMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: syncStatus == SyncStatus.error
                          ? AppColors.expense
                          : null,
                    ),
              ),
            ],

            if (isSyncing) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppSpacing.radiusFull,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor:
                      isDark ? AppColors.surfaceBorderDark : AppColors.brandSoft,
                  color: AppColors.brand,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: isPermanentlyDenied
                          ? onOpenSettings
                          : (isSyncing ? null : onPrimaryAction),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(primaryLabel),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: isSyncing ? null : onFallbackManual,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Add manually'),
                    ),
                  ),
                ),
                if (syncStatus == SyncStatus.error) ...[
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    height: 38,
                    width: 38,
                    child: OutlinedButton(
                      onPressed: isSyncing ? null : onRetry,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ),
                ],
                if (isSyncing) ...[
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    height: 38,
                    width: 38,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SyncStatus.syncing => ('Syncing', AppColors.brand),
      SyncStatus.success => ('Ready', AppColors.income),
      SyncStatus.error => ('Issue', AppColors.expense),
      SyncStatus.cancelled => ('Cancelled', AppColors.warning),
      SyncStatus.idle => ('Idle', AppColors.neutral),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppSpacing.radiusFull,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
