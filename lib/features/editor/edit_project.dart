import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

import '../marker/marker_spec.dart';
import '../marker/marker_timing.dart';
import 'audio_track.dart';
import 'overlay_items.dart';
import 'overlay_motion.dart';
import 'picture_look.dart';
import 'segment.dart';

export 'audio_track.dart';
export 'overlay_items.dart';
export 'overlay_motion.dart';
export 'picture_look.dart';
export 'segment.dart';

/// Pure project model + operations. No Flutter widgets, no platform calls: everything here is
/// unit tested. Times are SOURCE milliseconds except where a name says `out` (timeline time =
/// the edited video: kept segments back to back, each stretched by 1/speed).

/// A marker on the timeline. [cueStartMs] is when the cue ring begins; the "take" (the moment the
/// viewer should see the press) is cueStartMs + [MarkerTiming.cueMs].
class MarkerItem {
  const MarkerItem({
    required this.id,
    required this.spec,
    required this.cueStartMs,
    this.holdMs = 2000,
  });
  final String id;
  final MarkerSpec spec;
  final int cueStartMs;
  final int holdMs;

  int get takeMs => cueStartMs + MarkerTiming.cueMs;
  int get endMs => takeMs + holdMs + MarkerTiming.fadeMs;

  MarkerItem copyWith({MarkerSpec? spec, int? cueStartMs, int? holdMs}) =>
      MarkerItem(
        id: id,
        spec: spec ?? this.spec,
        cueStartMs: cueStartMs ?? this.cueStartMs,
        holdMs: holdMs ?? this.holdMs,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'spec': spec.toMap(),
    'cueStartMs': cueStartMs,
    'holdMs': holdMs,
  };
  factory MarkerItem.fromJson(Map<String, dynamic> j) => MarkerItem(
    id: j['id'] as String,
    spec: MarkerSpec.fromMap(j['spec'] as Map<String, dynamic>),
    cueStartMs: j['cueStartMs'] as int,
    holdMs: j['holdMs'] as int,
  );
}

/// Fonts the text overlays can use. Barlow is bundled with the app; the rest are Android's own
/// families, so they cost no storage.
enum TextFont { barlow, sans, condensed, serif, mono, cursive }

enum TextAlignment { left, center, right }

/// One-tap looks for a caption. Only styling changes: text, timing and position stay.
enum TextPreset { classic, subtitle, yellow, neon, clean, label }

extension TextPresetLook on TextPreset {
  TextItem apply(TextItem t) => switch (this) {
    TextPreset.classic => t.copyWith(
      color: const Color(0xFFFFFFFF),
      outline: true,
      box: null,
      shadow: false,
      bold: true,
      sizeU: 22,
    ),
    TextPreset.subtitle => t.copyWith(
      color: const Color(0xFFFFFFFF),
      outline: false,
      box: const Color(0xB3000000),
      shadow: false,
      bold: true,
      sizeU: 18,
    ),
    TextPreset.yellow => t.copyWith(
      color: const Color(0xFFFFD60A),
      outline: true,
      box: null,
      shadow: true,
      bold: true,
      sizeU: 22,
    ),
    TextPreset.neon => t.copyWith(
      color: const Color(0xFF2DE2FF),
      outline: false,
      box: null,
      shadow: true,
      bold: true,
      sizeU: 24,
    ),
    TextPreset.clean => t.copyWith(
      color: const Color(0xFFFFFFFF),
      outline: false,
      box: null,
      shadow: true,
      bold: false,
      sizeU: 20,
    ),
    TextPreset.label => t.copyWith(
      color: const Color(0xFF111111),
      outline: false,
      box: const Color(0xE6FFFFFF),
      shadow: false,
      bold: true,
      sizeU: 18,
    ),
  };
}

class TextItem {
  const TextItem({
    required this.id,
    this.text = '',
    this.color = const Color(0xFFFFFFFF),
    this.sizeU = 22,
    this.x = 0.5,
    this.y = 0.5,
    required this.startMs,
    required this.endMs,
    this.bold = true,
    this.font = TextFont.barlow,
    this.outline = true,
    this.box,
    this.shadow = false,
    this.align = TextAlignment.center,
    this.rotation = 0,
    this.opacity = 1,
    this.motion = ItemMotion.fadeOnly,
  });
  final String id;
  final String text;
  final Color color;
  final double sizeU;
  final double x;
  final double y;
  final int startMs;
  final int endMs;
  final bool bold;
  final TextFont font;

  /// A contrasting outline so the text reads on any picture.
  final bool outline;

  /// Background box colour (with its own alpha), or null for none.
  final Color? box;
  final bool shadow;
  final TextAlignment align;

  /// Degrees clockwise.
  final double rotation;
  final double opacity;
  final ItemMotion motion;

