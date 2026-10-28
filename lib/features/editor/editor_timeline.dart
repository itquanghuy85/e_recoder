import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../marker/marker_timing.dart';
import 'edit_project.dart';
import 'editor_controller.dart';

enum _Kind { segment, marker, text, cover, zoom, image, shape, pip, audio }

enum _Grab { none, body, start, end }

class _Chip {
  _Chip(
    this.kind,
    this.id,
    this.index,
    this.row,
    this.startOut,
    this.endOut,
    this.color,
    this.label,
  );
  final _Kind kind;
  final String id;
  final int index;
  final int row; // 0 = video row, 1.. = overlay rows
  final int startOut;
  final int endOut;
  final Color color;
  final String label;
}

/// The edited video as a timeline: the playhead stays in the middle and the tracks move under it
/// (drag to scrub, pinch to zoom). Rows: video segments, then one row per overlay kind in use.
/// Long-press a segment and slide to reorder; edges and overlays snap to neighbours.
class EditorTimeline extends StatefulWidget {
  const EditorTimeline({super.key, required this.controller});
  final EditorController controller;

  @override
  State<EditorTimeline> createState() => EditorTimelineState();
}

class EditorTimelineState extends State<EditorTimeline> {
  EditorController get c => widget.controller;

  double pxPerMs = 0.08; // 80 px per second
  static const double rulerH = 22;
  static const double videoH = 50;
  static const double rowH = 26;
  static const double gap = 4;

  // drag state
  _Kind? _dKind;
  _Grab _dGrab = _Grab.none;
  int _dIndex = 0;
  double _basePx = 0.08;
  Object? _dOrig;
  double _accDx = 0;
  int? _snapOut;

  // reorder state
  int? _reIdx;
  double _reDx = 0;
  double _reStartX = 0;
  int _reTarget = 0;
  double _reFingerX = 0;
  double _reScroll = 0; // how far the timeline scrolled under the finger during this drag
  double _reW = 0;
  Timer? _reTimer;

  @override
  void dispose() {
    _reTimer?.cancel();
    super.dispose();
  }

  void zoomBy(double f) =>
      setState(() => pxPerMs = (pxPerMs * f).clamp(0.01, 0.6));

  /// Fits the whole edited video in the width (the "zoom to fit" button).
  void zoomToFit(double width) {
    final total = math.max(1, c.project.outDurationMs);
    setState(() => pxPerMs = ((width * 0.9) / total).clamp(0.01, 0.6));
  }

  List<int> _rows(EditProject p) => [
    if (p.markers.isNotEmpty) 1,
    if (p.texts.isNotEmpty) 2,
    if (p.covers.isNotEmpty) 3,
    if (p.zooms.isNotEmpty) 4,
    if (p.images.isNotEmpty) 5,
    if (p.shapes.isNotEmpty) 6,
    if (p.pips.isNotEmpty) 7,
    if (p.audioTracks.isNotEmpty) 8,
  ];

  double _rowTop(int rowSlot) =>
      rulerH + videoH + gap + (rowSlot - 1) * (rowH + gap);

