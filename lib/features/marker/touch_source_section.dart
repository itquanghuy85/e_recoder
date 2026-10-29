import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../editor/touch_log.dart' show InputMode;
import '../record/recorder_controller.dart' show nativeRecorderProvider;
import 'marker_settings.dart';

/// Clean mode: how the editor finds out when you touched the screen, what happens to typing, and
/// the freeze that is put at each touch.
class TouchSourceSection extends ConsumerWidget {
  const TouchSourceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final s = ref.watch(markerSettingsProvider);
    final n = ref.read(markerSettingsProvider.notifier);
    final labels = {
      TouchSource.off: t.touchSourceOff,
      TouchSource.dots: t.touchSourceDots,
      TouchSource.manual: t.touchSourceManual,
    };
    final isAndroid = Platform.isAndroid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.sm),
        Text(t.touchSourceTitle, style: tt.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final src in TouchSource.values)
              if (src != TouchSource.dots || isAndroid)
                Semantics(
                  identifier: 'touch_source_${src.name}',
                  child: ChoiceChip(
                    label: Text(labels[src]!),
                    selected: s.touchSource == src,
                    onSelected: (_) =>
                        n.update(s.copyWith(touchSource: src)),
                  ),
                ),
          ],
        ),
        Text(
          t.touchSourceHint,
          style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        if (s.touchSource == TouchSource.dots)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('touch_guide_open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const TouchGuideDialog(),
              ),
              icon: const Icon(Icons.developer_mode),
              label: Text(t.touchGuideTitle),
            ),
          ),
        const SizedBox(height: Space.sm),
        Text(t.inputModeTitle, style: tt.titleSmall),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final (m, label) in [
              (InputMode.merge, t.inputModeMerge),
              (InputMode.perKey, t.inputModePerKey),
              (InputMode.skip, t.inputModeSkip),
            ])
              Semantics(
                identifier: 'input_mode_${m.name}',
                child: ChoiceChip(
                  label: Text(label),
                  selected: s.inputMode == m,
                  onSelected: (_) => n.update(s.copyWith(inputMode: m)),
                ),
              ),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 120, child: Text(t.pauseTitle, style: tt.labelLarge)),
            Expanded(
              child: Slider(
                key: const ValueKey('pause_ms'),
                value: s.pauseMs.toDouble(),
                min: 0,
                max: 1500,
                onChanged: (v) => n.update(s.copyWith(pauseMs: v.round())),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${(s.pauseMs / 1000).toStringAsFixed(1).replaceAll('.', ',')}s',
                style: tt.bodySmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 120, child: Text(t.pauseZoomTitle, style: tt.labelLarge)),
            Expanded(
              child: Slider(
                key: const ValueKey('pause_zoom'),
                value: s.pauseZoom,
                min: 1,
                max: 1.5,
                onChanged: (v) => n.update(
                  s.copyWith(pauseZoom: v < 1.1 ? 1.0 : v.clamp(1.2, 1.5)),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                s.pauseZoom < 1.1
                    ? '—'
                    : '${s.pauseZoom.toStringAsFixed(1).replaceAll('.', ',')}×',
                style: tt.bodySmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        Text(
          t.pauseHint,
          style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Three steps to turn on "show taps", each with a button that opens the right system page and a
/// live check of where the phone is now.
class TouchGuideDialog extends ConsumerStatefulWidget {
  const TouchGuideDialog({super.key});

  @override
  ConsumerState<TouchGuideDialog> createState() => _TouchGuideState();
}

class _TouchGuideState extends ConsumerState<TouchGuideDialog>
    with WidgetsBindingObserver {
  ({bool developer, bool showTaps})? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the system settings: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final v = await ref.read(nativeRecorderProvider).touchSetup();
      if (mounted) setState(() => _state = v);
    } catch (_) {
      // Unknown state: the steps still work, only the ticks are missing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final native = ref.read(nativeRecorderProvider);
    final st = _state;
    Widget status(bool? on, String yes, String no) => Row(
      children: [
        Icon(
          on == true ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
        ),
        const SizedBox(width: Space.xs),
        Expanded(child: Text(on == true ? yes : no, style: tt.bodySmall)),
      ],
    );
    return AlertDialog(
      title: Text(t.touchGuideTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.touchGuideStep1, style: tt.bodyMedium),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('guide_about'),
                onPressed: () => native.openSystemSettings('about'),
                child: Text(t.touchGuideAbout),
              ),
            ),
            Text(t.touchGuideStep2, style: tt.bodyMedium),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('guide_developer'),
                onPressed: () => native.openSystemSettings('developer'),
                child: Text(t.touchGuideDev),
              ),
            ),
            Text(t.touchGuideStep3, style: tt.bodyMedium),
            const SizedBox(height: Space.sm),
            status(st?.developer, t.touchGuideDevOn, t.touchGuideDevOff),
            status(st?.showTaps, t.touchGuideTapsOn, t.touchGuideTapsOff),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _check, child: Text(t.touchGuideRecheck)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
