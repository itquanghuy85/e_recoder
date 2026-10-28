import 'dart:math' as math;

/// Mirror of android/.../marker/MarkerAnim.kt: "cue → take" timing. Both files are covered by
/// the same test vectors (test/marker_timing_test.dart and MarkerAnimTest.kt) — change them together.
abstract final class MarkerTiming {
  static const int cueMs = 500;

  /// Range of the "keep the marker" setting. Mirror of MarkerAnim.MIN_HOLD_MS / MAX_HOLD_MS.
  static const int minHoldMs = 500;
  static const int maxHoldMs = 10000;
  static const int popMs = 140;
  static const int pressMs = 260;
  static const int fadeMs = 300;
  static const double ghostAlpha = 0.22;
  static const int never = 1 << 62;

  /// The water loop (rings, shine) repeats every [loopMs]; the editor shows it as [phaseCount]
  /// pre-rendered phases. Mirror of Water.PERIOD_MS in the native renderer.
  static const int loopMs = 1400;
  static const int phaseStepMs = 100;
  static const int phaseCount = loopMs ~/ phaseStepMs;

  /// Which phase to show [sinceTakeMs] after the take.
  static int phaseIndex(int sinceTakeMs) =>
      (math.max(0, sinceTakeMs - cueMs) ~/ phaseStepMs) % phaseCount;

  static double easeOut(double t) =>
      1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();

  static double easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    final x = t.clamp(0.0, 1.0) - 1;
    return 1 + c3 * x * x * x + c1 * x * x;
  }

  /// [tMs] is time since the cue started; [fadeStartMs] when the fade begins ([never] = stays).
  static MarkerFrame frame(int tMs, int fadeStartMs) {
    if (tMs < 0) return const MarkerFrame(0, 0, 1, 0, false);
    final fadeStart = math.max(fadeStartMs, cueMs);
    var fade = 1.0;
    var done = false;
    if (fadeStart != never && tMs > fadeStart) {
      fade = 1 - ((tMs - fadeStart) / fadeMs).clamp(0.0, 1.0);
      done = tMs >= fadeStart + fadeMs;
    }
    if (tMs < cueMs) {
      final p = easeOut(tMs / cueMs);
      return MarkerFrame(p, ghostAlpha * fade, 1, 0, done);
    }
    final since = tMs - cueMs;
    final pop = easeOutBack(since / popMs);
    final scale = 0.88 + 0.12 * pop;
    final pressT = (since / pressMs).clamp(0.0, 1.0);
    final press = pressT >= 1 ? 0.0 : math.sin(math.pi * pressT);
    return MarkerFrame(-1, fade, scale, press, done);
  }
}

class MarkerFrame {
  const MarkerFrame(
    this.cueProgress,
    this.bodyAlpha,
    this.bodyScale,
    this.press,
    this.done,
  );

  /// 0..1 while the cue ring converges, -1 once the cue is over.
  final double cueProgress;
  final double bodyAlpha;
  final double bodyScale;
  final double press;
  final bool done;
}
