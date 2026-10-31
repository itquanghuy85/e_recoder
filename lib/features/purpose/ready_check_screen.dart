import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../record/recorder_controller.dart' show nativeRecorderProvider;

/// What the recorder needs, as the screen asks for it: [mic] when sound is recorded, [overlay] for the
/// floating bar, the countdown and listening to taps. Notifications are only a convenience.
class ReadyNeeds {
  const ReadyNeeds({required this.mic, required this.overlay});
  final bool mic;
  final bool overlay;
}

/// Lists the permissions still missing, each with a button that goes to where it is switched on, and
/// pops `true` when the person taps "Ready to record". It is only shown when something is missing.
class ReadyCheckScreen extends ConsumerStatefulWidget {
  const ReadyCheckScreen({super.key, required this.needs});
  final ReadyNeeds needs;

  /// True when something needed is not granted yet (the screen would have something to show).
  static Future<bool> missingAnything(WidgetRef ref, ReadyNeeds needs) async {
    final perms = ref.read(permissionsGatewayProvider);
    if (needs.mic && !await perms.micGranted()) return true;
    if (needs.overlay && !await ref.read(nativeRecorderProvider).canOverlay()) {
      return true;
    }
    return false;
  }

  @override
  ConsumerState<ReadyCheckScreen> createState() => _ReadyCheckScreenState();
}

class _ReadyCheckScreenState extends ConsumerState<ReadyCheckScreen>
    with WidgetsBindingObserver {
  bool _mic = false;
  bool _overlay = false;
  bool _notif = false;
  bool _micAsked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system settings: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final perms = ref.read(permissionsGatewayProvider);
    final mic = await perms.micGranted();
    final notif = await perms.notificationsGranted();
    final overlay = await ref.read(nativeRecorderProvider).canOverlay();
    if (!mounted) return;
    setState(() {
      _mic = mic;
      _notif = notif;
      _overlay = overlay;
    });
  }

  Future<void> _enableMic() async {
    final perms = ref.read(permissionsGatewayProvider);
    // The first time the system asks; after a refusal only the app's settings page can switch it on.
    if (_micAsked) {
      await perms.openSettings();
    } else {
      _micAsked = true;
      await perms.requestMic();
    }
    await _refresh();
  }

  Future<void> _enableNotif() async {
    await ref.read(permissionsGatewayProvider).requestNotifications();
    await _refresh();
  }

  Future<void> _enableOverlay() =>
      ref.read(nativeRecorderProvider).requestOverlay();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final n = widget.needs;
    final ready = (!n.mic || _mic) && (!n.overlay || _overlay);
    final rows = <_Row>[
      if (n.mic)
        _Row(
          'mic',
          Icons.mic_none,
          t.readyMic,
          t.readyMicSub,
          _mic,
          _enableMic,
        ),
      if (n.overlay)
        _Row(
          'overlay',
          Icons.layers_outlined,
          t.readyOverlay,
          t.readyOverlaySub,
          _overlay,
          _enableOverlay,
        ),
      _Row(
        'notif',
        Icons.notifications_none,
        t.readyNotif,
        t.readyNotifSub,
        _notif,
        _enableNotif,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t.readyTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      t.readyHint,
                      style: tt.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: Space.lg),
                    for (final r in rows) ...[
                      Container(
                        padding: const EdgeInsets.all(Space.md),
                        decoration: BoxDecoration(
                          border: Border.all(color: c.outlineVariant),
                          borderRadius: BorderRadius.circular(Radii.md),
                          color: c.surfaceContainerLow,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              r.icon,
                              color: r.on ? c.tertiary : c.onSurfaceVariant,
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title, style: tt.titleSmall),
                                  Text(
                                    r.sub,
                                    style: tt.bodySmall?.copyWith(
                                      color: c.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            if (r.on)
                              Row(
                                key: ValueKey('ready_${r.id}_on'),
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: c.tertiary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: Space.xs),
                                  Text(t.readyOn, style: tt.labelLarge),
                                ],
                              )
                            else
                              Semantics(
                                identifier: 'ready_${r.id}',
                                child: FilledButton.tonal(
                                  key: ValueKey('ready_${r.id}'),
                                  onPressed: r.enable,
                                  child: Text(t.readyEnable),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.md),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  identifier: 'ready_go',
                  child: FilledButton(
                    key: const ValueKey('ready_go'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: ready
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: Text(ready ? t.readyGo : t.readyWaiting),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.id, this.icon, this.title, this.sub, this.on, this.enable);
  final String id;
  final IconData icon;
  final String title;
  final String sub;
  final bool on;
  final Future<void> Function() enable;
}
