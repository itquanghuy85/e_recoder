import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_tokens.dart';

/// Is this an iPhone? Several features exist only on Android (recording other apps, the floating dot,
/// hearing every tap, zoom and the other export effects): on iOS they are shown as such, never silently
/// missing or broken.
bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

/// Says why a feature is not on iPhone and what it gives on Android.
Future<void> showAndroidOnly(
  BuildContext context, {
  required String feature,
  required String gets,
}) {
  final t = AppL10n.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AndroidBadge(),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    t.androidOnlyTitle(feature),
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(t.androidOnlyGets(gets)),
            const SizedBox(height: Space.sm),
            Text(
              t.androidOnlyWhy,
              style: Theme.of(ctx).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Space.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t.androidOnlyOk),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The small "Android" label put on what iPhone does not have.
class AndroidBadge extends StatelessWidget {
  const AndroidBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.android, size: 14, color: cs.onSecondaryContainer),
            const SizedBox(width: 3),
            Text(
              AppL10n.of(context).androidBadge,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: cs.onSecondaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps controls that exist only on Android. On Android it is just [child]. On iPhone the controls are
/// shown dimmed and cannot be used, with the "Android" label; a tap says what they give on Android.
class AndroidOnly extends StatelessWidget {
  const AndroidOnly({
    super.key,
    required this.feature,
    required this.gets,
    required this.child,
  });
  final String feature;
  final String gets;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isIOS) return child;
    return Semantics(
      identifier: 'android_only',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => showAndroidOnly(context, feature: feature, gets: gets),
        child: Stack(
          children: [
            Opacity(opacity: 0.45, child: IgnorePointer(child: child)),
            const Positioned(top: 0, right: 0, child: AndroidBadge()),
          ],
        ),
      ),
    );
  }
}

/// A line above a panel that works only in part on iPhone.
class AndroidOnlyNote extends StatelessWidget {
  const AndroidOnlyNote({super.key, required this.gets});
  final String gets;

  @override
  Widget build(BuildContext context) {
    if (!isIOS) return const SizedBox.shrink();
    final t = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AndroidBadge(),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  t.androidOnlyNote(gets),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Instead of a panel that does nothing on iPhone: what it is and what it gives on Android.
class AndroidOnlyPanel extends StatelessWidget {
  const AndroidOnlyPanel({
    super.key,
    required this.feature,
    required this.gets,
  });
  final String feature;
  final String gets;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    return Semantics(
      identifier: 'android_only_panel',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AndroidBadge(),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    t.androidOnlyTitle(feature),
                    style: tt.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(t.androidOnlyGets(gets), style: tt.bodyMedium),
            const SizedBox(height: Space.xs),
            Text(
              t.androidOnlyWhy,
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
