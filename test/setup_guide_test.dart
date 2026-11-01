import 'package:e_screen_recorder/core/platform_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _openGuide(WidgetTester tester) async {
  await tester.tap(find.text('Cài đặt'));
  await tester.pumpAndSettle();
  final tile = find.text('Hướng dẫn thiết lập');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  group('Android: setup guide', () {
    testWidgets('each step says what you get and how, with its state', (
      tester,
    ) async {
      _phone(tester);
      final perms = FakePermissions()..mic = false;
      final (:app, :fake) = await buildTestApp(permissions: perms);
      fake.setup = (developer: true, showTaps: false);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await _openGuide(tester);

      expect(find.text('Thiết lập để dùng đủ tính năng'), findsOneWidget);
      for (final id in ['overlay', 'mic', 'notif', 'taps', 'battery']) {
        await tester.ensureVisible(find.byKey(ValueKey('setup_step_$id')));
        expect(find.byKey(ValueKey('setup_step_$id')), findsOneWidget);
      }
      // overlay and notifications are on, the microphone is off
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('setup_state_overlay')),
          matching: find.text('Đã bật'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('setup_state_mic')),
          matching: find.text('Chưa bật'),
        ),
        findsOneWidget,
      );
      // what you get is written out, and the developer mode steps use the old words
      expect(find.textContaining('Bạn được gì'), findsWidgets);
      expect(find.textContaining('tự đặt dấu'), findsWidgets);
      await tester.ensureVisible(find.byKey(const ValueKey('setup_step_taps')));
      expect(
        find.textContaining('bấm 7 lần vào Số hiệu bản dựng'),
        findsOneWidget,
      );
      expect(find.text('Chế độ nhà phát triển: đã bật'), findsOneWidget);
      expect(find.text('Hiển thị lần chạm: chưa bật'), findsOneWidget);
    });

    testWidgets('the pictures are the ones of a real recording', (
      tester,
    ) async {
      _phone(tester);
      final (:app, fake: _) = await buildTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await _openGuide(tester);
      final imgs = find.byType(Image);
      expect(imgs, findsWidgets);
      for (final e in tester.widgetList<Image>(imgs)) {
        expect(e.image, isA<AssetImage>());
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the buttons ask for the permission or open the right page', (
      tester,
    ) async {
      _phone(tester);
      final perms = FakePermissions()..mic = false;
      final (:app, :fake) = await buildTestApp(permissions: perms);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await _openGuide(tester);

      Future<void> tap(String id) async {
        await tester.ensureVisible(find.byKey(ValueKey(id)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(id)));
        await tester.pumpAndSettle();
      }

      await tap('setup_mic_on');
      expect(perms.calls, contains('requestMic'));
      await tap('setup_overlay_on');
      expect(fake.calls, contains('requestOverlay'));
      await tap('setup_taps_about');
      await tap('setup_taps_dev');
      expect(fake.opened, ['about', 'developer']);
    });

    testWidgets('the Record screen counts the steps left and opens the guide', (
      tester,
    ) async {
      _phone(tester);
      final perms = FakePermissions()
        ..mic = false
        ..notif = false;
      final (:app, fake: _) = await buildTestApp(permissions: perms);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup_banner')), findsOneWidget);
      expect(find.text('Còn 2 bước thiết lập'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setup_banner')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup_guide')), findsOneWidget);
    });

    testWidgets('nothing left: no banner', (tester) async {
      _phone(tester);
      final (:app, fake: _) = await buildTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup_banner')), findsNothing);
    });
  });

  group('iPhone: what is Android only is said so', () {
    // The platform is put back inside the test body: the framework checks it before any tearDown.
    Future<void> asIos(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('the guide lists what works and what is Android only', (
      tester,
    ) async {
      await asIos(() async {
        _phone(tester);
        final (:app, fake: _) = await buildTestApp();
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('setup_banner')), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('ios_more')));
        await tester.tap(find.byKey(const ValueKey('ios_more')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('setup_guide_ios')), findsOneWidget);
        expect(find.text('Làm được'), findsOneWidget);
        expect(find.text('Chỉ có trên Android'), findsOneWidget);
        expect(
          find.textContaining('Dấu tự động theo từng lần bấm'),
          findsOneWidget,
        );
        expect(find.textContaining('Phóng to tự động'), findsOneWidget);
      });
    });

    testWidgets(
      'the tutorial marks are dimmed with an Android label, a tap explains',
      (tester) async {
        await asIos(() async {
          _phone(tester);
          final (:app, fake: _) = await buildTestApp(prefs: {'purpose': 0});
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();
          expect(find.byType(AndroidBadge), findsWidgets);
          final marks = find.byKey(const ValueKey('quick_marks_auto'));
          await tester.ensureVisible(marks);
          await tester.pumpAndSettle();
          // dimmed and not usable: the tap goes to the explanation, not to the chip
          await tester.tap(marks, warnIfMissed: false);
          await tester.pumpAndSettle();
          expect(
            find.text('Dấu tự động theo lần bấm chỉ có trên Android'),
            findsOneWidget,
          );
          expect(find.textContaining('Trên Android bạn được'), findsOneWidget);
          await tester.tap(find.text('Đã hiểu'));
          await tester.pumpAndSettle();
          expect(
            find.text('Dấu tự động theo lần bấm chỉ có trên Android'),
            findsNothing,
          );
        });
      },
    );

    testWidgets('on Android nothing is dimmed or labelled', (tester) async {
      _phone(tester);
      final (:app, fake: _) = await buildTestApp(prefs: {'purpose': 0});
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byType(AndroidBadge), findsNothing);
      expect(find.byKey(const ValueKey('ios_more')), findsNothing);
    });
  });
}
