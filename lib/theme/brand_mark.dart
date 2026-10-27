import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The E Screen Recorder mark, drawn in code so the launcher icon, the splash, the store graphics
/// and the in-app logo all come from one source (`tool/make_icons_test.dart` renders the PNGs).
///
/// Idea: a glossy "record" drop (the live tally colour) in the middle of rings that spread like a
/// drop on water. The rings are iridescent (cyan, amber, coral, violet) because the app's job is to
/// show where the NEXT tap lands, so the rings read as "something is about to happen here".
abstract final class BrandMark {
  static const ink = Color(0xFF0E1116);
  static const inkLift = Color(0xFF22304D);
  static const tally = Color(0xFFFF5A52);
  static const tallyLight = Color(0xFFFFB3A6);
  static const tallyDeep = Color(0xFFA5162B);
  static const cue = Color(0xFFFFB938);
  static const key = Color(0xFF4DD6E8);
  static const violet = Color(0xFFB07CFF);

  static const _ringColors = [
    // inner: warm
    [cue, Color(0xFFFF7A59), tally, cue],
    // middle: coral into violet and blue
    [tally, violet, Color(0xFF6C8CFF), tally],
    // outer: cool
    [key, Color(0xFF6C8CFF), violet, key],
  ];

  /// Deep-water tile: a lifted navy glow top-left fading to ink.
  static void paintTile(Canvas c, Size s, {double radiusFrac = 0}) {
    final rect = Offset.zero & s;
    c.save();
    if (radiusFrac > 0) {
      c.clipRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(s.shortestSide * radiusFrac),
        ),
      );
    }
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(s.width * 0.32, s.height * 0.22),
          s.longestSide * 1.05,
          [inkLift, const Color(0xFF131A2A), ink],
          [0, 0.5, 1],
        ),
    );
    // A faint caustic band across the lower half, like light under water.
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, s.height * 0.55),
          Offset(s.width, s.height * 0.95),
          [
            key.withValues(alpha: 0),
            key.withValues(alpha: 0.10),
            violet.withValues(alpha: 0.07),
            violet.withValues(alpha: 0),
          ],
          [0, 0.4, 0.7, 1],
        ),
    );
    c.restore();
  }

  /// The mark centred in [s]. [scale] 1 = rings touch the canvas edge; use ~0.62 for an adaptive
  /// icon foreground. [ripple] (0..1) pushes the rings outward and fades them, for the splash.
  /// [mono] draws a single-colour silhouette for themed (monochrome) icons.
  static void paintMark(
    Canvas c,
    Size s, {
    double scale = 1,
    double ripple = 0,
    bool mono = false,
    Color monoColor = Colors.white,
  }) {
    final u = s.shortestSide * scale;
    final centre = Offset(s.width / 2, s.height / 2);

    // Rings: outer faint, inner strong. Each has a sweep gradient turned by a different angle.
    const base = [0.47, 0.365, 0.275];
    const width = [0.02, 0.028, 0.038];
    const alpha = [0.55, 0.8, 1.0];
    for (var i = 0; i < 3; i++) {
      final extra = ripple * (0.2 + 0.1 * i);
      final r = u * (base[i] + extra);
      final fade = 1 - ripple * ripple * (0.9 - 0.15 * i);
      final a = alpha[i] * fade.clamp(0.0, 1.0);
      if (a <= 0.01) continue;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * width[i]
        ..strokeCap = StrokeCap.round;
      if (mono) {
        stroke.color = monoColor.withValues(alpha: mono && i == 0 ? 0.55 : 1);
      } else {
        final cols = _ringColors[i];
        stroke.shader = ui.Gradient.sweep(
          centre,
          [for (final col in cols) col.withValues(alpha: a)],
          const [0, 0.34, 0.68, 1],
          TileMode.clamp,
          0,
          2 * math.pi,
          (Matrix4.identity()
                ..translateByDouble(centre.dx, centre.dy, 0, 1)
                ..rotateZ(i * 1.3 + 0.4)
                ..translateByDouble(-centre.dx, -centre.dy, 0, 1))
              .storage,
        );
      }
      c.drawCircle(centre, r, stroke);
    }

    // The drop.
    final r = u * 0.165;
    if (mono) {
      c.drawCircle(centre, r, Paint()..color = monoColor);
      return;
    }
    c.drawCircle(
      centre.translate(0, r * 0.14),
      r * 1.25,
      Paint()
        ..shader = ui.Gradient.radial(centre.translate(0, r * 0.14), r * 1.25, [
          tally.withValues(alpha: 0.38),
          tally.withValues(alpha: 0),
        ]),
    );
    c.drawCircle(
      centre,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          centre.translate(-r * 0.38, -r * 0.45),
          r * 1.7,
          [tallyLight, tally, tallyDeep],
          [0, 0.5, 1],
        ),
    );
    // Gloss: a bright crescent top-left and a small specular dot.
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
    c.drawOval(
      Rect.fromCenter(
        center: centre.translate(-r * 0.2, -r * 0.5),
        width: r * 1.5,
        height: r * 0.85,
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          centre.translate(0, -r),
          centre.translate(0, 0),
          [
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
    c.restore();
    c.drawCircle(
      centre.translate(-r * 0.42, -r * 0.5),
      r * 0.1,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  /// The full launcher tile: background + mark.
  static void paintIcon(Canvas c, Size s, {double radiusFrac = 0.22}) {
    paintTile(c, s, radiusFrac: radiusFrac);
    paintMark(c, s, scale: 0.94);
  }
}
