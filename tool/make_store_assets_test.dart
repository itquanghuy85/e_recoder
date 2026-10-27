// Frames the raw device screenshots (store/raw/<vi|en>/*.png) into Play Store screenshots and
// renders the feature graphic. Run:  flutter test tool/make_store_assets_test.dart
// Outputs: fastlane/metadata/android/<locale>/images/{phoneScreenshots,featureGraphic.png,icon.png}
import 'dart:io';
import 'dart:ui' as ui;

import 'package:e_screen_recorder/theme/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// (file stem, store order, vi headline, en headline)
const _shots = [
  ('07_live', 1, 'Chấm nhỏ ở góc.\nBấm trước, rồi mới bấm thật', 'One small dot.\nPoint first, then press'),
  ('05_editor', 2, 'Dấu báo trước nằm sẵn\ntrên dòng thời gian', 'Markers waiting\non the timeline'),
  ('06_auto', 3, 'Dựng tự động: phóng to,\nđánh số, tua nhanh', 'Auto direct: zoom,\nnumber, speed up'),
  ('03_modes', 4, 'Hai cách đánh dấu.\nBạn chọn', 'Two ways to mark.\nYour choice'),
  ('02_markers', 5, 'Dấu sống động\nnhư giọt nước', 'Markers that move\nlike water'),
  ('01_record', 6, 'Quay màn hình\nchỉ với một chạm', 'Record your screen\nin one tap'),
  ('04_library', 7, 'Mọi video ở lại\ntrên máy của bạn', 'All your videos\nstay on your phone'),
  ('08_dark', 8, 'Giao diện sáng\nvà tối', 'Light and\ndark themes'),
];

const _locales = {'vi': 'vi-VN', 'en': 'en-US'};
const _tagline = {
  'vi': 'Cho người xem biết trước\nchỗ bạn sắp bấm',
  'en': 'Show viewers where\nyou are about to tap',
};

Future<ui.Image> _load(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Future<void> _save(String path, int w, int h, void Function(Canvas, Size) draw) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  draw(c, Size(w.toDouble(), h.toDouble()));
  final img = await rec.endRecording().toImage(w, h);
  final data = (await img.toByteData(format: ui.ImageByteFormat.png))!;
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
}

TextPainter _text(String s, double size, FontWeight w, Color color, {double height = 1.12, TextAlign align = TextAlign.left}) {
  return TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'Barlow', fontSize: size, fontWeight: w, color: color, height: height),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 1000);
}