  List<_Chip> _chips(EditProject p, ColorScheme cs) {
    final chips = <_Chip>[];
    final starts = p.segmentOutStarts;
    for (var i = 0; i < p.segments.length; i++) {
      final s = p.segments[i];
      chips.add(
        _Chip(
          _Kind.segment,
          'seg$i',
          i,
          0,
          starts[i],
          starts[i] + s.outLengthMs,
          s.blank ? Colors.black : cs.surfaceContainerHighest,
          _segLabel(s),
        ),
      );
    }
    final slots = _rows(p);
    int slot(int kindRow) => slots.indexOf(kindRow) + 1;
    for (final m in p.markers) {
      chips.add(
        _Chip(
          _Kind.marker,
          m.id,
          0,
          slot(1),
          p.sourceToOut(m.cueStartMs),
          p.sourceToOut(m.endMs),
          m.spec.color,
          '',
        ),
      );
    }
    for (final t in p.texts) {
      chips.add(
        _Chip(
          _Kind.text,
          t.id,
          0,
          slot(2),
          p.sourceToOut(t.startMs),
          p.sourceToOut(t.endMs),
          cs.tertiary,
          t.text,
        ),
      );
    }
    for (final v in p.covers) {
      chips.add(
        _Chip(
          _Kind.cover,
          v.id,
          0,
          slot(3),
          p.sourceToOut(v.startMs),
          p.sourceToOut(v.endMs),
          v.color,
          '',
        ),
      );
    }
    for (final z in p.zooms) {
      chips.add(
        _Chip(
          _Kind.zoom,
          z.id,
          0,
          slot(4),
          p.sourceToOut(z.startMs),
          p.sourceToOut(z.endMs),
          cs.secondary,
          '${z.scale.toStringAsFixed(1)}×',
        ),
      );
    }
    for (final im in p.images) {
      chips.add(
        _Chip(
          _Kind.image,
          im.id,
          0,
          slot(5),
          p.sourceToOut(im.startMs),
          p.sourceToOut(im.endMs),
          cs.primary,
          im.name,
        ),
      );
    }
    for (final sh in p.shapes) {
      chips.add(
        _Chip(
          _Kind.shape,
          sh.id,
          0,
          slot(6),
          p.sourceToOut(sh.startMs),
          p.sourceToOut(sh.endMs),
          sh.color,
          sh.text,
        ),
      );
    }
    final total = p.outDurationMs;
    for (final pip in p.pips) {
      chips.add(
        _Chip(
          _Kind.pip,
          pip.id,
          0,
          slot(7),
          pip.startOutMs,
          pip.startOutMs + pip.playMs(total),
          cs.inversePrimary,
          pip.name,
        ),
      );
    }
    for (final a in p.audioTracks) {
      chips.add(
        _Chip(
          _Kind.audio,
          a.id,
          0,
          slot(8),
          a.startOutMs,
          a.endOutMs(total),
          a.kind == AudioKind.music
              ? const Color(0xFF2E7D6B)
              : const Color(0xFFB5651D),
          a.name.isEmpty ? (a.kind == AudioKind.music ? '♪' : '●') : a.name,
        ),
      );
    }
    return chips;
  }

  /// Short badge text of a segment: speed (or ramp), reverse, freeze, blank, volume.
  static String _segLabel(Segment s) {
    if (s.blank) return '■ ${(s.freezeMs / 1000).toStringAsFixed(1)}s';
    if (s.isStill) return '❄ ${(s.freezeMs / 1000).toStringAsFixed(1)}s';
    final parts = <String>[];
    if (s.reverse) parts.add('⟲');
    if (s.isRamp) {
      parts.add('${_fmtSpeed(s.speed)}→${_fmtSpeed(s.speedEnd!)}×');
    } else if (s.speed != 1) {
      parts.add('${_fmtSpeed(s.speed)}×');
    }
    if (s.volume == 0) {
      parts.add('♪✕');
    } else if (s.volume != 1) {
      parts.add('♪${(s.volume * 100).round()}');
    }
    return parts.join(' ');
  }

  static String _fmtSpeed(double s) => s == s.roundToDouble()
      ? s.toInt().toString()
      : s
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll('.', ',');

  double _x(int outMs, double w) => w / 2 + (outMs - c.outMs) * pxPerMs;

  Rect _chipRect(_Chip ch, double w) {
    final top = ch.row == 0 ? rulerH : _rowTop(ch.row);
    final h = ch.row == 0 ? videoH : rowH;
    final x0 = _x(ch.startOut, w);
    final x1 = math.max(_x(ch.endOut, w), x0 + 18);
    return Rect.fromLTRB(
      x0,
      top,
      x1 - (ch.kind == _Kind.segment ? 2 : 0),
      top + h,
    );
  }

  bool _isSelected(_Chip ch) => ch.kind == _Kind.segment
      ? (c.multiSelect
            ? c.multiSelected.contains(ch.index)
            : (c.selectedId == null && ch.index == c.selectedSegment))
      : ch.id == c.selectedId;

  ({_Chip? chip, _Grab grab}) _hit(Offset pos, double w) {
    final p = c.project;
    final cs = Theme.of(context).colorScheme;
    final chips = _chips(p, cs);
    // Prefer selected chip handles, then any chip body (overlays on top of the video row).
    for (final ch in chips.reversed) {
      final r = _chipRect(ch, w);
      if (!r.inflate(10).contains(pos)) continue;
      if (_isSelected(ch)) {
        // Easy-to-hit trim zones, but never more than 40 % of a short clip each.
        final zone = math.min(24.0, r.width * 0.4);
        if ((pos.dx - r.left).abs() < zone) return (chip: ch, grab: _Grab.start);
        if ((pos.dx - r.right).abs() < zone) return (chip: ch, grab: _Grab.end);
      }
      if (r.contains(pos)) return (chip: ch, grab: _Grab.body);
    }
    return (chip: null, grab: _Grab.none);
  }

