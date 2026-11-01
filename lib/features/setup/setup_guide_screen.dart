import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions_gateway.dart';
import '../../core/platform_support.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../record/recorder_controller.dart';

/// Where the phone stands for what the recorder needs. null = could not be read.
class SetupStatus {
  const SetupStatus({
    this.overlay,
    this.mic,
    this.notifications,
    this.developer,
    this.showTaps,
  });
  final bool? overlay;
  final bool? mic;
  final bool? notifications;
  final bool? developer;
  final bool? showTaps;

  /// Steps that are really off: the three permissions the recorder asks for.
  int get missing =>
      [overlay, mic, notifications].where((v) => v == false).length;
}

/// Read again whenever the guide or the Record screen comes back from the system settings.
final setupStatusProvider = FutureProvider.autoDispose<SetupStatus>((
  ref,
) async {
  final native = ref.read(nativeRecorderProvider);
  final perms = ref.read(permissionsGatewayProvider);
  Future<T?> safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  final setup = await safe(native.touchSetup);
  return SetupStatus(
    overlay: await safe(native.canOverlay),
    mic: await safe(perms.micGranted),
    notifications: await safe(perms.notificationsGranted),
    developer: setup?.developer,
    showTaps: setup?.showTaps,
  );
});

/// "Set up to use every feature": each step says what the person gets, how to turn it on, and whether it
/// is on. On iPhone it says what works and what is Android only instead.
class SetupGuideScreen extends ConsumerStatefulWidget {
  const SetupGuideScreen({super.key});

  @override
  ConsumerState<SetupGuideScreen> createState() => _SetupGuideState();
}

class _SetupGuideState extends ConsumerState<SetupGuideScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system settings: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.invalidate(setupStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(isIOS ? t.iosGuideTitle : t.setupTitle)),
      body: isIOS ? const _IosGuide() : const _AndroidGuide(),
    );
  }
}

class _AndroidGuide extends ConsumerWidget {
  const _AndroidGuide();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final native = ref.read(nativeRecorderProvider);
    final perms = ref.read(permissionsGatewayProvider);
    final st = ref.watch(setupStatusProvider).value ?? const SetupStatus();
    void recheck() => ref.invalidate(setupStatusProvider);

    return SingleChildScrollView(
      key: const ValueKey('setup_guide'),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.setupIntro, style: tt.bodyMedium),
          const SizedBox(height: Space.lg),
          _StepCard(
            id: 'overlay',
            icon: Icons.layers_outlined,
            title: t.permOverlayTitle,
            on: st.overlay,
            tag: t.setupRecommended,
            get: t.setupOverlayGet,
            how: t.setupOverlayHow,
            pictures: [
              ('assets/guide/result_cue.png', t.setupPicCue),
              ('assets/guide/result_mark.png', t.setupPicMark),
            ],
            actions: [
              _Act('setup_overlay_on', t.setupTurnOn, () async {
                await native.requestOverlay();
                recheck();
              }),
            ],
          ),
          _StepCard(
            id: 'mic',
            icon: Icons.mic_none,
            title: t.permMicTitle,
            on: st.mic,
            tag: t.setupRecommended,
            get: t.setupMicGet,
            how: t.setupMicHow,
            actions: [
              _Act('setup_mic_on', t.setupTurnOn, () async {
                if (!await perms.requestMic()) await perms.openSettings();
                recheck();
              }),
            ],
          ),
          _StepCard(
            id: 'notif',
            icon: Icons.notifications_none,
            title: t.permNotifTitle,
            on: st.notifications,
            tag: t.setupRecommended,
            get: t.setupNotifGet,
            how: t.setupNotifHow,
            actions: [
              _Act('setup_notif_on', t.setupTurnOn, () async {
                if (!await perms.requestNotifications()) {
                  await perms.openSettings();
                }
                recheck();
              }),
            ],
          ),
          _StepCard(
            id: 'taps',
            icon: Icons.touch_app_outlined,
            title: t.setupTapsTitle,
            on: st.showTaps,
            tag: t.setupOptional,
            get: t.setupTapsGet,
            how:
                '${t.touchGuideStep1}\n${t.touchGuideStep2}\n${t.setupTapsName}',
            pictures: [('assets/guide/result_mark.png', t.setupPicMark)],
            lines: [
              (st.developer, t.touchGuideDevOn, t.touchGuideDevOff),
              (st.showTaps, t.touchGuideTapsOn, t.touchGuideTapsOff),
            ],
            actions: [
              _Act(
                'setup_taps_about',
                t.touchGuideAbout,
                () => native.openSystemSettings('about'),
              ),
              _Act(
                'setup_taps_dev',
                t.touchGuideDev,
                () => native.openSystemSettings('developer'),
              ),
              _Act(
                'setup_taps_check',
                t.touchGuideRecheck,
                () async => recheck(),
              ),
            ],
          ),
          _StepCard(
            id: 'battery',
            icon: Icons.battery_charging_full,
            title: t.permBatteryTitle,
            on: null,
            tag: t.setupOptional,
            get: t.setupBatteryGet,
            how: t.setupBatteryHow,
            actions: [
              _Act('setup_battery_on', t.permOpenSettings, perms.openSettings),
            ],
          ),
        ],
      ),
    );
  }
}

