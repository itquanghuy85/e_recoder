import 'dart:convert';
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

  /// A comfortable bitrate for [w] x [h] at [fps] (about 0.07 bit per pixel per frame).
  /// A 60 fps source therefore asks for twice the bitrate of the same frame at 30 fps.
  static int defaultBitrate(int w, int h, {int fps = 30}) =>
      (w * h * fps * 0.07).round().clamp(1500000, maxVideoBitrate);

  static ExportPlan plan({
    required int frameW,
    required int frameH,
    required int durationMs,
    required ExportQuality quality,
    int? maxBytes,
    bool hasAudio = true,
    int sourceFps = 30,
  }) {
    final (w, h) = sizeFor(frameW, frameH, quality);
    var bitrate = defaultBitrate(w, h, fps: sourceFps);
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

/// An export setting the person saved under their own name ("My presets"). Kept apart from the
/// built-in [ExportPreset]s, in the settings store, so old installs and old projects are untouched.
class UserExportPreset {
  const UserExportPreset({
    required this.id,
    required this.name,
    this.quality = ExportQuality.original,
    this.gif = false,
    this.maxBytes,
    this.aspect,
  });

  final String id;
  final String name;
  final ExportQuality quality;
  final bool gif;

  /// Size cap of the file, null = none.
  final int? maxBytes;

  /// Output shape put into the project when the preset is picked, null = leave the project's.
  final OutAspect? aspect;

  UserExportPreset copyWith({String? id, String? name}) => UserExportPreset(
    id: id ?? this.id,
    name: name ?? this.name,
    quality: quality,
    gif: gif,
    maxBytes: maxBytes,
    aspect: aspect,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'quality': quality.name,
    'gif': gif,
    'maxBytes': ?maxBytes,
    if (aspect != null) 'aspect': aspect!.name,
  };

  /// Unknown or missing values fall back to the plain defaults, so a list written by a later
  /// version still opens.
  static UserExportPreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String || name.trim().isEmpty) return null;
    T? byName<T extends Enum>(List<T> values, Object? v) =>
        values.where((e) => e.name == v).firstOrNull;
    final cap = raw['maxBytes'];
    return UserExportPreset(
      id: id,
      name: name.trim(),
      quality:
          byName(ExportQuality.values, raw['quality']) ??
          ExportQuality.original,
      gif: raw['gif'] == true,
      maxBytes: cap is num && cap > 0 ? cap.toInt() : null,
      aspect: byName(OutAspect.values, raw['aspect']),
    );
  }
}

/// The saved list and which one is the default, as JSON in the settings store.
class UserPresetList {
  const UserPresetList(this.items, {this.defaultId});

  static const key = 'export.myPresets';
  static const maxItems = 12;

  final List<UserExportPreset> items;
  final String? defaultId;

  UserExportPreset? get defaultPreset =>
      items.where((e) => e.id == defaultId).firstOrNull;

  static UserPresetList decode(String? s) {
    if (s == null || s.isEmpty) return const UserPresetList([]);
    try {
      final j = jsonDecode(s);
      if (j is! Map) return const UserPresetList([]);
      final items = [
        for (final e in (j['items'] as List? ?? const []))
          ?UserExportPreset.fromJson(e),
      ];
      final d = j['default'];
      return UserPresetList(
        items,
        defaultId: d is String && items.any((e) => e.id == d) ? d : null,
      );
    } catch (_) {
      return const UserPresetList([]);
    }
  }

  String encode() => jsonEncode({
    'items': items.map((e) => e.toJson()).toList(),
    'default': ?defaultId,
  });

  /// Adds [p] (a new id) or replaces the one with the same id; the newest stays last. The list is
  /// capped so the chips stay readable.
  UserPresetList upsert(UserExportPreset p) {
    final i = items.indexWhere((e) => e.id == p.id);
    final next = [...items];
    if (i >= 0) {
      next[i] = p;
    } else {
      next.add(p);
    }
    while (next.length > maxItems) {
      next.removeAt(0);
    }
    return UserPresetList(
      next,
      defaultId: next.any((e) => e.id == defaultId) ? defaultId : null,
    );
  }

  UserPresetList remove(String id) => UserPresetList(
    [...items.where((e) => e.id != id)],
    defaultId: defaultId == id ? null : defaultId,
  );

  /// A copy of [id] named [name], right after it.
  UserPresetList duplicate(String id, String newId, String name) {
    final src = items.where((e) => e.id == id).firstOrNull;
    if (src == null) return this;
    return upsert(src.copyWith(id: newId, name: name));
  }

  /// [id] becomes the default; the same id again (or null) clears it.
  UserPresetList withDefault(String? id) => UserPresetList(
    items,
    defaultId: id == defaultId ? null : id,
  );
}
