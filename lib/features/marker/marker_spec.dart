import 'dart:ui' show Color;

/// Mirrors android/.../marker/MarkerSpec.kt. Positions are fractions of the video frame (0..1),
/// sizes are in "u" units (1 u = frame width / 360), so a marker looks the same at any resolution.
enum MarkerType {
  finger,
  ripple,
  arrow,
  circle,
  rect,
  pen,
  number;

  String get wire => name;
  static MarkerType of(String? s) => MarkerType.values.firstWhere(
    (t) => t.name == s,
    orElse: () => MarkerType.finger,
  );
}

class MarkerSpec {
  const MarkerSpec({
    required this.type,
    this.color = const Color(0xFFFF3B30),
    this.x0 = 0.5,
    this.y0 = 0.5,
    this.x1 = 0.5,
    this.y1 = 0.5,
    this.points = const [],
    this.rotation = 0,
    this.scale = 1,
    this.thickness = 5,
    this.opacity = 1,
    this.number = 1,
  });

  final MarkerType type;
  final Color color;
  final double x0, y0, x1, y1;
  final List<double> points;
  final double rotation;
  final double scale;
  final double thickness;
  final double opacity;
  final int number;

  MarkerSpec copyWith({
    MarkerType? type,
    Color? color,
    double? x0,
    double? y0,
    double? x1,
    double? y1,
    List<double>? points,
    double? rotation,
    double? scale,
    double? thickness,
    double? opacity,
    int? number,
  }) => MarkerSpec(
    type: type ?? this.type,
    color: color ?? this.color,
    x0: x0 ?? this.x0,
    y0: y0 ?? this.y0,
    x1: x1 ?? this.x1,
    y1: y1 ?? this.y1,
    points: points ?? this.points,
    rotation: rotation ?? this.rotation,
    scale: scale ?? this.scale,
    thickness: thickness ?? this.thickness,
    opacity: opacity ?? this.opacity,
    number: number ?? this.number,
  );

  @override
  bool operator ==(Object other) =>
      other is MarkerSpec &&
      other.type == type &&
      other.color == color &&
      other.x0 == x0 &&
      other.y0 == y0 &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.rotation == rotation &&
      other.scale == scale &&
      other.thickness == thickness &&
      other.opacity == opacity &&
      other.number == number &&
      _sameList(other.points, points);

  @override
  int get hashCode => Object.hash(
    type,
    color,
    x0,
    y0,
    x1,
    y1,
    rotation,
    scale,
    thickness,
    opacity,
    number,
    Object.hashAll(points),
  );

  static bool _sameList(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Map<String, Object> toMap() => {
    'type': type.wire,
    'color': color.toARGB32(),
    'x0': x0,
    'y0': y0,
    'x1': x1,
    'y1': y1,
    'points': points,
    'rotation': rotation,
    'scale': scale,
    'thickness': thickness,
    'opacity': opacity,
    'number': number,
  };

  factory MarkerSpec.fromMap(Map<dynamic, dynamic> m) => MarkerSpec(
    type: MarkerType.of(m['type'] as String?),
    color: Color((m['color'] as num).toInt()),
    x0: (m['x0'] as num).toDouble(),
    y0: (m['y0'] as num).toDouble(),
    x1: (m['x1'] as num).toDouble(),
    y1: (m['y1'] as num).toDouble(),
    points: ((m['points'] as List?) ?? const [])
        .map((e) => (e as num).toDouble())
        .toList(),
    rotation: (m['rotation'] as num).toDouble(),
    scale: (m['scale'] as num).toDouble(),
    thickness: (m['thickness'] as num).toDouble(),
    opacity: (m['opacity'] as num).toDouble(),
    number: (m['number'] as num).toInt(),
  );

  /// Anchor in fractions: the pivot for rotation and scale (same rule as MarkerRenderer.anchor).
  ({double x, double y}) get anchor {
    switch (type) {
      case MarkerType.arrow:
        return (x: x1, y: y1);
      case MarkerType.circle:
      case MarkerType.rect:
        return (x: (x0 + x1) / 2, y: (y0 + y1) / 2);
      case MarkerType.pen:
        if (points.length < 2) return (x: x0, y: y0);
        var l = points[0], r = points[0], t = points[1], b = points[1];
        for (var i = 0; i + 1 < points.length; i += 2) {
          if (points[i] < l) l = points[i];
          if (points[i] > r) r = points[i];
          if (points[i + 1] < t) t = points[i + 1];
          if (points[i + 1] > b) b = points[i + 1];
        }
        return (x: (l + r) / 2, y: (t + b) / 2);
      default:
        return (x: x0, y: y0);
    }
  }
}