class _Act {
  const _Act(this.id, this.label, this.run);
  final String id;
  final String label;
  final Future<void> Function() run;
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.on,
    required this.tag,
    required this.get,
    required this.how,
    required this.actions,
    this.pictures = const [],
    this.lines = const [],
  });
  final String id;
  final IconData icon;
  final String title;

  /// null: not known or not a switch.
  final bool? on;
  final String tag;
  final String get;
  final String how;
  final List<_Act> actions;

  /// (asset, caption): frames of a real recording showing the result.
  final List<(String, String)> pictures;

  /// (state, text when on, text when off): extra status lines.
  final List<(bool?, String, String)> lines;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'setup_step_$id',
      child: Card(
        key: ValueKey('setup_step_$id'),
        margin: const EdgeInsets.only(bottom: Space.md),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: cs.primary),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(title, style: tt.titleMedium)),
                  if (on != null)
                    Chip(
                      key: ValueKey('setup_state_$id'),
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        on! ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: on! ? cs.primary : cs.outline,
                      ),
                      label: Text(on! ? t.setupOn : t.setupOff),
                    ),
                ],
              ),
              Text(
                tag,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (pictures.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in pictures)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(Radii.sm),
                                child: Image.asset(
                                  p.$1,
                                  fit: BoxFit.cover,
                                  semanticLabel: p.$2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.$2,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Space.sm),
              Text(t.setupGetTitle, style: tt.labelLarge),
              Text(get, style: tt.bodyMedium),
              const SizedBox(height: Space.sm),
              Text(t.setupHowTitle, style: tt.labelLarge),
              Text(how, style: tt.bodyMedium),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Row(
                    children: [
                      Icon(
                        l.$1 == true
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: Text(
                          l.$1 == true ? l.$2 : l.$3,
                          style: tt.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final a in actions)
                    Semantics(
                      identifier: a.id,
                      child: FilledButton.tonal(
                        key: ValueKey(a.id),
                        onPressed: a.run,
                        child: Text(a.label),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosGuide extends StatelessWidget {
  const _IosGuide();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('setup_guide_ios'),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: cs.primary),
                      const SizedBox(width: Space.sm),
                      Text(t.iosCanTitle, style: tt.titleMedium),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(t.iosCanBody, style: tt.bodyMedium),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AndroidBadge(),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(t.iosOnlyTitle, style: tt.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(t.iosOnlyBody, style: tt.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// On the Record screen (Android): how many steps are still off, and a way into the guide.
class SetupBanner extends ConsumerStatefulWidget {
  const SetupBanner({super.key});

  @override
  ConsumerState<SetupBanner> createState() => _SetupBannerState();
}

class _SetupBannerState extends ConsumerState<SetupBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.invalidate(setupStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (isIOS) return const SizedBox.shrink();
    final n = ref.watch(setupStatusProvider).value?.missing ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Semantics(
        identifier: 'setup_banner',
        child: Material(
          key: const ValueKey('setup_banner'),
          color: cs.tertiaryContainer,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SetupGuideScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Row(
                children: [
                  Icon(Icons.checklist, color: cs.onTertiaryContainer),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.setupBannerTitle(n),
                          style: tt.titleSmall?.copyWith(
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                        Text(
                          t.setupBannerSub,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    t.setupBannerOpen,
                    style: tt.labelLarge?.copyWith(
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
