import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Output frame shape. [auto] keeps the shape of the (cropped) picture.
enum OutAspect { auto, r9x16, r1x1, r4x5, r16x9 }

extension OutAspectValue on OutAspect {
  /// width / height, or null for [OutAspect.auto].
  double? get ratio => switch (this) {
    OutAspect.auto => null,
    OutAspect.r9x16 => 9 / 16,
    OutAspect.r1x1 => 1,
    OutAspect.r4x5 => 4 / 5,
    OutAspect.r16x9 => 16 / 9,
  };
}

/// Ready-made colour looks. Each one is just a [ColorLook] with fixed numbers.
enum ColorPreset { none, vivid, warm, cool, bw, vintage, fade }

/// Colour adjustment of the whole picture, applied as ONE 4x4 matrix (rgb' = M * rgb + t) by the
/// exporter and as the equivalent colour filter by the preview, so both come from the same numbers.
class ColorLook {
  const ColorLook({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 1,
    this.warmth = 0,
  });

  /// -1 .. 1, added to every channel.
  final double brightness;

  /// -1 .. 1, scales the distance from mid-grey by (1 + contrast).
  final double contrast;

  /// 0 .. 2, 1 = unchanged, 0 = black and white.
  final double saturation;

  /// -1 .. 1, positive = warmer (more red, less blue).
  final double warmth;

  static const none = ColorLook();

  bool get isNone =>
      brightness == 0 && contrast == 0 && saturation == 1 && warmth == 0;

  static ColorLook preset(ColorPreset p) => switch (p) {
    ColorPreset.none => none,
    ColorPreset.vivid => const ColorLook(contrast: 0.12, saturation: 1.45),
    ColorPreset.warm => const ColorLook(warmth: 0.55, saturation: 1.08),
    ColorPreset.cool => const ColorLook(warmth: -0.55, saturation: 1.05),
    ColorPreset.bw => const ColorLook(contrast: 0.1, saturation: 0),
    ColorPreset.vintage => const ColorLook(
      brightness: 0.03,
      contrast: -0.08,
      saturation: 0.65,
      warmth: 0.4,
    ),
    ColorPreset.fade => const ColorLook(
      brightness: 0.06,
      contrast: -0.22,
      saturation: 0.8,
    ),
  };

  ColorLook copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) => ColorLook(
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
  );

  /// Row-major 3x4: each row is [r, g, b, offset] producing one output channel (colours 0..1).
  List<double> get rows {
    // warmth: red up, blue down
    final wr = 1 + 0.18 * warmth;
    final wb = 1 - 0.18 * warmth;
    // saturation around Rec.709 luma
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = saturation;
    // Start from identity and compose: out = B(C(S(W(in))))
    // W: diag(wr, 1, wb)
    // S: (1-s)*L*ones + s*I
    final sm = [
      [(1 - s) * lr + s, (1 - s) * lg, (1 - s) * lb],
      [(1 - s) * lr, (1 - s) * lg + s, (1 - s) * lb],
      [(1 - s) * lr, (1 - s) * lg, (1 - s) * lb + s],
    ];
    // M = S * W
    final w = [wr, 1.0, wb];
    final m = [
      for (var r = 0; r < 3; r++) [for (var c = 0; c < 3; c++) sm[r][c] * w[c]],
    ];
    // contrast around 0.5, then brightness
    final f = 1 + contrast;
    final t = 0.5 * (1 - f) + brightness;
    return [
      for (var r = 0; r < 3; r++) ...[m[r][0] * f, m[r][1] * f, m[r][2] * f, t],
    ];
  }

  /// Column-major 4x4 for Media3's RgbMatrix: rgb' = M * (r, g, b, 1).
  List<double> get matrix4 {
    final x = rows;
    return [
      x[0], x[4], x[8], 0, // column r
      x[1], x[5], x[9], 0, // column g
      x[2], x[6], x[10], 0, // column b
      x[3], x[7], x[11], 1, // column translation
    ];
  }

  /// The same look as Flutter's 4x5 colour matrix (offsets in 0..255).
  List<double> get flutterMatrix {
    final x = rows;
    return [
      x[0], x[1], x[2], 0, x[3] * 255, //
      x[4], x[5], x[6], 0, x[7] * 255,
      x[8], x[9], x[10], 0, x[11] * 255,
      0, 0, 0, 1, 0,
    ];
  }

  Map<String, Object> toJson() => {
    'b': brightness,
    'c': contrast,
    's': saturation,
    'w': warmth,
  };

  factory ColorLook.fromJson(Map<String, dynamic>? j) => j == null
      ? none
      : ColorLook(
          brightness: (j['b'] as num?)?.toDouble() ?? 0,
          contrast: (j['c'] as num?)?.toDouble() ?? 0,
          saturation: (j['s'] as num?)?.toDouble() ?? 1,
          warmth: (j['w'] as num?)?.toDouble() ?? 0,
        );

  @override
  bool operator ==(Object other) =>
      other is ColorLook &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.warmth == warmth;
  @override
  int get hashCode => Object.hash(brightness, contrast, saturation, warmth);
}

