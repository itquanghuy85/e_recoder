import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final paragraphs = [
      (t.privacyH1, t.privacyP1),
      (t.privacyH2, t.privacyP2),
      (t.privacyH3, t.privacyP3),
      (t.privacyH4, t.privacyP4),
      (t.privacyH5, t.privacyP5),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t.settingsPrivacy)),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          for (final (h, p) in paragraphs) ...[
            Text(h, style: tt.titleMedium),
            const SizedBox(height: Space.sm),
            Text(p, style: tt.bodyLarge),
            const SizedBox(height: Space.xl),
          ],
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.settingsAbout)),
      body: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.appTitle, style: tt.headlineSmall),
            const SizedBox(height: Space.xs),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) {
                final v = snap.data == null
                    ? ''
                    : '${snap.data!.version} (${snap.data!.buildNumber})';
                return Text(
                  t.aboutVersion(v),
                  style: tt.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                );
              },
            ),
            const SizedBox(height: Space.xl),
            Text(t.aboutBody, style: tt.bodyLarge),
            const SizedBox(height: Space.lg),
            Text(
              t.aboutLicenses,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
