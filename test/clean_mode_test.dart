import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/core/permissions_gateway.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/marker/marker_settings.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/features/record/recorder_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_recorder.dart';

Future<(ProviderContainer, FakeRecorder, MemoryProjectStore)> _make([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = MemoryProjectStore();
  final fake = FakeRecorder();
  final container = ProviderContainer(
    overrides: [
      settingsStoreProvider.overrideWithValue(await SettingsStore.load()),
      nativeRecorderProvider.overrideWithValue(fake),
      permissionsGatewayProvider.overrideWithValue(FakePermissions()),
      projectStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(fake.controller.close);
  container.read(recorderProvider); // start listening to the event stream
  return (container, fake, store);
}

RecSavedEvent _saved({List<RecMark> marks = const []}) => RecSavedEvent(
  'content://v/9',
  'ESR_9.mp4',
  20000,
  1000,
  width: 720,
  height: 1600,
  marks: marks,
);

RecMark _mark(int t, {MarkerType type = MarkerType.finger, double x = 0.5}) =>
    RecMark(
      tMs: t,
      holdMs: 2500,
      spec: MarkerSpec(type: type, x0: x, y0: 0.4, x1: x, y1: 0.4),
    );

void main() {
  group('marker settings', () {
    test('default to the small dot, bottom-left, no shake', () async {
      final (c, _, _) = await _make();
      final s = c.read(markerSettingsProvider);
      expect(s.mode, MarkMode.dot);
      expect(s.corner, 2);
      expect(s.armShake, isFalse);
      expect(s.autoZoom, isTrue);
      expect(s.autoNumber, isTrue);
    });

    test('the effect time is kept, limited to 0,5 .. 10 s, and reaches recording', () async {
      final (c, fake, _) = await _make({'marker.hold': 7500});
      expect(c.read(markerSettingsProvider).holdMs, 7500);
      await c
          .read(markerSettingsProvider.notifier)
          .update(const MarkerSettings(holdMs: 500));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('marker.hold'), 500);
      // A value from an old or hand-edited store is pulled back into the range.
      final (low, _, _) = await _make({'marker.hold': 50});
      expect(low.read(markerSettingsProvider).holdMs, 500);
      final (high, _, _) = await _make({'marker.hold': 99000});
      expect(high.read(markerSettingsProvider).holdMs, 10000);
      expect(fake, isNotNull);
    });

    test('mode, corner and shake survive a restart', () async {
      final (c, _, _) = await _make();
      await c
          .read(markerSettingsProvider.notifier)
          .update(
            const MarkerSettings(
              mode: MarkMode.clean,
              corner: 3,
              armShake: true,
              autoZoom: false,
            ),
          );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('marker.mode'), MarkMode.clean.index);
      expect(prefs.getInt('marker.corner'), 3);

      final (c2, _, _) = await _make({
        'marker.mode': MarkMode.clean.index,
        'marker.corner': 3,
        'marker.armShake': true,
        'marker.autoZoom': false,
      });
      final s = c2.read(markerSettingsProvider);
      expect(s.mode, MarkMode.clean);
      expect(s.corner, 3);
      expect(s.armShake, isTrue);
      expect(s.autoZoom, isFalse);
    });

    test(
      'a start request carries the mode and corner to the native side',
      () async {
        final (c, fake, _) = await _make({
          'marker.mode': 1,
          'marker.corner': 1,
        });
        await c.read(recorderProvider.notifier).start();
        expect(fake.lastRequest!.markMode, 'clean');
        expect(fake.lastRequest!.markCorner, 1);
        expect(fake.lastRequest!.toMap()['markMode'], 'clean');
      },
    );
  });

  group('draft after a clean recording', () {
    test(
      'marks become a project waiting in the store, zoom and steps applied',
      () async {
        final (c, fake, store) = await _make();
        fake.controller.add(
          _saved(
            marks: [
              _mark(2000, type: MarkerType.number),
              _mark(12000, type: MarkerType.number, x: 0.7),
            ],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final p = await store.load('content://v/9');
        expect(p, isNotNull);
        expect(p!.markers.length, 2);
        expect(p.zooms.length, 2);
        expect(p.markers.map((m) => m.spec.number).toList()..sort(), [1, 2]);
        expect(p.frameW, 720);
        expect(c.read(recorderProvider).notice, isA<SavedNotice>());
      },
    );

    test('with the options off the markers come without zoom', () async {
      final (_, fake, store) = await _make({
        'marker.autoZoom': false,
        'marker.autoNumber': false,
      });
      fake.controller.add(_saved(marks: [_mark(2000)]));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final p = await store.load('content://v/9');
      expect(p!.markers.length, 1);
      expect(p.zooms, isEmpty);
    });

    test('a normal recording leaves no project behind', () async {
      final (_, fake, store) = await _make();
      fake.controller.add(_saved());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await store.load('content://v/9'), isNull);
    });
  });

  group('editor auto direct', () {
    test(
      'analyses idle stretches once and applies everything as one undo step',
      () async {
        final fake = FakeRecorder();
        addTearDown(fake.controller.close);
        fake.idleRanges = [(startMs: 8000, endMs: 18000)];
        final base = AutoDirector.draft(
          EditProject.fresh(
            sourceUri: 'content://v/3',
            name: 'a.mp4',
            durationMs: 30000,
            frameW: 720,
            frameH: 1600,
          ),
          [_mark(2000)],
        );
        final c = EditorController(
          project: base,
          native: fake,
          store: MemoryProjectStore(),
          autosaveDelay: const Duration(milliseconds: 10),
        );
        addTearDown(c.dispose);

        await c.directAuto();
        expect(fake.calls.where((e) => e == 'analyzeIdle').length, 1);
        expect(c.project.zooms, isNotEmpty);
        expect(c.project.segments.any((s) => s.speed > 1), isTrue);
        expect(c.lastDirect!.zooms, 1);
        expect(c.lastDirect!.idle, 1);
        expect(c.directing, isFalse);

        c.undo();
        expect(c.project.zooms, isEmpty);
        expect(c.project.segments.length, 1);
      },
    );

    test('with idle off the video is not analysed', () async {
      final fake = FakeRecorder();
      addTearDown(fake.controller.close);
      final c = EditorController(
        project: AutoDirector.draft(
          EditProject.fresh(
            sourceUri: 'content://v/3',
            name: 'a.mp4',
            durationMs: 30000,
            frameW: 720,
            frameH: 1600,
          ),
          [_mark(2000)],
        ),
        native: fake,
        store: MemoryProjectStore(),
      );
      addTearDown(c.dispose);
      c.setDirectorOptions(const DirectorOptions(idle: false));
      await c.directAuto();
      expect(fake.calls, isNot(contains('analyzeIdle')));
      expect(c.project.zooms, isNotEmpty);
    });
  });
}
