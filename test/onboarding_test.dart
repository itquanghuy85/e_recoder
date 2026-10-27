import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('first run walks through three pages then opens the recorder', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp(onboarded: false);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('Người xem luôn biết bạn sắp bấm vào đâu'),
      findsOneWidget,
    );
    expect(find.text('Bắt đầu quay'), findsNothing);

    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Ba bước để chỉ điểm'), findsOneWidget);

    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Cho phép vài quyền'), findsOneWidget);
    expect(find.text('Bắt đầu dùng'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu dùng'));
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu quay'), findsOneWidget);
  });

  testWidgets('skip goes straight to the recorder and is remembered', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp(onboarded: false);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu quay'), findsOneWidget);
  });

  testWidgets('permission rows reflect what is granted', (tester) async {
    _phone(tester);
    final perms = FakePermissions()
      ..mic = false
      ..notif = true;
    final (:app, :fake) = await buildTestApp(permissions: perms);
    fake.overlayGranted = true;
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quyền và pin'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Quyền và pin'));
    await tester.pumpAndSettle();
    // overlay + notifications granted, microphone not
    expect(find.text('Đã cấp'), findsNWidgets(2));
    expect(find.text('Cấp quyền'), findsOneWidget);
    await tester.tap(find.text('Cấp quyền'));
    await tester.pumpAndSettle();
    expect(perms.calls, contains('requestMic'));
    // denied: sends the user to the app settings page
    expect(perms.calls, contains('openSettings'));
  });

  testWidgets('settings pages open: privacy and about', (tester) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quyền riêng tư'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Quyền riêng tư'));
    await tester.pumpAndSettle();
    expect(find.text('Video ở lại trên máy'), findsOneWidget);
  });
}
