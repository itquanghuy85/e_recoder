import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/native_recorder.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'video_thumb.dart';

/// One recording row: thumbnail, name + meta, right-aligned tabular duration.
/// In selection mode [selectionNumber] shows the pick order (null = not picked).
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.selecting = false,
    this.selectionNumber,
  });
  final MediaEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selecting;
  final int? selectionNumber;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final picked = selectionNumber != null;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        decoration: BoxDecoration(
          color: picked ? c.tertiaryContainer.withValues(alpha: 0.5) : null,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            if (selecting) ...[
              SizedBox(
                width: 28,
                height: 28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: picked ? c.tertiary : Colors.transparent,
                    border: Border.all(
                      color: picked ? c.tertiary : c.outline,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: picked
                        ? Text(
                            '$selectionNumber',
                            style: tt.labelMedium?.copyWith(
                              color: c.onTertiary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
            ],
            VideoThumb(uri: entry.uri),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: tt.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    t.videoMeta(
                      formatDate(entry.dateAdded),
                      formatBytes(entry.size),
                    ),
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            // Scales down rather than overflowing at very large system font sizes.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatClock(entry.durationMs),
                  style: timecodeStyle(context, size: 16),
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const SizedBox(width: Space.sm),
          ],
        ),
      ),
    );
  }
}
