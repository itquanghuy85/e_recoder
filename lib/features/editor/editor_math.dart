import 'edit_project.dart';

/// Mirror of ZoomTransformation.kt (same ramp, same clamp). Keep both in step.
const int kZoomRampMs = 350;

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
    final inP = _smooth((t - z.startMs) / kZoomRampMs);
    final outP = _smooth((z.endMs - t) / kZoomRampMs);
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
