import 'dart:math' as math;

/// How one cut joins the next. Each transition uses only the two clips' own pictures (no overlap
/// of two decoders): the outgoing clip leaves during the first half, the incoming clip arrives
/// during the second half, so the total length never changes and weak phones stay smooth.
enum TransitionKind {
  none,
  dipBlack,
  dipWhite,
  slideLeft,
  slideRight,
  slideUp,
  slideDown,
  zoom,
}

class Transition {
  const Transition(this.kind, [this.ms = 600]);
  final TransitionKind kind;

  /// Total length around the cut; half is spent on each side of it.
  final int ms;

  static const minMs = 200;
  static const maxMs = 1500;

  bool get isNone => kind == TransitionKind.none;

  Map<String, Object> toJson() => {'kind': kind.name, 'ms': ms};
  static Transition? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = TransitionKind.values.where((e) => e.name == j['kind']);
    if (k.isEmpty || k.first == TransitionKind.none) return null;
    return Transition(
      k.first,
      ((j['ms'] as num?) ?? 600).toInt().clamp(minMs, maxMs),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Transition && other.kind == kind && other.ms == ms;
  @override
  int get hashCode => Object.hash(kind, ms);
}

/// The look of one frame during a transition. Mirror of TransitionMath.kt: keep both in step.
class TransitionLook {
  const TransitionLook({
    this.mul = 1,
    this.add = 0,
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
  });

  /// Colour = picture * [mul] + [add] (same for r, g, b). Dip to black: add 0; dip to white: add 1-mul.
  final double mul;
  final double add;

  /// Picture shift in NDC units (the full frame width is 2).
  final double dx;
  final double dy;
  final double scale;

  static const none = TransitionLook();
  bool get isNone => mul == 1 && add == 0 && dx == 0 && dy == 0 && scale == 1;

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// [u] is the progress of the half: 0 = at the cut, 1 = back to a normal picture.
  /// [incoming] true for the clip arriving after the cut.
  static TransitionLook of(
    TransitionKind kind,
    double u, {
    required bool incoming,
  }) {
    final q = _smooth(u);
    final away = 1 - q;
    switch (kind) {
      case TransitionKind.none:
        return none;
      case TransitionKind.dipBlack:
        return TransitionLook(mul: q);
      case TransitionKind.dipWhite:
        return TransitionLook(mul: q, add: away);
      case TransitionKind.slideLeft:
      case TransitionKind.slideRight:
      case TransitionKind.slideUp:
      case TransitionKind.slideDown:
        final mx = kind == TransitionKind.slideLeft
            ? -1.0
            : kind == TransitionKind.slideRight
            ? 1.0
            : 0.0;
        final my = kind == TransitionKind.slideUp
            ? 1.0
            : kind == TransitionKind.slideDown
            ? -1.0
            : 0.0;
        final s = (incoming ? -1.0 : 1.0) * away * 2;
        return TransitionLook(dx: mx * s, dy: my * s);
      case TransitionKind.zoom:
        return TransitionLook(mul: q, scale: 1 + away * 0.5);
    }
  }

  /// The strongest of two looks (a clip so short that both of its ends are inside a transition).
  static TransitionLook strongest(TransitionLook a, TransitionLook b) {
    if (a.isNone) return b;
    if (b.isNone) return a;
    return a.mul <= b.mul && a.dx.abs() + a.dy.abs() >= b.dx.abs() + b.dy.abs()
        ? a
        : b;
  }
}

/// A kept part of the source, a freeze frame or a blank (black) gap.
///
/// Times are SOURCE milliseconds. Playing runs along a "play offset" p in [0, length]: forward it
/// is startMs + p, reversed it is endMs - p. Speed is constant, or a ramp from [speed] to
/// [speedEnd] sampled in [rampSteps] equal steps (the same steps are used by the player, the
/// timeline maths and the exporter, so all three agree to the millisecond).
class Segment {
  const Segment({
    required this.startMs,
    required this.endMs,
    this.speed = 1,
    this.speedEnd,
    this.reverse = false,
    this.freezeMs = 0,
    this.blank = false,
    this.volume = 1,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.transition,
  });

  final int startMs;
  final int endMs;
  final double speed;

  /// Speed at the end of a ramp; null = constant [speed].
  final double? speedEnd;
  final bool reverse;

  /// > 0: a still of the frame at [startMs] shown for this long (endMs is ignored).
  final int freezeMs;

  /// A black, silent gap of [freezeMs].
  final bool blank;

  /// Audio gain of this segment, 0 = muted. Up to 2 (200 %).
  final double volume;
  final int fadeInMs;
  final int fadeOutMs;

  /// How the cut BEFORE this segment looks (ignored for the first segment).
  final Transition? transition;

  static const rampSteps = 24;
  static const minSpeed = 0.1;
  static const maxSpeed = 8.0;

  bool get isStill => freezeMs > 0;
  bool get isRamp =>
      !isStill && speedEnd != null && (speedEnd! - speed).abs() > 0.01;

  /// Source length (0 for stills).
  int get lengthMs => isStill ? 0 : endMs - startMs;

  /// Nominal speed (used where one number is needed: labels, "is it sped up").
  double get meanSpeed => isRamp ? (speed + speedEnd!) / 2 : speed;

  double _stepSpeed(int k) =>
      isRamp ? speed + (speedEnd! - speed) * (k + 0.5) / rampSteps : speed;

