import 'dart:async';
import 'dart:typed_data';

import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/core/permissions_gateway.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/features/record/recorder_controller.dart';
import 'package:e_screen_recorder/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the platform layer so widget tests never touch channels.
class FakeRecorder implements NativeRecorder {
  FakeRecorder({List<MediaEntry>? media}) : media = media ?? [];

  final List<MediaEntry> media;
  final controller = StreamController<RecEvent>.broadcast();
  final calls = <String>[];
  StartRequest? lastRequest;
  bool overlayGranted = true;
  bool consent = true;

  @override
  Stream<RecEvent> get events => controller.stream;

  @override
  Future<bool> start(StartRequest r) async {
    calls.add('start');
    lastRequest = r;
    if (consent) controller.add(RecStateEvent(RecPhase.recording, 0));
    return consent;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    controller.add(RecStateEvent(RecPhase.idle, 0));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    controller.add(RecStateEvent(RecPhase.paused, 5000));
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    controller.add(RecStateEvent(RecPhase.recording, 5000));
  }

  @override
  Future<bool> canOverlay() async => overlayGranted;
  @override
  Future<void> requestOverlay() async => calls.add('requestOverlay');
  @override
  Future<({int width, int height, int dpi})> displayInfo() async =>
      (width: 1080, height: 2400, dpi: 440);
  @override
  Future<({int width, int height})> alignedSize(int width, int height) async =>
      (width: width, height: height);
  @override
  Future<int> freeSpace() async => 10 * 1024 * 1024 * 1024;
  @override
  Future<List<MediaEntry>> listMedia() async => media;
  @override
  Future<Uint8List?> thumbnail(String uri, {int w = 256, int h = 256}) async =>
      null;
  @override
  Future<String> rename(String uri, String name) async => 'ok';
  @override
  Future<String> delete(String uri) async => 'ok';
  @override
  Future<void> share(String uri) async => calls.add('share');

  Map<String, Object>? lastExportJob;

  @override
  Future<void> startExport(Map<String, Object> job) async {
    calls.add('startExport');
    lastExportJob = job;
  }

  @override
  Future<void> cancelExport() async => calls.add('cancelExport');

  @override
  Future<({Uint8List png, int w, int h})> renderText(
    Map<String, Object> clip,
    int frameW,
  ) async {
    calls.add('renderText');
    return (png: _png, w: 80, h: 30);
  }

  List<({int startMs, int endMs})> idleRanges = [];

  @override
  Future<List<({int startMs, int endMs})>> analyzeIdle(
    String uri,
    int durationMs,
  ) async {
    calls.add('analyzeIdle');
    return idleRanges;
  }

  @override
  Future<({Uint8List png, int w, int h})> renderCover(
    Map<String, Object> clip,
    int frameW,
    int frameH,
  ) async {
    calls.add('renderCover');
    return (png: _png, w: 80, h: 30);
  }

  PickedMedia? nextPick;
  ({String path, int durationMs})? nextVoice;
  double? nextLoudness;
  Uint8List? lastSavedImage;

  @override
  Future<({Uint8List png, int w, int h})> renderShape(
    Map<String, Object> clip,
    int frameW,
    int frameH,
  ) async {
    calls.add('renderShape');
    return (png: _png, w: 100, h: 60);
  }

  @override
  Future<PickedMedia?> pickMedia(String kind) async {
    calls.add('pickMedia:$kind');
    final p = nextPick;
    nextPick = null;
    return p;
  }

  @override
  Future<PickedMedia> mediaInfo(String path) async => PickedMedia(
    path: path,
    name: path.split('/').last,
    kind: 'audio',
    durationMs: 3000,
    width: 0,
    height: 0,
  );

  @override
  Future<String> startVoice() async {
    calls.add('startVoice');
    return '/voice.m4a';
  }

  @override
  Future<({String path, int durationMs})?> stopVoice() async {
    calls.add('stopVoice');
    return nextVoice;
  }

  @override
  Future<String> processVoice(String path, String fx, String denoise) async {
    calls.add('processVoice:$fx:$denoise');
    if (voiceFxFails) throw StateError('boom');
    return '$path.$fx.$denoise.m4a';
  }

  bool voiceFxFails = false;

  @override
  Future<List<double>?> waveform(
    String uri,
    int durationMs,
    int bucketMs,
  ) async => null;

  @override
  Future<double?> loudness(String uri, int startMs, int endMs) async {
    calls.add('loudness');
    return nextLoudness;
  }

  @override
  Future<ExportDoneEvent?> saveImage(Uint8List png, String prefix) async {
    calls.add('saveImage');
    lastSavedImage = png;
    return ExportDoneEvent(
      'content://img/1',
      'frame.png',
      0,
      png.length,
      mime: 'image/png',
    );
  }

  /// 1x1 transparent PNG.
  static final _png = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52, //
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<({Uint8List png, double half})> renderMarker(
    MarkerSpec spec,
    int frameW,
    int frameH, {
    int phaseMs = 0,
  }) async {
    calls.add('renderMarker:${spec.type.name}');
    return (png: _png, half: 40.0);
  }
}

class FakePermissions implements PermissionsGateway {
  bool mic = true;
  bool notif = true;
  final calls = <String>[];

  @override
  Future<bool> micGranted() async => mic;
  @override
  Future<bool> requestMic() async {
    calls.add('requestMic');
    return mic;
  }

  @override
  Future<bool> notificationsGranted() async => notif;
  @override
  Future<bool> requestNotifications() async {
    calls.add('requestNotifications');
    return notif;
  }

  @override
  Future<void> openSettings() async => calls.add('openSettings');
}

Future<({Widget app, FakeRecorder fake})> buildTestApp({
  List<MediaEntry>? media,
  bool onboarded = true,
  FakePermissions? permissions,
  Locale locale = const Locale('vi'),
}) async {
  SharedPreferences.setMockInitialValues({'onboarded': onboarded});
  final store = await SettingsStore.load();
  final fake = FakeRecorder(media: media);
  return (
    fake: fake,
    app: ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        localeProvider.overrideWithValue(locale),
        nativeRecorderProvider.overrideWithValue(fake),
        permissionsGatewayProvider.overrideWithValue(
          permissions ?? FakePermissions(),
        ),
      ],
      child: const EScreenRecorderApp(),
    ),
  );
}
