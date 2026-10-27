import 'dart:ui' show Color;

import 'overlay_motion.dart';

/// A picture from the phone placed over the video, in the OUTPUT frame (after crop and aspect).
class ImageItem {
  const ImageItem({
    required this.id,
    required this.path,
    required this.name,
    required this.pxW,
    required this.pxH,
    this.x = 0.5,
    this.y = 0.5,
    this.widthFrac = 0.3,
    this.rotation = 0,
    this.opacity = 1,
    required this.startMs,
    required this.endMs,
    this.motion = ItemMotion.fadeOnly,
  });

  final String id;

  /// A copy inside the app's storage.
  final String path;
  final String name;
  final int pxW;
  final int pxH;

  /// Centre, as fractions of the output frame.
  final double x;
  final double y;

  /// Width as a fraction of the output frame width (the height follows the picture's shape).
  final double widthFrac;
  final double rotation;
  final double opacity;
  final int startMs;
  final int endMs;
  final ItemMotion motion;

  double get aspect => pxW <= 0 || pxH <= 0 ? 1 : pxW / pxH;

  ImageItem copyWith({
    double? x,
    double? y,
    double? widthFrac,
    double? rotation,
    double? opacity,
    int? startMs,
    int? endMs,
    ItemMotion? motion,
  }) => ImageItem(
    id: id,
    path: path,
    name: name,
    pxW: pxW,
    pxH: pxH,
    x: x ?? this.x,
    y: y ?? this.y,
    widthFrac: widthFrac ?? this.widthFrac,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    motion: motion ?? this.motion,
  );

  Map<String, Object> toNative() => {
    'path': path,
    'pxW': pxW,
    'pxH': pxH,
    'x': x,
    'y': y,
    'widthFrac': widthFrac,
    'rotation': rotation,
    'opacity': opacity,
    'startMs': startMs,
    'endMs': endMs,
    'motion': motion.toJson(),
  };

  Map<String, Object> toJson() => {'id': id, 'name': name, ...toNative()};

  factory ImageItem.fromJson(Map<String, dynamic> j) => ImageItem(
    id: j['id'] as String,
    path: j['path'] as String,
    name: j['name'] as String? ?? '',
    pxW: (j['pxW'] as num).toInt(),
    pxH: (j['pxH'] as num).toInt(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    widthFrac: (j['widthFrac'] as num).toDouble(),
    rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
    startMs: (j['startMs'] as num).toInt(),
    endMs: (j['endMs'] as num).toInt(),
    motion: ItemMotion.fromJson(j['motion'] as Map<String, dynamic>?),
  );
}

enum ShapeKind { rect, ellipse, line, arrow, bubble }

/// A drawn shape or a callout bubble, in the OUTPUT frame. The bitmap is drawn by the native
/// renderer (the same one for the preview and the export).
class ShapeItem {
  const ShapeItem({
    required this.id,
    this.kind = ShapeKind.rect,
    this.x = 0.5,
    this.y = 0.5,
    this.w = 0.4,
    this.h = 0.2,
    this.color = const Color(0xFFFFD60A),
    this.strokeU = 4,
    this.filled = false,
    this.text = '',
    this.textColor = const Color(0xFF111111),
    this.tailX = -0.15,
    this.tailY = 0.18,
    this.rotation = 0,
    this.opacity = 1,
    required this.startMs,
    required this.endMs,
    this.motion = ItemMotion.fadeOnly,
  });

  final String id;
  final ShapeKind kind;

  /// Centre and size as fractions of the output frame.
  final double x;
  final double y;
  final double w;
  final double h;
  final Color color;

  /// Stroke width in 1/360 of the frame width.
  final double strokeU;
  final bool filled;

  /// Bubble text.
  final String text;
  final Color textColor;

  /// Bubble tail tip relative to the bubble centre, in fractions of the frame.
  final double tailX;
  final double tailY;
  final double rotation;
  final double opacity;
  final int startMs;
  final int endMs;
  final ItemMotion motion;

  ShapeItem copyWith({
    ShapeKind? kind,
    double? x,
    double? y,
    double? w,
    double? h,
    Color? color,
    double? strokeU,
    bool? filled,
    String? text,
    Color? textColor,
    double? tailX,
    double? tailY,
    double? rotation,
    double? opacity,
    int? startMs,
    int? endMs,
    ItemMotion? motion,
  }) => ShapeItem(
    id: id,
    kind: kind ?? this.kind,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    color: color ?? this.color,
    strokeU: strokeU ?? this.strokeU,
    filled: filled ?? this.filled,
    text: text ?? this.text,
    textColor: textColor ?? this.textColor,
    tailX: tailX ?? this.tailX,
    tailY: tailY ?? this.tailY,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    motion: motion ?? this.motion,
  );

  /// What changes the rendered bitmap.
  String get lookKey =>
      '${kind.name}|$w|$h|${color.toARGB32()}|$strokeU|$filled|$text|${textColor.toARGB32()}|$tailX|$tailY';