  /// Speed at play offset [p] (source ms moved along the playing direction).
  double speedAtPlay(double p) {
    if (!isRamp) return speed;
    final len = lengthMs;
    if (len <= 0) return speed;
    final k = (p / len * rampSteps).floor().clamp(0, rampSteps - 1);
    return _stepSpeed(k);
  }

  /// Output time (ms) needed to reach play offset [p].
  double outAtPlay(double p) {
    final len = lengthMs.toDouble();
    if (!isRamp) return p.clamp(0, len) / speed;
    final stepLen = len / rampSteps;
    var rest = p.clamp(0, len).toDouble();
    var out = 0.0;
    for (var k = 0; k < rampSteps && rest > 0; k++) {
      final d = math.min(stepLen, rest);
      out += d / _stepSpeed(k);
      rest -= d;
    }
    return out;
  }

  /// Play offset reached after [out] ms of output.
  double playAtOut(double out) {
    final len = lengthMs.toDouble();
    if (!isRamp) return (out * speed).clamp(0, len).toDouble();
    final stepLen = len / rampSteps;
    var rest = out < 0 ? 0.0 : out;
    var p = 0.0;
    for (var k = 0; k < rampSteps; k++) {
      final v = _stepSpeed(k);
      final stepOut = stepLen / v;
      if (rest <= stepOut) return p + rest * v;
      rest -= stepOut;
      p += stepLen;
    }
    return len;
  }

  int get outLengthMs =>
      isStill ? freezeMs : outAtPlay(lengthMs.toDouble()).round();

  /// Source time shown after [out] ms of this segment's output.
  int sourceAtOut(int out) {
    if (isStill) return startMs;
    final p = playAtOut(out.toDouble()).round();
    return reverse ? endMs - p : startMs + p;
  }

  /// Output offset of source time [t] inside this segment (t must be in [startMs, endMs]).
  int outAtSource(int t) {
    if (isStill) return 0;
    final p = reverse ? endMs - t : t - startMs;
    return outAtPlay(p.toDouble()).round();
  }

  /// Gain at output offset [outOffset] of a segment [outLen] long (volume + fades).
  double gainAt(int outOffset, int outLen) {
    var g = volume;
    if (fadeInMs > 0 && outOffset < fadeInMs) {
      g *= (outOffset / fadeInMs).clamp(0.0, 1.0);
    }
    final left = outLen - outOffset;
    if (fadeOutMs > 0 && left < fadeOutMs) {
      g *= (left / fadeOutMs).clamp(0.0, 1.0);
    }
    return g;
  }

  bool get hasAudio => !isStill && volume > 0;

  Segment copyWith({
    int? startMs,
    int? endMs,
    double? speed,
    Object? speedEnd = _keep,
    bool? reverse,
    int? freezeMs,
    bool? blank,
    double? volume,
    int? fadeInMs,
    int? fadeOutMs,
    Object? transition = _keep,
  }) => Segment(
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    speed: speed ?? this.speed,
    speedEnd: identical(speedEnd, _keep) ? this.speedEnd : speedEnd as double?,
    reverse: reverse ?? this.reverse,
    freezeMs: freezeMs ?? this.freezeMs,
    blank: blank ?? this.blank,
    volume: volume ?? this.volume,
    fadeInMs: fadeInMs ?? this.fadeInMs,
    fadeOutMs: fadeOutMs ?? this.fadeOutMs,
    transition: identical(transition, _keep)
        ? this.transition
        : transition as Transition?,
  );

  static const Object _keep = Object();

  Map<String, Object> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'speed': speed,
    'speedEnd': ?speedEnd,
    if (reverse) 'reverse': true,
    if (freezeMs > 0) 'freezeMs': freezeMs,
    if (blank) 'blank': true,
    if (volume != 1) 'volume': volume,
    if (fadeInMs > 0) 'fadeInMs': fadeInMs,
    if (fadeOutMs > 0) 'fadeOutMs': fadeOutMs,
    if (transition != null) 'transition': transition!.toJson(),
  };

  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
    startMs: j['startMs'] as int,
    endMs: j['endMs'] as int,
    speed: (j['speed'] as num).toDouble(),
    speedEnd: (j['speedEnd'] as num?)?.toDouble(),
    reverse: j['reverse'] as bool? ?? false,
    freezeMs: (j['freezeMs'] as num?)?.toInt() ?? 0,
    blank: j['blank'] as bool? ?? false,
    volume: (j['volume'] as num?)?.toDouble() ?? 1,
    fadeInMs: (j['fadeInMs'] as num?)?.toInt() ?? 0,
    fadeOutMs: (j['fadeOutMs'] as num?)?.toInt() ?? 0,
    transition: Transition.fromJson(j['transition']),
  );

  @override
  bool operator ==(Object other) =>
      other is Segment &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.speed == speed &&
      other.speedEnd == speedEnd &&
      other.reverse == reverse &&
      other.freezeMs == freezeMs &&
      other.blank == blank &&
      other.volume == volume &&
      other.fadeInMs == fadeInMs &&
      other.fadeOutMs == fadeOutMs &&
      other.transition == transition;
  @override
  int get hashCode => Object.hash(
    startMs,
    endMs,
    speed,
    speedEnd,
    reverse,
    freezeMs,
    blank,
    volume,
    fadeInMs,
    fadeOutMs,
    transition,
  );
}
