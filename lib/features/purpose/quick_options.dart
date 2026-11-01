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
              if (when != MarkWhen.none) w.holdSlider(t, mk, mkN),
              if (when == MarkWhen.auto && mk.autoZoom)
                w.slider(
                  'quick_zoom_scale',
                  t.zoomScale,
                  '${(mk.zoomScale * 100).round()}%',
                  mk.zoomScale * 100,
                  120,
                  300,
                  18,
                  (v) => mkN.update(mk.copyWith(zoomScale: v.round() / 100)),
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
              w.holdSlider(t, mk, mkN),
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
        if (markWhenOf(mk) == MarkWhen.auto)
          w.slider(
            'more_pause',
            t.pauseTitle,
            _secs(mk.pauseMs),
            mk.pauseMs.toDouble(),
            0,
            1500,
            15,
            (v) => mkN.update(mk.copyWith(pauseMs: v.round())),
          ),
        if (markWhenOf(mk) == MarkWhen.auto && mk.autoZoom) ...[
          w.slider(
            'more_zoom_ramp',
            t.zoomIn,
            _secs(mk.zoomRampMs),
            mk.zoomRampMs.toDouble(),
            100,
            2000,
            19,
            (v) => mkN.update(mk.copyWith(zoomRampMs: v.round())),
          ),
          w.slider(
            'more_zoom_hold',
            t.zoomHold,
            _secs(mk.zoomHoldMs),
            mk.zoomHoldMs.toDouble(),
            0,
            5000,
            50,
            (v) => mkN.update(mk.copyWith(zoomHoldMs: v.round())),
          ),
        ],
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

  /// A slider with its value written at the right: [text] is what is shown, [value] runs from [min] to
  /// [max] in [divisions] steps.
  Widget slider(
    String id,
    String title,
    String text,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> on,
  ) => Semantics(
    identifier: id,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: _tt.labelLarge)),
            Text(text, style: _tt.labelLarge),
          ],
        ),
        Slider(
          key: ValueKey(id),
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: on,
        ),
      ],
    ),
  );

  /// How long a mark stays on screen (0.5 to 10 s): the marks drawn by hand and the automatic ones.
  Widget holdSlider(
    AppL10n t,
    MarkerSettings mk,
    MarkerSettingsNotifier n,
  ) => slider(
    'quick_hold',
    t.holdTitle,
    _secs(mk.holdMs),
    mk.holdMs.toDouble(),
    MarkerTiming.minHoldMs.toDouble(),
    MarkerTiming.maxHoldMs.toDouble(),
    (MarkerTiming.maxHoldMs - MarkerTiming.minHoldMs) ~/ 100,
    (v) => n.update(mk.copyWith(holdMs: v.round())),
  );
}

/// Milliseconds as seconds with a comma, like "2,5 s".
String _secs(int ms) => '${(ms / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';

AudioMode _audio(bool mic, bool system) => mic && system
    ? AudioMode.both
    : mic
    ? AudioMode.mic
    : system
    ? AudioMode.system
    : AudioMode.none;
