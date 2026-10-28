import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import '../../core/native_recorder.dart' show RecMark;
import '../marker/marker_spec.dart';
import 'edit_project.dart';

/// What the "direct it for me" pass may do. Every item is optional and the result is an ordinary
/// project, so each change can be edited or undone like anything made by hand.
class DirectorOptions {
  const DirectorOptions({
    this.zoom = true,
    this.number = true,
    this.idle = true,
    this.stepLabel,
    this.zoomScale = AutoDirector.zoomScale,
    this.zoomRampMs = kZoomRampMs,
    this.zoomHoldMs = 0,
  });

  /// Zoom smoothly into the area of each marker.
  final bool zoom;

  /// Renumber step markers 1, 2, 3 in time order.
  final bool number;

  /// Speed up stretches where the screen does not change.
  final bool idle;

  /// When set (for example "Bước "), every step marker also gets a caption "Bước 1", "Bước 2" ...
  final String? stepLabel;

  /// How far automatic zooms go in (a wide spread of markers still gets a gentler zoom).
  final double zoomScale;

  /// Time to zoom in and to come back (shorter = snappier).
  final int zoomRampMs;

  /// Extra time the zoom stays after the marker has faded.
  final int zoomHoldMs;

  static const none = DirectorOptions(zoom: false, number: false, idle: false);

  DirectorOptions copyWith({
    bool? zoom,
    bool? number,
    bool? idle,
    Object? stepLabel = _keep,
    double? zoomScale,
    int? zoomRampMs,
    int? zoomHoldMs,
  }) => DirectorOptions(
    zoom: zoom ?? this.zoom,
    number: number ?? this.number,
    idle: idle ?? this.idle,
    stepLabel: identical(stepLabel, _keep)
        ? this.stepLabel
        : stepLabel as String?,
    zoomScale: zoomScale ?? this.zoomScale,
    zoomRampMs: zoomRampMs ?? this.zoomRampMs,
    zoomHoldMs: zoomHoldMs ?? this.zoomHoldMs,
  );

  static const Object _keep = Object();
}

typedef TimeRange = ({int startMs, int endMs});

/// Pure functions that turn what was recorded (markers placed in clean mode, a list of idle
/// stretches) into edits. No platform calls: everything here is unit tested.
abstract final class AutoDirector {
  static const zoomScale = 1.7;
  static const zoomLeadMs = 200;
  static const zoomMergeGapMs = 700;
  static const zoomMaxSpan = 0.5;
  static const idleSpeed = 4.0;
  static const idleMinMs = 1800;
  static const idleEdgeMs = 350;