  TextItem copyWith({
    String? text,
    Color? color,
    double? sizeU,
    double? x,
    double? y,
    int? startMs,
    int? endMs,
    bool? bold,
    TextFont? font,
    bool? outline,
    Object? box = _keepBox,
    bool? shadow,
    TextAlignment? align,
    double? rotation,
    double? opacity,
    ItemMotion? motion,
  }) => TextItem(
    id: id,
    text: text ?? this.text,
    color: color ?? this.color,
    sizeU: sizeU ?? this.sizeU,
    x: x ?? this.x,
    y: y ?? this.y,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    bold: bold ?? this.bold,
    font: font ?? this.font,
    outline: outline ?? this.outline,
    box: identical(box, _keepBox) ? this.box : box as Color?,
    shadow: shadow ?? this.shadow,
    align: align ?? this.align,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    motion: motion ?? this.motion,
  );
  static const Object _keepBox = Object();

  /// The shape the native renderer / exporter expects.
  Map<String, Object> toNative() => {
    'text': text,
    'color': color.toARGB32(),
    'sizeU': sizeU,
    'x': x,
    'y': y,
    'startMs': startMs,
    'endMs': endMs,
    'bold': bold,
    'font': font.name,
    'outline': outline,
    'box': ?box?.toARGB32(),
    'shadow': shadow,
    'align': align.name,
    'rotation': rotation,
    'opacity': opacity,
    'motion': motion.toJson(),
  };

  /// What changes the rendered bitmap (not where or when it is shown).
  String get lookKey =>
      '$text|${color.toARGB32()}|$sizeU|$bold|${font.name}|$outline|${box?.toARGB32()}|$shadow|${align.name}';

  Map<String, Object> toJson() => {'id': id, ...toNative()};
  factory TextItem.fromJson(Map<String, dynamic> j) => TextItem(
    id: j['id'] as String,
    text: j['text'] as String,
    color: Color(j['color'] as int),
    sizeU: (j['sizeU'] as num).toDouble(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    startMs: j['startMs'] as int,
    endMs: j['endMs'] as int,
    bold: j['bold'] as bool,
    font: TextFont.values.firstWhere(
      (e) => e.name == j['font'],
      orElse: () => TextFont.barlow,
    ),
    outline: j['outline'] as bool? ?? true,
    box: j['box'] == null ? null : Color(j['box'] as int),
    shadow: j['shadow'] as bool? ?? false,
    align: TextAlignment.values.firstWhere(
      (e) => e.name == j['align'],
      orElse: () => TextAlignment.center,
    ),
    rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
    motion: ItemMotion.fromJson(j['motion'] as Map<String, dynamic>?),
  );
}

/// Opaque block that hides sensitive content (a real blur is not available in the export engine).
/// What a rectangle on the picture does: hide it with a block, blur it, pixelate it, or dim everything
/// else so the rectangle stands out (spotlight).
enum CoverStyle { solid, blur, mosaic, spotlight }

class CoverItem {
  const CoverItem({
    required this.id,
    this.x0 = 0.2,
    this.y0 = 0.45,
    this.x1 = 0.8,
    this.y1 = 0.55,
    required this.startMs,
    required this.endMs,
    this.color = const Color(0xFF0E1116),
    this.style = CoverStyle.solid,
    this.strength = 0.5,
    this.end,
  });
  final String id;
  final double x0, y0, x1, y1;
  final int startMs;
  final int endMs;
  final Color color;
  final CoverStyle style;

  /// 0..1: how strong the blur, mosaic or dimming is (unused by [CoverStyle.solid]).
  final double strength;

  /// Where the rectangle ends up, or null to stay put. It glides there, eased, over the whole clip.
  final Rect? end;

  Rect get startRect => Rect.fromLTRB(x0, y0, x1, y1);

  /// The rectangle at source time [t]. Mirror of RegionMath.rectAt in RegionFx.kt.
  Rect rectAt(int t) {
    final e = end;
    if (e == null) return startRect;
    final len = math.max(1, endMs - startMs);
    final k = _smoothStep((t - startMs) / len);
    return Rect.lerp(startRect, e, k)!;
  }

  /// The start or end rectangle (what the panel and dragging edit).
  Rect editRect(bool atEnd) => atEnd && end != null ? end! : startRect;

  CoverItem withRect(Rect r, {required bool atEnd}) => atEnd && end != null
      ? copyWith(end: r)
      : copyWith(x0: r.left, y0: r.top, x1: r.right, y1: r.bottom);

  CoverItem copyWith({
    double? x0,
    double? y0,
    double? x1,
    double? y1,
    int? startMs,
    int? endMs,
    Color? color,
    CoverStyle? style,
    double? strength,
    Object? end = _keepEnd,
  }) => CoverItem(
    id: id,
    x0: x0 ?? this.x0,
    y0: y0 ?? this.y0,
    x1: x1 ?? this.x1,
    y1: y1 ?? this.y1,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    color: color ?? this.color,
    style: style ?? this.style,
    strength: strength ?? this.strength,
    end: identical(end, _keepEnd) ? this.end : end as Rect?,
  );

