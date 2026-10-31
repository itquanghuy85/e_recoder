import 'dart:convert';

import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/core/permissions_gateway.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/touch_log.dart' show RawTouch;
import 'package:e_screen_recorder/features/record/recorder_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_recorder.dart';

const _uri = 'content://v/9';

EditProject _base() => EditProject.fresh(
  sourceUri: _uri,
  name: 'ESR_9.mp4',
  durationMs: 20000,
  frameW: 720,
  frameH: 1600,
);

String _pending({int tries = 0, List<int> touches = const [5000, 9000]}) =>
    jsonEncode({'uri': _uri, 'touches': touches, 'tries': tries});

Future<({ProviderContainer c, FakeRecorder fake, MemoryProjectStore store})>
_launch(Map<String, Object> prefs, {EditProject? saved}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = MemoryProjectStore();
  if (saved != null) await store.save(saved);
  final fake = FakeRecorder();
  fake.touchPlaces[5000] = (x: 0.7, y: 0.2);
  fake.touchPlaces[9000] = (x: 0.3, y: 0.6);
  final c = ProviderContainer(
    overrides: [
      settingsStoreProvider.overrideWithValue(await SettingsStore.load()),
      nativeRecorderProvider.overrideWithValue(fake),
      permissionsGatewayProvider.overrideWithValue(FakePermissions()),
      projectStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(fake.controller.close);
  return (c: c, fake: fake, store: store);
}

void main() {
  test(
    'a build cut short by the app being killed is finished at the next launch',
    () async {
      final l = await _launch({'draft.pending': _pending()}, saved: _base());
      final n = l.c.read(recorderProvider.notifier);
      await n.draftReady;
      final p = (await l.store.load(_uri))!;
      expect(p.markers.length, greaterThanOrEqualTo(2));
      expect(l.fake.calls, contains('locateTouches:2'));
      expect(
        l.c.read(settingsStoreProvider).getString('draft.pending'),
        isNull,
      );
    },
  );

  test('a job whose project is gone is dropped, nothing is built', () async {
    final l = await _launch({'draft.pending': _pending()});
    await l.c.read(recorderProvider.notifier).draftReady;
    expect(l.fake.calls.where((e) => e.startsWith('locateTouches')), isEmpty);
    expect(l.c.read(settingsStoreProvider).getString('draft.pending'), isNull);
  });

  test(
    'a job that already failed twice is not tried again (no crash loop)',
    () async {
      final l = await _launch({
        'draft.pending': _pending(tries: 2),
      }, saved: _base());
      await l.c.read(recorderProvider.notifier).draftReady;
      expect(l.fake.calls.where((e) => e.startsWith('locateTouches')), isEmpty);
      expect(
        l.c.read(settingsStoreProvider).getString('draft.pending'),
        isNull,
      );
      expect((await l.store.load(_uri))!.markers, isEmpty);
    },
  );

  test('nothing pending: nothing happens at launch', () async {
    final l = await _launch({});
    await l.c.read(recorderProvider.notifier).draftReady;
    expect(l.fake.calls, isEmpty);
  });

  test(
    'a normal recording crosses the job out when its edit is built',
    () async {
      final l = await _launch({'marker.mode': 1});
      l.c.read(recorderProvider);
      l.fake.controller.add(
        RecSavedEvent(
          _uri,
          'ESR_9.mp4',
          20000,
          1000,
          width: 720,
          height: 1600,
          touches: [RawTouch(tMs: 5000)],
        ),
      );
      await l.c.read(recorderProvider.notifier).draftReady;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        l.c.read(settingsStoreProvider).getString('draft.pending'),
        isNull,
      );
      expect((await l.store.load(_uri))!.markers, isNotEmpty);
    },
  );
}