  /// A project that already carries the markers captured while recording. A mark's time is when the
  /// cue ring starts, which is exactly what [MarkerItem.cueStartMs] means.
  static EditProject draft(EditProject base, List<RecMark> marks) {
    final items = <MarkerItem>[];
    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      final cue = m.tMs.clamp(0, math.max(0, base.durationMs - 300)).toInt();
      items.add(
        MarkerItem(
          id: 'mk_${i}_${m.tMs}',
          spec: m.spec,
          cueStartMs: cue,
          holdMs: m.holdMs,
        ),
      );
    }
    return base.copyWith(markers: items);
  }

  /// The one entry point used after recording and by the editor's "Direct it" button.
  static EditProject direct(
    EditProject p,
    DirectorOptions o, {
    List<TimeRange> idleRanges = const [],
  }) {
    var out = p;
    if (o.number) out = renumber(out);
    if (o.stepLabel != null) out = labelSteps(out, o.stepLabel!);
    if (o.zoom) out = autoZoom(out, o);
    if (o.idle && idleRanges.isNotEmpty) out = speedUpIdle(out, idleRanges);
    return out;
  }

  /// A caption (the prefix, then N) over each step marker while it is shown. Ids are derived from the marker, so
  /// running this again replaces the captions instead of piling up new ones.
  static EditProject labelSteps(EditProject p, String prefix) {
    var out = p;
    for (final m in p.markers.where((m) => m.spec.type == MarkerType.number)) {
      final id = 'step_${m.id}';
      final existing = out.texts.where((t) => t.id == id).firstOrNull;
      final start = math.max(0, m.takeMs - 100);
      final end = math.min(p.durationMs, m.endMs);
      if (end - start < 300) continue;
      out = out.upsertText(
        (existing ??
                TextItem(
                  id: id,
                  x: 0.5,
                  y: 0.1,
                  sizeU: 20,
                  startMs: start,
                  endMs: end,
                  box: const Color(0xB3000000),
                  outline: false,
                  motion: const ItemMotion(enter: EnterExit.pop),
                ))
            .copyWith(
              text: '$prefix${m.spec.number}',
              startMs: start,
              endMs: end,
            ),
      );
    }
    return out;
  }

  /// Step markers get 1, 2, 3 ... in the order they appear.
  static EditProject renumber(EditProject p) {
    final steps =
        p.markers.where((m) => m.spec.type == MarkerType.number).toList()
          ..sort((a, b) => a.cueStartMs.compareTo(b.cueStartMs));
    if (steps.isEmpty) return p;
    final byId = <String, int>{
      for (var i = 0; i < steps.length; i++) steps[i].id: i + 1,
    };
    return p.copyWith(
      markers: [
        for (final m in p.markers)
          byId.containsKey(m.id)
              ? m.copyWith(spec: m.spec.copyWith(number: byId[m.id]))
              : m,
      ],
    );
  }

  /// Where the viewer should look for a marker: same rule as the native renderer's anchor.
  static Offset anchorOf(MarkerSpec s) {
    switch (s.type) {
      case MarkerType.arrow:
        return Offset(s.x1, s.y1);
      case MarkerType.circle:
      case MarkerType.rect:
        return Offset((s.x0 + s.x1) / 2, (s.y0 + s.y1) / 2);
      case MarkerType.pen:
        if (s.points.length < 2) return Offset(s.x0, s.y0);
        var l = s.points[0], r = s.points[0], t = s.points[1], b = s.points[1];
        for (var i = 0; i + 1 < s.points.length; i += 2) {
          l = math.min(l, s.points[i]);
          r = math.max(r, s.points[i]);
          t = math.min(t, s.points[i + 1]);
          b = math.max(b, s.points[i + 1]);
        }
        return Offset((l + r) / 2, (t + b) / 2);
      default:
        return Offset(s.x0, s.y0);
    }
  }

  /// One eased zoom per marker, merged when markers follow each other closely. Existing zoom clips
  /// are kept; a new window that would overlap one of them is dropped (clips must not overlap).
  static EditProject autoZoom(
    EditProject p, [
    DirectorOptions o = const DirectorOptions(),
  ]) {
    final marks = [...p.markers]
      ..sort((a, b) => a.cueStartMs.compareTo(b.cueStartMs));
    final windows = <_Win>[];
    for (final m in marks) {
      final start = math.max(0, m.cueStartMs - zoomLeadMs);
      final end = math.min(p.durationMs, m.endMs + o.zoomHoldMs);
      if (end - start < 800) continue;
      final a = anchorOf(m.spec);
      final last = windows.isEmpty ? null : windows.last;
      if (last != null && start - last.end < zoomMergeGapMs) {
        // Too far apart to share one frame: keep the first zoom only.
        last.tryAdd(a, end);
        continue;
      }
      windows.add(_Win(start, end, a));
    }
    var out = p;
    var n = 0;
    for (final w in windows) {
      final overlaps = out.zooms.any(
        (z) => w.start < z.endMs + 100 && w.end > z.startMs - 100,
      );
      if (overlaps) continue;
      final f = w.focus;
      out = out.upsertZoom(
        ZoomItem(
          id: 'zm_${n++}_${w.start}',
          fx: f.dx,
          fy: f.dy,
          scale: w.scaleCapped(o.zoomScale),
          startMs: w.start,
          endMs: w.end,
          inMs: o.zoomRampMs,
          outMs: o.zoomRampMs,
        ),
      );
    }
    return out;
  }

  /// Source-time ranges to speed up: each idle range, trimmed at both ends, minus the time a marker
  /// or caption is on screen (the viewer must see those at normal speed).
  static List<TimeRange> idleToSpeedUp(EditProject p, List<TimeRange> idle) {
    final busy = <TimeRange>[
      for (final m in p.markers) (startMs: m.cueStartMs, endMs: m.endMs),
      for (final t in p.texts) (startMs: t.startMs, endMs: t.endMs),
    ];
    final out = <TimeRange>[];
    for (final r in idle) {
      var pieces = <TimeRange>[
        (startMs: r.startMs + idleEdgeMs, endMs: r.endMs - idleEdgeMs),
      ];
      for (final b in busy) {
        final next = <TimeRange>[];
        for (final q in pieces) {
          if (b.endMs <= q.startMs || b.startMs >= q.endMs) {
            next.add(q);
            continue;
          }
          if (b.startMs > q.startMs) {
            next.add((startMs: q.startMs, endMs: b.startMs));
          }
          if (b.endMs < q.endMs) next.add((startMs: b.endMs, endMs: q.endMs));
        }
        pieces = next;
      }
      for (final q in pieces) {
        if (q.endMs - q.startMs >= idleMinMs) out.add(q);
      }
    }
    return out;
  }

  /// Splits at each range edge and plays the inside at [idleSpeed].
  static EditProject speedUpIdle(EditProject p, List<TimeRange> idle) {
    var out = p;
    for (final r in idleToSpeedUp(p, idle)) {
      out = out.splitAt(r.startMs).splitAt(r.endMs);
      for (var i = 0; i < out.segments.length; i++) {
        final s = out.segments[i];
        if (s.startMs >= r.startMs && s.endMs <= r.endMs && s.speed == 1) {
          out = out.setSpeed(i, idleSpeed);
        }
      }
    }
    return out;
  }
}

class _Win {
  _Win(this.start, this.end, Offset a)
    : minX = a.dx,
      maxX = a.dx,
      minY = a.dy,
      maxY = a.dy;
  final int start;
  int end;
  double minX, maxX, minY, maxY;

  void tryAdd(Offset a, int newEnd) {
    final nx0 = math.min(minX, a.dx), nx1 = math.max(maxX, a.dx);
    final ny0 = math.min(minY, a.dy), ny1 = math.max(maxY, a.dy);
    if (math.max(nx1 - nx0, ny1 - ny0) > AutoDirector.zoomMaxSpan) return;
    minX = nx0;
    maxX = nx1;
    minY = ny0;
    maxY = ny1;
    end = math.max(end, newEnd);
  }

  Offset get focus => Offset((minX + maxX) / 2, (minY + maxY) / 2);

  /// A wide spread needs a gentler zoom so both targets stay in frame.
  double scaleCapped(double cap) {
    final span = math.max(maxX - minX, maxY - minY);
    if (span <= 0.05) return cap;
    return (0.8 / (span + 0.25)).clamp(math.min(1.2, cap), cap).toDouble();
  }
}
