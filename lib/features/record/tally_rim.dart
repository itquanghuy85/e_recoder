import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// The tally: a keyline around the screen that says "this is live". Red while
/// recording, amber while paused. It pulses unless the system removes animations.
class TallyRim extends StatefulWidget {
  const TallyRim({
    super.key,
    required this.child,
    required this.live,
    this.paused = false,
  });
  final Widget child;
  final bool live;
  final bool paused;

  @override
  State<TallyRim> createState() => _TallyRimState();
}

class _TallyRimState extends State<TallyRim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.tallyPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        MediaQuery.of(context).disableAnimations ||
        !widget.live ||
        widget.paused;
    if (still) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TallyRim old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.paused ? scheme.secondary : scheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final a = widget.live ? 0.45 + 0.55 * _c.value : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withValues(alpha: a),
              width: widget.live ? 3 : 0,
            ),
          ),
          position: DecorationPosition.foreground,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
