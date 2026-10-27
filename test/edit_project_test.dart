import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:flutter_test/flutter_test.dart';

EditProject _p() => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: 10000,
  frameW: 720,
  frameH: 1600,
);

void main() {
  group('segments', () {
    test('fresh project keeps everything', () {
      final p = _p();
      expect(p.segments, [const Segment(startMs: 0, endMs: 10000)]);
      expect(p.outDurationMs, 10000);
    });

    test('split makes two segments covering the same material', () {
      final p = _p().splitAt(4000);
      expect(p.segments.length, 2);
      expect(p.segments[0], const Segment(startMs: 0, endMs: 4000));
      expect(p.segments[1], const Segment(startMs: 4000, endMs: 10000));
      expect(p.outDurationMs, 10000);
    });

    test('split too close to an edge does nothing', () {
      expect(_p().splitAt(100).segments.length, 1);
      expect(_p().splitAt(9900).segments.length, 1);
    });

    test('delete removes material and shortens the timeline', () {
      final p = _p().splitAt(4000).deleteSegment(0);
      expect(p.segments, [const Segment(startMs: 4000, endMs: 10000)]);
      expect(p.outDurationMs, 6000);
    });

    test('the last segment cannot be deleted', () {
      expect(_p().deleteSegment(0).segments.length, 1);
    });

    test('speed changes the out length only', () {
      final p = _p().setSpeed(0, 2);
      expect(p.segments[0].lengthMs, 10000);
      expect(p.outDurationMs, 5000);
      expect(_p().setSpeed(0, 0.5).outDurationMs, 20000);
    });

    test('trim clamps and keeps a minimum length', () {
      final p = _p().trimSegment(0, startMs: 9950);
      expect(p.segments[0].startMs, 10000 - EditProject.minSegmentMs);
      final q = _p().trimSegment(0, endMs: 50);
      expect(q.segments[0].endMs, EditProject.minSegmentMs);
    });

    test('move reorders the sequence', () {
      final p = _p().splitAt(3000).moveSegment(1, -1);
      expect(p.segments[0].startMs, 3000);
      expect(p.segments[1].startMs, 0);
    });
  });

  group('time mapping', () {
    test('source <-> out with a cut and a speed-up', () {
      // keep 0..2000 (1x), cut 2000..5000, keep 5000..9000 at 2x
      var p = _p().splitAt(2000).splitAt(5000).splitAt(9000);
      p = p.deleteSegment(1).setSpeed(1, 2).deleteSegment(2);
      expect(p.segments.map((s) => (s.startMs, s.endMs)).toList(), [
        (0, 2000),
        (5000, 9000),
      ]);
      expect(p.outDurationMs, 2000 + 2000);
      expect(p.sourceToOut(1000), 1000);
      expect(
        p.sourceToOut(3000),
        2000,
      ); // inside the cut: snaps to the next kept start
      expect(p.sourceToOut(7000), 2000 + 1000);
      expect(p.outToSource(1000), 1000);
      expect(p.outToSource(3000), 5000 + 2000);
      expect(p.segmentAtSource(3000), -1);
      expect(p.nextKeptStart(3000), 5000);
      expect(p.nextKeptStart(9500), isNull);
    });

    test('segment out starts accumulate', () {
      final p = _p().splitAt(2000).setSpeed(1, 2);
      expect(p.segmentOutStarts, [0, 2000]);
    });
  });

  group('overlays and persistence', () {
    test('upsert replaces by id and remove drops any overlay kind', () {
      var p = _p();
      final m = MarkerItem(
        id: 'm1',
        spec: const MarkerSpec(type: MarkerType.arrow),
        cueStartMs: 1000,
      );
      p = p.upsertMarker(m).upsertMarker(m.copyWith(cueStartMs: 2000));
      expect(p.markers.length, 1);
      expect(p.markers.first.cueStartMs, 2000);
      expect(p.markers.first.takeMs, 2500);
      p = p.upsertText(
        const TextItem(id: 't1', text: 'Xin chào', startMs: 0, endMs: 1000),
      );
      p = p.removeOverlay('m1').removeOverlay('t1');
      expect(p.markers, isEmpty);
      expect(p.texts, isEmpty);
    });

    test('next step number fills gaps', () {
      var p = _p();
      expect(p.nextStepNumber, 1);
      p = p.upsertMarker(
        MarkerItem(
          id: 'a',
          spec: const MarkerSpec(type: MarkerType.number, number: 1),
          cueStartMs: 0,
        ),
      );
      p = p.upsertMarker(
        MarkerItem(
          id: 'b',
          spec: const MarkerSpec(type: MarkerType.number, number: 3),
          cueStartMs: 0,
        ),
      );
      expect(p.nextStepNumber, 2);
    });

    test('encode/decode keeps every field', () {
      var p = _p().splitAt(3000).setSpeed(1, 1.5);
      p = p.upsertMarker(
        MarkerItem(
          id: 'm',
          spec: const MarkerSpec(
            type: MarkerType.circle,
            x0: 0.1,
            y0: 0.2,
            x1: 0.4,
            y1: 0.5,
            scale: 1.2,
            rotation: 15,
          ),
          cueStartMs: 800,
          holdMs: 1500,
        ),
      );
      p = p.upsertText(
        const TextItem(
          id: 't',
          text: 'Bước 1',
          startMs: 100,
          endMs: 2100,
          sizeU: 30,
        ),
      );
      p = p.upsertCover(const CoverItem(id: 'c', startMs: 0, endMs: 900));
      p = p.upsertZoom(
        const ZoomItem(
          id: 'z',
          fx: 0.3,
          fy: 0.7,
          scale: 2.5,
          startMs: 1000,
          endMs: 3000,
        ),
      );
      final q = EditProject.decode(p.encode());
      expect(q.encode(), p.encode());
      expect(q.markers.first.spec.rotation, 15);
      expect(q.texts.first.text, 'Bước 1');
      expect(q.zooms.first.scale, 2.5);
    });

    test('export map carries segments and overlays with native keys', () {
      final p = _p().upsertText(
        const TextItem(id: 't', text: 'x', startMs: 0, endMs: 10),
      );
      final m = p.toExportMap(outHeight: 720, bitrate: 4000000);
      expect(m['outHeight'], 720);
      expect((m['segments'] as List).length, 1);
      expect(((m['texts'] as List).first as Map)['text'], 'x');
    });
  });
}
