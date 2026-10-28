import 'dart:math' as math;

import 'package:e_screen_recorder/features/editor/picture_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no tilt: no enlargement, still the identity look', () {
    const look = PictureLook();
    expect(look.tiltZoom(720, 1600), closeTo(1, 1e-9));
    expect(look.isIdentity, isTrue);
  });

  test('a tilted picture is enlarged so its corners stay inside', () {
    for (final deg in [15.0, 30.0, 45.0, -30.0]) {
      final look = PictureLook(tilt: deg);
      expect(look.isIdentity, isFalse);
      final z = look.tiltZoom(720, 1600);
      // The frame, enlarged by z and turned back, must still lie inside the picture.
      final a = deg.abs() * math.pi / 180;
      const w = 720.0, h = 1600.0;
      final hw = w / 2 / z, hh = h / 2 / z;
      for (final sx in [-1, 1]) {
        for (final sy in [-1, 1]) {
          final x = sx * hw, y = sy * hh;
          final u = (x * math.cos(a) + y * math.sin(a)).abs();
          final v = (-x * math.sin(a) + y * math.cos(a)).abs();
          expect(u, lessThanOrEqualTo(w / 2 + 1e-6));
          expect(v, lessThanOrEqualTo(h / 2 + 1e-6));
        }
      }
    }
  });

  test('tilt survives JSON and is limited to -45..45', () {
    final back = PictureLook.fromJson(const PictureLook(tilt: 30).toJson());
    expect(back.tilt, 30);
    expect(PictureLook.fromJson({'tilt': 99}).tilt, 45);
    expect(PictureLook.fromJson(const PictureLook().toJson()).tilt, 0);
  });
}