  void _onStart(ScaleStartDetails d, double w) {
    _accDx = 0;
    _basePx = pxPerMs;
    if (_reIdx != null) return;
    if (d.pointerCount >= 2) {
      _dKind = null;
      return;
    }
    final h = _hit(d.localFocalPoint, w);
    final ch = h.chip;
    if (ch == null || h.grab == _Grab.none) {
      _dKind = null;
      return;
    }
    // Only the selected clip can be moved/trimmed; first touch selects it.
    if (!_isSelected(ch)) {
      _select(ch);
      _dKind = null;
      return;
    }
    // Stills and blanks have no source edges to trim.
    if (ch.kind == _Kind.segment && c.project.segments[ch.index].isStill) {
      _dKind = null;
      return;
    }
    _dKind = ch.kind;
    _dGrab = h.grab;
    _dIndex = ch.index;
    final p = c.project;
    _dOrig = switch (ch.kind) {
      _Kind.segment => p.segments[ch.index],
      _Kind.marker => p.markers.firstWhere((e) => e.id == ch.id),
      _Kind.text => p.texts.firstWhere((e) => e.id == ch.id),
      _Kind.cover => p.covers.firstWhere((e) => e.id == ch.id),
      _Kind.zoom => p.zooms.firstWhere((e) => e.id == ch.id),
      _Kind.image => p.images.firstWhere((e) => e.id == ch.id),
      _Kind.shape => p.shapes.firstWhere((e) => e.id == ch.id),
      _Kind.pip => p.pips.firstWhere((e) => e.id == ch.id),
      _Kind.audio => p.audioTracks.firstWhere((e) => e.id == ch.id),
    };
    c.beginGesture();
  }

  void _select(_Chip ch) {
    if (ch.kind == _Kind.segment) {
      c.toggleSegment(ch.index);
    } else {
      c.select(ch.id);
    }
  }

  void _onUpdate(ScaleUpdateDetails d, double w) {
    if (_reIdx != null) return;
    if (d.pointerCount >= 2) {
      setState(() => pxPerMs = (_basePx * d.horizontalScale).clamp(0.01, 0.6));
      return;
    }
    final dx = d.focalPointDelta.dx;
    _accDx += dx;
    if (_dKind == null) {
      c.seekOut((c.outMs - dx / pxPerMs).round());
      return;
    }
    final dOut = (_accDx / pxPerMs).round();
    final p = c.project;
    final snap = [...p.snapPointsOut, c.outMs];
    final reach = (10 / pxPerMs).round();
    int? snapped;
    int toSrc(int origSrc, int by) {
      final raw = p.sourceToOut(origSrc) + by;
      final target = EditProject.snapTo(raw, snap, reach);
      if (target != raw) snapped = target;
      return p.outToSource(target).clamp(0, p.durationMs);
    }

    switch (_dKind!) {
      case _Kind.segment:
        final o = _dOrig! as Segment;
        // Dragging an edge moves it along the PLAY direction's source axis.
        final srcDelta = (dOut * o.meanSpeed).round();
        if (_dGrab == _Grab.start) {
          c.trimSegmentLive(_dIndex, startMs: o.startMs + srcDelta);
        } else if (_dGrab == _Grab.end) {
          c.trimSegmentLive(_dIndex, endMs: o.endMs + srcDelta);
        }
      case _Kind.marker:
        final o = _dOrig! as MarkerItem;
        if (_dGrab == _Grab.body) {
          c.updateMarker(
            o.copyWith(cueStartMs: toSrc(o.cueStartMs, dOut)),
            record: false,
          );
        } else if (_dGrab == _Grab.end) {
          c.updateMarker(
            o.copyWith(holdMs: (o.holdMs + dOut).clamp(300, 15000)),
            record: false,
          );
        } else {
          c.updateMarker(
            o.copyWith(
              cueStartMs: toSrc(o.cueStartMs, dOut),
              holdMs: (o.holdMs - dOut).clamp(300, 15000),
            ),
            record: false,
          );
        }
      case _Kind.text:
        final o = _dOrig! as TextItem;
        final (s, e) = _span(o.startMs, o.endMs, dOut, toSrc);
        c.updateText(o.copyWith(startMs: s, endMs: e), record: false);
      case _Kind.cover:
        final o = _dOrig! as CoverItem;
        final (s, e) = _span(o.startMs, o.endMs, dOut, toSrc);
        c.updateCover(o.copyWith(startMs: s, endMs: e), record: false);
      case _Kind.zoom:
        final o = _dOrig! as ZoomItem;
        final (s, e) = _span(o.startMs, o.endMs, dOut, toSrc);
        c.updateZoom(o.copyWith(startMs: s, endMs: e), record: false);
      case _Kind.image:
        final o = _dOrig! as ImageItem;
        final (s, e) = _span(o.startMs, o.endMs, dOut, toSrc);
        c.updateImage(o.copyWith(startMs: s, endMs: e), record: false);
      case _Kind.shape:
        final o = _dOrig! as ShapeItem;
        final (s, e) = _span(o.startMs, o.endMs, dOut, toSrc);
        c.updateShape(o.copyWith(startMs: s, endMs: e), record: false);
      case _Kind.pip:
        // Picture-in-picture and audio sit on the OUTPUT timeline: the drag is in output time already.
        final o = _dOrig! as PipItem;
        final snapped0 = EditProject.snapTo(o.startOutMs + dOut, snap, reach);
        if (snapped0 != o.startOutMs + dOut) snapped = snapped0;
        if (_dGrab == _Grab.end) {
          c.updatePip(
            o.copyWith(durMs: (o.durMs + dOut).clamp(500, 30000)),
            record: false,
          );
        } else {
          c.updatePip(
            o.copyWith(startOutMs: snapped0.clamp(0, p.outDurationMs)),
            record: false,
          );
        }
      case _Kind.audio:
        final o = _dOrig! as AudioTrack;
        final snapped0 = EditProject.snapTo(o.startOutMs + dOut, snap, reach);
        if (snapped0 != o.startOutMs + dOut) snapped = snapped0;
        c.updateAudio(
          o.copyWith(startOutMs: snapped0.clamp(0, p.outDurationMs)),
          record: false,
        );
    }
    if (snapped != _snapOut) setState(() => _snapOut = snapped);
  }

