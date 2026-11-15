import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/touch_log.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

/// The real order of events after Stop: saving, then "saved", then idle. The result screen must open
/// (or the "still indexing" notice must show) whatever the mark mode, never nothing.
void main() {
  const uri = 'content://media/external/video/media/77';
  MediaEntry entry() => MediaEntry(
    uri: uri,
    name: 'ESR_77.mp4',
    durationMs: 20000,
    size: 1000,
    width: 720,
    height: 1600,
    dateAdded: DateTime(2026),
  );
  RecSavedEvent saved({List<RawTouch> touches = const []}) => RecSavedEvent(
    uri,
    'ESR_77.mp4',
    20000,
    1000,
    width: 720,
    height: 1600,
    touches: touches,
  );

  for (final (name, prefs) in [
    ('dot mode', <String, Object>{'marker.mode': 0}),
    ('clean + automatic', <String, Object>{'marker.mode': 1}),
  ]) {
    testWidgets('$name: Stop -> saved -> the result screen opens', (
      tester,
    ) async {
      final (:app, :fake) = await buildTestApp(
        prefs: prefs,
        projects: MemoryProjectStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      fake.controller.add(RecStateEvent(RecPhase.recording, 15000));
      await tester.pump();
      fake.controller.add(RecStateEvent(RecPhase.saving, 15000));
      await tester.pump();
      // The file reaches MediaStore, then the event, then the service goes idle.
      fake.media.add(entry());
      fake.controller.add(saved(touches: [RawTouch(tMs: 3000)]));
      fake.controller.add(RecStateEvent(RecPhase.idle, 0));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Quay xong rồi'), findsOneWidget);
    });
  }

  testWidgets('saved but not in the library yet: says so, does not stay silent', (
    tester,
  ) async {
    final (:app, :fake) = await buildTestApp(projects: MemoryProjectStore());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    fake.controller.add(saved());
    fake.controller.add(RecStateEvent(RecPhase.idle, 0));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.textContaining('Thư viện đang cập nhật'), findsOneWidget);
  });

  testWidgets('the library cannot be read: still says the video is saved', (
    tester,
  ) async {
    final (:app, :fake) = await buildTestApp(projects: MemoryProjectStore());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    fake.listFails = true;
    fake.controller.add(saved());
    fake.controller.add(RecStateEvent(RecPhase.idle, 0));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.textContaining('Thư viện đang cập nhật'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
