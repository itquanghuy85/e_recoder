import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'purpose.dart';

/// Three big choices: what do you want to do? Shown once on the first run, and again when a person
/// chooses to change it from the recorder's "Advanced" part.
class PurposeScreen extends ConsumerWidget {
  const PurposeScreen({super.key, this.onDone});

  /// Called after a choice; when null the screen pops itself (opened again from the recorder).
  final VoidCallback? onDone;

  Future<void> _pick(BuildContext context, WidgetRef ref, Purpose p) async {
    await ref.read(purposeProvider.notifier).choose(p);
    if (!context.mounted) return;
    if (onDone != null) {
      onDone!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final current = ref.watch(purposeProvider);
    final cards = [
      (
        Purpose.tutorial,
        Icons.school_outlined,
        t.purposeTutorial,
        t.purposeTutorialSub,
      ),
      (
        Purpose.game,
        Icons.sports_esports_outlined,
        t.purposeGame,
        t.purposeGameSub,
      ),
      (
        Purpose.plain,
        Icons.videocam_outlined,
        t.purposePlain,
        t.purposePlainSub,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Space.lg),
              Text(t.purposeTitle, style: tt.headlineSmall),
              const SizedBox(height: Space.sm),
              Text(
                t.purposeHint,
                style: tt.bodyMedium?.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: Space.xl),
              for (final (p, icon, title, sub) in cards) ...[
                Semantics(
                  identifier: 'purpose_${p.name}',
                  button: true,
                  child: InkWell(
                    key: ValueKey('purpose_${p.name}'),
                    borderRadius: BorderRadius.circular(Radii.md),
                    onTap: () => _pick(context, ref, p),
                    child: Ink(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(
                        color: current == p
                            ? c.primaryContainer
                            : c.surfaceContainerLow,
                        border: Border.all(
                          color: current == p ? c.primary : c.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 36, color: c.primary),
                          const SizedBox(width: Space.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: tt.titleMedium),
                                const SizedBox(height: Space.xs),
                                Text(
                                  sub,
                                  style: tt.bodySmall?.copyWith(
                                    color: c.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: Semantics(
                  identifier: 'purpose_skip',
                  child: TextButton(
                    key: const ValueKey('purpose_skip'),
                    onPressed: () => _pick(context, ref, Purpose.plain),
                    child: Text(t.purposeSkip),
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