void _phone(Canvas c, ui.Image shot, Rect rect, {double radius = 64}) {
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  // Shadow, then the screenshot clipped to the rounded rectangle, then a thin edge light.
  c.drawRRect(
    rr.shift(const Offset(0, 22)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
  );
  c.save();
  c.clipRRect(rr);
  c.drawImageRect(
    shot,
    Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
  c.drawRRect(
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: 0.28),
  );
}

const _endLine = {
  'vi': 'Miễn phí · Không quảng cáo\nVideo ở lại trên máy bạn',
  'en': 'Free · No ads\nYour videos stay on your phone',
};

void main() {
  setUpAll(() async {
    final loader = FontLoader('Barlow');
    for (final f in ['Regular', 'SemiBold']) {
      final bytes = File('assets/fonts/Barlow-$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  test('video cards', () async {
    for (final lang in _locales.keys) {
      for (final kind in ['title', 'end']) {
        await _save('store/video/cards/${kind}_$lang.png', 1080, 1920, (c, size) {
          BrandMark.paintTile(c, size);
          c.save();
          c.translate(size.width * 0.5 - 380, size.height * 0.5 - 640);
          BrandMark.paintMark(c, const Size(760, 760), ripple: kind == 'end' ? 0.5 : 0);
          c.restore();
          final name = _text('E Screen Recorder', 92, FontWeight.w600, const Color(0xFFF2F5FA), align: TextAlign.center);
          name.paint(c, Offset((size.width - name.width) / 2, size.height * 0.5 + 200));
          final tag = _text(kind == 'title' ? _tagline[lang]! : _endLine[lang]!, 52, FontWeight.w400, const Color(0xFFA3AEC2), height: 1.3, align: TextAlign.center);
          tag.paint(c, Offset((size.width - tag.width) / 2, size.height * 0.5 + 340));
        });
      }
    }
  });

  test('notification card', () async {
    final f = File('store/raw/notification.png');
    if (!f.existsSync()) return;
    final img = await _load(f.path);
    const caption = {
      'vi': 'Thông báo hiện suốt phiên quay.\nCó Tạm dừng và Dừng.',
      'en': 'A notification stays up while recording.\nPause and Stop are one tap away.',
    };
    for (final lang in _locales.keys) {
      await _save('store/video/cards/notification_$lang.png', 1080, 1920, (c, size) {
        BrandMark.paintTile(c, size);
        final w = 960.0;
        final h = w * img.height / img.width;
        final rect = Rect.fromLTWH((size.width - w) / 2, size.height * 0.36, w, h);
        c.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(40)).shift(const Offset(0, 14)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
        );
        c.save();
        c.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(40)));
        c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), rect, Paint()..filterQuality = FilterQuality.high);
        c.restore();
        final tp = _text(caption[lang]!, 56, FontWeight.w600, const Color(0xFFF2F5FA), align: TextAlign.center);
        tp.paint(c, Offset((size.width - tp.width) / 2, size.height * 0.16));
      });
    }
  });

  test('phone screenshots', () async {
    for (final lang in _locales.keys) {
      final loc = _locales[lang]!;
      final out = 'fastlane/metadata/android/$loc/images';
      var n = 0;
      for (final s in _shots) {
        final raw = File('store/raw/$lang/${s.$1}.png').existsSync()
            ? 'store/raw/$lang/${s.$1}.png'
            : 'store/raw/vi/${s.$1}.png';
        if (!File(raw).existsSync()) continue;
        final shot = await _load(raw);
        final headline = lang == 'vi' ? s.$3 : s.$4;
        await _save('$out/phoneScreenshots/${s.$2}_${s.$1.substring(3)}.png', 1080, 1920, (c, size) {
          BrandMark.paintTile(c, size);
          // Big soft rings behind the phone, like a drop spreading from the middle of the screenshot.
          final centre = Offset(size.width * 0.5, size.height * 0.62);
          for (var i = 0; i < 4; i++) {
            c.drawCircle(
              centre,
              380.0 + i * 190,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = BrandMark.key.withValues(alpha: 0.16 - i * 0.03),
            );
          }
          final tp = _text(headline, 76, FontWeight.w600, const Color(0xFFF2F5FA), align: TextAlign.center);
          tp.paint(c, Offset((size.width - tp.width) / 2, 120));
          // The phone bleeds off the bottom edge.
          final w = 800.0;
          final h = w * shot.height / shot.width;
          _phone(c, shot, Rect.fromLTWH((size.width - w) / 2, 400, w, h));
        });
        n++;
      }
      // Icon + feature graphic.
      File('store/icon_512.png').copySync('$out/icon.png');
      await _feature('$out/featureGraphic.png', lang);
      // ignore: avoid_print
      print('$loc: $n screenshots');
    }
  });
}

Future<void> _feature(String path, String lang) async {
  final left = File('store/raw/$lang/07_live.png').existsSync()
      ? 'store/raw/$lang/07_live.png'
      : 'store/raw/vi/07_live.png';
  final right = File('store/raw/$lang/05_editor.png').existsSync()
      ? 'store/raw/$lang/05_editor.png'
      : 'store/raw/vi/05_editor.png';
  final a = File(left).existsSync() ? await _load(left) : null;
  final b = File(right).existsSync() ? await _load(right) : null;
  await _save(path, 1024, 500, (c, size) {
    BrandMark.paintTile(c, size);
    // The mark, big, bleeding off the left edge.
    c.save();
    c.translate(-150, 70);
    BrandMark.paintMark(c, const Size(360, 360), scale: 1);
    c.restore();
    final title = _text('E Screen\nRecorder', 74, FontWeight.w600, const Color(0xFFF2F5FA), height: 1.0);
    title.paint(c, const Offset(240, 100));
    final tag = _text(_tagline[lang]!, 28, FontWeight.w400, const Color(0xFFA3AEC2), height: 1.25);
    tag.paint(c, const Offset(240, 290));
    // Two phones on the right, slightly rotated.
    void phone(ui.Image? img, double cx, double angle, double w) {
      if (img == null) return;
      final h = w * img.height / img.width;
      c.save();
      c.translate(cx, 330);
      c.rotate(angle);
      _phone(c, img, Rect.fromCenter(center: Offset.zero, width: w, height: h), radius: 28);
      c.restore();
    }

    phone(b, 840, 0.12, 190);
    phone(a, 700, -0.07, 210);
  });
}
