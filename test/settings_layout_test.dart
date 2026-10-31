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
      tester.getTopLeft(find.text('Đưa các chế độ quay về mặc định')).dy,
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
    expect(find.textContaining('các chế độ quay'), findsWidgets);
    // the marks have no page of their own any more: they are set per purpose on the Record tab
    expect(find.byKey(const ValueKey('settings_markers')), findsNothing);
  });
}