/// Where the picture sits in the output frame. All fractions are of the picture AFTER rotation.
///
/// Pipeline (same order in the exporter and the preview):
///   rotate -> markers, covers, zoom (picture space) -> crop -> fit the output aspect (bars or fill)
///   -> text and images (output space) -> colour look.
class PictureLook {
  const PictureLook({
    this.rotation = 0,
    this.tilt = 0,
    this.crop = const Rect.fromLTRB(0, 0, 1, 1),
    this.aspect = OutAspect.auto,
    this.fill = false,
    this.color = ColorLook.none,
  });

  /// 0, 90, 180 or 270 degrees clockwise.
  final int rotation;

  /// Free turn on top of [rotation], degrees clockwise in -45..45. The picture is enlarged just
  /// enough that no empty corner shows ([tiltZoom]).
  final double tilt;
  final Rect crop;
  final OutAspect aspect;

  /// When the output aspect differs from the cropped picture: false = black bars, true = fill and cut the excess.
  final bool fill;
  final ColorLook color;

  static const identity = PictureLook();

  bool get isCropped =>
      crop.left > 0.0005 ||
      crop.top > 0.0005 ||
      crop.right < 0.9995 ||
      crop.bottom < 0.9995;

  bool get isIdentity =>
      rotation == 0 && tilt.abs() < 0.05 && !isCropped && aspect == OutAspect.auto && color.isNone;

  PictureLook copyWith({
    int? rotation,
    double? tilt,
    Rect? crop,
    OutAspect? aspect,
    bool? fill,
    ColorLook? color,
  }) => PictureLook(
    rotation: rotation ?? this.rotation,
    tilt: tilt ?? this.tilt,
    crop: crop ?? this.crop,
    aspect: aspect ?? this.aspect,
    fill: fill ?? this.fill,
    color: color ?? this.color,
  );

  /// How much the turned picture must be enlarged to fill the frame again: the largest rectangle of
  /// the picture's own shape that fits inside the turned picture, inverted. Same maths as the exporter.
  double tiltZoom(int srcW, int srcH) {
    final a = (tilt.abs() % 180) * math.pi / 180;
    final f = a > math.pi / 2 ? math.pi - a : a;
    final p = pictureSize(srcW, srcH);
    final k = math.max(p.width / p.height, p.height / p.width);
    return math.cos(f) + k * math.sin(f);
  }

  /// Size of the picture after rotation, in pixels.
  Size pictureSize(int srcW, int srcH) => rotation % 180 == 0
      ? Size(srcW.toDouble(), srcH.toDouble())
      : Size(srcH.toDouble(), srcW.toDouble());

  /// Size of the cropped picture in pixels (even numbers).
  Size croppedSize(int srcW, int srcH) {
    final p = pictureSize(srcW, srcH);
    return Size(_even(p.width * crop.width), _even(p.height * crop.height));
  }

  /// Size of the output frame in pixels (even numbers): where text and images live.
  Size outputSize(int srcW, int srcH) {
    final c = croppedSize(srcW, srcH);
    final a = aspect.ratio;
    if (a == null) return c;
    final ca = c.width / c.height;
    if ((a - ca).abs() < 0.002) return c;
    if (fill) {
      // keep the full width or height, cut the other side
      return a > ca
          ? Size(c.width, _even(c.width / a))
          : Size(_even(c.height * a), c.height);
    }
    // black bars: grow the frame
    return a > ca
        ? Size(_even(c.height * a), c.height)
        : Size(c.width, _even(c.width / a));
  }

  /// Where the cropped picture is drawn inside the output frame, in output-frame fractions.
  Rect pictureRectInOutput(int srcW, int srcH) {
    final c = croppedSize(srcW, srcH);
    final o = outputSize(srcW, srcH);
    if (c == o) return const Rect.fromLTRB(0, 0, 1, 1);
    final scale = fill
        ? math.max(o.width / c.width, o.height / c.height)
        : math.min(o.width / c.width, o.height / c.height);
    final w = c.width * scale / o.width;
    final h = c.height * scale / o.height;
    return Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
  }

  static double _even(double v) {
    final i = v.round();
    return (i - i % 2).clamp(2, 100000).toDouble();
  }

  Map<String, Object> toJson() => {
    'rotation': rotation,
    if (tilt != 0) 'tilt': tilt,
    'crop': [crop.left, crop.top, crop.right, crop.bottom],
    'aspect': aspect.name,
    'fill': fill,
    'color': color.toJson(),
  };

  factory PictureLook.fromJson(Map<String, dynamic>? j) {
    if (j == null) return identity;
    final c = (j['crop'] as List?)?.map((e) => (e as num).toDouble()).toList();
    return PictureLook(
      rotation: ((j['rotation'] as num?)?.toInt() ?? 0) % 360,
      tilt: ((j['tilt'] as num?)?.toDouble() ?? 0).clamp(-45.0, 45.0),
      crop: c != null && c.length == 4
          ? Rect.fromLTRB(c[0], c[1], c[2], c[3])
          : const Rect.fromLTRB(0, 0, 1, 1),
      aspect: OutAspect.values.firstWhere(
        (e) => e.name == j['aspect'],
        orElse: () => OutAspect.auto,
      ),
      fill: j['fill'] as bool? ?? false,
      color: ColorLook.fromJson(j['color'] as Map<String, dynamic>?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PictureLook &&
      other.rotation == rotation &&
      other.tilt == tilt &&
      other.crop == crop &&
      other.aspect == aspect &&
      other.fill == fill &&
      other.color == color;
  @override
  int get hashCode => Object.hash(rotation, tilt, crop, aspect, fill, color);
}
