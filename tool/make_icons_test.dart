// Generates the launcher icons, splash assets and the Play Store icon from lib/theme/brand_mark.dart.
// Run:  flutter test tool/make_icons_test.dart
// Outputs go to android/app/src/main/res and store/ (committed, so the build needs no tooling).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:e_screen_recorder/theme/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _write(
  String path,
  int w,
  int h,
  void Function(Canvas, Size) draw,
) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  draw(canvas, Size(w.toDouble(), h.toDouble()));
  final img = await rec.endRecording().toImage(w, h);
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  test('generate icons', () async {
    const res = 'android/app/src/main/res';

    // Legacy launcher icons (rounded square), per density.
    const sizes = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final e in sizes.entries) {
      await _write(
        '$res/mipmap-${e.key}/ic_launcher.png',
        e.value,
        e.value,
        (c, s) => BrandMark.paintIcon(c, s),
      );
    }

    // Adaptive icon: 432 px canvas, the mark stays inside the 66% safe zone.
    await _write(
      '$res/drawable-nodpi/ic_launcher_foreground.png',
      432,
      432,
      (c, s) => BrandMark.paintMark(c, s, scale: 0.66),
    );
    await _write(
      '$res/drawable-nodpi/ic_launcher_background.png',
      432,
      432,
      (c, s) => BrandMark.paintTile(c, s),
    );
    await _write(
      '$res/drawable-nodpi/ic_launcher_monochrome.png',
      432,
      432,
      (c, s) => BrandMark.paintMark(c, s, scale: 0.66, mono: true),
    );
    File('$res/mipmap-anydpi-v26/ic_launcher.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
''');

    // Splash logo for Android < 12 (Android 12+ shows the launcher icon by itself).
    await _write(
      '$res/drawable-nodpi/splash_logo.png',
      576,
      576,
      (c, s) => BrandMark.paintIcon(c, s, radiusFrac: 0.26),
    );

    // Play Store: 512 icon (square: Play rounds it) and a copy for README / the site.
    await _write('store/icon_512.png', 512, 512, (c, s) {
      BrandMark.paintTile(c, s);
      BrandMark.paintMark(c, s, scale: 0.94);
    });
    await _write('assets/brand/logo_1024.png', 1024, 1024, (c, s) {
      BrandMark.paintIcon(c, s, radiusFrac: 0.22);
    });
    // App Store icon: 1024 square, no alpha channel needed by the site, Apple rounds it.
    await _write('store/ios_icon_1024.png', 1024, 1024, (c, s) {
      BrandMark.paintTile(c, s);
      BrandMark.paintMark(c, s, scale: 0.94);
    });
    expect(File('store/icon_512.png').existsSync(), isTrue);
  });
}
