import 'package:flutter/material.dart';

/// How much room the editor gives the picture and the timeline.
/// [normal]: tools shown. [workspace]: tools folded away. [full]: the picture over the whole screen.
enum EditorSpace {
  normal,
  workspace,
  full;

  /// One swipe down gives more room, one swipe up gives some back.
  EditorSpace swiped({required bool down}) => down
      ? (this == normal ? workspace : full)
      : (this == full ? workspace : normal);
}

bool _always() => true;

/// Sees a quick, mostly vertical swipe of one finger over [child] and tells [onSwipe] (true = down).
///
/// It only listens to the raw touches: it never takes part in the gesture arena, so what [child] does
/// with its own touches (scrubbing the timeline, dragging a mark, pinching the picture) is left alone.
/// To tell a swipe from those it asks for a fast, long, straight stroke: at least [minDistance] pixels,
/// steeper than 2 : 1, finished within [maxDuration], with no second finger.
class SwipeZone extends StatefulWidget {
  const SwipeZone({
    super.key,
    required this.onSwipe,
    required this.child,
    this.enabled = _always,
    this.minDistance = 72,
    this.maxDuration = const Duration(milliseconds: 650),
  });

  final ValueChanged<bool> onSwipe;
  final Widget child;

  /// Asked when the finger lifts (false = this swipe is not for the editor, e.g. a mark is selected).
  final ValueGetter<bool> enabled;
  final double minDistance;
  final Duration maxDuration;

  @override
  State<SwipeZone> createState() => _SwipeZoneState();
}

class _SwipeZoneState extends State<SwipeZone> {
  final _down = <int, Offset>{};
  final _since = <int, Duration>{};
  bool _multi = false;

  void _reset() {
    _down.clear();
    _since.clear();
    _multi = false;
  }

  void _onDown(PointerDownEvent e) {
    if (_down.isNotEmpty) _multi = true;
    _down[e.pointer] = e.position;
    _since[e.pointer] = e.timeStamp;
  }

  void _onUp(PointerUpEvent e) {
    final from = _down[e.pointer];
    final at = _since[e.pointer];
    _down.remove(e.pointer);
    _since.remove(e.pointer);
    final alone = !_multi;
    if (_down.isEmpty) _multi = false;
    if (!alone || !widget.enabled() || from == null || at == null) return;
    final d = e.position - from;
    if (d.dy.abs() < widget.minDistance) return;
    if (d.dx.abs() * 2 > d.dy.abs()) return;
    if (e.timeStamp - at > widget.maxDuration) return;
    widget.onSwipe(d.dy > 0);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onDown,
    onPointerUp: _onUp,
    onPointerCancel: (_) => _reset(),
    child: widget.child,
  );
}
