import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';

/// A short reminder of the swipe, over the picture, the first few times the editor opens. It does not
/// take touches and fades by itself.
class SwipeHint extends ConsumerStatefulWidget {
  const SwipeHint({super.key});

  @override
  ConsumerState<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends ConsumerState<SwipeHint> {
  static const _key = 'editor.swipeHints';
  static const _times = 3;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    try {
      final st = ref.read(settingsStoreProvider);
      final n = st.getInt(_key, 0);
      if (n < _times) {
        _show = true;
        st.setInt(_key, n + 1);
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _show = false);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Always a Positioned child: a plain child that collapses to nothing would shrink the whole Stack
    // (the picture) to nothing with it.
    if (!_show) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final t = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: Space.lg,
      right: Space.lg,
      bottom: Space.sm,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: _show ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.inverseSurface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.swipe_vertical, color: cs.onInverseSurface),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        t.editorSwipeHint,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onInverseSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
