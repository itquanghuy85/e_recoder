import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'marker_spec.dart';
import 'marker_timing.dart';

/// A marker image for one phase of the water loop, rendered natively. Keeps showing the previous
/// phase until the next one arrives, so playback never flickers.
class MarkerSprite extends StatefulWidget {
  const MarkerSprite({
    super.key,
    required this.spec,
    required this.phase,
    required this.load,
    required this.builder,
  });

  final MarkerSpec spec;

  /// Index into the loop, see [MarkerTiming.phaseIndex].
  final int phase;
  final Future<({Uint8List png, double side})> Function(int phase) load;
  final Widget Function(BuildContext context, Uint8List png, double side)
  builder;

  @override
  State<MarkerSprite> createState() => _MarkerSpriteState();
}

class _MarkerSpriteState extends State<MarkerSprite> {
  Uint8List? _png;
  double _side = 0;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(MarkerSprite old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase || old.spec != widget.spec) _fetch();
  }

  Future<void> _fetch() async {
    final seq = ++_seq;
    final r = await widget.load(widget.phase);
    if (!mounted || seq != _seq) return;
    setState(() {
      _png = r.png;
      _side = r.side;
    });
  }

  @override
  Widget build(BuildContext context) {
    final png = _png;
    if (png == null) return const SizedBox.shrink();
    return widget.builder(context, png, _side);
  }
}

/// Phase to show for a marker [sinceTakeMs] after its take; the first phase when motion is reduced.
int markerPhase(BuildContext context, int sinceTakeMs) =>
    MediaQuery.of(context).disableAnimations
    ? 0
    : MarkerTiming.phaseIndex(sinceTakeMs);
