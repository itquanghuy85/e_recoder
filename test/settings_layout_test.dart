import 'package:e_screen_recorder/features/marker/marker_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The app on its Settings tab.
Future<void> _openSettings(WidgetTester tester) async {
  _phone(tester);
  final (:app, fake: _) = await buildTestApp();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cài đặt'));
  await tester.pumpAndSettle();
}

/// The marker settings screen and the finder of its scrolling list.
Future<Finder> _openMarkers(WidgetTester tester) async {
  await _openSettings(tester);
  await tester.tap(find.byKey(const ValueKey('settings_markers')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return find
      .descendant(
        of: find.byType(MarkerSettingsScreen),
        matching: find.byType(Scrollable),
      )
      .first;
}

void main() {
  testWidgets('settings are grouped, each group says what it is for', (
    tester,
  ) async {
    await _openSettings(tester);
    // a tall window, so the whole list is built
    tester.view.physicalSize = const Size(1080, 4800);
    await tester.pumpAndSettle();
    final app = tester.getTopLeft(find.text('Ứng dụng')).dy;
    final rec = tester.getTopLeft(find.text('Quay màn hình').last).dy;
    final help = tester.getTopLeft(find.text('Trợ giúp và thông tin')).dy;
    expect(app, lessThan(rec));
    expect(rec, lessThan(help));
    // each entry sits under its group
    expect(
      tester.getTopLeft(find.text('Dấu đánh dấu')).dy,
      inInclusiveRange(rec, help),
    );
    expect(
      tester.getTopLeft(find.text('Quyền và pin')).dy,
      inInclusiveRange(rec, help),
    );
    expect(
      tester.getTopLeft(find.text('Quyền riêng tư')).dy,
      greaterThan(help),
    );
    // and says in plain words what it does
    expect(find.textContaining('tự động dựng'), findsWidgets);
  });

  testWidgets(
    'marker settings: four groups, in the order a person needs them',
    (tester) async {
      final scroller = await _openMarkers(tester);
      final titles = [
        'Kiểu dấu',
        'Dấu hiện bao lâu',
        'Cách đánh dấu khi quay',
        'Tự động dựng sau khi quay',
      ];
      final ys = <double>[];
      for (final tl in titles) {
        await tester.scrollUntilVisible(
          find.text(tl),
          300,
          scrollable: scroller,
        );
        ys.add(tester.getTopLeft(find.text(tl)).dy);
      }
      // each group has a one-line purpose under its title
      expect(
        find.textContaining('App tự phóng to vào chỗ bạn đã đánh dấu'),
        findsOneWidget,
      );
      // reaching them in order means scrolling down: each title is where the next scroll left it
      expect(ys.every((y) => y > 0), isTrue);
    },
  );

  testWidgets(
    'automatic editing: with the dot it says why not and offers the switch',
    (tester) async {
      final scroller = await _openMarkers(tester);
      final switchBtn = find.text('Bật Quay sạch, dựng sau');
      await tester.scrollUntilVisible(switchBtn, 300, scrollable: scroller);
      expect(find.textContaining('chỉ có khi quay sạch'), findsOneWidget);
      expect(find.byKey(const ValueKey('auto_zoom_setting')), findsNothing);
      expect(find.byKey(const ValueKey('auto_number_setting')), findsNothing);
      // what the switch does once tapped is checked on the phone (maestro/settings_layout.yaml)
    },
  );
}
