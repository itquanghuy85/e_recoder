import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_math.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void main() {
  group('RegionMath (same vectors as RegionMathTest.kt)', () {
    test(
      'mosaic cells, blur radius and spotlight dimming grow with strength',
      () {
        expect(RegionMath.mosaicBlockFrac(0), closeTo(0.02, 1e-9));
        expect(RegionMath.mosaicBlockFrac(1), closeTo(0.08, 1e-9));
        expect(RegionMath.blurRadiusFrac(0), closeTo(0.015, 1e-9));
        expect(RegionMath.blurRadiusFrac(1), closeTo(0.045, 1e-9));
        expect(RegionMath.spotlightDim(0), closeTo(0.35, 1e-9));
        expect(RegionMath.spotlightDim(1), closeTo(0.85, 1e-9));
      },
    );

    test('strength is clamped', () {
      expect(RegionMath.mosaicBlockFrac(5), RegionMath.mosaicBlockFrac(1));
      expect(RegionMath.blurRadiusFrac(-3), RegionMath.blurRadiusFrac(0));
    });

    test('fades in and out over 120 ms and is zero outside', () {
      expect(RegionMath.mix(999, 1000, 4000), 0);
      expect(RegionMath.mix(4001, 1000, 4000), 0);
      expect(RegionMath.mix(1000, 1000, 4000), 0);
      expect(RegionMath.mix(1060, 1000, 4000), closeTo(0.5, 1e-9));
      expect(RegionMath.mix(2500, 1000, 4000), 1);
      expect(RegionMath.mix(3940, 1000, 4000), closeTo(0.5, 1e-9));
    });
  });

  group('CoverItem', () {
    test('old projects (no style) load as solid blocks', () {
      final c = CoverItem.fromJson({
        'id': 'c',
        'x0': .1,
        'y0': .2,
        'x1': .5,
        'y1': .3,
        'startMs': 0,
        'endMs': 1000,
        'color': 0xFF0E1116,
      });
      expect(c.style, CoverStyle.solid);
      expect(c.strength, 0.5);
    });

    test('style and strength survive save and load and reach the exporter', () {
      const c = CoverItem(
        id: 'c',
        startMs: 0,
        endMs: 1000,
        style: CoverStyle.mosaic,
        strength: 0.8,
      );
      final back = CoverItem.fromJson(c.toJson());
      expect(back.style, CoverStyle.mosaic);
      expect(back.strength, closeTo(0.8, 1e-9));
      expect(c.toNative()['style'], 'mosaic');
      expect(c.toNative()['strength'], 0.8);
    });

    test('an unknown style or wild strength is repaired on load', () {
      final c = CoverItem.fromJson({
        'id': 'c',
        'x0': 0,
        'y0': 0,
        'x1': 1,
        'y1': 1,
        'startMs': 0,
        'endMs': 1,
        'color': 0,
        'style': 'sparkle',
        'strength': 7,
      });
      expect(c.style, CoverStyle.solid);
      expect(c.strength, 1);
    });
  });

  group('a region that glides', () {
    const c = CoverItem(
      id: 'c',
      x0: 0.1,
      y0: 0.2,
      x1: 0.3,
      y1: 0.4,
      startMs: 0,
      endMs: 1000,
      end: Rect.fromLTRB(0.5, 0.6, 0.9, 1.0),
    );

    test('eases from its start rectangle to its end rectangle', () {
      expect(c.rectAt(-100), c.startRect);
      expect(c.rectAt(0), c.startRect);
      final mid = c.rectAt(500);
      expect(mid.left, closeTo(0.3, 1e-9));
      expect(mid.top, closeTo(0.4, 1e-9));
      expect(mid.right, closeTo(0.6, 1e-9));
      expect(mid.bottom, closeTo(0.7, 1e-9));
      expect(c.rectAt(1000), c.end);
      expect(c.rectAt(5000), c.end);
      expect(
        c.rectAt(250).left,
        lessThan(0.3),
      ); // eased: slower than linear early on
    });

    test('without an end it stays put', () {
      expect(c.copyWith(end: null).rectAt(500), c.startRect);
    });

    test('the end point survives save and load and reaches the exporter', () {
      final back = CoverItem.fromJson(c.toJson());
      expect(back.end, c.end);
      expect(c.toNative()['ex0'], 0.5);
      expect(c.toNative()['ey1'], 1.0);
      expect(c.copyWith(end: null).toNative().containsKey('ex0'), isFalse);
    });

    test('editing the end point leaves the start alone, and the reverse', () {
      final moved = c.withRect(
        const Rect.fromLTRB(0.6, 0.6, 0.8, 0.8),
        atEnd: true,
      );
      expect(moved.startRect, c.startRect);
      expect(moved.end, const Rect.fromLTRB(0.6, 0.6, 0.8, 0.8));
      final other = c.withRect(
        const Rect.fromLTRB(0, 0, 0.2, 0.2),
        atEnd: false,
      );
      expect(other.end, c.end);
      expect(other.startRect, const Rect.fromLTRB(0, 0, 0.2, 0.2));
    });
  });

  group('adding regions', () {
    late EditorController c;
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
    });
    tearDown(() => c.dispose());

    test(
      'each style is added selected, and a spotlight gets a taller window',
      () {
        c.addCover(CoverStyle.blur);
        expect(c.project.covers.single.style, CoverStyle.blur);
        expect(c.selectedId, c.project.covers.single.id);
        c.addCover(CoverStyle.spotlight);
        final spot = c.project.covers.last;
        expect(spot.style, CoverStyle.spotlight);
        expect(
          spot.y1 - spot.y0,
          greaterThan(c.project.covers.first.y1 - c.project.covers.first.y0),
        );
      },
    );

    test('changing the style is one undoable step', () {
      c.addCover();
      final base = c.project.covers.single;
      c.updateCover(base.copyWith(style: CoverStyle.mosaic));
      expect(c.project.covers.single.style, CoverStyle.mosaic);
      c.undo();
      expect(c.project.covers.single.style, CoverStyle.solid);
    });
  });
}
