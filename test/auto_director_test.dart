import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:flutter_test/flutter_test.dart';

EditProject _base({int durationMs = 30000}) => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: durationMs,
  frameW: 720,
  frameH: 1600,
);

RecMark _mark(
  int tMs, {
  MarkerType type = MarkerType.finger,
  double x = 0.5,
  double y = 0.5,
  int number = 1,
}) => RecMark(
  tMs: tMs,
  holdMs: 2000,
  spec: MarkerSpec(type: type, x0: x, y0: y, x1: x, y1: y, number: number),
);

void main() {
  group('draft', () {
    test(
      'every recorded mark becomes a marker whose cue starts at its time',
      () {
        final p = AutoDirector.draft(_base(), [
          _mark(1000),
          _mark(8000, x: 0.2),
        ]);
        expect(p.markers.length, 2);
        expect(p.markers[0].cueStartMs, 1000);
        expect(p.markers[0].holdMs, 2000);
        expect(p.markers[1].spec.x0, 0.2);
        expect(p.markers.map((m) => m.id).toSet().length, 2);
      },
    );

    test('a mark past the end is pulled back inside the video', () {
      final p = AutoDirector.draft(_base(durationMs: 5000), [_mark(9000)]);
      expect(p.markers.single.cueStartMs, lessThan(5000));
    });

    test('no marks, no markers', () {
      expect(AutoDirector.draft(_base(), const []).markers, isEmpty);
    });
  });

  group('renumber', () {
    test('step markers are numbered in time order', () {
      final p = AutoDirector.renumber(
        AutoDirector.draft(_base(), [
          _mark(9000, type: MarkerType.number, number: 7),
          _mark(2000, type: MarkerType.number, number: 4),
          _mark(5000, type: MarkerType.finger),
        ]),
      );
      final steps = p.markers.where((m) => m.spec.type == MarkerType.number);
      final byTime = [...steps]
        ..sort((a, b) => a.cueStartMs.compareTo(b.cueStartMs));
      expect(byTime.map((m) => m.spec.number), [1, 2]);
    });
  });

  group('autoZoom', () {
    test('one eased zoom around each distant marker', () {
      final p = AutoDirector.autoZoom(
        AutoDirector.draft(_base(), [
          _mark(2000, x: 0.3, y: 0.4),
          _mark(15000, x: 0.7, y: 0.8),
        ]),
      );
      expect(p.zooms.length, 2);
      expect(p.zooms[0].fx, closeTo(0.3, 1e-9));
      expect(p.zooms[0].scale, AutoDirector.zoomScale);
      expect(p.zooms[0].startMs, lessThan(2000));
      expect(p.zooms[0].endMs, p.markers[0].endMs);
      expect(p.zooms[0].endMs, lessThan(p.zooms[1].startMs));
    });

    test('markers close in time share one zoom centred between them', () {
      final p = AutoDirector.autoZoom(
        AutoDirector.draft(_base(), [
          _mark(2000, x: 0.3, y: 0.5),
          _mark(3500, x: 0.7, y: 0.5),
        ]),
      );
      expect(p.zooms.length, 1);
      expect(p.zooms.single.fx, closeTo(0.5, 1e-9));
      expect(p.zooms.single.scale, lessThan(AutoDirector.zoomScale));
      expect(p.zooms.single.endMs, p.markers[1].endMs);
    });

    test('markers too far apart in one frame never get overlapping zooms', () {
      final p = AutoDirector.autoZoom(
        AutoDirector.draft(_base(), [
          _mark(2000, x: 0.1, y: 0.1),
          _mark(3000, x: 0.9, y: 0.9),
        ]),
      );
      expect(p.zooms.length, 1);
      expect(p.zooms.single.fx, closeTo(0.1, 1e-9));
    });

    test('a zoom the user already made is respected', () {
      final base = AutoDirector.draft(_base(), [_mark(2000)]);
      final withZoom = base.upsertZoom(
        const ZoomItem(id: 'mine', startMs: 1500, endMs: 4000),
      );
      final p = AutoDirector.autoZoom(withZoom);
      expect(p.zooms.length, 1);
      expect(p.zooms.single.id, 'mine');
    });
  });

  group('idle', () {
    test('trims the edges and keeps marker time at normal speed', () {
      final p = AutoDirector.draft(_base(), [_mark(10000)]);
      // Marker is on screen 10000 .. 10000+500+2000+300 = 12800.
      final r = AutoDirector.idleToSpeedUp(p, [(startMs: 4000, endMs: 14000)]);
      expect(
        r,
        [
          (startMs: 4350, endMs: 10000),
          (startMs: 12800, endMs: 13650),
        ].where((e) => e.endMs - e.startMs >= AutoDirector.idleMinMs).toList(),
      );
    });

    test('short stills are left alone', () {
      final r = AutoDirector.idleToSpeedUp(_base(), [
        (startMs: 1000, endMs: 2500),
      ]);
      expect(r, isEmpty);
    });

    test('speedUpIdle splits and speeds up only the idle part', () {
      final p = AutoDirector.speedUpIdle(_base(), [
        (startMs: 5000, endMs: 15000),
      ]);
      expect(p.segments.length, 3);
      expect(p.segments[0].speed, 1);
      expect(p.segments[1].speed, AutoDirector.idleSpeed);
      expect(p.segments[2].speed, 1);
      // The edited video got shorter, but the source is still covered end to end.
      expect(p.outDurationMs, lessThan(30000));
      expect(p.segments.first.startMs, 0);
      expect(p.segments.last.endMs, 30000);
    });

    test('direct applies number, zoom and idle together', () {
      final base = AutoDirector.draft(_base(), [
        _mark(2000, type: MarkerType.number, number: 3),
      ]);
      final p = AutoDirector.direct(
        base,
        const DirectorOptions(),
        idleRanges: [(startMs: 8000, endMs: 20000)],
      );
      expect(p.markers.single.spec.number, 1);
      expect(p.zooms, isNotEmpty);
      expect(p.segments.any((s) => s.speed > 1), isTrue);
    });

    test('options can switch everything off', () {
      final base = AutoDirector.draft(_base(), [_mark(2000)]);
      final p = AutoDirector.direct(
        base,
        DirectorOptions.none,
        idleRanges: [(startMs: 8000, endMs: 20000)],
      );
      expect(p.zooms, isEmpty);
      expect(p.segments.length, 1);
    });
  });
}
