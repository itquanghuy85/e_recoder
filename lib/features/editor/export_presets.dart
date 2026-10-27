import 'dart:math' as math;

import 'picture_look.dart';

/// What the export sheet offers. A preset fixes the target (size, shape, size cap); the sheet still
/// lets the user pick any quality by hand ("custom").
enum ExportPreset { custom, youtube, vertical, share, gif }

/// Short side of the output frame for the quality chips (0 = keep the source size).
enum ExportQuality { original, p1080, p720, p480 }

class PresetSpec {
  const PresetSpec({
    required this.quality,
    this.aspect,
    this.maxBytes,
    this.fps = 30,
    this.gif = false,
  });

  final ExportQuality quality;

  /// Output shape the preset wants (applied to the project so the preview matches), null = leave it.
  final OutAspect? aspect;

  /// Target upper limit of the file, null = none.
  final int? maxBytes;
  final int fps;
  final bool gif;

  static PresetSpec of(ExportPreset p) => switch (p) {
    ExportPreset.custom => const PresetSpec(quality: ExportQuality.original),
    ExportPreset.youtube => const PresetSpec(quality: ExportQuality.p1080),
    ExportPreset.vertical => const PresetSpec(
      quality: ExportQuality.p1080,
      aspect: OutAspect.r9x16,
    ),
    ExportPreset.share => const PresetSpec(
      quality: ExportQuality.p720,
      maxBytes: 24 * 1024 * 1024,
    ),
    ExportPreset.gif => const PresetSpec(
      quality: ExportQuality.p480,
      gif: true,
    ),
  };
}

class ExportPlan {
  const ExportPlan({
    required this.outW,
    required this.outH,
    required this.bitrate,
    required this.estimatedBytes,
    required this.fitsCap,
  });

  final int outW;
  final int outH;
  final int bitrate;

  /// Video + audio, approximate.
  final int estimatedBytes;

  /// False when the size cap cannot be met even at the lowest quality we allow.
  final bool fitsCap;
}

class ExportPlanner {
  static const audioBitrate = 128000;
  static const minVideoBitrate = 350000;
  static const maxVideoBitrate = 25000000;
  static const containerOverhead = 1.03;

  /// Output dimensions for a source frame of [frameW] x [frameH] at [quality]: the "p" figure is the
  /// short side, never upscaled, always even numbers.
  static (int, int) sizeFor(int frameW, int frameH, ExportQuality q) {
    final target = switch (q) {
      ExportQuality.original => 0,
      ExportQuality.p1080 => 1080,
      ExportQuality.p720 => 720,
      ExportQuality.p480 => 480,
    };
    final short = math.min(frameW, frameH);
    if (target == 0 || short <= target) return (_even(frameW), _even(frameH));
    final k = target / short;
    return (_even((frameW * k).round()), _even((frameH * k).round()));
  }

  /// A comfortable bitrate for [w] x [h] at 30 fps (about 0.07 bit per pixel).
  static int defaultBitrate(int w, int h, {int fps = 30}) =>
      (w * h * fps * 0.07).round().clamp(1500000, maxVideoBitrate);

  static ExportPlan plan({
    required int frameW,
    required int frameH,
    required int durationMs,
    required ExportQuality quality,
    int? maxBytes,
    bool hasAudio = true,
  }) {
    final (w, h) = sizeFor(frameW, frameH, quality);
    var bitrate = defaultBitrate(w, h);
    var fits = true;
    final secs = math.max(0.1, durationMs / 1000);
    if (maxBytes != null) {
      final audio = hasAudio ? audioBitrate : 0;
      final budget = (maxBytes * 8 / containerOverhead / secs) - audio;
      if (budget < bitrate) bitrate = budget.floor();
      if (bitrate < minVideoBitrate) {
        bitrate = minVideoBitrate;
        fits = false;
      }
    }
    final bytes =
        ((bitrate + (hasAudio ? audioBitrate : 0)) *
                secs /
                8 *
                containerOverhead)
            .round();
    return ExportPlan(
      outW: w,
      outH: h,
      bitrate: bitrate,
      estimatedBytes: bytes,
      fitsCap: fits && (maxBytes == null || bytes <= maxBytes * 1.02),
    );
  }

  static int _even(int v) => math.max(2, v - v % 2);
}
