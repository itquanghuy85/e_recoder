import 'dart:math' as math;

import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_stage.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'helpers/fake_recorder.dart';

void main() {
  late EditorController c;
  late VideoPlayerController video;

  setUp(() {
    c = EditorController(
      project: EditProject.fresh(
        sourceUri: 'content://v/1',
        name: 'a.mp4',
        durationMs: 10000,
        frameW: 720,
        frameH: 1600,
      ),
      native: FakeRecorder(),
      store: MemoryProjectStore(),
      autosaveDelay: const Duration(milliseconds: 10),
    );
    video = VideoPlayerController.networkUrl(
      Uri.parse('https://x.invalid/v.mp4'),
    );
  });

  tearDown(() {
    c.dispose();
    video.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 800,
            child: EditorStage(controller: c, video: video),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The selected text's frame on the 360 x 800 stage (the output frame is 720 x 1600, so k = 0.5).
  Rect frameOfText() {
    final t = c.project.texts.single;
    return Rect.fromCenter(
      center: Offset(t.x * 360, t.y * 800),
      width: math.max(60, t.text.length * t.sizeU * 0.55 * 0.5),
      height: t.sizeU * 1.5 * 0.5,
    );
  }

  testWidgets('dragging a corner handle resizes the text, one undo step', (
    tester,
  ) async {
    c.addText();
    await pump(tester);
    final before = c.project.texts.single.sizeU;
    final undoBefore = c.canUndo;
    final corner = frameOfText().bottomRight;
    final g = await tester.startGesture(corner);
    await g.moveBy(const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 16));
    await g.up();
    await tester.pump();
    final after = c.project.texts.single.sizeU;
    expect(after, greaterThan(before * 1.3));
    expect(c.project.texts.single.id, c.selectedId, reason: 'still selected');
    // one gesture, one step
    c.undo();
    expect(c.project.texts.single.sizeU, before);
    expect(undoBefore, isTrue); // adding the text was an earlier step
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets(
    'the knob above the frame turns the text and clicks onto 90 degrees',
    (tester) async {
      c.addText();
      await pump(tester);
      final f = frameOfText();
      final knob = f.topCenter.translate(0, -26);
      final g = await tester.startGesture(knob);
      // swing the knob from straight up to straight right of the centre
      final r = (knob - f.center).distance;
      for (var i = 1; i <= 10; i++) {
        final a = -math.pi / 2 + (math.pi / 2) * i / 10;
        await g.moveTo(f.center + Offset(math.cos(a), math.sin(a)) * r);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump();
      expect(c.project.texts.single.rotation, closeTo(90, 0.5));
    },
  );

  testWidgets('dragging the body near the middle snaps to the middle', (
    tester,
  ) async {
    c.addText();
    await pump(tester);
    final t0 = c.project.texts.single;
    final start = Offset(t0.x * 360, t0.y * 800);
    final g = await tester.startGesture(start);
    // 1 px is well inside the snap distance of the middle line
    await g.moveBy(const Offset(4, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(2, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.project.texts.single.x, closeTo(0.5, 1e-9));
    await g.up();
    await tester.pump();
  });
  testWidgets('a caption is resized through its style, not the item size', (
    tester,
  ) async {
    c.addCue();
    await pump(tester);
    final item = c.project.texts.single;
    final style0 = item.captionStyle!.sizeU;
    final itemSize0 = item.sizeU;
    // "Câu mới" is the default line: 7 characters at the caption size, on a 360 px wide stage.
    final f = Rect.fromCenter(
      center: Offset(item.x * 360, item.y * 800),
      width: math.max(60, 7 * style0 * 0.55 * 0.5),
      height: style0 * 1.5 * 0.5,
    );
    final g = await tester.startGesture(f.bottomRight);
    await g.moveBy(const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 16));
    await g.up();
    await tester.pump();
    final after = c.project.texts.single;
    expect(after.captionStyle!.sizeU, greaterThan(style0 * 1.3));
    expect(
      after.sizeU,
      itemSize0,
      reason: 'the item size is not what a caption shows',
    );
    expect(after.cues, isNotNull);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
