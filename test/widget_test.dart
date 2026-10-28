import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/marker/marker_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

MediaEntry _entry(String name) => MediaEntry(
  uri: 'content://media/$name',
  name: name,
  durationMs: 83000,
  size: 24 * 1024 * 1024,
  width: 1080,
  height: 2400,
  dateAdded: DateTime(2026, 10, 26, 9, 30),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shell shows record tab and navigates', (tester) async {
    final (:app, :fake) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu quay'), findsOneWidget);

    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có video nào'), findsOneWidget);

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme_selector')), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('theme selector switches to dark', (tester) async {
    final (:app, fake: _) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  testWidgets('library lists recordings with right-aligned duration', (
    tester,
  ) async {
    final (:app, fake: _) = await buildTestApp(
      media: [_entry('ESR_1.mp4'), _entry('ESR_2.mp4')],
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('ESR_1.mp4'), findsWidgets);
    expect(find.text('01:23'), findsWidgets);
    expect(find.textContaining('24,0 MB'), findsWidgets);
  });

  testWidgets('profile card opens the capture settings sheet', (tester) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.textContaining('1080p · 30 fps · Cân bằng'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile_card')));
    await tester.pumpAndSettle();
    expect(find.text('Cấu hình quay'), findsOneWidget);
    await tester.tap(find.text('60 fps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1080p · 60 fps · Cân bằng'), findsOneWidget);
  });

  testWidgets('recording state shows timer, pause and stop', (tester) async {
    final (:app, :fake) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    fake.controller.add(RecStateEvent(RecPhase.recording, 65000));
    await tester.pump();
    await tester.pump();
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Đang quay'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('live_pause')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Đã tạm dừng'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('live_stop')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bắt đầu quay'), findsOneWidget);
    expect(fake.calls, containsAllInOrder(['pause', 'stop']));
  });

  testWidgets('marker settings: pick a tool, preview re-renders natively', (
    tester,
  ) async {
    _phone(tester);
    final (:app, :fake) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings_markers')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final scroller = find
        .descendant(
          of: find.byType(MarkerSettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(find.text('Xem thử'), findsOneWidget);
    expect(fake.calls, contains('renderMarker:finger'));
    await tester.scrollUntilVisible(
      find.text('Mũi tên'),
      200,
      scrollable: scroller,
    );
    await tester.tap(find.text('Mũi tên'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.calls, contains('renderMarker:arrow'));

    // The effect time is a seconds slider from 0,5 s to 10 s; it shows its value and is kept.
    final holdSlider = find.descendant(
      of: find.byKey(const ValueKey('marker_hold_slider')),
      matching: find.byType(Slider),
    );
    await tester.scrollUntilVisible(holdSlider, 200, scrollable: scroller);
    expect(find.text('2,5 giây'), findsWidgets);
    expect(find.textContaining('0,5 s'), findsOneWidget);
    expect(find.textContaining('10 s'), findsOneWidget);
    await tester.drag(holdSlider, const Offset(2000, 0)); // far right = longest
    await tester.pump();
    expect(find.text('10 giây'), findsWidgets);
    await tester.drag(
      holdSlider,
      const Offset(-4000, 0),
    ); // far left = shortest
    await tester.pump();
    expect(find.text('0,5 giây'), findsWidgets);
  });

  testWidgets('saved event shows a snackbar with a View action', (
    tester,
  ) async {
    final (:app, :fake) = await buildTestApp(media: [_entry('ESR_9.mp4')]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    fake.controller.add(
      RecSavedEvent('content://media/ESR_9.mp4', 'ESR_9.mp4', 83000, 1000),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Đã lưu ESR_9.mp4'), findsOneWidget);
    expect(find.text('Xem'), findsOneWidget);
  });
}
