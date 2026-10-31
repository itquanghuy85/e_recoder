import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell_provider.dart';
import '../../core/formatters.dart';
import '../../core/native_recorder.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../library/media_repository.dart';
import '../marker/marker_settings.dart';
import '../purpose/purpose.dart';
import '../purpose/purpose_screen.dart';
import '../purpose/ready_check_screen.dart';
import '../purpose/result_screen.dart';
import '../library/media_tile.dart';
import '../library/player_screen.dart';
import 'rec_settings.dart';
import 'rec_settings_sheet.dart';
import 'recorder_controller.dart';
import 'tally_rim.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  Future<void> _start() async {
    final t = AppL10n.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // With a purpose chosen, a missing permission is explained on its own screen before recording
    // starts, instead of failing after the tap.
    if (ref.read(purposeProvider) != null) {
      final rec = ref.read(recSettingsProvider);
      final needs = ReadyNeeds(
        mic: rec.mic || rec.system,
        overlay: rec.floatingBar || rec.countdown > 0,
      );
      if (await ReadyCheckScreen.missingAnything(ref, needs)) {
        if (!mounted) return;
        final go = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => ReadyCheckScreen(needs: needs),
          ),
        );
        if (go != true || !mounted) return;
      }
    }
    final r = await ref.read(recorderProvider.notifier).start();
    if (!mounted) return;
    final msg = switch (r) {
      StartResult.lowStorage => t.errLowStorage,
      StartResult.micDenied => t.errMic,
      StartResult.needsOverlay => t.errOverlay,
      StartResult.error => t.errStart,
      StartResult.ok || StartResult.declined => null,
    };
    if (msg != null) _snack(msg);
  }

  void _snack(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          action: action,
          // Float above the profile card + record button so the primary action stays reachable.
          margin: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 190),
        ),
      );
  }

  /// [result]: the three-choice screen shown after a recording; otherwise the plain player.
  Future<void> _openSaved(String uri, {bool result = false}) async {
    final list = await ref.read(mediaListProvider.future);
    final entry = list.where((e) => e.uri == uri).firstOrNull;
    if (entry != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              result ? ResultScreen(entry: entry) : PlayerScreen(entry: entry),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final state = ref.watch(recorderProvider);

    ref.listen<RecorderState>(recorderProvider, (prev, next) {
      final n = next.notice;
      if (n == null) return;
      switch (n) {
        case SavedNotice() when ref.read(purposeProvider) != null:
          // A purpose was chosen: show what came out, with Export now / Edit more / Record again.
          _openSaved(n.uri, result: true);
        case SavedNotice():
          _snack(
            t.savedSnack(n.name),
            action: SnackBarAction(
              label: t.actionView,
              onPressed: () => _openSaved(n.uri),
            ),
          );
        case ErrorNotice():
          _snack(switch (n.code) {
            'low_storage' => t.errLowStorage,
            'empty_recording' => t.errEmpty,
            'save_failed' => t.errSave,
            'capture_failed' => t.errCapture,
            _ => t.errStart,
          });
      }
      ref.read(recorderProvider.notifier).clearNotice();
    });

    final live =
        state.phase == RecPhase.recording || state.phase == RecPhase.paused;
    return TallyRim(
      live: live,
      paused: state.phase == RecPhase.paused,
      child: switch (state.phase) {
        RecPhase.idle => _IdleView(onStart: _start),
        _ => _LiveView(state: state),
      },
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final s = ref.watch(recSettingsProvider);
    final list = ref.watch(mediaListProvider);
    final purpose = ref.watch(purposeProvider);
    final summary = t.profileSummary(
      resolutionLabel(t, s.resolution),
      s.fps,
      qualityLabel(t, s.quality),
    );

    final profileCard = Semantics(
      identifier: 'profile_card',
      button: true,
      label: t.profileEdit,
      child: InkWell(
        key: const ValueKey('profile_card'),
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => showRecSettingsSheet(context),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(Radii.md),
            color: c.surfaceContainerLow,
          ),
          child: Row(
            children: [
              Icon(Icons.tune, color: c.onSurfaceVariant),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary, style: tt.titleSmall),
                    const SizedBox(height: Space.xs),
                    Text(
                      audioLabel(t, s.audio),
                      style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_less, color: c.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );

    // Scrolls when the content does not fit (very large system fonts, small screens); otherwise the
    // spacer keeps the profile card and the record button at the bottom, in the thumb zone.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.lg,
          Space.xl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight - Space.lg - Space.xl,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.appTitle, style: tt.headlineSmall),
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  const SizedBox(height: Space.sm),
                  Semantics(
                    identifier: 'ios_notice',
                    child: Text(t.iosNoRecording, style: tt.bodyMedium),
                  ),
                ],
                const SizedBox(height: Space.xl),
                Row(
                  children: [
                    Expanded(child: Text(t.recentTitle, style: tt.titleMedium)),
                    TextButton(
                      onPressed: () =>
                          ref.read(shellIndexProvider.notifier).go(1),
                      child: Text(t.seeAll),
                    ),
                  ],
                ),
                list.when(
                  data: (items) => items.isEmpty
                      ? Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            t.libraryEmptyBody,
                            style: tt.bodyMedium?.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final e in items.take(3))
                              MediaTile(
                                entry: e,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PlayerScreen(entry: e),
                                  ),
                                ),
                              ),
                          ],
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const Spacer(),
                const SizedBox(height: Space.lg),
                if (purpose == null) ...[
                  // Not chosen yet (the app was already in use): the old screen, plus an offer.
                  _PurposeOffer(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PurposeScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  profileCard,
                ],
                const SizedBox(height: Space.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('record_start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.onPrimary,
                      minimumSize: Size(
                        purpose == null ? 240 : double.infinity,
                        purpose == null ? 64 : 92,
                      ),
                      textStyle: purpose == null
                          ? tt.titleMedium
                          : tt.titleLarge,
                    ),
                    onPressed: onStart,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: Text(switch (purpose) {
                      Purpose.tutorial => t.recordTutorial,
                      Purpose.game => t.recordGame,
                      Purpose.plain => t.recordPlain,
                      null => t.recordStart,
                    }),
                  ),
                ),
                if (purpose != null) ...[
                  const SizedBox(height: Space.md),
                  // Everything else lives here, folded away, for the people who want it.
                  Semantics(
                    identifier: 'record_advanced',
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const ValueKey('record_advanced'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(t.advancedTitle, style: tt.titleSmall),
                        children: [
                          profileCard,
                          const SizedBox(height: Space.sm),
                          ListTile(
                            key: const ValueKey('change_purpose'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.swap_horiz),
                            title: Text(
                              t.advancedPurpose(_purposeName(t, purpose)),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PurposeScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveView extends ConsumerWidget {
  const _LiveView({required this.state});
  final RecorderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final bar = ref.watch(recSettingsProvider).floatingBar;
    final clean = ref.watch(markerSettingsProvider).mode == MarkMode.clean;
    final ctl = ref.read(recorderProvider.notifier);
    final paused = state.phase == RecPhase.paused;

    final status = switch (state.phase) {
      RecPhase.countdown => t.statusCountdown,
      RecPhase.saving => t.statusSaving,
      RecPhase.paused => t.statusPaused,
      _ => t.statusRecording,
    };

    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        children: [
          const Spacer(),
          if (state.phase == RecPhase.saving)
            const CircularProgressIndicator()
          else
            Semantics(
              liveRegion: false,
              label: '$status ${formatClock(state.elapsedMs)}',
              child: ExcludeSemantics(
                child: Text(
                  formatClock(state.elapsedMs),
                  style: timecodeStyle(context, size: 72),
                ),
              ),
            ),
          const SizedBox(height: Space.md),
          Text(
            status,
            style: tt.titleMedium?.copyWith(
              color: paused ? c.secondary : c.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.lg),
          if (state.phase == RecPhase.recording || paused)
            Text(
              !bar
                  ? t.recordingHintNoBar
                  : (clean ? t.recordingHintClean : t.recordingHint),
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          const Spacer(),
          if (state.phase == RecPhase.recording || paused)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Flexible: on a narrow phone the two buttons share the row instead of overflowing it.
                Flexible(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('live_pause'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 56),
                    ),
                    onPressed: paused ? ctl.resume : ctl.pause,
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    label: Text(paused ? t.recordResume : t.recordPause),
                  ),
                ),
                const SizedBox(width: Space.md),
                Flexible(
                  child: FilledButton.icon(
                    key: const ValueKey('live_stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.onPrimary,
                      minimumSize: const Size(120, 56),
                    ),
                    onPressed: ctl.stop,
                    icon: const Icon(Icons.stop),
                    label: Text(t.recordStop),
                  ),
                ),
              ],
            )
          else if (state.phase == RecPhase.countdown)
            OutlinedButton(onPressed: ctl.stop, child: Text(t.cancel)),
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}

String _purposeName(AppL10n t, Purpose p) => switch (p) {
  Purpose.tutorial => t.purposeTutorial,
  Purpose.game => t.purposeGame,
  Purpose.plain => t.purposePlain,
};

/// A card that offers the purpose question to someone who was using the app before it existed.
class _PurposeOffer extends StatelessWidget {
  const _PurposeOffer({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'purpose_offer',
      button: true,
      child: InkWell(
        key: const ValueKey('purpose_offer'),
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: c.secondaryContainer,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: c.onSecondaryContainer),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.purposeOffer,
                      style: tt.titleSmall?.copyWith(
                        color: c.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      t.purposeOfferSub,
                      style: tt.bodySmall?.copyWith(
                        color: c.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