  Map<String, Object> toNative() => {
    'x0': x0,
    'y0': y0,
    'x1': x1,
    'y1': y1,
    'startMs': startMs,
    'endMs': endMs,
    'color': color.toARGB32(),
    'style': style.name,
    'strength': strength,
    if (end != null) ...{
      'ex0': end!.left,
      'ey0': end!.top,
      'ex1': end!.right,
      'ey1': end!.bottom,
    },
  };

  Map<String, Object> toJson() => {'id': id, ...toNative()};
  factory CoverItem.fromJson(Map<String, dynamic> j) => CoverItem(
    id: j['id'] as String,
    x0: (j['x0'] as num).toDouble(),
    y0: (j['y0'] as num).toDouble(),
    x1: (j['x1'] as num).toDouble(),
    y1: (j['y1'] as num).toDouble(),
    startMs: j['startMs'] as int,
    endMs: j['endMs'] as int,
    color: Color(j['color'] as int),
    style: CoverStyle.values.firstWhere(
      (s) => s.name == j['style'],
      orElse: () => CoverStyle.solid,
    ),
    strength: ((j['strength'] as num?) ?? 0.5).toDouble().clamp(0.0, 1.0),
    end: j['ex0'] == null
        ? null
        : Rect.fromLTRB(
            (j['ex0'] as num).toDouble(),
            (j['ey0'] as num).toDouble(),
            (j['ex1'] as num).toDouble(),
            (j['ey1'] as num).toDouble(),
          ),
  );
}

const Object _keepEnd = Object();

double _smoothStep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Default time a zoom takes to reach full scale and to come back. Mirror of ZoomMath.RAMP_MS.
const int kZoomRampMs = 350;

class ZoomItem {
  const ZoomItem({
    required this.id,
    this.fx = 0.5,
    this.fy = 0.5,
    this.scale = 2,
    required this.startMs,
    required this.endMs,
    this.inMs = kZoomRampMs,
    this.outMs = kZoomRampMs,
  });
  final String id;
  final double fx, fy;
  final double scale;
  final int startMs;
  final int endMs;

  /// How long the zoom takes to reach full scale / to come back (shorter = faster).
  final int inMs;
  final int outMs;

  ZoomItem copyWith({
    double? fx,
    double? fy,
    double? scale,
    int? startMs,
    int? endMs,
    int? inMs,
    int? outMs,
  }) => ZoomItem(
    id: id,
    fx: fx ?? this.fx,
    fy: fy ?? this.fy,
    scale: scale ?? this.scale,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    inMs: inMs ?? this.inMs,
    outMs: outMs ?? this.outMs,
  );

  Map<String, Object> toNative() => {
    'fx': fx,
    'fy': fy,
    'scale': scale,
    'startMs': startMs,
    'endMs': endMs,
    'inMs': inMs,
    'outMs': outMs,
  };
  Map<String, Object> toJson() => {'id': id, ...toNative()};
  factory ZoomItem.fromJson(Map<String, dynamic> j) => ZoomItem(
    id: j['id'] as String,
    fx: (j['fx'] as num).toDouble(),
    fy: (j['fy'] as num).toDouble(),
    scale: (j['scale'] as num).toDouble(),
    startMs: j['startMs'] as int,
    endMs: j['endMs'] as int,
    inMs: (j['inMs'] as int?) ?? kZoomRampMs,
    outMs: (j['outMs'] as int?) ?? kZoomRampMs,
  );
}

class EditProject {
  const EditProject({
    required this.id,
    required this.sourceUri,
    required this.name,
    required this.durationMs,
    required this.frameW,
    required this.frameH,
    required this.segments,
    this.markers = const [],
    this.texts = const [],
    this.covers = const [],
    this.zooms = const [],
    this.images = const [],
    this.shapes = const [],
    this.audioTracks = const [],
    this.pips = const [],
    this.look = PictureLook.identity,
    this.muteFast = true,
  });

  final String id;
  final String sourceUri;
  final String name;
  final int durationMs;
  final int frameW;
  final int frameH;
  final List<Segment> segments;
  final List<MarkerItem> markers;
  final List<TextItem> texts;
  final List<CoverItem> covers;
  final List<ZoomItem> zooms;
  final List<ImageItem> images;
  final List<ShapeItem> shapes;
  final List<AudioTrack> audioTracks;
  final List<PipItem> pips;

  /// Rotation, crop, output shape and colour of the picture.
  final PictureLook look;

  /// Sound is dropped while a clip plays faster than 2x (sped-up speech is only noise).
  final bool muteFast;

  /// The volume a segment really has, with [muteFast] applied.
  double effectiveVolume(Segment s) =>
      muteFast && s.meanSpeed > 2.0001 ? 0 : s.volume;

