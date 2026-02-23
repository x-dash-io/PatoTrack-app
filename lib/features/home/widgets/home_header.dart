import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../styles/app_spacing.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.user,
    required this.greeting,
  });

  final User user;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'there';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    displayName,
                    style: theme.textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Account avatar for $displayName',
              child: CircleAvatar(
                radius: 24,
                backgroundImage:
                    user.photoURL == null ? null : NetworkImage(user.photoURL!),
                child: user.photoURL == null
                    ? Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: theme.textTheme.titleMedium,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
