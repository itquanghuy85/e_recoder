import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

/// Large system fonts and both themes must not overflow or hide the primary actions.
Widget _scaled(Widget app, double scale) => MediaQuery(
  data: MediaQueryData(
    textScaler: TextScaler.linear(scale),
    size: const Size(360, 800),
    devicePixelRatio: 3,
  ),
  child: app,
);

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('record, library and settings survive text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final (:app, :fake) = await buildTestApp(
        media: [
          MediaEntry(
            uri: 'content://m/1',
            name: 'ESR_20261026_101010_a_very_long_recording_name.mp4',
            durationMs: 3725000,
            size: 123456789,
            width: 1080,
            height: 2400,
            dateAdded: DateTime(2026, 10, 26, 10, 10),
          ),
        ],
      );
      await tester.pumpWidget(_scaled(app, scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Bắt đầu quay'), findsOneWidget);

      await tester.tap(find.text('Thư viện'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fake.calls, isEmpty);
    });
  }

  testWidgets('onboarding pages fit at 2x text', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (:app, fake: _) = await buildTestApp(onboarded: false);
    await tester.pumpWidget(_scaled(app, 2.0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Tiếp'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Bắt đầu dùng'), findsOneWidget);
  });

  testWidgets('dark theme renders the record screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (:app, fake: _) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Bắt đầu quay'), findsOneWidget);
  });
}