  Map<String, Object> toNative() => {
    'kind': kind.name,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'color': color.toARGB32(),
    'strokeU': strokeU,
    'filled': filled,
    'text': text,
    'textColor': textColor.toARGB32(),
    'tailX': tailX,
    'tailY': tailY,
    'rotation': rotation,
    'opacity': opacity,
    'startMs': startMs,
    'endMs': endMs,
    'motion': motion.toJson(),
  };

  Map<String, Object> toJson() => {'id': id, ...toNative()};

  factory ShapeItem.fromJson(Map<String, dynamic> j) => ShapeItem(
    id: j['id'] as String,
    kind: ShapeKind.values.firstWhere(
      (e) => e.name == j['kind'],
      orElse: () => ShapeKind.rect,
    ),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    w: (j['w'] as num).toDouble(),
    h: (j['h'] as num).toDouble(),
    color: Color(j['color'] as int),
    strokeU: (j['strokeU'] as num?)?.toDouble() ?? 4,
    filled: j['filled'] as bool? ?? false,
    text: j['text'] as String? ?? '',
    textColor: Color((j['textColor'] as num?)?.toInt() ?? 0xFF111111),
    tailX: (j['tailX'] as num?)?.toDouble() ?? -0.15,
    tailY: (j['tailY'] as num?)?.toDouble() ?? 0.18,
    rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
    startMs: (j['startMs'] as num).toInt(),
    endMs: (j['endMs'] as num).toInt(),
    motion: ItemMotion.fromJson(j['motion'] as Map<String, dynamic>?),
  );
}

/// A small video or picture shown over the main video (picture in picture), placed on the OUTPUT timeline.
class PipItem {
  const PipItem({
    required this.id,
    required this.path,
    required this.name,
    required this.isVideo,
    required this.fileMs,
    required this.pxW,
    required this.pxH,
    this.x = 0.78,
    this.y = 0.2,
    this.widthFrac = 0.34,
    this.startOutMs = 0,
    this.trimStartMs = 0,
    this.durMs = 4000,
    this.volume = 0,
    this.opacity = 1,
  });

  final String id;
  final String path;
  final String name;
  final bool isVideo;

  /// Length of a video file (0 for pictures).
  final int fileMs;
  final int pxW;
  final int pxH;
  final double x;
  final double y;
  final double widthFrac;
  final int startOutMs;
  final int trimStartMs;

  /// How long it stays on screen (a video stops at its end).
  final int durMs;

  /// Sound of a PiP video, 0 = silent.
  final double volume;
  final double opacity;

  double get aspect => pxW <= 0 || pxH <= 0 ? 1 : pxW / pxH;

  /// How long it really shows inside a video [outMs] long.
  int playMs(int outMs) {
    var d = durMs;
    if (isVideo) {
      final own = fileMs - trimStartMs;
      if (own < d) d = own;
    }
    final room = outMs - startOutMs;
    return d < room ? d : (room < 0 ? 0 : room);
  }

  PipItem copyWith({
    double? x,
    double? y,
    double? widthFrac,
    int? startOutMs,
    int? trimStartMs,
    int? durMs,
    double? volume,
    double? opacity,
  }) => PipItem(
    id: id,
    path: path,
    name: name,
    isVideo: isVideo,
    fileMs: fileMs,
    pxW: pxW,
    pxH: pxH,
    x: x ?? this.x,
    y: y ?? this.y,
    widthFrac: widthFrac ?? this.widthFrac,
    startOutMs: startOutMs ?? this.startOutMs,
    trimStartMs: trimStartMs ?? this.trimStartMs,
    durMs: durMs ?? this.durMs,
    volume: volume ?? this.volume,
    opacity: opacity ?? this.opacity,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'isVideo': isVideo,
    'fileMs': fileMs,
    'pxW': pxW,
    'pxH': pxH,
    'x': x,
    'y': y,
    'widthFrac': widthFrac,
    'startOutMs': startOutMs,
    'trimStartMs': trimStartMs,
    'durMs': durMs,
    'volume': volume,
    'opacity': opacity,
  };

  factory PipItem.fromJson(Map<String, dynamic> j) => PipItem(
    id: j['id'] as String,
    path: j['path'] as String,
    name: j['name'] as String? ?? '',
    isVideo: j['isVideo'] as bool? ?? false,
    fileMs: (j['fileMs'] as num?)?.toInt() ?? 0,
    pxW: (j['pxW'] as num).toInt(),
    pxH: (j['pxH'] as num).toInt(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    widthFrac: (j['widthFrac'] as num).toDouble(),
    startOutMs: (j['startOutMs'] as num?)?.toInt() ?? 0,
    trimStartMs: (j['trimStartMs'] as num?)?.toInt() ?? 0,
    durMs: (j['durMs'] as num?)?.toInt() ?? 4000,
    volume: (j['volume'] as num?)?.toDouble() ?? 0,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
  );
}
