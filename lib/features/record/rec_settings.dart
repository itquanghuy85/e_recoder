import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';

enum Resolution { p720, p1080, native }

enum Quality { low, balanced, high }

enum AudioMode { none, mic, system, both }

/// Persisted capture profile. Defaults: 1080p / 30 fps / balanced, mic only, 3 s countdown.
class RecSettings {
  const RecSettings({
    this.resolution = Resolution.p1080,
    this.fps = 30,
    this.quality = Quality.balanced,
    this.audio = AudioMode.mic,
    this.countdown = 3,
    this.floatingBar = true,
  });

  final Resolution resolution;
  final int fps;
  final Quality quality;
  final AudioMode audio;
  final int countdown;
  final bool floatingBar;

  bool get mic => audio == AudioMode.mic || audio == AudioMode.both;
  bool get system => audio == AudioMode.system || audio == AudioMode.both;

  RecSettings copyWith({
    Resolution? resolution,
    int? fps,
    Quality? quality,
    AudioMode? audio,
    int? countdown,
    bool? floatingBar,
  }) => RecSettings(
    resolution: resolution ?? this.resolution,
    fps: fps ?? this.fps,
    quality: quality ?? this.quality,
    audio: audio ?? this.audio,
    countdown: countdown ?? this.countdown,
    floatingBar: floatingBar ?? this.floatingBar,
  );

  /// Target short-side in px; null keeps the native size.
  int? get shortSide => switch (resolution) {
    Resolution.p720 => 720,
    Resolution.p1080 => 1080,
    Resolution.native => null,
  };

  /// Bits per pixel per frame, tuned for screen content (flat areas, sharp text).
  double get bitsPerPixel => switch (quality) {
    Quality.low => 0.04,
    Quality.balanced => 0.07,
    Quality.high => 0.11,
  };

  /// Pure sizing math, kept out of the platform layer so it can be unit tested.
  ({int width, int height, int bitrate}) plan(int displayW, int displayH) {
    var w = displayW.toDouble();
    var h = displayH.toDouble();
    final target = shortSide;
    if (target != null) {
      final short = w < h ? w : h;
      if (short > target) {
        final k = target / short;
        w *= k;
        h *= k;
      }
    }
    final bitrate = (w * h * fps * bitsPerPixel).round().clamp(
      1500000,
      25000000,
    );
    return (width: w.round(), height: h.round(), bitrate: bitrate);
  }
}

class RecSettingsNotifier extends Notifier<RecSettings> {
  @override
  RecSettings build() {
    final s = ref.read(settingsStoreProvider);
    return RecSettings(
      resolution:
          Resolution.values[s.getInt('rec.resolution', Resolution.p1080.index)],
      fps: s.getInt('rec.fps', 30),
      quality: Quality.values[s.getInt('rec.quality', Quality.balanced.index)],
      audio: AudioMode.values[s.getInt('rec.audio', AudioMode.mic.index)],
      countdown: s.getInt('rec.countdown', 3),
      floatingBar: s.getBool('rec.floatingBar', true),
    );
  }

  Future<void> update(RecSettings v) async {
    state = v;
    final s = ref.read(settingsStoreProvider);
    await s.setInt('rec.resolution', v.resolution.index);
    await s.setInt('rec.fps', v.fps);
    await s.setInt('rec.quality', v.quality.index);
    await s.setInt('rec.audio', v.audio.index);
    await s.setInt('rec.countdown', v.countdown);
    await s.setBool('rec.floatingBar', v.floatingBar);
  }
}

final recSettingsProvider = NotifierProvider<RecSettingsNotifier, RecSettings>(
  RecSettingsNotifier.new,
);
