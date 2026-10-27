import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:flutter_test/flutter_test.dart';

EditProject _p({int ms = 10000}) => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: ms,
  frameW: 720,
  frameH: 1600,
);

void main() {
  goldenTests();
  group('speed ramp maths', () {
    const ramp = Segment(startMs: 0, endMs: 8000, speed: 1, speedEnd: 4);

    test('constant speed is the plain division', () {
      const s = Segment(startMs: 1000, endMs: 5000, speed: 2);
      expect(s.outLengthMs, 2000);
      expect(s.sourceAtOut(500), 2000);
      expect(s.outAtSource(3000), 1000);
    });

    test('a ramp lies between the slow and the fast constant lengths', () {
      expect(ramp.isRamp, isTrue);
      expect(ramp.outLengthMs, lessThan(8000));
      expect(ramp.outLengthMs, greaterThan(2000));
    });

    test('out <-> play offset are inverse of each other along the ramp', () {
      for (final p in [0, 123, 1000, 4321, 7999, 8000]) {
        final out = ramp.outAtPlay(p.toDouble());
        expect(ramp.playAtOut(out), closeTo(p, 0.01));
      }
    });

    test('the ramp speeds up monotonically', () {
      var last = 0.0;
      for (var p = 0; p < 8000; p += 250) {
        final v = ramp.speedAtPlay(p.toDouble());
        expect(v, greaterThanOrEqualTo(last));
        last = v;
      }
      expect(ramp.speedAtPlay(0), closeTo(1.0625, 0.01));
      expect(ramp.speedAtPlay(7999), closeTo(3.9375, 0.01));
    });

    test('reverse reads the same range backwards', () {
      const r = Segment(startMs: 2000, endMs: 6000, reverse: true);
      expect(r.outLengthMs, 4000);
      expect(r.sourceAtOut(0), 6000);
      expect(r.sourceAtOut(1000), 5000);
      expect(r.outAtSource(5000), 1000);
    });

    test('a still shows one source time for its whole length', () {
      const f = Segment(startMs: 3000, endMs: 3001, freezeMs: 2500);
      expect(f.outLengthMs, 2500);
      expect(f.lengthMs, 0);
      expect(f.sourceAtOut(1800), 3000);
      expect(f.hasAudio, isFalse);
    });
  });

  group('audio gain', () {
    test('volume and fades', () {
      const s = Segment(
        startMs: 0,
        endMs: 4000,
        volume: 0.5,
        fadeInMs: 1000,
        fadeOutMs: 1000,
      );
      expect(s.gainAt(0, 4000), 0);
      expect(s.gainAt(500, 4000), closeTo(0.25, 1e-9));
      expect(s.gainAt(2000, 4000), closeTo(0.5, 1e-9));
      expect(s.gainAt(3500, 4000), closeTo(0.25, 1e-9));
      expect(s.gainAt(4000, 4000), 0);
    });
  });

  group('sequence operations', () {
    test('duplicate repeats the material and lengthens the timeline', () {
      final p = _p().duplicateSegment(0);
      expect(p.segments.length, 2);
      expect(p.outDurationMs, 20000);
      // Both copies show the same source time at their own output times.
      expect(p.outToSource(1000), 1000);
      expect(p.outToSource(11000), 1000);
    });

    test(
      'reordering keeps time mapping correct (source order != sequence order)',
      () {
        var p = _p().splitAt(4000); // [0..4000][4000..10000]
        p = p.moveSegmentTo(1, 0); //   [4000..10000][0..4000]
        expect(p.outDurationMs, 10000);
        expect(p.outToSource(0), 4000);
        expect(p.outToSource(7000), 1000);
        expect(p.sourceToOut(1000), 7000);
        expect(p.sourceToOut(5000), 1000);
      },
    );

    test('a cut-out time snaps to the next kept start by source time', () {
      var p = _p().splitAt(2000).splitAt(5000);
      p = p.deleteSegment(1); // keeps [0..2000][5000..10000]
      expect(p.sourceToOut(3000), 2000);
    });

    test('splitAtOut cuts the right copy of a repeated segment', () {
      final p = _p().duplicateSegment(0).splitAtOut(14000);
      expect(p.segments.length, 3);
      expect(p.segments[1].endMs, 4000);
      expect(p.segments[2].startMs, 4000);
    });

    test('blank keeps the timeline length and moves nothing', () {
      var p = _p().splitAt(4000);
      p = p.blankSegment(0);
      expect(p.segments[0].blank, isTrue);
      expect(p.outDurationMs, 10000);
      expect(p.segments[1].startMs, 4000);
    });

    test('freeze is inserted after the segment and adds its length', () {
      var p = _p().splitAt(4000);
      p = p.insertFreeze(0, 4000, ms: 1500);
      expect(p.segments.length, 3);
      expect(p.segments[1].isStill, isTrue);
      expect(p.outDurationMs, 11500);
      expect(p.outToSource(4500), 4000);
    });

    test('deleting several segments at once keeps at least one', () {
      var p = _p().splitAt(2000).splitAt(5000);
      expect(p.deleteSegments({0, 2}).segments.length, 1);
      expect(p.deleteSegments({0, 1, 2}).segments.length, 3);
    });

    test(
      'splitting a reversed ramp keeps both halves reversed and consistent',
      () {
        var p = _p().setSpeedRamp(0, 1, 3).setReverse(0, true);
        final before = p.outDurationMs;
        p = p.splitAt(5000);
        expect(p.segments.length, 2);
        expect(p.segments.every((s) => s.reverse), isTrue);
        expect(p.segments[0].startMs, 5000); // later half plays first
        expect((p.outDurationMs - before).abs(), lessThan(before * 0.03));
      },
    );
  });

  group('transitions', () {
    test('only one side of a cut is affected and length never changes', () {
      var p = _p().splitAt(5000);
      final len = p.outDurationMs;
      p = p.setTransition(1, const Transition(TransitionKind.dipBlack, 800));
      expect(p.outDurationMs, len);
      expect(p.transitionHalfMs(1), 400);
      // away from the cut: no change
      expect(p.transitionLookAt(2000).isNone, isTrue);
      // exactly at the cut both halves are fully "away"
      final atCut = p.transitionLookAt(4999);
      expect(atCut.mul, lessThan(0.05));
      expect(p.transitionLookAt(5000).mul, lessThan(0.05));
      // after the half it is back to normal
      expect(p.transitionLookAt(5400).isNone, isTrue);
    });

    test('the first segment cannot carry a transition', () {
      final p = _p()
          .splitAt(5000)
          .setTransition(0, const Transition(TransitionKind.zoom));
      expect(p.segments[0].transition, isNull);
    });

    test('a short clip limits the transition to 45 percent of itself', () {
      var p = _p().splitAt(5000).splitAt(5400);
      p = p.setTransition(1, const Transition(TransitionKind.slideLeft, 1500));
      expect(p.transitionHalfMs(1), (400 * 0.45).floor());
    });

    test('slides move the outgoing and incoming picture opposite ways', () {
      final out = TransitionLook.of(
        TransitionKind.slideLeft,
        0.0,
        incoming: false,
      );
      final inc = TransitionLook.of(
        TransitionKind.slideLeft,
        0.0,
        incoming: true,
      );
      expect(out.dx, lessThan(0));
      expect(inc.dx, greaterThan(0));
      expect(
        TransitionLook.of(TransitionKind.slideUp, 1.0, incoming: true).isNone,
        isTrue,
      );
    });

    test('dip to white brightens, dip to black darkens', () {
      final w = TransitionLook.of(TransitionKind.dipWhite, 0.0, incoming: true);
      final b = TransitionLook.of(TransitionKind.dipBlack, 0.0, incoming: true);
      expect(w.add, closeTo(1, 1e-9));
      expect(w.mul, closeTo(0, 1e-9));
      expect(b.add, 0);
    });

    test('deleting the first segment drops the transition that pointed into the new first', () {
      var p = _p()
          .splitAt(5000)
          .setTransition(1, const Transition(TransitionKind.zoom));
      p = p.deleteSegment(0);
      expect(p.segments.single.transition, isNull);
    });
  });

  group('snapping and persistence', () {
    test('snapTo pulls to the nearest point within reach only', () {
      expect(EditProject.snapTo(1030, [0, 1000, 5000], 60), 1000);
      expect(EditProject.snapTo(1100, [0, 1000, 5000], 60), 1100);
    });

    test('new fields survive a save and load', () {
      var p = _p().splitAt(5000);
      p = p
          .setSpeedRamp(0, 0.5, 2)
          .setReverse(1, true)
          .setAudio(1, volume: 0.3, fadeInMs: 400);
      p = p.setTransition(1, const Transition(TransitionKind.slideDown, 700));
      final q = EditProject.decode(p.encode());
      expect(q.segments, p.segments);
    });

    test('a project saved before these fields still loads', () {
      const old =
          '{"v":1,"id":"x","sourceUri":"x","name":"n","durationMs":1000,"frameW":10,"frameH":20,'
          '"segments":[{"startMs":0,"endMs":1000,"speed":1.0}],"markers":[],"texts":[],"covers":[],"zooms":[]}';
      final p = EditProject.decode(old);
      expect(p.segments.single, const Segment(startMs: 0, endMs: 1000));
    });
  });
}

