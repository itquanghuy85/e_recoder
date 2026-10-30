import 'dart:ui' show Offset, Size;

import 'edit_project.dart';

/// Mirror of ZoomTransformation.kt (same ramps, same clamp). Keep both in step.

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Zoom state at source time [t]: [scale] 1 = none; ([cx], [cy]) is the centre of the visible
/// window as fractions of the frame, already clamped so the window stays inside the picture.
({double scale, double cx, double cy}) zoomAt(List<ZoomItem> zooms, int t) {
  var s = 1.0;
  var fx = 0.5;
  var fy = 0.5;
  for (final z in zooms) {
    if (t < z.startMs || t > z.endMs) continue;
    // Both ramps must fit in the clip: if they do not, they shrink together.
    final len = z.endMs - z.startMs;
    final fit = z.inMs + z.outMs > len && z.inMs + z.outMs > 0
        ? len / (z.inMs + z.outMs)
        : 1.0;
    final rampIn = z.inMs * fit, rampOut = z.outMs * fit;
    final inP = rampIn <= 0 ? 1.0 : _smooth((t - z.startMs) / rampIn);
    final outP = rampOut <= 0 ? 1.0 : _smooth((z.endMs - t) / rampOut);
    s = 1 + (z.scale - 1) * (inP < outP ? inP : outP);
    fx = z.fx;
    fy = z.fy;
  }
  if ((s - 1).abs() < 1e-4) return (scale: 1.0, cx: 0.5, cy: 0.5);
  // The visible window has half-size 0.5/s (in fractions); keep it inside [0,1].
  final half = 0.5 / s;
  return (
    scale: s,
    cx: fx.clamp(half, 1 - half).toDouble(),
    cy: fy.clamp(half, 1 - half).toDouble(),
  );
}

/// Mirror of RegionMath in RegionFx.kt: how blur, mosaic and spotlight scale with their strength.
/// Keep both in step (same test vectors in editor_controller_test.dart and RegionMathTest.kt).
abstract final class RegionMath {
  static const int fadeMs = 120;

  /// Mosaic cell size, as a fraction of the frame width.
  static double mosaicBlockFrac(double s) => 0.02 + 0.06 * s.clamp(0.0, 1.0);

  /// Blur radius, as a fraction of the frame width.
  static double blurRadiusFrac(double s) => 0.015 + 0.03 * s.clamp(0.0, 1.0);

  /// How dark everything outside a spotlight gets (0..1).
  static double spotlightDim(double s) => 0.35 + 0.5 * s.clamp(0.0, 1.0);

  /// 0 outside the clip, easing to 1 over [fadeMs] at both ends.
  static double mix(int t, int startMs, int endMs) {
    if (t < startMs || t > endMs) return 0;
    final a =
        ((t - startMs) < (endMs - t) ? (t - startMs) : (endMs - t)) / fadeMs;
    final x = a.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}

/// Zoom and pan of the editor's preview for LOOKING only: it is never saved in the project and
/// never reaches the export. A content point `p` (stage pixels at 1x) shows at `p * scale + offset`.
class ViewZoom {
  const ViewZoom([this.scale = 1, this.offset = Offset.zero]);

  static const double minScale = 1;
  static const double maxScale = 5;

  final double scale;
  final Offset offset;

  bool get isZoomed => scale > 1.001;

  /// Where a point of the stage (as touched, at 1x) lies in the content.
  Offset toContent(Offset screen) => (screen - offset) / scale;

  /// The view in which content point [q] sits under [focal] at [scale]. The picture stays
  /// overlapping the viewport but is allowed to leave blank space around it, so zooming the
  /// preview is no longer clamped to edge-to-edge coverage by the fixed frame.
  static ViewZoom pinch({
    required Offset q,
    required Offset focal,
    required double scale,
    required Size box,
  }) {
    final s = scale.clamp(minScale, maxScale).toDouble();
    final o = focal - q * s;
    return ViewZoom(
      s,
      Offset(
        o.dx.clamp(-box.width * s, box.width).toDouble(),
        o.dy.clamp(-box.height * s, box.height).toDouble(),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ViewZoom && other.scale == scale && other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, offset);
}
