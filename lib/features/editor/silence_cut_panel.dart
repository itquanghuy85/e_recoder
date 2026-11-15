import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'editor_controller.dart';

String _secs(int ms) =>
    '${(ms / 1000).toStringAsFixed(1).replaceAll('.', ',')}s';

/// One-tap cut of the quiet stretches: find them, review the list (with a shortest-length slider,
/// a small keep-at-each-end pad and the speed of the parts that stay), then cut in one undoable step.
/// Nothing happens without the person seeing how much of the video would go.
class SilenceCutPanel extends StatelessWidget {
  const SilenceCutPanel({super.key, required this.c});

  final EditorController c;

  Future<void> _apply(BuildContext context) async {
    final t = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final plan = c.silencePlan();
    if (plan.ranges == 0) {
      messenger?.showSnackBar(SnackBar(content: Text(t.silenceNoPick)));
      return;
    }
    final total = c.project.outDurationMs;
    final pct = total <= 0 ? 0 : ((plan.removedMs * 100) / total).round();
    // Cutting nearly everything, or leaving less than a second, is almost always a mistake: ask.
    if (plan.resultMs < 1000 || pct > 80) {
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(
            t.silenceHeavy(pct, _secs(plan.resultMs)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(t.silenceConfirm),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    final done = c.applySilenceCut();
    if (!context.mounted || done == null) return;
    messenger?.showSnackBar(
      SnackBar(content: Text(t.silenceDone(done.ranges))),
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
    final found = c.idleCandidates;
    final picked = c.pickedSilence;
    final last = c.lastSilenceCut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Semantics(
          identifier: 'silence_cut_panel',
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.silenceCutTitle, style: tt.titleSmall),
              const SizedBox(height: Space.xs),
              Text(
                t.silenceCutHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: c.findingSilence ? null : c.findSilence,
                    icon: c.findingSilence
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(
                      c.findingSilence ? t.silenceFinding : t.silenceFind,
                    ),
                  ),
                  if (found != null && found.isNotEmpty)
                    TextButton(
                      onPressed: c.pickAllSilence,
                      child: Text(t.silenceSelectAll),
                    ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(t.silenceThreshold, style: tt.labelLarge),
                  ),
                  Expanded(
                    child: Slider(
                      value: c.silenceMinMs.toDouble().clamp(500, 3000),
                      min: 500,
                      max: 3000,
                      divisions: 25,
                      label: _secs(c.silenceMinMs),
                      onChanged: (v) => c.setSilenceMin(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(_secs(c.silenceMinMs), style: tt.bodySmall),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t.silencePadOpt, style: tt.bodyMedium),
                value: c.silencePadMs > 0,
                onChanged: (v) => c.setSilencePad(v ? 200 : 0),
              ),
              Text(t.silenceKeepSpeed, style: tt.labelLarge),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final x in const [1.0, 2.0, 4.0, 8.0])
                    ChoiceChip(
                      label: Text('${x.toInt()}×'),
                      selected: (c.silenceKeepSpeed - x).abs() < 1e-9,
                      onSelected: (_) => c.setSilenceKeepSpeed(x),
                    ),
                ],
              ),
              if (found != null && found.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    t.silenceNone,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              if (found != null && found.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(t.silenceListTitle, style: tt.labelLarge),
                for (var i = 0; i < found.length; i++)
                  Builder(
                    builder: (context) {
                      final long =
                          found[i].endMs - found[i].startMs >= c.silenceMinMs;
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${_secs(found[i].startMs)} – ${_secs(found[i].endMs)}'
                          ' · ${_secs(found[i].endMs - found[i].startMs)}',
                          style: tt.bodyMedium,
                        ),
                        value: c.idlePicked.contains(i) && long,
                        onChanged: long ? (_) => c.toggleSilenceRange(i) : null,
                      );
                    },
                  ),
                Semantics(
                  identifier: 'silence_apply',
                  child: FilledButton.icon(
                    onPressed: picked.isEmpty
                        ? null
                        : () => _apply(context),
                    icon: const Icon(Icons.content_cut),
                    label: Text(t.silenceApply),
                  ),
                ),
              ],
              if (last != null)
                Semantics(
                  identifier: 'silence_last',
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      t.silenceDone(last.ranges),
                      style: tt.bodySmall?.copyWith(color: cs.onSurface),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
