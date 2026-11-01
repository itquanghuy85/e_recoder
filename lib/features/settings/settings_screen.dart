import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../purpose/purpose.dart';
import '../onboarding/onboarding_screen.dart';
import 'about_screens.dart';
import 'permissions_panel.dart';
import 'section_header.dart';

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
        SettingsSectionHeader(
          icon: Icons.palette_outlined,
          title: t.settingsGroupApp,
          sub: t.settingsTheme,
        ),
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
        SettingsSectionHeader(
          icon: Icons.videocam_outlined,
          title: t.settingsGroupRecord,
          sub: t.settingsGroupRecordSub,
        ),
        Semantics(
          identifier: 'settings_reset_modes',
          child: ListTile(
            key: const ValueKey('settings_reset_modes'),
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: Space.md,
            leading: Icon(Icons.restart_alt, color: c.primary),
            title: Text(t.settingsResetModes, style: tt.titleMedium),
            subtitle: Text(
              t.settingsResetModesSub,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
            onTap: () => _resetModes(context, ref),
          ),
        ),
        _SettingsTile(
          id: 'settings_permissions',
          icon: Icons.verified_user_outlined,
          title: t.settingsPermissions,
          sub: t.settingsPermissionsSub,
          page: const PermissionsScreen(),
        ),
        const SizedBox(height: Space.lg),
        SettingsSectionHeader(
          icon: Icons.help_outline,
          title: t.settingsGroupHelp,
          sub: t.settingsGroupHelpSub,
        ),
        _SettingsTile(
          id: 'settings_guide',
          icon: Icons.menu_book_outlined,
          title: t.settingsGuide,
          sub: t.settingsGuideSub,
          page: const OnboardingScreen(),
        ),
        _SettingsTile(
          id: 'settings_privacy',
          icon: Icons.lock_outline,
          title: t.settingsPrivacy,
          sub: t.settingsPrivacySub,
          page: const PrivacyScreen(),
        ),
        _SettingsTile(
          id: 'settings_about',
          icon: Icons.info_outline,
          title: t.settingsAbout,
          sub: t.settingsAboutSub,
          page: const AboutScreen(),
        ),
      ],
    );
  }
}

/// Asks first: every purpose's settings go back to the first ones.
Future<void> _resetModes(BuildContext context, WidgetRef ref) async {
  final t = AppL10n.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(t.resetModesConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.cancel),
        ),
        Semantics(
          identifier: 'reset_modes_ok',
          child: FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.resetModesAction),
          ),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(purposeProvider.notifier).resetAll();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(t.resetModesDone)),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.id,
    required this.icon,
    required this.title,
    required this.sub,
    required this.page,
  });
  final String id;
  final IconData icon;
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
        leading: Icon(icon, color: c.primary),
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
