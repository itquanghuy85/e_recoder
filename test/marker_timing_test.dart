import 'package:e_screen_recorder/features/marker/marker_timing.dart';
import 'package:flutter_test/flutter_test.dart';

/// These vectors are duplicated in android/app/src/test/.../MarkerAnimTest.kt.
void main() {
  const never = MarkerTiming.never;

  test('before the cue starts nothing shows', () {
    final f = MarkerTiming.frame(-5, never);
    expect(f.bodyAlpha, 0);
    expect(f.done, isFalse);
  });

  test('cue: ring converges and the body is a faint ghost', () {
    final start = MarkerTiming.frame(0, never);
    expect(start.cueProgress, closeTo(0, 1e-9));
    expect(start.bodyAlpha, closeTo(MarkerTiming.ghostAlpha, 1e-9));
    final mid = MarkerTiming.frame(250, never);
    expect(mid.cueProgress, closeTo(0.875, 1e-9)); // easeOut(0.5)
    expect(mid.bodyScale, 1);
  });

  test('take: solid body, press pulse peaks mid-way, no cue ring', () {
    final take = MarkerTiming.frame(500, never);
    expect(take.cueProgress, -1);
    expect(take.bodyAlpha, 1);
    expect(take.press, closeTo(0, 1e-9));
    final peak = MarkerTiming.frame(500 + 130, never);
    expect(peak.press, closeTo(1, 1e-9));
    final after = MarkerTiming.frame(500 + 400, never);
    expect(after.press, 0);
    expect(after.bodyScale, closeTo(1, 1e-9));
  });

  test('pop-in overshoots then settles', () {
    final early = MarkerTiming.frame(500 + 70, never);
    expect(early.bodyScale, greaterThan(0.88));
    final settled = MarkerTiming.frame(500 + 140, never);
    expect(settled.bodyScale, closeTo(1.0, 1e-9));
  });

  test('fade starts after the hold and finishes after fadeMs', () {
    const fadeStart = 500 + 2500;
    expect(MarkerTiming.frame(fadeStart, fadeStart).bodyAlpha, 1);
    final half = MarkerTiming.frame(fadeStart + 150, fadeStart);
    expect(half.bodyAlpha, closeTo(0.5, 1e-9));
    expect(half.done, isFalse);
    final end = MarkerTiming.frame(fadeStart + 300, fadeStart);
    expect(end.bodyAlpha, 0);
    expect(end.done, isTrue);
  });

  test('fade can never start before the cue ends', () {
    final f = MarkerTiming.frame(100, 0);
    expect(f.bodyAlpha, closeTo(MarkerTiming.ghostAlpha, 1e-9));
  });

  group('water loop phase', () {
    test('stays on the first phase until the take', () {
      expect(MarkerTiming.phaseIndex(0), 0);
      expect(MarkerTiming.phaseIndex(MarkerTiming.cueMs - 1), 0);
    });

    test('advances in 100 ms steps and wraps every 1400 ms', () {
      const take = MarkerTiming.cueMs;
      expect(MarkerTiming.phaseIndex(take + 100), 1);
      expect(MarkerTiming.phaseIndex(take + 1399), 13);
      expect(MarkerTiming.phaseIndex(take + 1400), 0);
      expect(MarkerTiming.phaseIndex(take + 2950), 1);
    });
  });
}
