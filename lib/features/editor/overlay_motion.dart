import 'dart:math' as math;

/// How an overlay moves while it is on screen. Shared by text, images and shapes, and mirrored in
/// OverlayMotion.kt (golden values in the tests of both): the preview and the exporter must agree.
enum Ease { linear, easeIn, easeOut, easeInOut }

enum EnterExit { none, fade, pop, slideUp, slideDown, slideLeft, slideRight }

double applyEase(Ease e, double t) {
  final x = t.clamp(0.0, 1.0);
  return switch (e) {
    Ease.linear => x,
    Ease.easeIn => x * x,
    Ease.easeOut => 1 - (1 - x) * (1 - x),
    Ease.easeInOut => x * x * (3 - 2 * x),
  };
}

/// Position / size / opacity of an overlay: where it starts, and optionally where it ends.
class ItemMotion {
  const ItemMotion({
    this.endX,
    this.endY,
    this.endScale,
    this.endOpacity,
    this.ease = Ease.easeInOut,
    this.enter = EnterExit.fade,
    this.exit = EnterExit.fade,
    this.enterExitMs = 220,
  });

  /// Keyframe at the end of the overlay's life; null = same as the start. Any non-null value animates.
  final double? endX;
  final double? endY;
  final double? endScale;
  final double? endOpacity;
  final Ease ease;
  final EnterExit enter;
  final EnterExit exit;
  final int enterExitMs;

  static const none = ItemMotion(enter: EnterExit.none, exit: EnterExit.none);
  static const fadeOnly = ItemMotion();

  bool get hasKeyframe =>
      endX != null || endY != null || endScale != null || endOpacity != null;

  ItemMotion copyWith({
    Object? endX = _keep,
    Object? endY = _keep,
    Object? endScale = _keep,
    Object? endOpacity = _keep,
    Ease? ease,
    EnterExit? enter,
    EnterExit? exit,
    int? enterExitMs,
  }) => ItemMotion(
    endX: identical(endX, _keep) ? this.endX : endX as double?,
    endY: identical(endY, _keep) ? this.endY : endY as double?,
    endScale: identical(endScale, _keep) ? this.endScale : endScale as double?,
    endOpacity: identical(endOpacity, _keep)
        ? this.endOpacity
        : endOpacity as double?,
    ease: ease ?? this.ease,
    enter: enter ?? this.enter,
    exit: exit ?? this.exit,
    enterExitMs: enterExitMs ?? this.enterExitMs,
  );
  static const Object _keep = Object();

  Map<String, Object> toJson() => {
    'endX': ?endX,
    'endY': ?endY,
    'endScale': ?endScale,
    'endOpacity': ?endOpacity,
    'ease': ease.name,
    'enter': enter.name,
    'exit': exit.name,
    'enterExitMs': enterExitMs,
  };

  factory ItemMotion.fromJson(Map<String, dynamic>? j) {
    if (j == null) return fadeOnly;
    T pick<T extends Enum>(List<T> v, Object? n, T d) =>
        v.firstWhere((e) => e.name == n, orElse: () => d);
    return ItemMotion(
      endX: (j['endX'] as num?)?.toDouble(),
      endY: (j['endY'] as num?)?.toDouble(),
      endScale: (j['endScale'] as num?)?.toDouble(),
      endOpacity: (j['endOpacity'] as num?)?.toDouble(),
      ease: pick(Ease.values, j['ease'], Ease.easeInOut),
      enter: pick(EnterExit.values, j['enter'], EnterExit.fade),
      exit: pick(EnterExit.values, j['exit'], EnterExit.fade),
      enterExitMs: (j['enterExitMs'] as num?)?.toInt() ?? 220,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ItemMotion &&
      other.endX == endX &&
      other.endY == endY &&
      other.endScale == endScale &&
      other.endOpacity == endOpacity &&
      other.ease == ease &&
      other.enter == enter &&
      other.exit == exit &&
      other.enterExitMs == enterExitMs;
  @override
  int get hashCode => Object.hash(
    endX,
    endY,
    endScale,
    endOpacity,
    ease,
    enter,
    exit,
    enterExitMs,
  );
}

/// State of an overlay at one instant: centre (fractions of the output frame), a size factor and opacity.
class MotionState {
  const MotionState(this.x, this.y, this.scale, this.alpha);
  final double x;
  final double y;
  final double scale;
  final double alpha;

  bool get visible => alpha > 0.002 && scale > 0.001;
}

/// [t] is the time into the overlay's life ([lifeMs] long). Base values are the overlay's own x, y,
/// scale (1 = natural size) and opacity.
MotionState motionAt(
  ItemMotion m, {
  required double x,
  required double y,
  required double scale,
  required double opacity,
  required int t,
  required int lifeMs,
}) {
  if (t < 0 || t > lifeMs) return const MotionState(0, 0, 0, 0);
  var px = x, py = y, ps = scale, pa = opacity;
  if (m.hasKeyframe && lifeMs > 0) {
    final k = applyEase(m.ease, t / lifeMs);
    px = x + ((m.endX ?? x) - x) * k;
    py = y + ((m.endY ?? y) - y) * k;
    ps = scale + ((m.endScale ?? scale) - scale) * k;
    pa = opacity + ((m.endOpacity ?? opacity) - opacity) * k;
  }
  final ms = math.max(1, math.min(m.enterExitMs, lifeMs ~/ 2));
  void phase(EnterExit kind, double u, bool entering) {
    // u: 0 = hidden / displaced, 1 = settled
    final q = applyEase(Ease.easeOut, u);
    final away = 1 - q;
    switch (kind) {
      case EnterExit.none:
        break;
      case EnterExit.fade:
        pa *= q;
      case EnterExit.pop:
        pa *= q;
        ps *= 0.6 + 0.4 * q;
      case EnterExit.slideUp:
        py += (entering ? 1 : -1) * 0.08 * away;
        pa *= q;
      case EnterExit.slideDown:
        py += (entering ? -1 : 1) * 0.08 * away;
        pa *= q;
      case EnterExit.slideLeft:
        px += (entering ? 1 : -1) * 0.08 * away;
        pa *= q;
      case EnterExit.slideRight:
        px += (entering ? -1 : 1) * 0.08 * away;
        pa *= q;
    }
  }

  if (t < ms) phase(m.enter, t / ms, true);
  if (lifeMs - t < ms) phase(m.exit, (lifeMs - t) / ms, false);
  return MotionState(px, py, ps, pa.clamp(0.0, 1.0));
}
