import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_settings_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'about_screens.dart';
import 'permissions_panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text(t.navSettings, style: tt.headlineSmall),
        const SizedBox(height: Space.lg),
        Text(t.settingsTheme, style: tt.titleMedium),
        const SizedBox(height: Space.sm),
        SegmentedButton<ThemeMode>(
          key: const ValueKey('theme_selector'),
          segments: [
            ButtonSegment(value: ThemeMode.system, label: Text(t.themeSystem)),
            ButtonSegment(value: ThemeMode.light, label: Text(t.themeLight)),
            ButtonSegment(value: ThemeMode.dark, label: Text(t.themeDark)),
          ],
          selected: {mode},
          onSelectionChanged: (s) =>
              ref.read(themeModeProvider.notifier).set(s.first),
        ),
        const SizedBox(height: Space.xl),
        const Divider(),
        Semantics(
          identifier: 'settings_markers',
          child: ListTile(
            key: const ValueKey('settings_markers'),
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: Space.md,
            title: Text(t.settingsMarkers, style: tt.titleMedium),
            subtitle: Text(
              t.settingsMarkersSub,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
            trailing: Icon(Icons.chevron_right, color: c.onSurfaceVariant),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MarkerSettingsScreen(),
              ),
            ),
          ),
        ),
        _SettingsTile(
          id: 'settings_permissions',
          title: t.settingsPermissions,
          sub: t.settingsPermissionsSub,
          page: const PermissionsScreen(),
        ),
        _SettingsTile(
          id: 'settings_guide',
          title: t.settingsGuide,
          sub: t.settingsGuideSub,
          page: const OnboardingScreen(),
        ),
        _SettingsTile(
          id: 'settings_privacy',
          title: t.settingsPrivacy,
          sub: t.settingsPrivacySub,
          page: const PrivacyScreen(),
        ),
        _SettingsTile(
          id: 'settings_about',
          title: t.settingsAbout,
          sub: t.settingsAboutSub,
          page: const AboutScreen(),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.id,
    required this.title,
    required this.sub,
    required this.page,
  });
  final String id;
  final String title;
  final String sub;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Semantics(
      identifier: id,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: Space.md,
        title: Text(title, style: tt.titleMedium),
        subtitle: Text(
          sub,
          style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: c.onSurfaceVariant),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => page)),
      ),
    );
  }
}
