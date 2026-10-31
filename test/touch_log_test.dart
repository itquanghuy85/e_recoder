import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/touch_log.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

EditProject _base([int ms = 30000]) => EditProject.fresh(
  sourceUri: 'file:///x.mp4',
  name: 'x',
  durationMs: ms,
  frameW: 1080,
  frameH: 2400,
);

RawTouch _t(int ms, [double x = 0.5, double y = 0.3]) =>
    RawTouch(tMs: ms, x: x, y: y);

void main() {
  group('classify', () {
    test('a lone press is a tap', () {
      final e = TouchClassifier.classify([_t(1000)]);
      expect(e.single.kind, TouchKind.tap);
    });

    test('a long drag is a swipe', () {
      final e = TouchClassifier.classify([
        const RawTouch(tMs: 1000, x: 0.5, y: 0.5, dist: 0.3),
      ]);
      expect(e.single.kind, TouchKind.swipe);
    });

    test('a bounce at the same place is noise', () {
      final e = TouchClassifier.classify([_t(1000), _t(1100)]);
      expect(e.map((x) => x.kind), [TouchKind.tap, TouchKind.noise]);
    });

    test('ten digits on the keyboard are one typing group', () {
      final e = TouchClassifier.classify([
        _t(500, 0.5, 0.2),
        for (var i = 0; i < 10; i++) _t(2000 + i * 400, 0.1 + i * 0.08, 0.8),
        _t(9000, 0.5, 0.3),
      ]);
      final keys = e.where((x) => x.kind == TouchKind.input).toList();
      expect(keys.length, 10);
      expect(keys.map((k) => k.group).toSet().length, 1);
      expect(keys.first.count, 10);
      expect(e.where((x) => x.kind == TouchKind.tap).length, 2);
    });

    test('two presses low on the screen are buttons, not typing', () {
      final e = TouchClassifier.classify([_t(1000, 0.5, 0.9), _t(5000, 0.2, 0.9)]);
      expect(e.every((x) => x.kind == TouchKind.tap), isTrue);
    });

    test('a pause over two seconds splits two typing bursts', () {
      final e = TouchClassifier.classify([
        for (var i = 0; i < 4; i++) _t(1000 + i * 300, 0.1 + i * 0.1, 0.8),
        for (var i = 0; i < 4; i++) _t(8000 + i * 300, 0.1 + i * 0.1, 0.8),
      ]);
      expect(e.map((x) => x.group).toSet(), {1, 2});
    });

    test('touches without a position are never typing', () {
      final e = TouchClassifier.classify([
        for (var i = 0; i < 6; i++) RawTouch(tMs: 1000 + i * 300),
      ]);
      expect(e.every((x) => x.kind != TouchKind.input), isTrue);
    });
  });

  group('freezes', () {
    test('close taps share one freeze', () {
      final f = TouchPlan.freezes(
        TouchClassifier.classify([_t(1000), _t(1900, 0.2, 0.4), _t(5000, 0.7, 0.2)]),
        800,
      );
      expect(f.map((x) => x.tMs), [1000, 5000]);
      expect(f.every((x) => x.ms == 800), isTrue);
    });

    test('zero means no freeze, and the time is capped at 1.5 s', () {
      final ev = TouchClassifier.classify([_t(1000)]);
      expect(TouchPlan.freezes(ev, 0), isEmpty);
      expect(TouchPlan.freezes(ev, 9000).single.ms, 1500);
    });
  });

  group('fromTouches', () {
    const opts = DirectorOptions(pauseMs: 800);

    test('each tap gets a numbered mark and a freeze', () {
      final p = AutoDirector.fromTouches(
        _base(),
        TouchClassifier.classify([_t(3000), _t(9000, 0.2, 0.6)]),
        opts,
      );
      expect(p.markers.length, 2);
      expect(p.markers.map((m) => m.spec.number), [1, 2]);
      final stills = p.segments.where((s) => s.isStill).toList();
      expect(stills.length, 2);
      expect(stills.every((s) => s.freezeMs == 800), isTrue);
      expect(p.outDurationMs, 30000 + 1600);
    });

    test('the chosen mark, colour and time are used at every tap', () {
      for (final type in MarkerType.values) {
        final p = AutoDirector.fromTouches(
          _base(),
          TouchClassifier.classify([_t(3000, 0.4, 0.5), _t(9000, 0.2, 0.6)]),
          DirectorOptions(
            markerType: type,
            markerColor: const Color(0xFF34C759),
            markerThickness: 8,
            markerHoldMs: 2000,
          ),
        );
        expect(p.markers.length, 2, reason: type.name);
        expect(p.markers.every((m) => m.spec.type == type), isTrue);
        expect(p.markers.first.spec.color, const Color(0xFF34C759));
        expect(p.markers.first.spec.thickness, 8);
        expect(p.markers.first.holdMs, 2000);
        final s = p.markers.first.spec;
        // every shape stays inside the frame and sits on the tap
        for (final v in [s.x0, s.y0, s.x1, s.y1, ...s.points]) {
          expect(v, inInclusiveRange(0.0, 1.0));
        }
        final a = s.anchor;
        if (type == MarkerType.circle || type == MarkerType.rect) {
          expect(a.x, closeTo(0.4, 0.001));
          expect(a.y, closeTo(0.5, 0.001));
        }
        if (type == MarkerType.circle) {
          // round on screen: width and height in pixels match
          expect((s.x1 - s.x0) * 1080, closeTo((s.y1 - s.y0) * 2400, 1));
        }
      }
    });

    test('without a chosen mark the old rule stays (number, or ripple)', () {
      final ev = TouchClassifier.classify([_t(3000)]);
      expect(
        AutoDirector.fromTouches(_base(), ev, const DirectorOptions())
            .markers.single.spec.type,
        MarkerType.number,
      );
      expect(
        AutoDirector.fromTouches(_base(), ev, const DirectorOptions(number: false))
            .markers.single.spec.type,
        MarkerType.ripple,
      );
    });

    test('typing is one step, not one mark per key', () {
      final p = AutoDirector.fromTouches(
        _base(),
        TouchClassifier.classify([
          _t(1000, 0.5, 0.2),
          for (var i = 0; i < 8; i++) _t(4000 + i * 400, 0.1 + i * 0.1, 0.8),
        ]),
        opts,
      );
      expect(p.markers.length, 1);
      expect(p.texts.map((t) => t.text), containsAll(['Typing…', 'Typed']));
    });

    test('typing can be left out or shown key by key (short bursts only)', () {
      final ev = TouchClassifier.classify([
        for (var i = 0; i < 3; i++) _t(4000 + i * 400, 0.1 + i * 0.1, 0.8),
      ]);
      final skip = AutoDirector.fromTouches(
        _base(),
        ev,
        opts.copyWith(inputMode: InputMode.skip),
      );
      expect(skip.markers, isEmpty);
      expect(skip.texts, isEmpty);
      final each = AutoDirector.fromTouches(
        _base(),
        ev,
        opts.copyWith(inputMode: InputMode.perKey),
      );
      expect(each.markers.length, 3);
      final longBurst = AutoDirector.fromTouches(
        _base(),
        TouchClassifier.classify([
          for (var i = 0; i < 9; i++) _t(4000 + i * 400, 0.1 + i * 0.1, 0.8),
        ]),
        opts.copyWith(inputMode: InputMode.perKey),
      );
      expect(longBurst.markers, isEmpty);
    });

    test('without positions: captions only, no marks and no zoom', () {
      final p = AutoDirector.fromTouches(
        _base(),
        TouchClassifier.classify([
          const RawTouch(tMs: 3000),
          const RawTouch(tMs: 9000),
        ]),
        opts.copyWith(pauseZoom: 1.4),
      );
      expect(p.markers, isEmpty);
      expect(p.zooms, isEmpty);
      expect(p.texts.map((t) => t.text), ['Step 1', 'Step 2']);
    });

    test('the zoom is gentle and only when asked for', () {
      final ev = TouchClassifier.classify([_t(3000, 0.7, 0.4)]);
      expect(AutoDirector.fromTouches(_base(), ev, opts).zooms, isEmpty);
      final z = AutoDirector.fromTouches(
        _base(),
        ev,
        opts.copyWith(pauseZoom: 9),
      ).zooms;
      expect(z.single.scale, 1.5);
    });

    test('a freeze is not sped up with the idle stretches', () {
      var p = AutoDirector.fromTouches(
        _base(),
        TouchClassifier.classify([_t(5000)]),
        opts.copyWith(number: false),
      );
      p = AutoDirector.speedUpIdle(p, [(startMs: 2000, endMs: 12000)]);
      final still = p.segments.firstWhere((s) => s.isStill);
      expect(still.speed, 1);
      expect(still.freezeMs, 800);
    });

    test('marker type follows the number option', () {
      final ev = TouchClassifier.classify([_t(3000)]);
      expect(
        AutoDirector.fromTouches(_base(), ev, opts).markers.single.spec.type,
        MarkerType.number,
      );
      expect(
        AutoDirector.fromTouches(
          _base(),
          ev,
          opts.copyWith(number: false),
        ).markers.single.spec.type,
        MarkerType.ripple,
      );
    });
  });

  test('old marks without the new fields read as plain taps', () {
    // (RecMark.fromMap is exercised through the saved event in clean_mode_test)
    expect(TouchKind.of(null), TouchKind.tap);
    expect(TouchKind.of('swipe'), TouchKind.swipe);
  });
}
