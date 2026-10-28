/// Music chosen from the phone, or a voice-over recorded in the editor. Tracks sit on the OUTPUT
/// timeline ([startOutMs]) and are mixed with the video's own sound by the exporter.
enum AudioKind { music, voice }

/// What a voice-over sounds like. [none] keeps the original. Mirror of VoiceFxMath in VoiceFx.kt.
enum VoiceFx { none, deep, high, chipmunk, robot, echo, reverb }

/// How much background noise is taken out of a voice-over.
enum Denoise { off, light, strong }

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.kind,
    required this.path,
    required this.name,
    required this.fileMs,
    this.startOutMs = 0,
    this.trimStartMs = 0,
    this.volume = 1,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.loop = false,
    this.duck = true,
    this.fx = VoiceFx.none,
    this.denoise = Denoise.off,
    this.fxPath,
  });

  final String id;
  final AudioKind kind;

  /// A copy inside the app's own storage (the picked file may be revoked later).
  final String path;
  final String name;

  /// Length of the file.
  final int fileMs;
  final int startOutMs;

  /// Where in the file playing starts.
  final int trimStartMs;
  final double volume;
  final int fadeInMs;
  final int fadeOutMs;

  /// Music only: repeat until the end of the video.
  final bool loop;

  /// Music only: get quieter while a voice-over is speaking.
  final bool duck;

  /// Voice-over only: effect and noise reduction. They are applied ONCE to the file ([fxPath]);
  /// the preview and the export both play that file, so they always sound the same, and [path]
  /// stays the untouched original to go back to.
  final VoiceFx fx;
  final Denoise denoise;
  final String? fxPath;

  bool get hasVoiceWork => fx != VoiceFx.none || denoise != Denoise.off;

  /// The file that is played and exported.
  String get playPath => hasVoiceWork && fxPath != null ? fxPath! : path;

  /// How long this track plays in a video [outMs] long (never past the end of the video).
  int playMs(int outMs) {
    final room = outMs - startOutMs;
    if (room <= 0) return 0;
    if (loop && kind == AudioKind.music) return room;
    final own = fileMs - trimStartMs;
    return own < room ? own : room;
  }

  int endOutMs(int outMs) => startOutMs + playMs(outMs);

  /// Gain at [offsetMs] into the track. [duckRanges] are voice-over spans (output time) that lower music.
  double gainAt(int offsetMs, int playLenMs, List<(int, int)> duckRanges) {
    var g = volume;
    if (fadeInMs > 0 && offsetMs < fadeInMs) {
      g *= (offsetMs / fadeInMs).clamp(0.0, 1.0);
    }
    final left = playLenMs - offsetMs;
    if (fadeOutMs > 0 && left < fadeOutMs) {
      g *= (left / fadeOutMs).clamp(0.0, 1.0);
    }
    if (kind == AudioKind.music && duck && duckRanges.isNotEmpty) {
      g *= duckFactor(startOutMs + offsetMs, duckRanges);
    }
    return g;
  }

  /// Music level while a voice speaks (linear ramps of [duckRampMs] at both ends).
  static const duckLevel = 0.3;
  static const duckRampMs = 250;

  static double duckFactor(int outMs, List<(int, int)> ranges) {
    var f = 1.0;
    for (final (a, b) in ranges) {
      double k;
      if (outMs >= a && outMs <= b) {
        k = duckLevel;
      } else if (outMs < a && a - outMs < duckRampMs) {
        k = 1 - (1 - duckLevel) * (1 - (a - outMs) / duckRampMs);
      } else if (outMs > b && outMs - b < duckRampMs) {
        k = 1 - (1 - duckLevel) * (1 - (outMs - b) / duckRampMs);
      } else {
        continue;
      }
      if (k < f) f = k;
    }
    return f;
  }

  AudioTrack copyWith({
    int? startOutMs,
    int? trimStartMs,
    double? volume,
    int? fadeInMs,
    int? fadeOutMs,
    bool? loop,
    bool? duck,
    String? name,
    VoiceFx? fx,
    Denoise? denoise,
    Object? fxPath = _keep,
  }) => AudioTrack(
    id: id,
    kind: kind,
    path: path,
    name: name ?? this.name,
    fileMs: fileMs,
    startOutMs: startOutMs ?? this.startOutMs,
    trimStartMs: trimStartMs ?? this.trimStartMs,
    volume: volume ?? this.volume,
    fadeInMs: fadeInMs ?? this.fadeInMs,
    fadeOutMs: fadeOutMs ?? this.fadeOutMs,
    loop: loop ?? this.loop,
    duck: duck ?? this.duck,
    fx: fx ?? this.fx,
    denoise: denoise ?? this.denoise,
    fxPath: identical(fxPath, _keep) ? this.fxPath : fxPath as String?,
  );

  static const Object _keep = Object();

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'path': path,
    'name': name,
    'fileMs': fileMs,
    'startOutMs': startOutMs,
    'trimStartMs': trimStartMs,
    'volume': volume,
    'fadeInMs': fadeInMs,
    'fadeOutMs': fadeOutMs,
    'loop': loop,
    'duck': duck,
    if (fx != VoiceFx.none) 'fx': fx.name,
    if (denoise != Denoise.off) 'denoise': denoise.name,
    'fxPath': ?fxPath,
  };

  factory AudioTrack.fromJson(Map<String, dynamic> j) => AudioTrack(
    id: j['id'] as String,
    kind: AudioKind.values.firstWhere(
      (e) => e.name == j['kind'],
      orElse: () => AudioKind.music,
    ),
    path: j['path'] as String,
    name: j['name'] as String? ?? '',
    fileMs: (j['fileMs'] as num).toInt(),
    startOutMs: (j['startOutMs'] as num?)?.toInt() ?? 0,
    trimStartMs: (j['trimStartMs'] as num?)?.toInt() ?? 0,
    volume: (j['volume'] as num?)?.toDouble() ?? 1,
    fadeInMs: (j['fadeInMs'] as num?)?.toInt() ?? 0,
    fadeOutMs: (j['fadeOutMs'] as num?)?.toInt() ?? 0,
    loop: j['loop'] as bool? ?? false,
    duck: j['duck'] as bool? ?? true,
    fx: VoiceFx.values.firstWhere(
      (e) => e.name == j['fx'],
      orElse: () => VoiceFx.none,
    ),
    denoise: Denoise.values.firstWhere(
      (e) => e.name == j['denoise'],
      orElse: () => Denoise.off,
    ),
    fxPath: j['fxPath'] as String?,
  );
}
