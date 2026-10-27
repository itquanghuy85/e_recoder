import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'rec_settings.dart';

String resolutionLabel(AppL10n t, Resolution r) => switch (r) {
  Resolution.p720 => t.resolution720,
  Resolution.p1080 => t.resolution1080,
  Resolution.native => t.resolutionNative,
};

String qualityLabel(AppL10n t, Quality q) => switch (q) {
  Quality.low => t.qualityLow,
  Quality.balanced => t.qualityBalanced,
  Quality.high => t.qualityHigh,
};

String audioLabel(AppL10n t, AudioMode a) => switch (a) {
  AudioMode.none => t.audioNone,
  AudioMode.mic => t.audioMic,
  AudioMode.system => t.audioSystem,
  AudioMode.both => t.audioBoth,
};

Future<void> showRecSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _RecSettingsSheet(),
    );

class _RecSettingsSheet extends ConsumerWidget {
  const _RecSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final s = ref.watch(recSettingsProvider);
    final n = ref.read(recSettingsProvider.notifier);

    Widget group<T>(
      String title,
      List<T> values,
      T selected,
      String Function(T) label,
      void Function(T) onTap,
      String Function(T) idOf,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tt.titleSmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final v in values)
                  Semantics(
                    identifier: idOf(v),
                    child: ChoiceChip(
                      label: Text(label(v)),
                      selected: v == selected,
                      onSelected: (_) => onTap(v),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      // useSafeArea leaves the bottom edge alone: keep the Close button above the navigation bar.
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        Space.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.profileTitle, style: tt.titleLarge)),
              Semantics(
                identifier: 'rec_reset',
                child: TextButton(
                  onPressed: () => n.update(const RecSettings()),
                  child: Text(t.resetDefaults),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          group<Resolution>(
            t.optResolution,
            Resolution.values,
            s.resolution,
            (v) => resolutionLabel(t, v),
            (v) => n.update(s.copyWith(resolution: v)),
            (v) => 'res_${v.name}',
          ),
          group<int>(
            t.optFps,
            const [30, 60],
            s.fps,
            (v) => t.fpsValue(v),
            (v) => n.update(s.copyWith(fps: v)),
            (v) => 'fps_$v',
          ),
          group<Quality>(
            t.optQuality,
            Quality.values,
            s.quality,
            (v) => qualityLabel(t, v),
            (v) => n.update(s.copyWith(quality: v)),
            (v) => 'quality_${v.name}',
          ),
          group<AudioMode>(
            t.optAudio,
            AudioMode.values,
            s.audio,
            (v) => audioLabel(t, v),
            (v) => n.update(s.copyWith(audio: v)),
            (v) => 'audio_${v.name}',
          ),
          group<int>(
            t.optCountdown,
            const [0, 3, 5],
            s.countdown,
            (v) => v == 0 ? t.countdownOff : t.countdownSeconds(v),
            (v) => n.update(s.copyWith(countdown: v)),
            (v) => 'countdown_$v',
          ),
          Semantics(
            identifier: 'floating_bar_switch',
            child: SwitchListTile(
              key: const ValueKey('floating_bar_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(t.optFloatingBar, style: tt.titleSmall),
              subtitle: Text(
                t.floatingBarHint,
                style: tt.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              value: s.floatingBar,
              onChanged: (v) => n.update(s.copyWith(floatingBar: v)),
            ),
          ),
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.close),
            ),
          ),
        ],
      ),
    );
  }
}
