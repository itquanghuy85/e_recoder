/// Word-level timing and styling for progressive (karaoke-style) captions.
///
/// Pure Dart: no widgets and no platform calls, so it is unit tested like the rest of the
/// project model. Times are SOURCE milliseconds, the same clock `TextItem.startMs/endMs` use.
library;

/// One spoken word inside a caption cue.
class WordTiming {
  const WordTiming({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;

  /// How much of the word has been spoken at [ms]: 0 before [startMs], 1 from [endMs], linear between.
  double progressAt(int ms) {
    final len = endMs - startMs;
    if (len <= 0) return ms >= startMs ? 1 : 0;
    if (ms <= startMs) return 0;
    if (ms >= endMs) return 1;
    return (ms - startMs) / len;
  }

  /// Progress of one character of the word, for a typewriter reveal.
  ///
  /// The characters share the word's span equally: character [charIndex] starts at
  /// `startMs + i / length * duration` and is complete one slice later. 0 before that,
  /// 1 after it. Out-of-range indexes clamp to the first / last character.
  double charProgressAt(int ms, int charIndex) {
    final length = text.length;
    if (length <= 0) return ms >= endMs ? 1 : 0;
    final i = charIndex.clamp(0, length - 1);
    final span = endMs - startMs;
    if (span <= 0) return ms >= endMs ? 1 : 0;
    final from = startMs + (span * i / length).floor();
    final to = startMs + (span * (i + 1) / length).floor();
    if (ms <= from) return 0;
    if (ms >= to) return 1;
    final len = to - from;
    if (len <= 0) return 1;
    return (ms - from) / len;
  }

  Map<String, Object> toJson() => {
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
  };

  factory WordTiming.fromJson(Map<String, dynamic> j) => WordTiming(
    text: j['text'] as String? ?? '',
    startMs: (j['startMs'] as num?)?.toInt() ?? 0,
    endMs: (j['endMs'] as num?)?.toInt() ?? 0,
  );
}

/// One line of subtitle: its text, when it is shown, and (when known) its word timings.
class CaptionCue {
  const CaptionCue({
    required this.text,
    required this.startMs,
    required this.endMs,
    this.words = const [],
  });

  final String text;
  final int startMs;
  final int endMs;
  final List<WordTiming> words;

  /// True while the cue is on screen (start inclusive, end exclusive).
  bool isActiveAt(int ms) => ms >= startMs && ms < endMs;

  Map<String, Object> toJson() => {
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
    'words': words.map((e) => e.toJson()).toList(),
  };

  factory CaptionCue.fromJson(Map<String, dynamic> j) => CaptionCue(
    text: j['text'] as String? ?? '',
    startMs: (j['startMs'] as num?)?.toInt() ?? 0,
    endMs: (j['endMs'] as num?)?.toInt() ?? 0,
    words: ((j['words'] as List?) ?? const [])
        .map((e) => WordTiming.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// A copy with new text / timing; words are kept unless [words] is given.
  CaptionCue copyWith({
    String? text,
    int? startMs,
    int? endMs,
    List<WordTiming>? words,
  }) => CaptionCue(
    text: text ?? this.text,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    words: words ?? this.words,
  );

  /// Splits [text] on whitespace and shares [durationMs] equally between the words.
  ///
  /// Used when a cue has no word timing (typed by hand or an SRT import): every word gets an
  /// equal slice, which is enough for a word-by-word reveal. Runs of spaces are dropped; the
  /// total span always equals [durationMs].
  static List<WordTiming> splitEvenly(
    String text,
    int durationMs, {
    int startMs = 0,
  }) {
    final parts = text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return const [];
    final span = durationMs <= 0 ? 0 : durationMs;
    return [
      for (var i = 0; i < parts.length; i++)
        WordTiming(
          text: parts[i],
          startMs: startMs + (span * i ~/ parts.length),
          endMs: startMs + (span * (i + 1) ~/ parts.length),
        ),
    ];
  }
}

/// How a caption reveals its text as the playhead moves.
enum RevealMode { none, wordByWord, charByChar, karaokeHighlight }

/// Look of a caption overlay. Colours are ARGB ints; positions and sizes are in editor "U" units,
/// exactly like [TextItem.sizeU] / [TextItem.x] / [TextItem.y], so native preview and export read
/// the same numbers.
class CaptionStyle {
  const CaptionStyle({
    this.fontId = 'barlow',
    this.sizeU = 22,
    this.color = 0xFFFFFFFF,
    this.outlineColor,
    this.outlineWidth = 0,
    this.shadowColor,
    this.shadowBlur = 0,
    this.boxColor,
    this.boxRadius = 0,
    this.align = 'center',
    this.x = 0.5,
    this.y = 0.85,
    this.revealMode = RevealMode.wordByWord,
    this.templateId,
  });

  final String fontId;
  final double sizeU;
  final int color;
  final int? outlineColor;
  final double outlineWidth;
  final int? shadowColor;
  final double shadowBlur;
  final int? boxColor;
  final double boxRadius;
  final String align;
  final double x;
  final double y;
  final RevealMode revealMode;
  final String? templateId;

  static const Object _keep = Object();

  CaptionStyle copyWith({
    String? fontId,
    double? sizeU,
    int? color,
    Object? outlineColor = _keep,
    double? outlineWidth,
    Object? shadowColor = _keep,
    double? shadowBlur,
    Object? boxColor = _keep,
    double? boxRadius,
    String? align,
    double? x,
    double? y,
    RevealMode? revealMode,
    Object? templateId = _keep,
  }) => CaptionStyle(
    fontId: fontId ?? this.fontId,
    sizeU: sizeU ?? this.sizeU,
    color: color ?? this.color,
    outlineColor: identical(outlineColor, _keep)
        ? this.outlineColor
        : outlineColor as int?,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    shadowColor: identical(shadowColor, _keep)
        ? this.shadowColor
        : shadowColor as int?,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    boxColor: identical(boxColor, _keep) ? this.boxColor : boxColor as int?,
    boxRadius: boxRadius ?? this.boxRadius,
    align: align ?? this.align,
    x: x ?? this.x,
    y: y ?? this.y,
    revealMode: revealMode ?? this.revealMode,
    templateId: identical(templateId, _keep)
        ? this.templateId
        : templateId as String?,
  );

  Map<String, Object?> toJson() => {
    'fontId': fontId,
    'sizeU': sizeU,
    'color': color,
    'outlineColor': outlineColor,
    'outlineWidth': outlineWidth,
    'shadowColor': shadowColor,
    'shadowBlur': shadowBlur,
    'boxColor': boxColor,
    'boxRadius': boxRadius,
    'align': align,
    'x': x,
    'y': y,
    'revealMode': revealMode.name,
    'templateId': templateId,
  };

  factory CaptionStyle.fromJson(Map<String, dynamic> j) => CaptionStyle(
    fontId: j['fontId'] as String? ?? 'barlow',
    sizeU: (j['sizeU'] as num?)?.toDouble() ?? 22,
    color: (j['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
    outlineColor: (j['outlineColor'] as num?)?.toInt(),
    outlineWidth: (j['outlineWidth'] as num?)?.toDouble() ?? 0,
    shadowColor: (j['shadowColor'] as num?)?.toInt(),
    shadowBlur: (j['shadowBlur'] as num?)?.toDouble() ?? 0,
    boxColor: (j['boxColor'] as num?)?.toInt(),
    boxRadius: (j['boxRadius'] as num?)?.toDouble() ?? 0,
    align: j['align'] as String? ?? 'center',
    x: (j['x'] as num?)?.toDouble() ?? 0.5,
    y: (j['y'] as num?)?.toDouble() ?? 0.85,
    revealMode: RevealMode.values.firstWhere(
      (e) => e.name == j['revealMode'],
      orElse: () => RevealMode.wordByWord,
    ),
    templateId: j['templateId'] as String?,
  );
}