  /// Gain of [s] at output offset [out] (volume, fades, fast-speed mute).
  double gainOf(Segment s, int out) =>
      muteFast && s.meanSpeed > 2.0001 ? 0 : s.gainAt(out, s.outLengthMs);

  /// A fresh project that keeps the whole source.
  factory EditProject.fresh({
    required String sourceUri,
    required String name,
    required int durationMs,
    required int frameW,
    required int frameH,
  }) => EditProject(
    id: sourceUri,
    sourceUri: sourceUri,
    name: name,
    durationMs: durationMs,
    frameW: frameW,
    frameH: frameH,
    segments: [Segment(startMs: 0, endMs: durationMs)],
  );

  EditProject copyWith({
    List<Segment>? segments,
    List<MarkerItem>? markers,
    List<TextItem>? texts,
    List<CoverItem>? covers,
    List<ZoomItem>? zooms,
    List<ImageItem>? images,
    List<ShapeItem>? shapes,
    List<AudioTrack>? audioTracks,
    List<PipItem>? pips,
    PictureLook? look,
    bool? muteFast,
  }) => EditProject(
    id: id,
    sourceUri: sourceUri,
    name: name,
    durationMs: durationMs,
    frameW: frameW,
    frameH: frameH,
    segments: segments ?? this.segments,
    markers: markers ?? this.markers,
    texts: texts ?? this.texts,
    covers: covers ?? this.covers,
    zooms: zooms ?? this.zooms,
    images: images ?? this.images,
    shapes: shapes ?? this.shapes,
    audioTracks: audioTracks ?? this.audioTracks,
    pips: pips ?? this.pips,
    look: look ?? this.look,
    muteFast: muteFast ?? this.muteFast,
  );

  // ---- timeline mapping -----------------------------------------------------------------------

  int get outDurationMs => segments.fold(0, (a, s) => a + s.outLengthMs);

  /// Index of the first segment (in sequence order) that holds source time [t], or -1 if it was
  /// cut out. Stills and blanks hold no source time.
  int segmentAtSource(int t) {
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (!s.isStill && t >= s.startMs && t < s.endMs) return i;
    }
    return -1;
  }

