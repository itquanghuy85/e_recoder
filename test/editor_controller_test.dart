import 'package:e_screen_recorder/core/native_recorder.dart';
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

    test('the visible window never leaves the frame', () {
      final mid = zoomAt([z], 3000);
      expect(mid.cx, closeTo(0.75, 1e-9)); // 1 - 0.5/2
      expect(mid.cy, closeTo(0.25, 1e-9)); // 0.5/2
    });
  });
}