// Golden values shared with SegmentPlanTest.kt: the Dart model and the exporter must agree.
void goldenTests() {
  group('golden (shared with the exporter)', () {
    test('ramp 1x -> 4x over 8 s is 3695 ms long', () {
      const s = Segment(startMs: 0, endMs: 8000, speed: 1, speedEnd: 4);
      expect(s.outLengthMs, 3695);
    });
    test('ramp 0.5x -> 2x over 6 s is 5543 ms long', () {
      const s = Segment(startMs: 1000, endMs: 7000, speed: 0.5, speedEnd: 2);
      expect(s.outLengthMs, 5543);
    });
    test('transition looks at fixed progress values', () {
      final a = TransitionLook.of(
        TransitionKind.dipWhite,
        0.25,
        incoming: true,
      );
      expect(a.mul, closeTo(0.15625, 1e-6));
      expect(a.add, closeTo(0.84375, 1e-6));
      final b = TransitionLook.of(
        TransitionKind.slideLeft,
        0.5,
        incoming: false,
      );
      expect(b.dx, closeTo(-1.0, 1e-6));
      final c = TransitionLook.of(TransitionKind.zoom, 0.5, incoming: true);
      expect(c.scale, closeTo(1.25, 1e-6));
      expect(c.mul, closeTo(0.5, 1e-6));
    });
  });
}
