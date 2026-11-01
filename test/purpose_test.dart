import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/features/record/rec_settings.dart';
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

  testWidgets('first run: tutorial is picked and its settings applied', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp(onboarded: false);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(c.read(purposeProvider), Purpose.tutorial);
    expect(c.read(settingsStoreProvider).getInt('purpose', -1), 0);
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
    Future<ProviderContainer> open(
      WidgetTester tester,
      Map<String, Object> prefs,
    ) async {
      _phone(tester);
      final (:app, fake: _) = await buildTestApp(prefs: prefs);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
    }

    Future<void> tapId(WidgetTester tester, String id) async {
      await tester.ensureVisible(find.byKey(ValueKey(id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(id)));
      await tester.pumpAndSettle();
    }

    // The purpose buttons are at the top, the "More options" fold near the bottom.
    Future<void> tapText(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    for (final p in Purpose.values) {
      testWidgets('one big "Start recording" button for ${p.name}', (
        tester,
      ) async {
        await open(tester, {'purpose': p.index});
        expect(find.text('Bắt đầu quay'), findsOneWidget);
        final size = tester.getSize(find.byKey(const ValueKey('record_start')));
        expect(size.height, greaterThanOrEqualTo(80));
        expect(size.width, greaterThan(300)); // the whole row
        // the purpose is picked on top, nothing is left of the old screen
        expect(find.byKey(const ValueKey('purpose_selector')), findsOneWidget);
        expect(find.byKey(const ValueKey('profile_card')), findsNothing);
        expect(find.byKey(const ValueKey('change_purpose')), findsNothing);
        expect(find.text('Nâng cao'), findsNothing);
        expect(find.text('Thêm tuỳ chọn'), findsOneWidget);
      });
    }

    testWidgets('quick options: a tick is saved at once', (tester) async {
      final c = await open(tester, {'purpose': Purpose.tutorial.index});
      expect(c.read(recSettingsProvider).audio, AudioMode.mic);
      await tapId(tester, 'quick_system');
      expect(c.read(recSettingsProvider).audio, AudioMode.both);
      await tapId(tester, 'quick_mic');
      expect(c.read(recSettingsProvider).audio, AudioMode.system);
      await tapId(tester, 'quick_marks_auto');
      expect(c.read(markerSettingsProvider).mode, MarkMode.clean);
      expect(c.read(markerSettingsProvider).touchSource, TouchSource.auto);
      await tapId(tester, 'quick_auto_zoom');
      expect(c.read(markerSettingsProvider).autoZoom, isFalse);
      // what was saved is what the next launch reads
      final s = c.read(settingsStoreProvider);
      expect(s.getInt('rec.audio', -1), AudioMode.system.index);
    });

    testWidgets('tap marks: automatic, by hand, or none', (tester) async {
      final c = await open(tester, {'purpose': Purpose.tutorial.index});
      await tapId(tester, 'quick_marks_live');
      expect(c.read(markerSettingsProvider).mode, MarkMode.dot);
      expect(find.byKey(const ValueKey('quick_auto_zoom')), findsNothing);
      await tapId(tester, 'quick_marks_none');
      expect(c.read(markerSettingsProvider).mode, MarkMode.clean);
      expect(c.read(markerSettingsProvider).touchSource, TouchSource.off);
      expect(find.byKey(const ValueKey('quick_auto_number')), findsNothing);
      await tapId(tester, 'quick_marks_auto');
      expect(c.read(markerSettingsProvider).touchSource, TouchSource.auto);
    });

    testWidgets('each purpose keeps its own settings', (tester) async {
      final c = await open(tester, {'purpose': Purpose.tutorial.index});
      await tapId(tester, 'quick_marks_auto');
      await tapId(tester, 'quick_res_p720');
      expect(c.read(recSettingsProvider).resolution, Resolution.p720);

      // game, used for the first time: starts from what was in use, with its ready settings on top
      await tapText(tester, 'Game');
      expect(c.read(purposeProvider), Purpose.game);
      expect(c.read(recSettingsProvider).resolution, Resolution.p720);
      expect(c.read(markerSettingsProvider).mode, MarkMode.dot);
      await tapId(tester, 'quick_res_native');
      await tapId(tester, 'quick_smooth');
      expect(c.read(recSettingsProvider).fps, 60);

      // back to tutorial: its own settings, untouched by what was done in game
      await tapText(tester, 'Hướng dẫn');
      expect(c.read(recSettingsProvider).resolution, Resolution.p720);
      expect(c.read(recSettingsProvider).fps, 30);
      expect(c.read(markerSettingsProvider).mode, MarkMode.clean);
      expect(c.read(markerSettingsProvider).touchSource, TouchSource.auto);

      // and game again: what was picked there
      await tapText(tester, 'Game');
      expect(c.read(recSettingsProvider).resolution, Resolution.native);
      expect(c.read(recSettingsProvider).fps, 60);

      // all of it is saved: the choice, the settings in use, and a copy per purpose
      final s = c.read(settingsStoreProvider);
      expect(s.getInt('purpose', -1), Purpose.game.index);
      expect(s.getInt('rec.resolution', -1), Resolution.native.index);
      expect(s.getString(profileKey(Purpose.tutorial)), isNotNull);
      expect(s.getString(profileKey(Purpose.game)), isNotNull);
    });

    testWidgets('someone who used the app before keeps their settings', (
      tester,
    ) async {
      // no purpose saved yet (the old screen), settings of their own
      final c = await open(tester, {
        'rec.resolution': Resolution.p720.index,
        'rec.countdown': 5,
        'marker.color': 3,
      });
      expect(c.read(purposeProvider), Purpose.tutorial);
      expect(c.read(settingsStoreProvider).getInt('purpose', -1), 0);
      expect(c.read(recSettingsProvider).resolution, Resolution.p720);
      expect(c.read(recSettingsProvider).countdown, 5);
      expect(c.read(markerSettingsProvider).colorIndex, 3);
      expect(c.read(markerSettingsProvider).mode, MarkMode.clean);
      // and every other purpose starts from them too
      await tapText(tester, 'Quay thường');
      expect(c.read(recSettingsProvider).resolution, Resolution.p720);
      expect(c.read(recSettingsProvider).countdown, 5);
      expect(c.read(markerSettingsProvider).colorIndex, 3);
    });

    testWidgets('more options belong to the purpose', (tester) async {
      await open(tester, {
        'purpose': Purpose.tutorial.index,
        'marker.mode': MarkMode.clean.index,
        'marker.touchSourceV2': TouchSource.auto.index,
      });
      // the main options: how long a mark shows, how far the zoom goes
      expect(find.byKey(const ValueKey('quick_hold')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_zoom_scale')), findsOneWidget);
      await tapText(tester, 'Thêm tuỳ chọn');
      expect(find.byKey(const ValueKey('quick_mark_number')), findsOneWidget);
      expect(find.byKey(const ValueKey('more_zoom_ramp')), findsOneWidget);
      expect(find.byKey(const ValueKey('more_zoom_hold')), findsOneWidget);
      expect(find.byKey(const ValueKey('more_pause')), findsOneWidget);
      expect(find.byKey(const ValueKey('more_countdown_3')), findsOneWidget);
      expect(find.byKey(const ValueKey('more_floating')), findsNothing);

      await tapText(tester, 'Game');
      await tapText(tester, 'Thêm tuỳ chọn');
      expect(find.byKey(const ValueKey('more_floating')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_mark_number')), findsNothing);
      expect(find.byKey(const ValueKey('quick_zoom_scale')), findsNothing);
      expect(find.byKey(const ValueKey('quick_hold')), findsOneWidget); // marks by hand have it too
    });

    testWidgets('a change in More options is saved for that purpose', (
      tester,
    ) async {
      final c = await open(tester, {'purpose': Purpose.plain.index});
      await tapText(tester, 'Thêm tuỳ chọn');
      await tapId(tester, 'more_countdown_0');
      expect(c.read(recSettingsProvider).countdown, 0);
      await tapText(tester, 'Hướng dẫn');
      expect(c.read(recSettingsProvider).countdown, 0); // first use: starts from it
      await tapText(tester, 'Thêm tuỳ chọn');
      await tapId(tester, 'more_countdown_5');
      expect(c.read(recSettingsProvider).countdown, 5);
      await tapText(tester, 'Quay thường');
      expect(c.read(recSettingsProvider).countdown, 0);
    });

    testWidgets('reset puts every purpose back to its first settings', (
      tester,
    ) async {
      final c = await open(tester, {'purpose': Purpose.game.index});
      await tapId(tester, 'quick_res_p720');
      await tapId(tester, 'quick_smooth');
      await c.read(purposeProvider.notifier).resetAll();
      await tester.pumpAndSettle();
      expect(c.read(purposeProvider), Purpose.game);
      expect(c.read(recSettingsProvider).resolution, Resolution.p1080);
      expect(c.read(recSettingsProvider).fps, 30);
      expect(c.read(markerSettingsProvider).mode, MarkMode.dot); // game's ready settings
      final s = c.read(settingsStoreProvider);
      expect(s.getString(profileKey(Purpose.tutorial)), isNull);
      expect(s.getString(profileKey(Purpose.plain)), isNull);
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

    testWidgets('no microphone: "Record without sound" starts without it', (
      tester,
    ) async {
      final fake = await open(tester, mic: false);
      await tester.tap(find.byKey(const ValueKey('record_start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ready_mic')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ready_no_sound')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(c.read(recSettingsProvider).audio, AudioMode.none);
      expect(fake.calls, contains('start'));
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
  });
}
