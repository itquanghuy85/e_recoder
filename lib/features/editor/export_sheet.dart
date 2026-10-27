import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/native_recorder.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../library/player_screen.dart';
import '../record/recorder_controller.dart';
import 'editor_controller.dart';
import 'export_presets.dart';

/// Export options, progress and result in one sheet.
Future<void> showExportSheet(
  BuildContext context,
  EditorController c, {
  Future<void> Function()? onSaveStill,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  isDismissible: c.exportState.phase != ExportPhase.running,
  enableDrag: c.exportState.phase != ExportPhase.running,
  builder: (_) => _ExportSheet(c: c, onSaveStill: onSaveStill),
);

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({required this.c, this.onSaveStill});
  final EditorController c;
  final Future<void> Function()? onSaveStill;

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  ExportQuality _q = ExportQuality.original;
  bool _gif = false;
  ExportPreset _preset = ExportPreset.custom;
  int? _cap;

  String _presetLabel(AppL10n t, ExportPreset p) => switch (p) {
    ExportPreset.custom => t.presetCustom,
    ExportPreset.youtube => t.presetYoutube,
    ExportPreset.vertical => t.presetVertical,
    ExportPreset.share => t.presetShare,
    ExportPreset.gif => t.presetGif,
  };

  void _pickPreset(ExportPreset p) {
    final spec = PresetSpec.of(p);
    setState(() {
      _preset = p;
      if (p != ExportPreset.custom) {
        _q = spec.quality;
        _gif = spec.gif;
        _cap = spec.maxBytes;
      } else {
        _cap = null;
      }
    });
    // The preset's shape goes into the project so the preview shows what will be exported.
    if (spec.aspect != null) widget.c.setAspect(spec.aspect!);
  }

  String _qLabel(AppL10n t, ExportQuality q) => switch (q) {
    ExportQuality.original => t.qualityOriginal,
    ExportQuality.p1080 => t.resolution1080,
    ExportQuality.p720 => t.resolution720,
    ExportQuality.p480 => t.resolution480,
  };

  /// The size the export will have, and a warning when a size cap cannot be met.
  List<Widget> _estimate(
    AppL10n t,
    TextTheme tt,
    ColorScheme cs,
    EditorController c,
  ) {
    final plan = c.planFor(_q, maxBytes: _cap);
    return [
      Text(
        t.exportEstimate(formatBytes(plan.estimatedBytes)),
        key: const ValueKey('export_estimate'),
        style: tt.bodyMedium,
      ),
      if (!plan.fitsCap)
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Text(
            t.exportCapMissed,
            style: tt.bodySmall?.copyWith(color: cs.error),
          ),
        ),
      if (_preset == ExportPreset.vertical)
        Text(
          t.presetVerticalNote,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      const SizedBox(height: Space.sm),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final c = widget.c;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.exportState;
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Space.lg,
              0,
              Space.lg,
              Space.xl + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.exportTitle, style: tt.titleLarge),
                const SizedBox(height: Space.sm),
                Text(
                  t.exportSummary(formatClock(c.project.outDurationMs)),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: Space.lg),
                if (s.phase == ExportPhase.idle ||
                    s.phase == ExportPhase.error) ...[
                  Text(t.exportPreset, style: tt.titleSmall),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    children: [
                      for (final p in ExportPreset.values)
                        Semantics(
                          identifier: 'preset_${p.name}',
                          child: ChoiceChip(
                            label: Text(_presetLabel(t, p)),
                            selected: _preset == p,
                            onSelected: (_) => _pickPreset(p),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  Text(t.exportFormat, style: tt.titleSmall),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    children: [
                      Semantics(
                        identifier: 'fmt_mp4',
                        child: ChoiceChip(
                          label: Text(t.formatMp4),
                          selected: !_gif,
                          onSelected: (_) => setState(() {
                            _gif = false;
                            _preset = ExportPreset.custom;
                            _cap = null;
                          }),
                        ),
                      ),
                      Semantics(
                        identifier: 'fmt_gif',
                        child: ChoiceChip(
                          label: Text(t.formatGif),
                          selected: _gif,
                          onSelected: (_) => setState(() {
                            _gif = true;
                            _preset = ExportPreset.custom;
                            _cap = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  if (!_gif) ...[
                    Text(t.exportQuality, style: tt.titleSmall),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      children: [
                        for (final q in ExportQuality.values)
                          Semantics(
                            identifier: 'quality_${q.name}',
                            child: ChoiceChip(
                              label: Text(_qLabel(t, q)),
                              selected: _q == q,
                              onSelected: (_) => setState(() {
                                _q = q;
                                if (_preset != ExportPreset.share) {
                                  _preset = ExportPreset.custom;
                                }
                              }),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                  ] else ...[
                    Text(
                      t.gifHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                  if (!_gif) ..._estimate(t, tt, cs, c),
                  if (widget.onSaveStill != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        identifier: 'export_still',
                        child: TextButton.icon(
                          onPressed: widget.onSaveStill,
                          icon: const Icon(Icons.photo_outlined),
                          label: Text(t.exportStill),
                        ),
                      ),
                    ),
                  if (s.phase == ExportPhase.error) ...[
                    Text(
                      t.exportError,
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                    ),
                    if (s.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: SelectableText(
                          '${s.errorCode}: ${s.errorMessage}',
                          key: const ValueKey('export_error_detail'),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: Space.md),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      identifier: 'export_start',
                      child: FilledButton.icon(
                        onPressed: () =>
                            c.startExport(_q, gif: _gif, maxBytes: _cap),
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(t.exportStart),
                      ),
                    ),
                  ),
                ] else if (s.phase == ExportPhase.running) ...[
                  Semantics(
                    identifier: 'export_progress',
                    label: t.exportRunning((s.progress * 100).round()),
                    child: LinearProgressIndicator(
                      value: s.progress == 0 ? null : s.progress,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    t.exportRunning((s.progress * 100).round()),
                    style: tt.bodyMedium,
                  ),
                  const SizedBox(height: Space.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: c.cancelExport,
                      child: Text(t.cancel),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: cs.tertiary),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(t.exportDone, style: tt.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${s.result!.name} · ${formatBytes(s.result!.size)}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: Space.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          c.dismissExport();
                          Navigator.of(context).pop();
                        },
                        child: Text(t.close),
                      ),
                      const SizedBox(width: Space.sm),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(nativeRecorderProvider)
                            .share(s.result!.uri),
                        icon: const Icon(Icons.share_outlined),
                        label: Text(t.menuShare),
                      ),
                      const SizedBox(width: Space.sm),
                      if (!s.result!.isGif)
                        Semantics(
                          identifier: 'export_view',
                          child: FilledButton(
                            onPressed: () {
                              final r = s.result!;
                              final entry = MediaEntry(
                                uri: r.uri,
                                name: r.name,
                                durationMs: r.durationMs,
                                size: r.size,
                                width: c.project.frameW,
                                height: c.project.frameH,
                                dateAdded: DateTime.now(),
                              );
                              c.dismissExport();
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PlayerScreen(entry: entry),
                                ),
                              );
                            },
                            child: Text(t.actionView),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
