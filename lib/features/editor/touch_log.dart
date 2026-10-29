import 'dart:math' as math;

/// What a touch turned out to be once the whole recording is looked at.
/// [tap]: a press that means something (button, menu, switch). [input]: one key of a typing burst.
/// [swipe]: a scroll or drag. [noise]: a stray or repeated touch that is not worth a mark.
enum TouchKind {
  tap,
  input,
  swipe,
  noise;

  String get wire => name;
  static TouchKind of(String? s) =>
      TouchKind.values.firstWhere((k) => k.name == s, orElse: () => tap);
}

/// What the director does with typing.
enum InputMode {
  /// A burst of keys becomes one "typing" step (default).
  merge,

  /// Every key gets its own mark, but only for short bursts.
  perKey,

  /// Typing is left out completely.
  skip;

  static InputMode of(int i) => values[i.clamp(0, values.length - 1)];
}

/// A touch as found by the scan: [x]/[y] are fractions of the frame, or null when only the moment is
/// known (frame-change fallback). [dist] is how far the finger travelled, in frame widths.
class RawTouch {
  const RawTouch({
    required this.tMs,
    this.x,
    this.y,
    this.durMs = 0,
    this.dist = 0,
    this.app,
  });
  final int tMs;
  final double? x;
  final double? y;
  final int durMs;
  final double dist;
  final String? app;

  bool get hasPosition => x != null && y != null;

  factory RawTouch.fromMap(Map<dynamic, dynamic> m) {
    double? pos(Object? v) {
      final d = (v as num?)?.toDouble();
      return d == null || d < 0 ? null : d;
    }

    return RawTouch(
      tMs: (m['tMs'] as num).toInt(),
      x: pos(m['x']),
      y: pos(m['y']),
      durMs: (m['durMs'] as num?)?.toInt() ?? 0,
      dist: (m['dist'] as num?)?.toDouble() ?? 0,
      app: m['app'] as String?,
    );
  }
}

/// A classified touch. Typing keys that follow each other share a [group] (> 0) and [count] tells how
/// many keys the group has; [sensitive] marks content that must never be shown.
class TouchEvent {
  const TouchEvent({
    required this.tMs,
    required this.kind,
    this.x,
    this.y,
    this.endMs,
    this.group = 0,
    this.count = 1,
    this.sensitive = false,
    this.app,
    this.pauseMs,
  });
  final int tMs;
  final int? endMs;
  final TouchKind kind;
  final double? x;
  final double? y;
  final int group;
  final int count;
  final bool sensitive;
  final String? app;

  /// Freeze time for this touch alone; null follows the project-wide setting.
  final int? pauseMs;

  bool get hasPosition => x != null && y != null;
}

/// Pure rules that turn raw touches into [TouchEvent]s.
abstract final class TouchClassifier {
  /// Below this fraction of the frame height a touch can be a key of the on-screen keyboard.
  static const keyboardTop = 0.55;

  /// Keys closer than this belong to the same typing burst.
  static const burstGapMs = 2000;
  static const minKeys = 3;

  /// A second touch this close (time and place) to the previous one is a bounce, not a new step.
  static const bounceMs = 250;
  static const bounceDist = 0.04;
  static const swipeDist = 0.05;

  static List<TouchEvent> classify(List<RawTouch> raw) {
    final sorted = [...raw]..sort((a, b) => a.tMs.compareTo(b.tMs));
    final kinds = List<TouchKind>.filled(sorted.length, TouchKind.tap);
    RawTouch? lastTap;
    for (var i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      if (t.dist >= swipeDist) {
        kinds[i] = TouchKind.swipe;
        continue;
      }
      final p = lastTap;
      if (p != null && t.tMs - p.tMs < bounceMs && _near(p, t)) {
        kinds[i] = TouchKind.noise;
        continue;
      }
      lastTap = t;
    }
    final groups = List<int>.filled(sorted.length, 0);
    final counts = List<int>.filled(sorted.length, 1);
    var nextGroup = 1;
    var i = 0;
    while (i < sorted.length) {
      if (!_isKey(sorted[i], kinds[i])) {
        i++;
        continue;
      }
      var j = i;
      final run = <int>[i];
      for (var k = i + 1; k < sorted.length; k++) {
        if (kinds[k] == TouchKind.noise) continue;
        if (!_isKey(sorted[k], kinds[k])) break;
        if (sorted[k].tMs - sorted[run.last].tMs > burstGapMs) break;
        run.add(k);
        j = k;
      }
      if (run.length >= minKeys) {
        for (final r in run) {
          kinds[r] = TouchKind.input;
          groups[r] = nextGroup;
          counts[r] = run.length;
        }
        nextGroup++;
      }
      i = j + 1;
    }
    return [
      for (var n = 0; n < sorted.length; n++)
        TouchEvent(
          tMs: sorted[n].tMs,
          endMs: sorted[n].tMs + sorted[n].durMs,
          kind: kinds[n],
          x: sorted[n].x,
          y: sorted[n].y,
          group: groups[n],
          count: counts[n],
          app: sorted[n].app,
        ),
    ];
  }

  /// Only touches whose place is known can be told to be on the keyboard.
  static bool _isKey(RawTouch t, TouchKind k) =>
      k == TouchKind.tap && t.hasPosition && t.y! >= keyboardTop;

  static bool _near(RawTouch a, RawTouch b) {
    if (!a.hasPosition || !b.hasPosition) return true;
    final dx = a.x! - b.x!, dy = a.y! - b.y!;
    return math.sqrt(dx * dx + dy * dy) < bounceDist;
  }
}

/// One merged freeze: where and for how long (source time).
typedef FreezeAt = ({int tMs, int ms});

abstract final class TouchPlan {
  /// Freeze points for the meaningful touches: touches closer than [mergeMs] share one freeze (the
  /// first one's moment), and a touch can carry its own [TouchEvent.pauseMs]. Typing is not handled
  /// here (the director freezes before and after a typing step itself).
  static List<FreezeAt> freezes(
    List<TouchEvent> events,
    int defaultMs, {
    int mergeMs = 1500,
  }) {
    final taps = events.where((e) => e.kind == TouchKind.tap).toList()
      ..sort((a, b) => a.tMs.compareTo(b.tMs));
    final out = <FreezeAt>[];
    int? lastT;
    for (final e in taps) {
      final ms = (e.pauseMs ?? defaultMs).clamp(0, 1500);
      if (ms <= 0) continue;
      if (lastT != null && e.tMs - lastT < mergeMs) continue;
      out.add((tMs: e.tMs, ms: ms));
      lastT = e.tMs;
    }
    return out;
  }
}