  /// Output-timeline time of source time [t]: the first segment (sequence order) that holds it.
  /// A time in a cut-out gap snaps to the start of the next kept material (by source time).
  int sourceToOut(int t) {
    var acc = 0;
    final starts = segmentOutStarts;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (!s.isStill && t >= s.startMs && t <= s.endMs) {
        return starts[i] + s.outAtSource(t);
      }
      acc = starts[i] + s.outLengthMs;
    }
    // Not inside any segment: snap forward to the nearest kept start after t.
    int? bestStart;
    var bestOut = acc;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.isStill || s.startMs < t) continue;
      if (bestStart == null || s.startMs < bestStart) {
        bestStart = s.startMs;
        bestOut = starts[i] + s.outAtSource(s.reverse ? s.endMs : s.startMs);
      }
    }
    return bestOut;
  }

  /// Index of the segment playing at output time [out] (the last one at or past the end).
  int segmentAtOut(int out) {
    var acc = 0;
    for (var i = 0; i < segments.length; i++) {
      final len = segments[i].outLengthMs;
      if (out < acc + len) return i;
      acc += len;
    }
    return segments.isEmpty ? -1 : segments.length - 1;
  }

  /// Source time of output time [out], clamped into the kept material.
  int outToSource(int out) {
    final i = segmentAtOut(out);
    if (i < 0) return 0;
    final starts = segmentOutStarts;
    final s = segments[i];
    final local = (out - starts[i]).clamp(0, s.outLengthMs);
    return s.sourceAtOut(local);
  }

  /// Output start time of each segment.
  List<int> get segmentOutStarts {
    final r = <int>[];
    var acc = 0;
    for (final s in segments) {
      r.add(acc);
      acc += s.outLengthMs;
    }
    return r;
  }

  /// First kept source time at or after [t] (used to skip cut-out gaps during playback), or null.
  int? nextKeptStart(int t) {
    int? best;
    for (final s in segments) {
      if (s.isStill) continue;
      if (t < s.endMs) {
        final c = t < s.startMs ? s.startMs : t;
        if (best == null || c < best) best = c;
      }
    }
    return best;
  }

  /// Half-length (ms) of the transition into segment [i], limited by both neighbours so the
  /// transition never eats more than 45 % of either clip. 0 = no transition.
  int transitionHalfMs(int i) {
    if (i <= 0 || i >= segments.length) return 0;
    final tr = segments[i].transition;
    if (tr == null || tr.isNone) return 0;
    final cap =
        (math.min(segments[i - 1].outLengthMs, segments[i].outLengthMs) * 0.45)
            .floor();
    return math.min(tr.ms ~/ 2, cap);
  }

  /// The picture change at output time [out] caused by transitions (a transition leaves the
  /// preceding clip's last half and enters the next clip's first half).
  TransitionLook transitionLookAt(int out) {
    final i = segmentAtOut(out);
    if (i < 0) return TransitionLook.none;
    final starts = segmentOutStarts;
    final local = out - starts[i];
    final len = segments[i].outLengthMs;
    var look = TransitionLook.none;
    final inHalf = transitionHalfMs(i);
    if (inHalf > 0 && local < inHalf) {
      look = TransitionLook.of(
        segments[i].transition!.kind,
        local / inHalf,
        incoming: true,
      );
    }
    final outHalf = transitionHalfMs(i + 1);
    if (outHalf > 0 && len - local < outHalf) {
      look = TransitionLook.strongest(
        look,
        TransitionLook.of(
          segments[i + 1].transition!.kind,
          (len - local) / outHalf,
          incoming: false,
        ),
      );
    }
    return look;
  }

  // ---- editing operations (all return a new project) ----------------------------------------

  static const minSegmentMs = 200;

  /// Splits the segment under source time [t]. No-op if too close to an edge.
  EditProject splitAt(int t) {
    final i = segmentAtSource(t);
    return i < 0 ? this : splitSegmentAt(i, t);
  }

  /// Splits segment [i] at source time [t] (stills cannot be split).
  EditProject splitSegmentAt(int i, int t) {
    if (i < 0 || i >= segments.length) return this;
    final s = segments[i];
    if (s.isStill) return this;
    if (t - s.startMs < minSegmentMs || s.endMs - t < minSegmentMs) return this;
    // The sequence is in PLAY order: a reversed clip plays its later half first.
    final left = s.copyWith(endMs: t);
    final right = s.copyWith(startMs: t);
    var first = (s.reverse ? right : left).copyWith(fadeOutMs: 0);
    var second = (s.reverse ? left : right).copyWith(
      fadeInMs: 0,
      transition: null,
    );
    if (s.isRamp) {
      // A speed ramp keeps its shape: each half gets the speed the ramp has at the cut.
      final pCut = (s.reverse ? s.endMs - t : t - s.startMs).toDouble();
      final vCut = s.speed + (s.speedEnd! - s.speed) * (pCut / s.lengthMs);
      first = first.copyWith(speed: s.speed, speedEnd: vCut);
      second = second.copyWith(speed: vCut, speedEnd: s.speedEnd);
    }
    final next = [...segments]..replaceRange(i, i + 1, [first, second]);
    return copyWith(segments: next);
  }

  /// Splits at output time [out] (the right call once segments can be reordered or repeated).
  EditProject splitAtOut(int out) {
    final i = segmentAtOut(out);
    if (i < 0) return this;
    final s = segments[i];
    if (s.isStill) return this;
    final starts = segmentOutStarts;
    final t = s.sourceAtOut((out - starts[i]).clamp(0, s.outLengthMs));
    return splitSegmentAt(i, t);
  }

  /// Removes a segment (ripple: later segments move up). The last one cannot be removed.
  EditProject deleteSegment(int i) {
    if (segments.length <= 1 || i < 0 || i >= segments.length) return this;
    final next = [...segments]..removeAt(i);
    // The first segment never carries a transition.
    if (next.isNotEmpty && next.first.transition != null) {
      next[0] = next.first.copyWith(transition: null);
    }
    return copyWith(segments: next);
  }

  /// Removes several segments at once (ripple). At least one segment always stays.
  EditProject deleteSegments(Set<int> idx) {
    if (idx.isEmpty) return this;
    final keep = [
      for (var i = 0; i < segments.length; i++)
        if (!idx.contains(i)) segments[i],
    ];
    if (keep.isEmpty) return this;
    if (keep.first.transition != null) {
      keep[0] = keep.first.copyWith(transition: null);
    }
    return copyWith(segments: keep);
  }

  /// Replaces segment [i] by a black silent gap of the same output length (nothing moves).
  EditProject blankSegment(int i) {
    if (i < 0 || i >= segments.length) return this;
    final s = segments[i];
    final out = s.outLengthMs;
    return copyWith(
      segments: [...segments]
        ..[i] = Segment(
          startMs: 0,
          endMs: 0,
          freezeMs: out < minSegmentMs ? minSegmentMs : out,
          blank: true,
          transition: s.transition,
        ),
    );
  }

  /// Inserts a copy of segment [i] right after it.
  EditProject duplicateSegment(int i) {
    if (i < 0 || i >= segments.length) return this;
    final copy = segments[i].copyWith(transition: null);
    return copyWith(segments: [...segments]..insert(i + 1, copy));
  }

  /// Inserts a freeze frame of source time [t] lasting [ms] after segment [i].
  EditProject insertFreeze(int i, int t, {int ms = 2000}) =>
      insertFreezeAt(i + 1, t, ms: ms);

  /// Inserts a freeze frame at sequence position [pos] (0 = before everything).
  EditProject insertFreezeAt(int pos, int t, {int ms = 2000}) {
    if (pos < 0 || pos > segments.length) return this;
    final at = t.clamp(0, durationMs - 1);
    final still = Segment(
      startMs: at,
      endMs: at + 1,
      freezeMs: ms.clamp(minSegmentMs, 30000),
    );
    final next = [...segments]..insert(pos, still);
    if (next.first.transition != null) {
      next[0] = next.first.copyWith(transition: null);
    }
    return copyWith(segments: next);
  }

  EditProject setFreezeMs(int i, int ms) {
    if (i < 0 || i >= segments.length || !segments[i].isStill) return this;
    return copyWith(
      segments: [...segments]
        ..[i] = segments[i].copyWith(freezeMs: ms.clamp(minSegmentMs, 30000)),
    );
  }

  EditProject setSpeed(int i, double speed) {
    if (i < 0 || i >= segments.length || segments[i].isStill) return this;
    return copyWith(
      segments: [...segments]
        ..[i] = segments[i].copyWith(
          speed: speed.clamp(Segment.minSpeed, Segment.maxSpeed),
          speedEnd: null,
        ),
    );
  }

  /// A ramp from [from] to [to] across the segment.
  EditProject setSpeedRamp(int i, double from, double to) {
    if (i < 0 || i >= segments.length || segments[i].isStill) return this;
    return copyWith(
      segments: [...segments]
        ..[i] = segments[i].copyWith(
          speed: from.clamp(Segment.minSpeed, Segment.maxSpeed),
          speedEnd: to.clamp(Segment.minSpeed, Segment.maxSpeed),
        ),
    );
  }

  EditProject setReverse(int i, bool reverse) {
    if (i < 0 || i >= segments.length || segments[i].isStill) return this;
    return copyWith(
      segments: [...segments]..[i] = segments[i].copyWith(reverse: reverse),
    );
  }

  EditProject setAudio(int i, {double? volume, int? fadeInMs, int? fadeOutMs}) {
    if (i < 0 || i >= segments.length) return this;
    return copyWith(
      segments: [...segments]
        ..[i] = segments[i].copyWith(
          volume: volume?.clamp(0.0, 2.0),
          fadeInMs: fadeInMs?.clamp(0, 5000),
          fadeOutMs: fadeOutMs?.clamp(0, 5000),
        ),
    );
  }

  /// Sets the transition INTO segment [i] (the first segment has none).
  EditProject setTransition(int i, Transition? t) {
    if (i <= 0 || i >= segments.length) return this;
    final tr = (t == null || t.isNone)
        ? null
        : Transition(t.kind, t.ms.clamp(Transition.minMs, Transition.maxMs));
    return copyWith(
      segments: [...segments]..[i] = segments[i].copyWith(transition: tr),
    );
  }

  /// The same transition on every cut.
  EditProject setAllTransitions(Transition? t) {
    final next = [...segments];
    for (var i = 1; i < next.length; i++) {
      final tr = (t == null || t.isNone)
          ? null
          : Transition(t.kind, t.ms.clamp(Transition.minMs, Transition.maxMs));
      next[i] = next[i].copyWith(transition: tr);
    }
    return copyWith(segments: next);
  }

  /// Trims the edges of segment [i] (source time), keeping at least [minSegmentMs].
  EditProject trimSegment(int i, {int? startMs, int? endMs}) {
    if (i < 0 || i >= segments.length || segments[i].isStill) return this;
    final s = segments[i];
    final ns = (startMs ?? s.startMs).clamp(0, s.endMs - minSegmentMs);
    final ne = (endMs ?? s.endMs).clamp(ns + minSegmentMs, durationMs);
    return copyWith(
      segments: [...segments]..[i] = s.copyWith(startMs: ns, endMs: ne),
    );
  }

  /// Moves a segment one place earlier (-1) or later (+1) in the sequence.
  EditProject moveSegment(int i, int delta) => moveSegmentTo(i, i + delta);

  /// Moves segment [from] so it ends up at index [to].
  EditProject moveSegmentTo(int from, int to) {
    if (from < 0 ||
        to < 0 ||
        from >= segments.length ||
        to >= segments.length ||
        from == to) {
      return this;
    }
    final next = [...segments];
    final s = next.removeAt(from);
    next.insert(to, s);
    if (next.first.transition != null) {
      next[0] = next.first.copyWith(transition: null);
    }
    return copyWith(segments: next);
  }

  /// Snap points on the output timeline (segment boundaries, markers, overlays): used while dragging.
  List<int> get snapPointsOut {
    final pts = <int>{0, outDurationMs, ...segmentOutStarts};
    for (final m in markers) {
      pts
        ..add(sourceToOut(m.cueStartMs))
        ..add(sourceToOut(m.takeMs))
        ..add(sourceToOut(m.endMs));
    }
    for (final t in texts) {
      pts
        ..add(sourceToOut(t.startMs))
        ..add(sourceToOut(t.endMs));
    }
    for (final c in covers) {
      pts
        ..add(sourceToOut(c.startMs))
        ..add(sourceToOut(c.endMs));
    }
    for (final z in zooms) {
      pts
        ..add(sourceToOut(z.startMs))
        ..add(sourceToOut(z.endMs));
    }
    for (final i in images) {
      pts
        ..add(sourceToOut(i.startMs))
        ..add(sourceToOut(i.endMs));
    }
    for (final sh in shapes) {
      pts
        ..add(sourceToOut(sh.startMs))
        ..add(sourceToOut(sh.endMs));
    }
    final total = outDurationMs;
    for (final p in pips) {
      pts
        ..add(p.startOutMs)
        ..add(p.startOutMs + p.playMs(total));
    }
    for (final a in audioTracks) {
      pts
        ..add(a.startOutMs)
        ..add(a.endOutMs(total));
    }
    return pts.toList()..sort();
  }

  /// [value] pulled to the nearest snap point within [within] ms, else unchanged.
  static int snapTo(int value, List<int> points, int within) {
    var best = value;
    var bestD = within + 1;
    for (final p in points) {
      final d = (p - value).abs();
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return bestD <= within ? best : value;
  }

  // ---- overlays -------------------------------------------------------------------------------

  EditProject upsertMarker(MarkerItem m) =>
      copyWith(markers: _upsert(markers, m, (e) => e.id));
  EditProject upsertText(TextItem m) =>
      copyWith(texts: _upsert(texts, m, (e) => e.id));
  EditProject upsertCover(CoverItem m) =>
      copyWith(covers: _upsert(covers, m, (e) => e.id));
  EditProject upsertZoom(ZoomItem m) =>
      copyWith(zooms: _upsert(zooms, m, (e) => e.id));

  EditProject upsertImage(ImageItem m) =>
      copyWith(images: _upsert(images, m, (e) => e.id));
  EditProject upsertShape(ShapeItem m) =>
      copyWith(shapes: _upsert(shapes, m, (e) => e.id));
  EditProject upsertAudio(AudioTrack m) =>
      copyWith(audioTracks: _upsert(audioTracks, m, (e) => e.id));
  EditProject upsertPip(PipItem m) =>
      copyWith(pips: _upsert(pips, m, (e) => e.id));

  EditProject removeOverlay(String id) => copyWith(
    images: images.where((e) => e.id != id).toList(),
    shapes: shapes.where((e) => e.id != id).toList(),
    audioTracks: audioTracks.where((e) => e.id != id).toList(),
    pips: pips.where((e) => e.id != id).toList(),
    markers: markers.where((e) => e.id != id).toList(),
    texts: texts.where((e) => e.id != id).toList(),
    covers: covers.where((e) => e.id != id).toList(),
    zooms: zooms.where((e) => e.id != id).toList(),
  );

  static List<T> _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((e) => id(e) == id(item));
    return i < 0 ? [...list, item] : ([...list]..[i] = item);
  }

  /// Next free step number among number markers (1, 2, 3 ...).
  int get nextStepNumber {
    final used = markers
        .where((m) => m.spec.type == MarkerType.number)
        .map((m) => m.spec.number)
        .toSet();
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return n;
  }

  // ---- persistence + export -------------------------------------------------------------------

  String encode() => jsonEncode({
    'v': 2,
    'id': id,
    'sourceUri': sourceUri,
    'name': name,
    'durationMs': durationMs,
    'frameW': frameW,
    'frameH': frameH,
    'segments': segments.map((e) => e.toJson()).toList(),
    'markers': markers.map((e) => e.toJson()).toList(),
    'texts': texts.map((e) => e.toJson()).toList(),
    'covers': covers.map((e) => e.toJson()).toList(),
    'zooms': zooms.map((e) => e.toJson()).toList(),
    'images': images.map((e) => e.toJson()).toList(),
    'shapes': shapes.map((e) => e.toJson()).toList(),
    'audioTracks': audioTracks.map((e) => e.toJson()).toList(),
    'pips': pips.map((e) => e.toJson()).toList(),
    'look': look.toJson(),
    'muteFast': muteFast,
  });

  factory EditProject.decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? const [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return EditProject(
      id: j['id'] as String,
      sourceUri: j['sourceUri'] as String,
      name: j['name'] as String,
      durationMs: j['durationMs'] as int,
      frameW: j['frameW'] as int,
      frameH: j['frameH'] as int,
      segments: list('segments', Segment.fromJson),
      markers: list('markers', MarkerItem.fromJson),
      texts: list('texts', TextItem.fromJson),
      covers: list('covers', CoverItem.fromJson),
      zooms: list('zooms', ZoomItem.fromJson),
      images: list('images', ImageItem.fromJson),
      shapes: list('shapes', ShapeItem.fromJson),
      audioTracks: list('audioTracks', AudioTrack.fromJson),
      pips: list('pips', PipItem.fromJson),
      look: PictureLook.fromJson(j['look'] as Map<String, dynamic>?),
      muteFast: j['muteFast'] as bool? ?? true,
    );
  }

  /// One segment for the exporter: its own fields plus what the exporter cannot derive alone
  /// (the transitions around it, already limited by the neighbouring clips).
  Map<String, Object> _segmentExport(int i) {
    final s = segments[i];
    final next = i + 1 < segments.length ? segments[i + 1].transition : null;
    final inHalf = transitionHalfMs(i);
    final outHalf = transitionHalfMs(i + 1);
    return {
      ...s.toJson(),
      'volume': effectiveVolume(s),
      if (s.transition != null && inHalf > 0)
        'transInKind': s.transition!.kind.name,
      if (inHalf > 0) 'transInHalfMs': inHalf,
      if (next != null && outHalf > 0) 'transOutKind': next.kind.name,
      if (outHalf > 0) 'transOutHalfMs': outHalf,
    };
  }

  /// Size of the picture after rotation (the frame markers, covers and zoom live in).
  ({int w, int h}) get pictureDims {
    final p = look.pictureSize(frameW, frameH);
    return (w: p.width.round(), h: p.height.round());
  }

  /// Size of the output frame (where text, images and shapes live), before the quality scaling.
  ({int w, int h}) get outDims {
    final o = look.outputSize(frameW, frameH);
    return (w: o.width.round(), h: o.height.round());
  }

  /// Payload for the native exporter.
  Map<String, Object> toExportMap({
    required int outHeight,
    required int bitrate,
    bool gif = false,
    int gifFps = 10,
    int gifWidth = 480,
  }) {
    final pic = pictureDims;
    final out = outDims;
    final total = outDurationMs;
    final cropped = look.croppedSize(frameW, frameH);
    final wanted = look.aspect.ratio;
    // Only ask for a different shape when the output is not simply the cropped picture.
    final aspect =
        wanted != null &&
            (wanted - cropped.width / cropped.height).abs() > 0.002
        ? wanted
        : 0.0;
    return {
      'sourceUri': sourceUri,
      'frameW': pic.w,
      'frameH': pic.h,
      'outHeight': outHeight,
      'bitrate': bitrate,
      'segments': [for (var i = 0; i < segments.length; i++) _segmentExport(i)],
      'markers': markers
          .map(
            (m) => {
              'spec': m.spec.toMap(),
              'cueStartMs': m.cueStartMs,
              'holdMs': m.holdMs,
            },
          )
          .toList(),
      'texts': texts.map((e) => e.toNative()).toList(),
      'covers': covers.map((e) => e.toNative()).toList(),
      'zooms': zooms.map((e) => e.toNative()).toList(),
      'images': images.map((e) => e.toNative()).toList(),
      'shapes': shapes.map((e) => e.toNative()).toList(),
      'pips': [
        for (final p in pips)
          if (p.playMs(total) > 0)
            {
              'path': p.path,
              'isVideo': p.isVideo,
              'pxW': p.pxW,
              'pxH': p.pxH,
              'x': p.x,
              'y': p.y,
              'widthFrac': p.widthFrac,
              'startOutMs': p.startOutMs,
              'trimStartMs': p.trimStartMs,
              'playMs': p.playMs(total),
              'volume': p.volume,
              'opacity': p.opacity,
            },
      ],
      'audioClips': [
        for (final a in audioTracks)
          if (a.playMs(total) > 0)
            {
              'path': a.path,
              'music': a.kind == AudioKind.music,
              'startOutMs': a.startOutMs,
              'trimStartMs': a.trimStartMs,
              'playMs': a.playMs(total),
              'fileMs': a.fileMs,
              'volume': a.volume,
              'fadeInMs': a.fadeInMs,
              'fadeOutMs': a.fadeOutMs,
              'loop': a.loop,
              'duck': a.duck,
            },
        // The sound of a picture-in-picture video is just another track.
        for (final p in pips)
          if (p.isVideo && p.volume > 0 && p.playMs(total) > 0)
            {
              'path': p.path,
              'music': false,
              'startOutMs': p.startOutMs,
              'trimStartMs': p.trimStartMs,
              'playMs': p.playMs(total),
              'fileMs': p.fileMs,
              'volume': p.volume,
              'fadeInMs': 0,
              'fadeOutMs': 0,
              'loop': false,
              'duck': false,
            },
      ],
      'picture': {
        'srcW': frameW,
        'srcH': frameH,
        'rotation': look.rotation,
        'crop': [
          look.crop.left,
          look.crop.top,
          look.crop.right,
          look.crop.bottom,
        ],
        'aspect': aspect,
        'fill': look.fill,
        'outW': out.w,
        'outH': out.h,
        if (!look.color.isNone) 'color': look.color.matrix4,
      },
      'gif': gif,
      'gifFps': gifFps,
      'gifWidth': gifWidth,
    };
  }
}