  (int, int) _span(int s, int e, int dOut, int Function(int, int) toSrc) {
    switch (_dGrab) {
      case _Grab.body:
        // Either edge may snap; take whichever moved the least.
        final ns = toSrc(s, dOut);
        final ne = toSrc(e, dOut);
        if ((ns - s - dOut).abs() <= (ne - e - dOut).abs()) {
          return (ns, ns + (e - s));
        }
        return (ne - (e - s), ne);
      case _Grab.start:
        return (math.min(toSrc(s, dOut), e - 300), e);
      case _Grab.end:
        return (s, math.max(toSrc(e, dOut), s + 300));
      case _Grab.none:
        return (s, e);
    }
  }

  void _onEnd(ScaleEndDetails d) {
    if (_dKind != null) c.flush();
    _dKind = null;
    if (_snapOut != null) setState(() => _snapOut = null);
  }

  void _onTap(TapUpDetails d, double w) {
    final h = _hit(d.localPosition, w);
    if (h.chip != null) {
      _select(h.chip!);
      return;
    }
    c.select(null);
    c.seekOut((c.outMs + (d.localPosition.dx - w / 2) / pxPerMs).round());
  }

  // ---- drag to reorder -------------------------------------------------------------------------

  void _reStart(LongPressStartDetails d, double w) {
    final h = _hit(d.localPosition, w);
    final ch = h.chip;
    if (ch == null ||
        ch.kind != _Kind.segment ||
        c.project.segments.length < 2) {
      return;
    }
    HapticFeedback.mediumImpact();
    c.selectSegment(ch.index);
    _reW = w;
    _reScroll = 0;
    _reFingerX = d.localPosition.dx;
    setState(() {
      _reIdx = ch.index;
      _reStartX = d.localPosition.dx;
      _reDx = 0;
      _reTarget = ch.index;
    });
    _reTimer?.cancel();
    _reTimer = Timer.periodic(const Duration(milliseconds: 32), (_) => _reAutoScroll());
  }

