import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/caption_models.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_math.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/features/marker/marker_timing.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

EditProject _project() => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: 20000,
  frameW: 720,
  frameH: 1600,
);

EditorController _controller(FakeRecorder fake, MemoryProjectStore store) =>
    EditorController(
      project: _project(),
      native: fake,
      store: store,
      autosaveDelay: const Duration(milliseconds: 10),
    );

void main() {
  late FakeRecorder fake;
  late MemoryProjectStore store;
  late EditorController c;

  setUp(() {
    fake = FakeRecorder();
    store = MemoryProjectStore();
    c = _controller(fake, store);
  });

  tearDown(() => c.dispose());

  test('a marker is placed so its take lands on the playhead', () {
    c.seekOut(8000);
    c.addMarker(MarkerType.arrow, color: const Color(0xFFFF3B30));
    final m = c.project.markers.single;
    expect(m.cueStartMs, 8000 - MarkerTiming.cueMs);
    expect(m.takeMs, 8000);
    expect(c.selectedId, m.id);
  });

  test('a marker at the very start cannot start before 0', () {
    c.addMarker(MarkerType.finger, color: const Color(0xFFFF3B30));
    expect(c.project.markers.single.cueStartMs, 0);
  });

  test('step numbers count up', () {
    c.addMarker(MarkerType.number, color: const Color(0xFFFFFFFF));
    c.addMarker(MarkerType.number, color: const Color(0xFFFFFFFF));
    expect(c.project.markers.map((m) => m.spec.number), [1, 2]);
  });

  test('split + delete shortens the timeline and undo restores it', () {
    c.seekOut(5000);
    c.split();
    expect(c.project.segments.length, 2);
    c.selectSegment(0);
    c.deleteSelectedSegment();
    expect(c.project.outDurationMs, 15000);
    c.undo();
    expect(c.project.outDurationMs, 20000);
    expect(c.project.segments.length, 2);
    c.redo();
    expect(c.project.outDurationMs, 15000);
  });

  test('a drag is one undo step', () {
    c.addText();
    final before = c.project.texts.single;
    c.beginGesture();
    for (var i = 1; i <= 5; i++) {
      c.updateText(
        c.project.texts.single.copyWith(x: 0.5 + i * 0.05),
        record: false,
      );
    }
    expect(c.project.texts.single.x, closeTo(0.75, 1e-9));
    c.undo();
    expect(c.project.texts.single.x, before.x);
  });

  test('editing autosaves to the store', () async {
    c.addCover();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final saved = await store.load(c.project.id);
    expect(saved!.covers.length, 1);
  });

  test('speed applies to the selected segment only', () {
    c.seekOut(5000);
    c.split();
    c.selectSegment(1);
    c.setSpeed(2);
    expect(c.project.segments[0].speed, 1);
    expect(c.project.segments[1].speed, 2);
    expect(c.project.outDurationMs, 5000 + 7500);
  });

  test('export: quality maps to an even output height, never upscales', () {
    expect(c.outHeightFor(ExportQuality.original), 0);
    expect(c.outHeightFor(ExportQuality.p720), 0); // short side is already 720
    expect(c.outHeightFor(ExportQuality.p1080), 0);
    expect(c.outHeightFor(ExportQuality.p480) % 2, 0);
    expect(c.outHeightFor(ExportQuality.p480), lessThan(1600));
  });

  test('export lifecycle follows native events', () async {
    await c.startExport(ExportQuality.p480);
    expect(c.exportState.phase, ExportPhase.running);
    expect(fake.calls, contains('startExport'));
    expect(
      fake.lastExportJob!['outHeight'],
      c.outHeightFor(ExportQuality.p480),
    );
    fake.controller.add(ExportProgressEvent(0.4));
    await Future<void>.delayed(Duration.zero);
    expect(c.exportState.progress, closeTo(0.4, 1e-9));
    fake.controller.add(
      ExportDoneEvent('content://x', 'ESR_edit.mp4', 1000, 2048),
    );
    await Future<void>.delayed(Duration.zero);
    expect(c.exportState.phase, ExportPhase.done);
    expect(c.exportState.result!.name, 'ESR_edit.mp4');
    c.dismissExport();
    expect(c.exportState.phase, ExportPhase.idle);
  });

  test('export error is reported', () async {
    await c.startExport(ExportQuality.original);
    fake.controller.add(ExportErrorEvent('export_failed', 'x'));
    await Future<void>.delayed(Duration.zero);
    expect(c.exportState.phase, ExportPhase.error);
    expect(c.exportState.errorCode, 'export_failed');
  });

  test('overlay images are rendered once per distinct look', () async {
    final spec = const MarkerSpec(
      type: MarkerType.circle,
      x0: 0.2,
      y0: 0.2,
      x1: 0.6,
      y1: 0.4,
    );
    await c.markerImage(spec);
    await c.markerImage(spec);
    expect(fake.calls.where((e) => e == 'renderMarker:circle').length, 1);
    await c.markerImage(spec.copyWith(scale: 2));
    expect(fake.calls.where((e) => e == 'renderMarker:circle').length, 2);
  });

  group('zoom math', () {
    const z = ZoomItem(
      id: 'z',
      fx: 0.9,
      fy: 0.1,
      scale: 2,
      startMs: 1000,
      endMs: 5000,
    );

    test('no zoom outside the clip', () {
      expect(zoomAt([z], 500).scale, 1);
      expect(zoomAt([z], 5200).scale, 1);
    });

    test('ramps in and out and holds in between', () {
      expect(zoomAt([z], 1000).scale, closeTo(1, 1e-9));
      final mid = zoomAt([z], 3000);
      expect(mid.scale, closeTo(2, 1e-9));
      final early = zoomAt([z], 1000 + 175).scale;
      expect(early, greaterThan(1));
      expect(early, lessThan(2));
    });

    test('ramp speed is adjustable and shrinks to fit a short clip', () {
      const slow = ZoomItem(
        id: 'z',
        scale: 2,
        startMs: 0,
        endMs: 6000,
        inMs: 2000,
        outMs: 100,
      );
      expect(zoomAt([slow], 1000).scale, closeTo(1.5, 1e-9)); // halfway in
      expect(zoomAt([slow], 5950).scale, closeTo(1.5, 1e-9)); // halfway out
      const instant = ZoomItem(
        id: 'z',
        scale: 2,
        startMs: 0,
        endMs: 6000,
        inMs: 0,
        outMs: 0,
      );
      expect(zoomAt([instant], 1).scale, closeTo(2, 1e-9));
      const tight = ZoomItem(
        id: 'z',
        scale: 2,
        startMs: 0,
        endMs: 1000,
        inMs: 2000,
        outMs: 2000,
      );
      expect(
        zoomAt([tight], 500).scale,
        closeTo(2, 1e-9),
      ); // ramps meet at the middle
    });

    test('old projects without ramps still load with the default', () {
      final z = ZoomItem.fromJson({
        'id': 'z',
        'fx': .5,
        'fy': .5,
        'scale': 2,
        'startMs': 0,
        'endMs': 1000,
      });
      expect(z.inMs, kZoomRampMs);
      expect(ZoomItem.fromJson(z.copyWith(inMs: 900).toJson()).inMs, 900);
    });

    test('the visible window never leaves the frame', () {
      final mid = zoomAt([z], 3000);
      expect(mid.cx, closeTo(0.75, 1e-9)); // 1 - 0.5/2
      expect(mid.cy, closeTo(0.25, 1e-9)); // 0.5/2
    });
  });
  group('cueImage', () {
    const base = TextItem(id: 't', text: '', startMs: 0, endMs: 5000);
    final withCues = base.copyWith(
      cues: const [
        CaptionCue(text: 'A', startMs: 0, endMs: 1000),
        CaptionCue(text: 'B', startMs: 2000, endMs: 3000),
      ],
    );

    test('null cues or no active cue gives null and never renders', () async {
      expect(await c.cueImage(base, 500), isNull);
      expect(await c.cueImage(withCues, 1500), isNull);
      expect(fake.calls.where((e) => e == 'renderCue'), isEmpty);
    });

    test(
      'without a reveal the cue renders once and then hits the cache',
      () async {
        final still = withCues.copyWith(
          captionStyle: const CaptionStyle(revealMode: RevealMode.none),
        );
        expect(await c.cueImage(still, 100), isNotNull);
        expect(await c.cueImage(still, 900), isNotNull);
        expect(fake.calls.where((e) => e == 'renderCue').length, 1);
        expect(fake.cueTimes.single, isNull);
        expect(await c.cueImage(still, 2500), isNotNull);
        expect(fake.calls.where((e) => e == 'renderCue').length, 2);
      },
    );

    test(
      'a reveal is redrawn every 50 ms of playhead time, not more often',
      () async {
        expect(await c.cueImage(withCues, 110), isNotNull);
        expect(await c.cueImage(withCues, 140), isNotNull);
        expect(fake.cueTimes, [100]);
        expect(await c.cueImage(withCues, 160), isNotNull);
        expect(fake.cueTimes, [100, 150]);
        expect(
          await c.cueImage(withCues, 115),
          isNotNull,
        ); // back to a cached step
        expect(fake.cueTimes.length, 2);
      },
    );

    test('the reveal cache keeps the last 12 pictures', () async {
      for (var i = 0; i < 13; i++) {
        await c.cueImage(withCues, i * 50);
      }
      expect(fake.cueTimes.length, 13);
      await c.cueImage(withCues, 12 * 50); // newest: still cached
      expect(fake.cueTimes.length, 13);
      await c.cueImage(withCues, 0); // oldest: was dropped
      expect(fake.cueTimes.length, 14);
    });
  });
}
