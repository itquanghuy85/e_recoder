import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_inspector.dart';
import '../marker/marker_settings.dart';
import '../marker/marker_spec.dart';
import '../marker/marker_timing.dart';
import '../record/rec_settings.dart';
import '../record/rec_settings_sheet.dart';
import 'purpose.dart';

/// How a tutorial gets its tap marks. [auto]: a clean recording, marks drawn afterwards at every tap.
/// [live]: the small dot, marks placed by hand while recording. [none]: a clean recording, no marks.
enum MarkWhen { auto, live, none }

MarkWhen markWhenOf(MarkerSettings m) => m.mode == MarkMode.dot
    ? MarkWhen.live
    : m.touchSource == TouchSource.auto
    ? MarkWhen.auto
    : MarkWhen.none;

MarkerSettings applyMarkWhen(MarkWhen w, MarkerSettings m) => switch (w) {
  MarkWhen.auto => m.copyWith(
    mode: MarkMode.clean,
    touchSource: TouchSource.auto,
  ),
  MarkWhen.live => m.copyWith(mode: MarkMode.dot, touchSource: TouchSource.off),
  MarkWhen.none => m.copyWith(
    mode: MarkMode.clean,
    touchSource: TouchSource.off,
  ),
};

/// The choices people change most, right on the Record screen for the chosen purpose, so nobody has to
/// open the settings. Every tap is saved at once (the settings providers write on `update`) and belongs
/// to that purpose: the next recording, and the next launch, starts from what was picked last.
class QuickOptions extends ConsumerWidget {
  const QuickOptions({super.key, required this.purpose});
  final Purpose purpose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final c = Theme.of(context).colorScheme;
    final rec = ref.watch(recSettingsProvider);
    final recN = ref.read(recSettingsProvider.notifier);
    final mk = ref.watch(markerSettingsProvider);
    final mkN = ref.read(markerSettingsProvider.notifier);
    final w = _Bits(context);
    final when = markWhenOf(mk);

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
            Wrap(
              children: [
                w.tick(
                  'quick_mic',
                  t.audioMic,
                  rec.mic,
                  (v) =>
                      recN.update(rec.copyWith(audio: _audio(v, rec.system))),
                ),
                w.tick(
                  'quick_system',
                  t.audioSystem,
                  rec.system,
                  (v) => recN.update(rec.copyWith(audio: _audio(rec.mic, v))),
                ),
              ],
            ),
            w.group(t.optResolution, [
              for (final r in Resolution.values)
                w.chip(
                  'quick_res_${r.name}',
                  resolutionLabel(t, r),
                  rec.resolution == r,
                  () => recN.update(rec.copyWith(resolution: r)),
                ),
            ]),
            if (purpose == Purpose.tutorial) ...[
              w.group(t.markWhenTitle, [
                for (final m in MarkWhen.values)
                  w.chip(
                    'quick_marks_${m.name}',
                    switch (m) {
                      MarkWhen.auto => t.markWhenAuto,
                      MarkWhen.live => t.markWhenLive,
                      MarkWhen.none => t.markWhenNone,
                    },
                    when == m,
                    () => mkN.update(applyMarkWhen(m, mk)),
                  ),
              ]),
              if (when != MarkWhen.none)
                Wrap(
                  children: [
                    w.tick(
                      'quick_auto_number',
                      t.autoNumberOpt,
                      mk.autoNumber,
                      (v) => mkN.update(mk.copyWith(autoNumber: v)),
                    ),
                    if (when == MarkWhen.auto)
                      w.tick(
                        'quick_auto_zoom',
                        t.autoZoomOpt,
                        mk.autoZoom,
                        (v) => mkN.update(mk.copyWith(autoZoom: v)),
                      ),
                  ],
                ),
            ],
            if (purpose == Purpose.game) ...[
              w.tick(
                'quick_smooth',
                t.optSmooth,
                rec.fps >= 60,
                (v) => recN.update(rec.copyWith(fps: v ? 60 : 30)),
              ),
              w.group(t.quickGameMark, [
                for (final m in MarkerType.values)
                  w.chip(
                    'quick_tool_${m.name}',
                    markerTypeLabel(t, m),
                    mk.tool == m,
                    () => mkN.update(mk.copyWith(tool: m)),
                    icon: markerTypeIcon(m),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rest of the purpose's settings, folded away under "More options". Like [QuickOptions], every
/// change is saved at once and belongs to the chosen purpose.
class MoreOptions extends ConsumerWidget {
  const MoreOptions({super.key, required this.purpose});
  final Purpose purpose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final rec = ref.watch(recSettingsProvider);
    final recN = ref.read(recSettingsProvider.notifier);
    final mk = ref.watch(markerSettingsProvider);
    final mkN = ref.read(markerSettingsProvider.notifier);
    final w = _Bits(context);

    final fps = w.group(t.optFps, [
      for (final v in const [30, 60])
        w.chip(
          'more_fps_$v',
          t.fpsValue(v),
          rec.fps == v,
          () => recN.update(rec.copyWith(fps: v)),
        ),
    ]);
    final quality = w.group(t.optQuality, [
      for (final q in Quality.values)
        w.chip(
          'more_quality_${q.name}',
          qualityLabel(t, q),
          rec.quality == q,
          () => recN.update(rec.copyWith(quality: q)),
        ),
    ]);
    final countdown = w.group(t.optCountdown, [
      for (final v in const [0, 3, 5])
        w.chip(
          'more_countdown_$v',
          v == 0 ? t.countdownOff : t.countdownSeconds(v),
          rec.countdown == v,
          () => recN.update(rec.copyWith(countdown: v)),
        ),
    ]);
    final floating = w.tick(
      'more_floating',
      t.optFloatingBar,
      rec.floatingBar,
      (v) => recN.update(rec.copyWith(floatingBar: v)),
    );

    final children = switch (purpose) {
      Purpose.tutorial => [
        if (markWhenOf(mk) == MarkWhen.auto)
          w.group(t.autoMarkerTitle, [
            for (final m in MarkerType.values)
              w.chip(
                'quick_mark_${m.name}',
                markerTypeLabel(t, m),
                mk.autoMarker == m,
                () => mkN.update(mk.copyWith(autoMarker: m)),
                icon: markerTypeIcon(m),
              ),
          ]),
        if (markWhenOf(mk) != MarkWhen.none)
          w.slider(
            'more_hold',
            t.markerHold,
            mk.holdMs,
            MarkerTiming.minHoldMs,
            MarkerTiming.maxHoldMs,
            (v) => mkN.update(mk.copyWith(holdMs: v)),
          ),
        if (markWhenOf(mk) == MarkWhen.auto)
          w.slider(
            'more_pause',
            t.pauseTitle,
            mk.pauseMs,
            0,
            1500,
            (v) => mkN.update(mk.copyWith(pauseMs: v)),
          ),
        fps,
        quality,
        countdown,
      ],
      Purpose.game => [floating, quality, countdown],
      Purpose.plain => [countdown, floating, fps, quality],
    };

    return Semantics(
      identifier: 'record_more',
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('record_more_${purpose.name}'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: Space.sm),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(t.moreOptions, style: tt.titleSmall),
          children: children,
        ),
      ),
    );
  }
}

/// Small building blocks shared by both option groups.
class _Bits {
  _Bits(this.context);
  final BuildContext context;

  TextTheme get _tt => Theme.of(context).textTheme;

  Widget group(String title, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _tt.labelLarge),
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
              Flexible(child: Text(label, style: _tt.bodyMedium)),
              const SizedBox(width: Space.sm),
            ],
          ),
        ),
      );

  /// A time in milliseconds, shown in seconds, in steps of 0.1 s.
  Widget slider(
    String id,
    String title,
    int ms,
    int min,
    int max,
    ValueChanged<int> on,
  ) {
    final secs = (ms / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return Semantics(
      identifier: id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: _tt.labelLarge)),
              Text('$secs s', style: _tt.labelLarge),
            ],
          ),
          Slider(
            key: ValueKey(id),
            value: ms.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) ~/ 100,
            onChanged: (v) => on(v.round()),
          ),
        ],
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
