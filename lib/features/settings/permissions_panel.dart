import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../record/recorder_controller.dart';

/// Status + grant buttons for the permissions the recorder uses. Rechecks when the app resumes
/// (the user comes back from a system settings page).
class PermissionsPanel extends ConsumerStatefulWidget {
  const PermissionsPanel({super.key});

  @override
  ConsumerState<PermissionsPanel> createState() => _PermissionsPanelState();
}

class _PermissionsPanelState extends ConsumerState<PermissionsPanel>
    with WidgetsBindingObserver {
  bool? _overlay;
  bool? _mic;
  bool? _notif;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final g = ref.read(permissionsGatewayProvider);
    final native = ref.read(nativeRecorderProvider);
    final o = await native.canOverlay();
    final m = await g.micGranted();
    final n = await g.notificationsGranted();
    if (mounted) {
      setState(() {
        _overlay = o;
        _mic = m;
        _notif = n;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final g = ref.read(permissionsGatewayProvider);
    final native = ref.read(nativeRecorderProvider);
    // iOS has no "display over other apps" permission and no battery optimisation to switch off.
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!ios)
          _PermRow(
            id: 'perm_overlay',
            icon: Icons.layers_outlined,
            title: t.permOverlayTitle,
            body: t.permOverlayBody,
            granted: _overlay,
            onGrant: () async {
              await native.requestOverlay();
            },
          ),
        _PermRow(
          id: 'perm_mic',
          icon: Icons.mic_none,
          title: t.permMicTitle,
          body: t.permMicBody,
          granted: _mic,
          onGrant: () async {
            final ok = await g.requestMic();
            if (!ok) await g.openSettings();
            await _refresh();
          },
        ),
        _PermRow(
          id: 'perm_notif',
          icon: Icons.notifications_none,
          title: t.permNotifTitle,
          body: t.permNotifBody,
          granted: _notif,
          onGrant: () async {
            final ok = await g.requestNotifications();
            if (!ok) await g.openSettings();
            await _refresh();
          },
        ),
        if (!ios)
          _PermRow(
            id: 'perm_battery',
            icon: Icons.battery_charging_full,
            title: t.permBatteryTitle,
            body: t.permBatteryBody,
            granted: null,
            grantLabel: t.permOpenSettings,
            onGrant: g.openSettings,
          ),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.granted,
    required this.onGrant,
    this.grantLabel,
  });
  final String id;
  final IconData icon;
  final String title;
  final String body;

  /// null = unknown / not applicable (always shows the action).
  final bool? granted;
  final Future<void> Function() onGrant;
  final String? grantLabel;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.onSurfaceVariant),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleSmall),
                const SizedBox(height: Space.xs),
                Text(
                  body,
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: Space.sm),
                if (granted == true)
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: c.tertiary),
                      const SizedBox(width: Space.xs),
                      Text(
                        t.permGranted,
                        style: tt.labelLarge?.copyWith(color: c.tertiary),
                      ),
                    ],
                  )
                else
                  Semantics(
                    identifier: id,
                    child: OutlinedButton(
                      onPressed: onGrant,
                      child: Text(grantLabel ?? t.permGrant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.settingsPermissions)),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: const [PermissionsPanel()],
      ),
    );
  }
}
