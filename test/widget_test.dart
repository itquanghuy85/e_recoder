import 'package:e_screen_recorder/core/native_recorder.dart';
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

  testWidgets('frame rate is picked under More options', (tester) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp(prefs: {'purpose': 2});
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm tuỳ chọn'));
    await tester.tap(find.text('Thêm tuỳ chọn'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('more_fps_60')));
    await tester.tap(find.byKey(const ValueKey('more_fps_60')));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('more_fps_60')),
    );
    expect(chip.selected, isTrue);
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

  testWidgets('tutorial: mark time and zoom level are sliders on the main options', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp(
      prefs: {'purpose': 0, 'marker.mode': 1, 'marker.touchSourceV2': 3},
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    final hold = find.byKey(const ValueKey('quick_hold'));
    await tester.ensureVisible(hold);
    await tester.pumpAndSettle();
    expect(find.text('2,5 s'), findsOneWidget);
    await tester.drag(hold, const Offset(2000, 0)); // far right = longest
    await tester.pumpAndSettle();
    expect(find.text('10,0 s'), findsOneWidget);
    await tester.drag(hold, const Offset(-4000, 0)); // far left = shortest
    await tester.pumpAndSettle();
    expect(find.text('0,5 s'), findsOneWidget);

    // zoom level: 170 % by default, up to 300 %
    final zoom = find.byKey(const ValueKey('quick_zoom_scale'));
    await tester.ensureVisible(zoom);
    await tester.pumpAndSettle();
    expect(find.text('170%'), findsOneWidget);
    await tester.drag(zoom, const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(find.text('300%'), findsOneWidget);
    await tester.drag(zoom, const Offset(-4000, 0));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
  });
}
