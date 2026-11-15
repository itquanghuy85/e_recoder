import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_timeline.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

/// Dragging the timeline while the video plays: playback steps aside for the drag (otherwise the
/// player keeps pulling the playhead back) and goes on from the new place when the finger lifts.
void main() {
  testWidgets('a drag while playing pauses, moves the playhead, then resumes', (
    tester,
  ) async {
    final fake = FakeRecorder();
    addTearDown(fake.controller.close);
    final c = EditorController(
      project: EditProject.fresh(
        sourceUri: 'content://v/1',
        name: 'a.mp4',
        durationMs: 60000,
        frameW: 720,
        frameH: 1600,
      ),
      native: fake,
      store: MemoryProjectStore(),
      autosaveDelay: const Duration(milliseconds: 10),
    );
    addTearDown(c.dispose);
    c.seekOut(20000);
    c.setPlaying(true);
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        locale: const Locale('vi'),
        home: Scaffold(
          body: Center(
            child: EditorTimeline(
              controller: c,
              onScrubStart: () async {
                events.add('pause');
                c.setPlaying(false);
              },
              onScrubEnd: () async {
                events.add('play@${c.outMs}');
                c.setPlaying(true);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Drag to the left = later in the video. Start on the ruler, where no clip can be grabbed.
    final box = tester.getRect(find.byType(EditorTimeline));
    final g = await tester.startGesture(Offset(box.center.dx, box.top + 8));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-30, 0));
      await tester.pump();
    }
    expect(events, ['pause']);
    expect(c.playing, isFalse);
    await g.up();
    await tester.pump();
    expect(c.outMs, greaterThan(20000));
    expect(events.length, 2);
    expect(events.last, 'play@${c.outMs}');
    expect(c.playing, isTrue);
  });
}
