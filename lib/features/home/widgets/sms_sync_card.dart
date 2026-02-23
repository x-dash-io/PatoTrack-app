import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final isGranted = permissionStatus.isGranted;
    final isPermanentlyDenied = permissionStatus.isPermanentlyDenied;
    final isSyncing = syncStatus == SyncStatus.syncing;

    final primaryLabel = isGranted
        ? 'Sync now'
        : isPermanentlyDenied
            ? 'Open settings'
            : 'Enable SMS import';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sms_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'M-Pesa SMS import',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(
                    label: _statusLabel(syncStatus),
                    color: _statusColor(syncStatus),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We only read M-Pesa messages after you enable import and tap sync. You can continue without permission and add transactions manually.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                lastSyncAt == null
                    ? 'Last sync: never'
                    : 'Last sync: ${DateFormat('MMM d, h:mm a').format(lastSyncAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (syncMessage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  syncMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: syncStatus == SyncStatus.error
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (isSyncing) ...[
                const SizedBox(height: AppSpacing.sm),
                const LinearProgressIndicator(minHeight: 4),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton.icon(
                    onPressed: isPermanentlyDenied
                        ? onOpenSettings
                        : (isSyncing ? null : onPrimaryAction),
                    icon: Icon(
                      isGranted ? Icons.sync_rounded : Icons.verified_user,
                    ),
                    label: Text(primaryLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: isSyncing ? null : onFallbackManual,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Add manually'),
                  ),
                  if (syncStatus == SyncStatus.error)
                    OutlinedButton.icon(
                      onPressed: isSyncing ? null : onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  if (isSyncing)
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.success:
        return 'Ready';
      case SyncStatus.error:
        return 'Issue';
      case SyncStatus.cancelled:
        return 'Cancelled';
      case SyncStatus.idle:
        return 'Idle';
    }
  }

  static Color _statusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.cancelled:
        return Colors.orange;
      case SyncStatus.idle:
        return Colors.grey;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
            ),
      ),
    );
  }
}
