import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_preview.dart';
import '../marker/marker_spec.dart';
import '../settings/permissions_panel.dart';

class OnboardedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).getBool('onboarded', false);

  Future<void> complete() async {
    state = true;
    await ref.read(settingsStoreProvider).setBool('onboarded', true);
  }
}

final onboardedProvider = NotifierProvider<OnboardedNotifier, bool>(
  OnboardedNotifier.new,
);

/// Three short pages: the idea, how point mode works, and the permissions. Shown once; it can be
/// reopened from Settings → Hướng dẫn.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// Called when finished; when null the screen pops itself (reopened from Settings).
  final VoidCallback? onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  static const _pages = 3;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardedProvider.notifier).complete();
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _next() {
    if (_index == _pages - 1) {
      _finish();
    } else {
      _page.nextPage(duration: Motion.medium, curve: Motion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    final last = _index == _pages - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Semantics(
                  identifier: 'onb_skip',
                  child: TextButton(onPressed: _finish, child: Text(t.onbSkip)),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [_PageIdea(), _PageSteps(), _PagePermissions()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.sm,
                Space.xl,
                Space.xl,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _pages; i++)
                    AnimatedContainer(
                      duration: Motion.short,
                      margin: const EdgeInsets.only(right: Space.sm),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? cs.tertiary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  // Expanded + Align: the button may wrap its label instead of overflowing the row.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        identifier: 'onb_next',
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.tertiary,
                            foregroundColor: cs.onTertiary,
                            minimumSize: const Size(140, 52),
                          ),
                          onPressed: _next,
                          child: Text(last ? t.onbStart : t.onbNext),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIdea extends StatelessWidget {
  const _PageIdea();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    // A scrolling page: at large system font sizes the text needs the room, the demo shrinks.
    return LayoutBuilder(
      builder: (context, box) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        children: [
          SizedBox(
            height: (box.maxHeight * 0.5).clamp(160.0, 420.0),
            child: Center(
              child: MarkerPreview(
                spec: const MarkerSpec(
                  type: MarkerType.finger,
                  color: Color(0xFFFF3B30),
                  x0: 0.5,
                  y0: 0.55,
                  x1: 0.5,
                  y1: 0.55,
                ),
                holdMs: 1400,
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(t.onbTitle1, style: tt.headlineSmall),
          const SizedBox(height: Space.sm),
          Text(
            t.onbBody1,
            style: tt.bodyLarge?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PageSteps extends StatelessWidget {
  const _PageSteps();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final steps = [t.onbStep1, t.onbStep2, t.onbStep3];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      children: [
        const SizedBox(height: Space.xl),
        Text(t.onbTitle2, style: tt.headlineSmall),
        const SizedBox(height: Space.xl),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: tt.titleMedium?.copyWith(
                      color: c.onTertiaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(steps[i], style: tt.bodyLarge),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PagePermissions extends StatelessWidget {
  const _PagePermissions();

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      children: [
        const SizedBox(height: Space.xl),
        Text(t.onbTitle3, style: tt.headlineSmall),
        const SizedBox(height: Space.sm),
        Text(
          t.onbBody3,
          style: tt.bodyLarge?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        const PermissionsPanel(),
      ],
    );
  }
}