  /// Where the dragged clip would land: how many of the other clips have their middle left of it.
  int _reTargetFor(int idx, double w) {
    final p = c.project;
    final starts = p.segmentOutStarts;
    double centre(int i) => _x(starts[i] + p.segments[i].outLengthMs ~/ 2, w);
    final dragged = centre(idx) + _reDx;
    var target = 0;
    for (var i = 0; i < p.segments.length; i++) {
      if (i != idx && centre(i) < dragged) target++;
    }
    return target;
  }

  void _reMove(LongPressMoveUpdateDetails d, double w) {
    final idx = _reIdx;
    if (idx == null) return;
    _reFingerX = d.localPosition.dx;
    _reW = w;
    _reDx = _reFingerX - _reStartX + _reScroll;
    _reRefresh(idx, w);
  }

  void _reRefresh(int idx, double w) {
    final target = _reTargetFor(idx, w);
    if (target != _reTarget) HapticFeedback.selectionClick();
    setState(() => _reTarget = target);
  }

  /// Near the left or right edge the timeline scrolls by itself so a clip can be carried far.
  void _reAutoScroll() {
    final idx = _reIdx;
    if (idx == null || !mounted) return;
    const edge = 56.0;
    final w = _reW;
    var dir = 0.0;
    if (_reFingerX < edge) {
      dir = -(edge - _reFingerX) / edge;
    } else if (_reFingerX > w - edge) {
      dir = (_reFingerX - (w - edge)) / edge;
    }
    if (dir == 0) return;
    final before = c.outMs;
    // up to ~14 px per tick, whatever the zoom
    c.seekOut(before + (dir.clamp(-1.0, 1.0) * 14 / pxPerMs).round());
    final moved = (c.outMs - before) * pxPerMs;
    if (moved == 0) return;
    // The chips slid under the finger: keep the carried clip where the finger is.
    _reScroll += moved;
    _reDx = _reFingerX - _reStartX + _reScroll;
    _reRefresh(idx, w);
  }

