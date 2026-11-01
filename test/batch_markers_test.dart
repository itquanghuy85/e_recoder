import 'dart:ui' show Color;

import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

EditProject _project() {
  final base = EditProject.fresh(
    sourceUri: 'content://v/1',
    name: 'a.mp4',
    durationMs: 30000,
    frameW: 720,
    frameH: 1600,
  );
  return base.copyWith(
    markers: [
      MarkerItem(
        id: 'a',
        cueStartMs: 1000,
        spec: AutoDirector.tapSpec(
          MarkerType.arrow,
          0.3,
          0.4,
          1,
          frameW: 720,
          frameH: 1600,
        ),
      ),
      MarkerItem(
        id: 'b',
        cueStartMs: 5000,
        spec: AutoDirector.tapSpec(
          MarkerType.arrow,
          0.6,
          0.7,
          2,
          frameW: 720,
          frameH: 1600,
        ),
      ),
    ],
  );
}

void main() {
  group('AutoDirector.restyleMarkers', () {
    test('an arrow becomes a tap mark at the spot it pointed at', () {
      final out = AutoDirector.restyleMarkers(
        _project(),
        type: MarkerType.finger,
      );
      expect(
        out.markers.map((m) => m.spec.type),
        everyElement(MarkerType.finger),
      );
      expect(out.markers[0].spec.x0, closeTo(0.3, 1e-9));
      expect(out.markers[0].spec.y0, closeTo(0.4, 1e-9));
      expect(out.markers[1].spec.x0, closeTo(0.6, 1e-9));
      // timing is not touched
      expect(out.markers.map((m) => m.cueStartMs), [1000, 5000]);
    });

    test('only the ids given are changed', () {
      final out = AutoDirector.restyleMarkers(
        _project(),
        type: MarkerType.circle,
        ids: {'b'},
      );
      expect(out.markers[0].spec.type, MarkerType.arrow);
      expect(out.markers[1].spec.type, MarkerType.circle);
    });

    test('colour and thickness change without changing the kind or place', () {
      const red = Color(0xFF00FF00);
      final out = AutoDirector.restyleMarkers(
        _project(),
        color: red,
        thickness: 8,
      );
      for (final m in out.markers) {
        expect(m.spec.color, red);
        expect(m.spec.thickness, 8);
        expect(m.spec.type, MarkerType.arrow);
      }
      expect(out.markers[0].spec.x1, closeTo(0.3, 1e-9));
    });

    test('becoming step numbers renumbers 1, 2 in time order', () {
      final out = AutoDirector.restyleMarkers(
        _project(),
        type: MarkerType.number,
      );
      expect(out.markers.map((m) => m.spec.number), [1, 2]);
    });

    test('nothing asked, nothing changed', () {
      final p = _project();
      expect(identical(AutoDirector.restyleMarkers(p), p), isTrue);
    });
  });

  group('EditorController batch', () {
    late EditorController c;
    setUp(() {
      c = EditorController(
        project: _project(),
        native: FakeRecorder(),
        store: MemoryProjectStore(),
        autosaveDelay: const Duration(milliseconds: 10),
      );
    });
    tearDown(() => c.dispose());

    test(
      'restyle with nothing picked changes every mark, in one undo step',
      () {
        c.restyleMarkers(type: MarkerType.finger);
        expect(
          c.project.markers.map((m) => m.spec.type),
          everyElement(MarkerType.finger),
        );
        c.undo();
        expect(
          c.project.markers.map((m) => m.spec.type),
          everyElement(MarkerType.arrow),
        );
      },
    );

    test('restyle changes only the picked marks', () {
      c.setMultiSelect(true);
      c.toggleMarker('a');
      c.restyleMarkers(type: MarkerType.circle);
      expect(c.project.markers[0].spec.type, MarkerType.circle);
      expect(c.project.markers[1].spec.type, MarkerType.arrow);
      c.selectAllMarkers();
      expect(c.multiMarkerIds, {'a', 'b'});
      c.clearMarkerSelection();
      expect(c.multiMarkerIds, isEmpty);
    });

    test('select all clips, from here, and clear', () {
      c.setMultiSelect(true);
      c.selectAllSegments();
      expect(c.activeSegments.length, c.project.segments.length);
      c.selectSegmentsFrom(0);
      expect(c.activeSegments.first, 0);
      c.clearSegmentSelection();
      expect(c.activeSegments.length, 1);
    });
  });
}
