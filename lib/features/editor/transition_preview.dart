import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/native_recorder.dart';
import 'editor_stage.dart' show transitionedPicture;
import 'segment.dart';

/// The two frames around a cut (end of the clip before, start of the clip after), read once per cut.
class CutFrames {
  const CutFrames(this.before, this.after);
  final Uint8List before;
  final Uint8List after;

  static final Map<String, CutFrames?> _cache = {};

  /// Null when either frame cannot be read: the picker then shows plain names.
  static Future<CutFrames?> load(
    NativeRecorder native,
    String uri, {
    required int beforeMs,
    required int afterMs,
    int w = 160,
    int h = 160,
  }) async {
    final key = '$uri@$beforeMs/$afterMs';
    if (_cache.containsKey(key)) return _cache[key];
    CutFrames? r;
    try {
      final a = await native.frameAt(uri, beforeMs, w: w, h: h);
      final b = await native.frameAt(uri, afterMs, w: w, h: h);
      if (a != null && b != null) r = CutFrames(a, b);
    } catch (_) {}
    if (_cache.length > 24) _cache.clear();
    _cache[key] = r;
    return r;
  }
}

/// Where a looping preview is at [ms] of its [cycleMs] cycle: the frame before the cut is held, the
/// transition plays in [playMs] (outgoing half, then incoming half), then the frame after is held.
/// Pure, so the timing is unit tested. Uses [TransitionLook.of], the formula of the preview and export.
({bool incoming, TransitionLook look}) transitionPreviewAt(
  TransitionKind kind,
  int ms, {
  int cycleMs = 1400,
  int playMs = 600,
}) {
  final hold = (cycleMs - playMs) ~/ 2;
  final t = ms % cycleMs;
  if (t < hold) return (incoming: false, look: TransitionLook.none);
  if (t >= hold + playMs) return (incoming: true, look: TransitionLook.none);
  final s = (t - hold) / playMs;
  if (s < 0.5) {
    return (
      incoming: false,
      look: TransitionLook.of(kind, 1 - s * 2, incoming: false),
    );
  }
  return (
    incoming: true,
    look: TransitionLook.of(kind, (s - 0.5) * 2, incoming: true),
  );
}

/// A small looping picture of [kind] made from the video's own frames (0.6 s transition).
class TransitionPreview extends StatefulWidget {
  const TransitionPreview({
    super.key,
    required this.kind,
    required this.frames,
    required this.width,
    required this.height,
  });

  final TransitionKind kind;
  final CutFrames frames;
  final double width;
  final double height;

  @override
  State<TransitionPreview> createState() => _TransitionPreviewState();
}

class _TransitionPreviewState extends State<TransitionPreview>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1400);
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  @override
  void initState() {
    super.initState();
    // No motion when the person asked the phone for less animation: the picture after the cut shows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      _a.repeat();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: w,
        height: h,
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final at = _a.isAnimating
                ? (_a.value * _cycle.inMilliseconds).round()
                : _cycle.inMilliseconds - 1;
            final p = transitionPreviewAt(widget.kind, at);
            final img = Image.memory(
              p.incoming ? widget.frames.after : widget.frames.before,
              width: w,
              height: h,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            );
            return ClipRect(child: transitionedPicture(p.look, w, h, img));
          },
        ),
      ),
    );
  }
}