  void _reEnd() {
    _reTimer?.cancel();
    _reTimer = null;
    final idx = _reIdx;
    if (idx == null) return;
    final target = _reTarget;
    setState(() => _reIdx = null);
    if (target != idx) c.moveSegmentTo(idx, target);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final rows = _rows(c.project).length;
        final height =
            rulerH + videoH + (rows > 0 ? gap + rows * (rowH + gap) : 0) + 4;
        return LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final p = c.project;
            final starts = p.segmentOutStarts;
            return Semantics(
              identifier: 'editor_timeline',
              label: AppL10n.of(context).timelineSummary(
                p.segments.length,
                p.markers.length,
                p.texts.length,
                p.covers.length,
                p.zooms.length,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) => _onStart(d, w),
                onScaleUpdate: (d) => _onUpdate(d, w),
                onScaleEnd: _onEnd,
                onTapUp: (d) => _onTap(d, w),
                onLongPressStart: (d) => _reStart(d, w),
                onLongPressMoveUpdate: (d) => _reMove(d, w),
                onLongPressEnd: (_) => _reEnd(),
                onLongPressCancel: _reEnd,
                child: SizedBox(
                  height: height,
                  width: w,
                  child: CustomPaint(
                    painter: _TimelinePainter(
                      chips: _chips(p, cs),
                      segments: p.segments,
                      wave: c.waveform,
                      scheme: cs,
                      outMs: c.outMs,
                      total: p.outDurationMs,
                      pxPerMs: pxPerMs,
                      selected: _isSelected,
                      chipRect: _chipRect,
                      textStyle: Theme.of(context).textTheme.labelSmall!,
                      clockStyle: TextStyle(
                        fontFamily: 'BarlowSemiCondensed',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      markerCueWidth: MarkerTiming.cueMs * pxPerMs,
                      height: height,
                      transitionCuts: [
                        for (var i = 1; i < p.segments.length; i++)
                          if (p.segments[i].transition != null) starts[i],
                      ],
                      snapOut: _snapOut,
                      reorderIdx: _reIdx,
                      reorderDx: _reDx,
                      reorderTarget: _reTarget,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.chips,
    required this.segments,
    required this.wave,
    required this.scheme,
    required this.outMs,
    required this.total,
    required this.pxPerMs,
    required this.selected,
    required this.chipRect,
    required this.textStyle,
    required this.clockStyle,
    required this.markerCueWidth,
    required this.height,
    required this.transitionCuts,
    required this.snapOut,
    required this.reorderIdx,
    required this.reorderDx,
    required this.reorderTarget,
  });

  final List<_Chip> chips;
  final List<Segment> segments;

  /// Peak levels of the source sound per [EditorController.waveBucketMs] (null = none).
  final List<double>? wave;
  final ColorScheme scheme;
  final int outMs;
  final int total;
  final double pxPerMs;
  final bool Function(_Chip) selected;
  final Rect Function(_Chip, double) chipRect;
  final TextStyle textStyle;
  final TextStyle clockStyle;
  final double markerCueWidth;
  final double height;
  final List<int> transitionCuts;
  final int? snapOut;
  final int? reorderIdx;
  final double reorderDx;
  final int reorderTarget;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    double x(int ms) => w / 2 + (ms - outMs) * pxPerMs;

    // background of the movable area beyond the video is left empty: the video "starts" at x(0)
    _ruler(canvas, size, x);

    for (final ch in chips) {
      var r = chipRect(ch, w);
      final dragging =
          ch.kind == _Kind.segment &&
          reorderIdx != null &&
          ch.index == reorderIdx;
      if (dragging) r = r.shift(Offset(reorderDx, -4));
      if (r.right < -20 || r.left > w + 20) continue;
      final sel = selected(ch);
      final rr = RRect.fromRectAndRadius(
        r,
        Radius.circular(ch.kind == _Kind.segment ? 8 : 6),
      );
      final isVideo = ch.kind == _Kind.segment;
      final fill = Paint()
        ..color = isVideo
            ? (sel ? scheme.tertiaryContainer : ch.color)
            : ch.color.withValues(alpha: 0.9);
      if (dragging) {
        canvas.drawShadow(Path()..addRRect(rr), Colors.black, 6, true);
      }
      canvas.drawRRect(rr, fill);
      if (isVideo && wave != null) {
        _waveform(canvas, rr, r, segments[ch.index], w);
      }

      if (ch.kind == _Kind.marker) {
        // The cue part (ring converging) is hatched amber: it is the lead-in the viewer sees.
        final cueW = math.min(markerCueWidth, r.width);
        final cue = Rect.fromLTWH(r.left, r.top, cueW, r.height);
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(cue, Paint()..color = const Color(0xFFFFB938));
        final hatch = Paint()
          ..color = const Color(0xFF111111).withValues(alpha: 0.55)
          ..strokeWidth = 2;
        for (var hx = cue.left - r.height; hx < cue.right; hx += 7) {
          canvas.drawLine(
            Offset(hx, cue.bottom),
            Offset(hx + r.height, cue.top),
            hatch,
          );
        }
        canvas.restore();
      }

      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 2.5 : 1
        ..color = sel ? scheme.tertiary : scheme.outlineVariant;
      canvas.drawRRect(rr, border);

      if (ch.label.isNotEmpty && r.width > 30) {
        final onColor = ch.kind == _Kind.text || ch.kind == _Kind.zoom
            ? scheme.onTertiary
            : scheme.onSurface;
        final tp = TextPainter(
          text: TextSpan(
            text: ch.label,
            style: textStyle.copyWith(
              color: isVideo
                  ? (ch.color == Colors.black ? Colors.white : scheme.onSurface)
                  : onColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r.width - 10);
        tp.paint(canvas, Offset(r.left + 6, r.center.dy - tp.height / 2));
      }

      if (sel && !dragging) {
        final hp = Paint()..color = scheme.tertiary;
        for (final hx in [r.left, r.right]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(hx, r.center.dy),
                width: 8,
                height: math.min(r.height - 8, 26),
              ),
              const Radius.circular(3),
            ),
            hp,
          );
        }
      }
    }

    // transitions: a small diamond on the cut
    for (final cut in transitionCuts) {
      final cx = x(cut);
      if (cx < -10 || cx > w + 10) continue;
      final cy = EditorTimelineState.rulerH + EditorTimelineState.videoH / 2;
      final path = Path()
        ..moveTo(cx, cy - 8)
        ..lineTo(cx + 8, cy)
        ..lineTo(cx, cy + 8)
        ..lineTo(cx - 8, cy)
        ..close();
      canvas.drawPath(path, Paint()..color = scheme.tertiary);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = scheme.onTertiary,
      );
    }

    // reorder: where the dragged segment will land
    if (reorderIdx != null) {
      final others = chips
          .where((e) => e.kind == _Kind.segment && e.index != reorderIdx)
          .toList();
      double lx;
      if (others.isEmpty) {
        lx = w / 2;
      } else if (reorderTarget <= 0) {
        lx = chipRect(others.first, w).left;
      } else if (reorderTarget >= others.length) {
        lx = chipRect(others.last, w).right;
      } else {
        lx = chipRect(others[reorderTarget], w).left;
      }
      canvas.drawLine(
        Offset(lx, EditorTimelineState.rulerH - 2),
        Offset(lx, EditorTimelineState.rulerH + EditorTimelineState.videoH + 2),
        Paint()
          ..color = scheme.tertiary
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      // round tips so the landing place reads at a glance, even under a thumb
      final tip = Paint()..color = scheme.tertiary;
      canvas.drawCircle(Offset(lx, EditorTimelineState.rulerH - 3), 5, tip);
      canvas.drawCircle(
        Offset(lx, EditorTimelineState.rulerH + EditorTimelineState.videoH + 3),
        5,
        tip,
      );
    }

    // snap guide
    if (snapOut != null) {
      final sx = x(snapOut!);
      canvas.drawLine(
        Offset(sx, 0),
        Offset(sx, height),
        Paint()
          ..color = const Color(0xFFFFB938)
          ..strokeWidth = 1.5,
      );
    }

    // playhead
    final ph = Paint()
      ..color = scheme.tertiary
      ..strokeWidth = 2;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, height), ph);
    final tri = Path()
      ..moveTo(w / 2 - 6, 0)
      ..lineTo(w / 2 + 6, 0)
      ..lineTo(w / 2, 8)
      ..close();
    canvas.drawPath(tri, Paint()..color = scheme.tertiary);
  }

