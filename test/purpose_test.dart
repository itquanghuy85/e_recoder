import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/marker/marker_settings.dart';
import 'package:e_screen_recorder/features/purpose/purpose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('what each purpose switches', () {
    const base = MarkerSettings();
    test('tutorial: clean recording, listens to taps, marks and zooms', () {
      final m = applyPurposeToMarkers(Purpose.tutorial, base);
      expect(m.mode, MarkMode.clean);
      expect(m.touchSource, TouchSource.auto);
      expect(m.autoNumber, isTrue);
      expect(m.autoZoom, isTrue);
    });

    test('game: marks by hand, no automatic zoom', () {
      final m = applyPurposeToMarkers(
        Purpose.game,
        base.copyWith(mode: MarkMode.clean, autoZoom: true),
      );
      expect(m.mode, MarkMode.dot);
      expect(m.autoZoom, isFalse);
      expect(m.autoNumber, isTrue);
    });

    test('plain: everything automatic is off', () {
      final m = applyPurposeToMarkers(Purpose.plain, base);
      expect(m.mode, MarkMode.dot);
      expect(m.touchSource, TouchSource.off);
      expect(m.autoNumber, isFalse);
      expect(m.autoZoom, isFalse);
    });

    test('the look the person chose is left alone', () {
      final mine = base.copyWith(
        tool: MarkerType.circle,
        colorIndex: 2,
        thickness: 8,
        holdMs: 4000,
        autoMarker: MarkerType.arrow,
      );
      for (final p in Purpose.values) {
        final m = applyPurposeToMarkers(p, mine);
        expect(m.tool, MarkerType.circle);
        expect(m.colorIndex, 2);
        expect(m.thickness, 8);
        expect(m.holdMs, 4000);
        expect(m.autoMarker, MarkerType.arrow);
      }
    });
  });

  testWidgets('first run: the choice is saved, applied and not asked again', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp(onboarded: false);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Làm video hướng dẫn'));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(c.read(purposeProvider), Purpose.tutorial);
    expect(c.read(markerSettingsProvider).mode, MarkMode.clean);
    expect(c.read(markerSettingsProvider).touchSource, TouchSource.auto);
    expect(find.text('Bạn muốn làm gì?'), findsNothing);
  });

  testWidgets('someone already past the introduction is not asked', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn làm gì?'), findsNothing);
  });

  group('the recorder screen', () {
    Future<void> open(WidgetTester tester, Map<String, Object> prefs) async {
      _phone(tester);
      final (:app, fake: _) = await buildTestApp(prefs: prefs);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
    }

    for (final (p, label) in [
      (Purpose.tutorial, 'Quay hướng dẫn tự động'),
      (Purpose.game, 'Quay game'),
      (Purpose.plain, 'Quay video'),
    ]) {
      testWidgets('one big button says what it does for ${p.name}', (
        tester,
      ) async {
        await open(tester, {'purpose': p.index});
        expect(find.text(label), findsOneWidget);
        expect(find.text('Bắt đầu quay'), findsNothing);
        final size = tester.getSize(find.byKey(const ValueKey('record_start')));
        expect(size.height, greaterThanOrEqualTo(88));
        expect(size.width, greaterThan(300)); // the whole row
      });
    }

    testWidgets('the old controls are folded into Advanced', (tester) async {
      await open(tester, {'purpose': Purpose.tutorial.index});
      expect(find.text('Nâng cao'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_card')), findsNothing);
      await tester.tap(find.text('Nâng cao'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile_card')), findsOneWidget);
      // and the choice can be changed from there
      await tester.tap(find.byKey(const ValueKey('change_purpose')));
      await tester.pumpAndSettle();
      expect(find.text('Bạn muốn làm gì?'), findsOneWidget);
      await tester.tap(find.text('Quay game'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn muốn làm gì?'), findsNothing);
      expect(find.text('Quay game'), findsWidgets); // the big button now
      final c = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(c.read(purposeProvider), Purpose.game);
    });

    testWidgets('the old way is untouched when no purpose was chosen', (
      tester,
    ) async {
      await open(tester, {});
      expect(find.text('Bắt đầu quay'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_card')), findsOneWidget);
      expect(find.text('Nâng cao'), findsNothing);
      // and the choice is offered
      expect(find.byKey(const ValueKey('purpose_offer')), findsOneWidget);
    });
  });

  group('ready to record?', () {
    Future<FakeRecorder> open(
      WidgetTester tester, {
      bool overlay = true,
      bool mic = true,
    }) async {
      _phone(tester);
      final perms = FakePermissions()..mic = mic;
      final (:app, :fake) = await buildTestApp(
        prefs: {'purpose': Purpose.tutorial.index},
        permissions: perms,
      );
      fake.overlayGranted = overlay;
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('nothing missing: recording starts at once', (tester) async {
      final fake = await open(tester);
      await tester.tap(find.byKey(const ValueKey('record_start')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sẵn sàng quay chưa?'), findsNothing);
      expect(fake.calls, contains('start'));
    });

    testWidgets('a missing permission is listed, not a silent failure', (
      tester,
    ) async {
      final fake = await open(tester, overlay: false, mic: false);
      await tester.tap(find.byKey(const ValueKey('record_start')));
      await tester.pumpAndSettle();
      expect(find.text('Sẵn sàng quay chưa?'), findsOneWidget);
      expect(fake.calls, isNot(contains('start')));
      expect(find.byKey(const ValueKey('ready_mic')), findsOneWidget);
      expect(find.byKey(const ValueKey('ready_overlay')), findsOneWidget);
      // the way in is shut until everything needed is on
      final go = tester.widget<FilledButton>(
        find.byKey(const ValueKey('ready_go')),
      );
      expect(go.onPressed, isNull);
    });

    testWidgets('the Turn on button goes to the place, and Ready opens', (
      tester,
    ) async {
      final fake = await open(tester, overlay: false);
      await tester.tap(find.byKey(const ValueKey('record_start')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ready_mic')),
        findsNothing,
      ); // mic is on
      await tester.tap(find.byKey(const ValueKey('ready_overlay')));
      await tester.pumpAndSettle();
      expect(fake.calls, contains('requestOverlay'));
      // the person comes back from the system settings with it switched on
      fake.overlayGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ready_overlay_on')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ready_go')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.calls, contains('start'));
    });

    testWidgets('the old way keeps its old behaviour (no screen)', (
      tester,
    ) async {
      _phone(tester);
      final (:app, :fake) = await buildTestApp();
      fake.overlayGranted = false;
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_start')));
      await tester.pumpAndSettle();
      expect(find.text('Sẵn sàng quay chưa?'), findsNothing);
      expect(fake.calls, contains('requestOverlay')); // as before
    });
  });

  group('after recording', () {
    final entry = MediaEntry(
      uri: 'content://v/9',
      name: 'ESR_9.mp4',
      durationMs: 20000,
      size: 1000,
      width: 720,
      height: 1600,
      dateAdded: DateTime(2026, 10, 31),
    );

    Future<FakeRecorder> open(
      WidgetTester tester,
      Map<String, Object> prefs,
    ) async {
      _phone(tester);
      final (:app, :fake) = await buildTestApp(
        media: [entry],
        prefs: prefs,
        projects: MemoryProjectStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      fake.controller.add(
        RecSavedEvent('content://v/9', 'ESR_9.mp4', 20000, 1000),
      );
      // the list reloads, then the screen is pushed and slides in
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      return fake;
    }

    testWidgets('with a purpose: the result screen, not the editor', (
      tester,
    ) async {
      await open(tester, {'purpose': Purpose.tutorial.index});
      expect(find.text('Quay xong rồi'), findsOneWidget);
      expect(find.byKey(const ValueKey('result_export')), findsOneWidget);
      expect(find.byKey(const ValueKey('result_edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('result_back')), findsOneWidget);
      expect(find.text('Sửa thêm'), findsOneWidget);
      expect(find.text('Xuất ngay'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
    });

    testWidgets('Export now exports the recording at once', (tester) async {
      final fake = await open(tester, {'purpose': Purpose.plain.index});
      await tester.tap(find.byKey(const ValueKey('result_export')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fake.calls, contains('startExport'));
      expect(fake.lastExportJob!['sourceUri'], 'content://v/9');
      // the buttons that would leave are shut while it runs
      final back = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('result_back')),
      );
      expect(back.onPressed, isNull);
      fake.controller.add(
        ExportDoneEvent('content://e/1', 'ESR_edit_9.mp4', 20000, 5000),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('result_done')), findsOneWidget);
      expect(find.text('Đã xuất: ESR_edit_9.mp4'), findsOneWidget);
    });

    testWidgets('Record again goes back to the recorder', (tester) async {
      await open(tester, {'purpose': Purpose.plain.index});
      await tester.tap(find.byKey(const ValueKey('result_back')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Quay xong rồi'), findsNothing);
      expect(find.byKey(const ValueKey('record_start')), findsOneWidget);
    });

    testWidgets('the old way still shows the snack bar with View', (
      tester,
    ) async {
      await open(tester, {});
      expect(find.text('Quay xong rồi'), findsNothing);
      expect(find.text('Xem'), findsOneWidget);
    });
  });
}
