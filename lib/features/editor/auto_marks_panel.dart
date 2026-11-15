import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_inspector.dart';
import 'editor_controller.dart';
import 'editor_tools.dart' show editorSecs;

/// Review list for the marks made by "find my taps". Shows which marks stand on a guessed place,
/// lets each one be turned off (and back on) with one undoable step, and offers to look for the
/// real places again or to undo the whole automatic pass.
class AutoMarksPanel extends StatelessWidget {
  const AutoMarksPanel({super.key, required this.c});

  final EditorController c;

  Future<void> _relocate(BuildContext context) async {
    final t = AppL10n.of(context);
    final m = ScaffoldMessenger.maybeOf(context);
    final n = await c.relocateEstimatedMarks();
    if (!context.mounted) return;
    m?.showSnackBar(
      SnackBar(
        content: Text(n > 0 ? t.autoMarksRelocated(n) : t.autoMarksNoRelocate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => _body(context),
  );

  Widget _body(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rows = c.reviewMarks;
    if (rows.isEmpty) return const SizedBox.shrink();
    final estimated = c.estimatedMarkCount;
    final parked = c.parkedAutoMarkCount;
    // The number of touches heard in the last pass; before one ran, every reviewed mark counts.
    final heard =
        c.lastTouches?.taps ?? c.project.autoHeard ?? rows.length - parked;

    return Semantics(
      identifier: 'auto_marks_panel',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(t.autoMarksTitle, style: tt.titleSmall),
          const SizedBox(height: Space.xs),
          Semantics(
            identifier: 'auto_marks_summary',
            liveRegion: true,
            child: Text(
              t.autoMarksSummary(heard, rows.length - parked, estimated),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: Space.sm),
          for (final m in rows)
            Semantics(
              identifier: 'auto_mark_${m.id}',
              child: InkWell(
                onTap: () => c.focusMark(m.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        markerTypeIcon(m.spec.type),
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${editorSecs(m.cueStartMs.toDouble())}'
                              ' · ${markerTypeLabel(t, m.spec.type)}',
                              style: tt.bodyMedium,
                            ),
                            if (m.estimated)
                              Text(
                                t.autoMarksEstimated,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.tertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: c.project.markers.any((e) => e.id == m.id),
                        // Turning a mark off takes it out of the video at once; the switch is also
                        // the way back, and both are a single undo step.
                        onChanged: (_) => c.toggleAutoMark(m.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              if (estimated > 0)
                OutlinedButton.icon(
                  onPressed: c.directing ? null : () => _relocate(context),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(t.autoMarksRelocate),
                ),
              if (estimated > 0)
                OutlinedButton.icon(
                  onPressed: c.directing ? null : c.removeEstimatedMarks,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(t.autoMarksRemoveEstimated),
                ),
              if (parked > 0)
                TextButton.icon(
                  onPressed: c.restoreParkedMarks,
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text(t.autoMarksRestoreAll),
                ),
              if (c.canUndo)
                TextButton(
                  onPressed: c.undo,
                  child: Text(t.autoMarksUndo),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
