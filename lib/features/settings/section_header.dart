import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Title of a group on a settings screen: what the group is and what it is for, in one line, so a new
/// person can tell where a setting lives before opening anything.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.sub,
    this.icon,
    this.step,
  });

  final String title;

  /// One line saying what the group is for.
  final String? sub;
  final IconData? icon;

  /// Position in a sequence ("1" of the marker steps), drawn in a small badge.
  final int? step;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step != null || icon != null) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: c.primaryContainer,
              child: step != null
                  ? Text(
                      '$step',
                      style: tt.labelLarge?.copyWith(
                        color: c.onPrimaryContainer,
                      ),
                    )
                  : Icon(icon, size: 16, color: c.onPrimaryContainer),
            ),
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: tt.titleMedium),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
