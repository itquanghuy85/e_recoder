import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../../theme/app_tokens.dart';
import 'marker_spec.dart';
import 'marker_timing.dart';

/// How markers are made while recording.
/// [dot]: a small corner dot; tap it, touch the spot you are about to press, then press for real.
/// The marker is drawn live (and recorded). [clean]: nothing on screen; the touch is only logged
/// and the editor draws the marker afterwards.
enum MarkMode { dot, clean }

/// Defaults the floating tray starts with. The tray itself changes colour/tool/size per session.
class MarkerSettings {
  const MarkerSettings({
    this.tool = MarkerType.finger,
    this.colorIndex = 0,
    this.thickness = 5,
    this.holdMs = 2500,
    this.autoExit = true,
    this.exitDelayMs = 900,
    this.mode = MarkMode.dot,
    this.corner = 2,
    this.armShake = false,
    this.autoZoom = true,
    this.autoNumber = true,
    this.zoomScale = 1.7,
    this.zoomRampMs = 350,
    this.zoomHoldMs = 0,
  });

  final MarkMode mode;

  /// After a clean recording, zoom into each marker and renumber the steps automatically.
  final bool autoZoom;
  final bool autoNumber;

  /// Automatic zoom into markers: how far, how fast, and how long it stays after the marker fades.
  final double zoomScale;
  final int zoomRampMs;
  final int zoomHoldMs;

  /// 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right.
  final int corner;
  final bool armShake;

  final MarkerType tool;
  final int colorIndex;
  final double thickness;
  final int holdMs;
  final bool autoExit;

  /// How long after placing a marker before touches go back to the app underneath.
  final int exitDelayMs;

  static const thicknessOptions = [3.0, 5.0, 8.0];

  int get color => MarkerPalette
      .colors[colorIndex.clamp(0, MarkerPalette.colors.length - 1)]
      .toARGB32();

  MarkerSettings copyWith({
    MarkerType? tool,
    int? colorIndex,
    double? thickness,
    int? holdMs,
    bool? autoExit,
    int? exitDelayMs,
    MarkMode? mode,
    int? corner,
    bool? armShake,
    bool? autoZoom,
    bool? autoNumber,
    double? zoomScale,
    int? zoomRampMs,
    int? zoomHoldMs,
  }) => MarkerSettings(
    tool: tool ?? this.tool,
    colorIndex: colorIndex ?? this.colorIndex,
    thickness: thickness ?? this.thickness,
    holdMs: holdMs ?? this.holdMs,
    autoExit: autoExit ?? this.autoExit,
    exitDelayMs: exitDelayMs ?? this.exitDelayMs,
    mode: mode ?? this.mode,
    corner: corner ?? this.corner,
    armShake: armShake ?? this.armShake,
    autoZoom: autoZoom ?? this.autoZoom,
    autoNumber: autoNumber ?? this.autoNumber,
    zoomScale: zoomScale ?? this.zoomScale,
    zoomRampMs: zoomRampMs ?? this.zoomRampMs,
    zoomHoldMs: zoomHoldMs ?? this.zoomHoldMs,
  );
}

class MarkerSettingsNotifier extends Notifier<MarkerSettings> {
  @override
  MarkerSettings build() {
    final s = ref.read(settingsStoreProvider);
    return MarkerSettings(
      tool:
          MarkerType.values[s
              .getInt('marker.tool', 0)
              .clamp(0, MarkerType.values.length - 1)],
      colorIndex: s.getInt('marker.color', 0),
      thickness: s.getInt('marker.thickness', 5).toDouble(),
      holdMs: s
          .getInt('marker.hold', 2500)
          .clamp(MarkerTiming.minHoldMs, MarkerTiming.maxHoldMs),
      autoExit: s.getBool('marker.autoExit', true),
      exitDelayMs: s.getInt('marker.exitDelay', 900).clamp(0, 5000),
      mode:
          MarkMode.values[s
              .getInt('marker.mode', 0)
              .clamp(0, MarkMode.values.length - 1)],
      corner: s.getInt('marker.corner', 2).clamp(0, 3),
      armShake: s.getBool('marker.armShake', false),
      autoZoom: s.getBool('marker.autoZoom', true),
      autoNumber: s.getBool('marker.autoNumber', true),
      zoomScale: (s.getInt('marker.zoomScale', 170) / 100).clamp(1.2, 4.0),
      zoomRampMs: s.getInt('marker.zoomRamp', 350).clamp(100, 2000),
      zoomHoldMs: s.getInt('marker.zoomHold', 0).clamp(0, 5000),
    );
  }

  Future<void> update(MarkerSettings v) async {
    state = v;
    final s = ref.read(settingsStoreProvider);
    await s.setInt('marker.tool', v.tool.index);
    await s.setInt('marker.color', v.colorIndex);
    await s.setInt('marker.thickness', v.thickness.round());
    await s.setInt('marker.hold', v.holdMs);
    await s.setBool('marker.autoExit', v.autoExit);
    await s.setInt('marker.exitDelay', v.exitDelayMs);
    await s.setInt('marker.mode', v.mode.index);
    await s.setInt('marker.corner', v.corner);
    await s.setBool('marker.armShake', v.armShake);
    await s.setBool('marker.autoZoom', v.autoZoom);
    await s.setBool('marker.autoNumber', v.autoNumber);
    await s.setInt('marker.zoomScale', (v.zoomScale * 100).round());
    await s.setInt('marker.zoomRamp', v.zoomRampMs);
    await s.setInt('marker.zoomHold', v.zoomHoldMs);
  }
}

final markerSettingsProvider =
    NotifierProvider<MarkerSettingsNotifier, MarkerSettings>(
      MarkerSettingsNotifier.new,
    );