  void _ruler(Canvas canvas, Size size, double Function(int) x) {
    const steps = [
      100,
      250,
      500,
      1000,
      2000,
      5000,
      10000,
      30000,
      60000,
      300000,
    ];
    var step = steps.last;
    for (final s in steps) {
      if (s * pxPerMs >= 56) {
        step = s;
        break;
      }
    }
    final minMs = ((0 - size.width / 2) / pxPerMs + outMs).floor();
    final maxMs = ((size.width / 2) / pxPerMs + outMs).ceil();
    final first = (math.max(0, minMs) ~/ step) * step;
    final tick = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1;
    for (var ms = first; ms <= math.min(maxMs, total); ms += step) {
      final px = x(ms);
      canvas.drawLine(Offset(px, rulerH - 7), Offset(px, rulerH - 1), tick);
      final tp = TextPainter(
        text: TextSpan(text: formatClock(ms), style: clockStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px + 3, 1));
    }
  }

  static const double rulerH = EditorTimelineState.rulerH;

  /// The sound of a segment as mirrored bars behind its label. Time runs through the segment
  /// linearly in source time (a speed ramp is drawn as if it were constant); a reversed segment is
  /// mirrored, and the bars follow the segment's volume.
  void _waveform(Canvas canvas, RRect rr, Rect r, Segment seg, double width) {
    final peaks = wave!;
    if (seg.blank || seg.isStill || seg.volume <= 0 || r.width < 6) return;
    const step = 3.0;
    const bucketMs = EditorController.waveBucketMs;
    final srcLen = seg.endMs - seg.startMs;
    final msPerPx = srcLen / r.width;
    final perColumn = math.max(1, (msPerPx * step / bucketMs).ceil());
    final paint = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.30)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final half = r.height * 0.40;
    final gain = seg.volume.clamp(0.0, 2.0);
    canvas.save();
    canvas.clipRRect(rr);
    final from = math.max(r.left, -step);
    final to = math.min(r.right, width + step);
    for (var px = from; px < to; px += step) {
      final frac = ((px - r.left) / r.width).clamp(0.0, 1.0);
      final src = seg.startMs + (seg.reverse ? 1 - frac : frac) * srcLen;
      final b0 = (src / bucketMs).floor().clamp(0, peaks.length - 1);
      var peak = 0.0;
      for (var b = b0; b < math.min(peaks.length, b0 + perColumn); b++) {
        peak = math.max(peak, peaks[b]);
      }
      // A touch of compression so quiet speech still shows.
      final h = math.pow(peak, 0.6) * gain * half;
      final bar = math.max(1.0, math.min(half, h.toDouble()));
      canvas.drawLine(
        Offset(px, r.center.dy - bar),
        Offset(px, r.center.dy + bar),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => true;
}
