import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_inspector.dart';
import '../marker/marker_settings.dart';
import '../marker/marker_spec.dart';
import '../record/rec_settings.dart';
import '../record/rec_settings_sheet.dart';
import 'purpose.dart';

/// The choices people change most, right on the Record screen for the chosen purpose, so nobody has to
/// open the settings. Every tap is saved at once (the settings providers write on `update`), so the
/// next recording, and the next launch, starts from what was picked last.
class QuickOptions extends ConsumerWidget {
  const QuickOptions({super.key, required this.purpose});
  final Purpose purpose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final rec = ref.watch(recSettingsProvider);
    final recN = ref.read(recSettingsProvider.notifier);
    final mk = ref.watch(markerSettingsProvider);
    final mkN = ref.read(markerSettingsProvider.notifier);

    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tt.labelLarge),
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.sm, runSpacing: Space.xs, children: chips),
        ],
      ),
    );

    Widget chip(
      String id,
      String label,
      bool selected,
      VoidCallback onTap, {
      IconData? icon,
    }) => Semantics(
      identifier: id,
      child: ChoiceChip(
        key: ValueKey(id),
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );

    Widget tick(String id, String label, bool value, ValueChanged<bool> on) =>
        Semantics(
          identifier: id,
          child: InkWell(
            key: ValueKey(id),
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => on(!value),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: value,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => on(v ?? false),
                ),
                Flexible(child: Text(label, style: tt.bodyMedium)),
                const SizedBox(width: Space.sm),
              ],
            ),
          ),
        );

    return Material(
      key: const ValueKey('quick_options'),
      color: c.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.quickTitle, style: tt.titleSmall),
            const SizedBox(height: Space.sm),
            tick(
              'quick_mic',
              t.audioMic,
              rec.mic,
              (v) => recN.update(rec.copyWith(audio: _audio(v, rec.system))),
            ),
            tick(
              'quick_system',
              t.audioSystem,
              rec.system,
              (v) => recN.update(rec.copyWith(audio: _audio(rec.mic, v))),
            ),
            group(t.optResolution, [
              for (final r in Resolution.values)
                chip(
                  'quick_res_${r.name}',
                  resolutionLabel(t, r),
                  rec.resolution == r,
                  () => recN.update(rec.copyWith(resolution: r)),
                ),
            ]),
            if (purpose == Purpose.tutorial) ...[
              group(t.autoMarkerTitle, [
                for (final m in MarkerType.values)
                  chip(
                    'quick_mark_${m.name}',
                    markerTypeLabel(t, m),
                    mk.autoMarker == m,
                    () => mkN.update(mk.copyWith(autoMarker: m)),
                    icon: markerTypeIcon(m),
                  ),
              ]),
              Wrap(
                children: [
                  tick(
                    'quick_touches',
                    t.quickTouches,
                    mk.touchSource == TouchSource.auto,
                    (v) => mkN.update(
                      mk.copyWith(
                        mode: v ? MarkMode.clean : MarkMode.dot,
                        touchSource: v ? TouchSource.auto : TouchSource.off,
                      ),
                    ),
                  ),
                  tick(
                    'quick_auto_number',
                    t.autoNumberOpt,
                    mk.autoNumber,
                    (v) => mkN.update(mk.copyWith(autoNumber: v)),
                  ),
                  tick(
                    'quick_auto_zoom',
                    t.autoZoomOpt,
                    mk.autoZoom,
                    (v) => mkN.update(mk.copyWith(autoZoom: v)),
                  ),
                ],
              ),
            ],
            if (purpose == Purpose.game)
              group(t.quickGameMark, [
                for (final m in MarkerType.values)
                  chip(
                    'quick_tool_${m.name}',
                    markerTypeLabel(t, m),
                    mk.tool == m,
                    () => mkN.update(mk.copyWith(tool: m)),
                    icon: markerTypeIcon(m),
                  ),
              ]),
          ],
        ),
      ),
    );
  }
}

AudioMode _audio(bool mic, bool system) => mic && system
    ? AudioMode.both
    : mic
    ? AudioMode.mic
    : system
    ? AudioMode.system
    : AudioMode.none;
