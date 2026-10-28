import 'dart:async';

import 'package:flutter/services.dart';

import '../features/marker/marker_spec.dart';

enum RecPhase { idle, countdown, recording, paused, saving }

RecPhase _phaseOf(String? s) => switch (s) {
  'countdown' => RecPhase.countdown,
  'recording' => RecPhase.recording,
  'paused' => RecPhase.paused,
  'saving' => RecPhase.saving,
  _ => RecPhase.idle,
};

/// One event from the native recorder service.
sealed class RecEvent {}

class RecStateEvent extends RecEvent {
  RecStateEvent(this.phase, this.elapsedMs);
  final RecPhase phase;
  final int elapsedMs;
}

/// A marker placed in "clean" mode while recording: nothing was drawn, so the editor draws it.
class RecMark {
  const RecMark({required this.tMs, required this.holdMs, required this.spec});
  final int tMs;
  final int holdMs;
  final MarkerSpec spec;
}

class RecSavedEvent extends RecEvent {
  RecSavedEvent(
    this.uri,
    this.name,
    this.durationMs,
    this.size, {
    this.width = 0,
    this.height = 0,
    this.marks = const [],
  });
  final String uri;
  final String name;
  final int durationMs;
  final int size;
  final int width;
  final int height;
  final List<RecMark> marks;
}

class RecErrorEvent extends RecEvent {
  RecErrorEvent(this.code, this.message);
  final String code;
  final String message;
}

class ExportProgressEvent extends RecEvent {
  ExportProgressEvent(this.value);

  /// 0..1
  final double value;
}

class ExportDoneEvent extends RecEvent {
  ExportDoneEvent(
    this.uri,
    this.name,
    this.durationMs,
    this.size, {
    this.mime = 'video/mp4',
  });
  final String mime;
  bool get isGif => mime == 'image/gif';
  final String uri;
  final String name;
  final int durationMs;
  final int size;
}

class ExportErrorEvent extends RecEvent {
  ExportErrorEvent(this.code, this.message);
  final String code;
  final String message;
}

class MediaEntry {
  const MediaEntry({
    required this.uri,
    required this.name,
    required this.durationMs,
    required this.size,
    required this.width,
    required this.height,
    required this.dateAdded,
  });

  final String uri;
  final String name;
  final int durationMs;
  final int size;
  final int width;
  final int height;
  final DateTime dateAdded;

  factory MediaEntry.fromMap(Map<dynamic, dynamic> m) => MediaEntry(
    uri: m['uri'] as String,
    name: m['name'] as String,
    durationMs: (m['durationMs'] as num).toInt(),
    size: (m['size'] as num).toInt(),
    width: (m['width'] as num).toInt(),
    height: (m['height'] as num).toInt(),
    dateAdded: DateTime.fromMillisecondsSinceEpoch(
      (m['dateAdded'] as num).toInt() * 1000,
    ),
  );
}

class StartRequest {
  const StartRequest({
    required this.width,
    required this.height,
    required this.dpi,
    required this.fps,
    required this.bitrate,
    required this.mic,
    required this.system,
    required this.countdown,
    required this.floatingBar,
    this.markerHoldMs = 2500,
    this.markerAutoExit = true,
    this.markerExitDelayMs = 900,
    this.markerColor = 0xFFFF3B30,
    this.markerThickness = 5,
    this.markerTool = 'finger',
    this.markMode = 'dot',
    this.markCorner = 2,
    this.armShake = false,
  });

  final String markMode;
  final int markCorner;
  final bool armShake;

  final int markerHoldMs;
  final bool markerAutoExit;
  final int markerExitDelayMs;
  final int markerColor;
  final double markerThickness;
  final String markerTool;

  final int width;
  final int height;
  final int dpi;
  final int fps;
  final int bitrate;
  final bool mic;
  final bool system;
  final int countdown;
  final bool floatingBar;

  Map<String, Object> toMap() => {
    'width': width,
    'height': height,
    'dpi': dpi,
    'fps': fps,
    'bitrate': bitrate,
    'mic': mic,
    'system': system,
    'countdown': countdown,
    'floatingBar': floatingBar,
    'markerHoldMs': markerHoldMs,
    'markerAutoExit': markerAutoExit,
    'markerExitDelayMs': markerExitDelayMs,
    'markerColor': markerColor,
    'markerThickness': markerThickness,
    'markerTool': markerTool,
    'markMode': markMode,
    'markCorner': markCorner,
    'armShake': armShake,
  };
}

/// Thin typed wrapper over the platform channels; the only place that knows channel names.
class NativeRecorder {
  NativeRecorder();

  static const _method = MethodChannel('escreenrecorder/recorder');
  static const _events = EventChannel('escreenrecorder/recorder/events');

  /// One shared subscription to the platform stream: EventChannel allows a single native sink,
  /// so every listener (recorder, editor) must hang off the same broadcast stream.
  late final Stream<RecEvent> events = _events
      .receiveBroadcastStream()
      .map<RecEvent>((e) {
        final m = e as Map<dynamic, dynamic>;
        switch (m['type']) {
          case 'saved':
            return RecSavedEvent(
              m['uri'] as String,
              m['name'] as String,
              (m['durationMs'] as num).toInt(),
              (m['size'] as num).toInt(),
              width: (m['width'] as num?)?.toInt() ?? 0,
              height: (m['height'] as num?)?.toInt() ?? 0,
              marks: [
                for (final raw in (m['marks'] as List<dynamic>? ?? const []))
                  RecMark(
                    tMs: ((raw as Map)['tMs'] as num).toInt(),
                    holdMs: (raw['holdMs'] as num).toInt(),
                    spec: MarkerSpec.fromMap(
                      Map<String, dynamic>.from(raw['spec'] as Map),
                    ),
                  ),
              ],
            );
          case 'error':
            return RecErrorEvent(
              m['code'] as String,
              (m['message'] as String?) ?? '',
            );
          case 'exportProgress':
            return ExportProgressEvent((m['value'] as num).toDouble());
          case 'exportDone':
            return ExportDoneEvent(
              m['uri'] as String,
              m['name'] as String,
              (m['durationMs'] as num).toInt(),
              (m['size'] as num).toInt(),
              mime: (m['mime'] as String?) ?? 'video/mp4',
            );
          case 'exportError':
            return ExportErrorEvent(
              m['code'] as String,
              (m['message'] as String?) ?? '',
            );
          default:
            return RecStateEvent(
              _phaseOf(m['phase'] as String?),
              (m['elapsedMs'] as num).toInt(),
            );
        }
      })
      .asBroadcastStream();

  /// Shows the system consent dialog and starts the service. False if the user declined.
  Future<bool> start(StartRequest r) async =>
      (await _method.invokeMethod<bool>('start', r.toMap())) ?? false;

  Future<void> stop() => _method.invokeMethod('stop');
  Future<void> pause() => _method.invokeMethod('pause');
  Future<void> resume() => _method.invokeMethod('resume');

  Future<bool> canOverlay() async =>
      (await _method.invokeMethod<bool>('canOverlay')) ?? false;
  Future<void> requestOverlay() => _method.invokeMethod('requestOverlay');

  Future<({int width, int height, int dpi})> displayInfo() async {
    final m = (await _method.invokeMapMethod<String, int>('displayInfo'))!;
    return (width: m['width']!, height: m['height']!, dpi: m['dpi']!);
  }

  Future<({int width, int height})> alignedSize(int width, int height) async {
    final m = (await _method.invokeMapMethod<String, int>('alignedSize', {
      'width': width,
      'height': height,
    }))!;
    return (width: m['width']!, height: m['height']!);
  }

  Future<int> freeSpace() async =>
      (await _method.invokeMethod<int>('freeSpace')) ?? -1;

  Future<List<MediaEntry>> listMedia() async {
    final raw =
        await _method.invokeListMethod<Map<dynamic, dynamic>>('listMedia') ??
        const [];
    return raw.map(MediaEntry.fromMap).toList();
  }

  Future<Uint8List?> thumbnail(String uri, {int w = 256, int h = 256}) =>
      _method.invokeMethod<Uint8List>('thumbnail', {
        'uri': uri,
        'w': w,
        'h': h,
      });

  /// Returns "ok", "needs_permission" or "error".
  Future<String> rename(String uri, String name) async =>
      (await _method.invokeMethod<String>('rename', {
        'uri': uri,
        'name': name,
      })) ??
      'error';

  Future<String> delete(String uri) async =>
      (await _method.invokeMethod<String>('delete', {'uri': uri})) ?? 'error';

  Future<void> share(String uri) => _method.invokeMethod('share', {'uri': uri});

  /// Stretches (source ms) where the screen does not change, for the editor's auto direct.
  Future<List<({int startMs, int endMs})>> analyzeIdle(
    String uri,
    int durationMs,
  ) async {
    final raw =
        await _method.invokeListMethod<List<dynamic>>('analyzeIdle', {
          'uri': uri,
          'durationMs': durationMs,
        }) ??
        const [];
    return [
      for (final r in raw)
        (startMs: (r[0] as num).toInt(), endMs: (r[1] as num).toInt()),
    ];
  }

  Future<void> startExport(Map<String, Object> job) =>
      _method.invokeMethod('export', job);

  Future<void> cancelExport() => _method.invokeMethod('cancelExport');

  /// Native rendering of caption and cover clips, so the editor shows exactly what is exported.
  Future<({Uint8List png, int w, int h})> renderText(
    Map<String, Object> clip,
    int frameW,
  ) async {
    final m = (await _method.invokeMapMethod<String, Object?>('renderText', {
      'clip': clip,
      'frameW': frameW,
    }))!;
    return (
      png: m['png'] as Uint8List,
      w: (m['w'] as num).toInt(),
      h: (m['h'] as num).toInt(),
    );
  }

  Future<({Uint8List png, int w, int h})> renderCover(
    Map<String, Object> clip,
    int frameW,
    int frameH,
  ) async {
    final m = (await _method.invokeMapMethod<String, Object?>('renderCover', {
      'clip': clip,
      'frameW': frameW,
      'frameH': frameH,
    }))!;
    return (
      png: m['png'] as Uint8List,
      w: (m['w'] as num).toInt(),
      h: (m['h'] as num).toInt(),
    );
  }

  /// Transparent PNG of one marker body, sized to its bounds; the anchor is the image centre.
  /// [half] is the half-size of the bitmap in frame pixels (frame = [frameW] x [frameH]).
  Future<({Uint8List png, double half})> renderMarker(
    MarkerSpec spec,
    int frameW,
    int frameH, {
    int phaseMs = 0,
  }) async {
    final m = (await _method.invokeMapMethod<String, Object?>('renderMarker', {
      'spec': spec.toMap(),
      'frameW': frameW,
      'frameH': frameH,
      'phaseMs': phaseMs,
    }))!;
    return (png: m['png'] as Uint8List, half: (m['half'] as num).toDouble());
  }

  /// A shape / callout bubble drawn by the native renderer (the same one the exporter uses).
  Future<({Uint8List png, int w, int h})> renderShape(
    Map<String, Object> clip,
    int frameW,
    int frameH,
  ) async {
    final m = (await _method.invokeMapMethod<String, Object?>('renderShape', {
      'clip': clip,
      'frameW': frameW,
      'frameH': frameH,
    }))!;
    return (
      png: m['png'] as Uint8List,
      w: (m['w'] as num).toInt(),
      h: (m['h'] as num).toInt(),
    );
  }

  /// Opens the system picker ('audio', 'image', 'video' or 'visual' = image or video). The file is
  /// copied into the app. Null when the user cancels.
  Future<PickedMedia?> pickMedia(String kind) async {
    final m = await _method.invokeMapMethod<String, Object?>('pickMedia', {
      'kind': kind,
    });
    return m == null ? null : PickedMedia.fromMap(m);
  }

  /// Opens the system picker for one video and returns it where it is (not copied, the gallery is
  /// not scanned). Null when the user cancels.
  Future<MediaEntry?> pickVideoToEdit() async {
    final m = await _method.invokeMapMethod<String, Object?>('pickVideoToEdit');
    if (m == null) return null;
    return MediaEntry.fromMap({...m, 'dateAdded': DateTime.now().millisecondsSinceEpoch ~/ 1000});
  }

  Future<PickedMedia> mediaInfo(String path) async {
    final m = (await _method.invokeMapMethod<String, Object?>('mediaInfo', {
      'path': path,
    }))!;
    return PickedMedia.fromMap({
      ...m,
      'path': path,
      'name': path.split('/').last,
    });
  }

  /// Starts recording a voice-over; returns the file being written.
  Future<String> startVoice() async =>
      (await _method.invokeMethod<String>('startVoice'))!;

  /// Stops the voice-over: its file and length, or null when nothing usable was recorded.
  Future<({String path, int durationMs})?> stopVoice() async {
    final m = await _method.invokeMapMethod<String, Object?>('stopVoice');
    if (m == null) return null;
    return (
      path: m['path'] as String,
      durationMs: (m['durationMs'] as num).toInt(),
    );
  }

  /// RMS loudness (dBFS) of part of a video's sound, null when it has none.
  Future<double?> loudness(String uri, int startMs, int endMs) async {
    final v = await _method.invokeMethod<num>('loudness', {
      'uri': uri,
      'startMs': startMs,
      'endMs': endMs,
    });
    return v?.toDouble();
  }

  /// Whether this phone can turn speech into text on the device, and for which languages
  /// ("installed", "downloadable" or "unsupported" per language tag such as "vi-VN").
  Future<({bool available, Map<String, String> languages})> sttSupport(
    List<String> langs,
  ) async {
    final m = (await _method.invokeMapMethod<String, Object?>('sttSupport', {
      'langs': langs,
    }))!;
    return (
      available: m['available'] as bool,
      languages: (m['languages'] as Map).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
    );
  }

  /// Starts turning the speech in [uri] (a video) into text, on the device, in language [lang].
  /// Follow it with [sttStatus]; stop it with [sttCancel].
  Future<void> sttStart(String uri, String lang) =>
      _method.invokeMethod<void>('sttStart', {'uri': uri, 'lang': lang});

  Future<SttStatus> sttStatus() async => SttStatus.fromMap(
    (await _method.invokeMapMethod<String, Object?>('sttStatus'))!,
  );

  Future<void> sttCancel() => _method.invokeMethod<void>('sttCancel');

  /// Asks Android to download the on-device language pack of [lang] (done by the system).
  Future<void> sttDownload(String lang) =>
      _method.invokeMethod<void>('sttDownload', {'lang': lang});

  /// Applies a voice effect and/or noise reduction to a voice file once and returns the new file
  /// (an m4a of the same length). [fx]: none|deep|high|chipmunk|robot|echo|reverb;
  /// [denoise]: off|light|strong. Asking again for the same combination returns the same file.
  Future<String> processVoice(String path, String fx, String denoise) async =>
      (await _method.invokeMethod<String>('processVoice', {
        'path': path,
        'fx': fx,
        'denoise': denoise,
      }))!;

  /// Peak level (0..1) of every [bucketMs] slice of a video's sound, null when it has none.
  Future<List<double>?> waveform(
    String uri,
    int durationMs,
    int bucketMs,
  ) async {
    final v = await _method.invokeListMethod<num>('waveform', {
      'uri': uri,
      'durationMs': durationMs,
      'bucketMs': bucketMs,
    });
    return v?.map((e) => e.toDouble()).toList();
  }

  /// Saves PNG bytes into Pictures/E Screen Recorder.
  Future<ExportDoneEvent?> saveImage(Uint8List png, String prefix) async {
    final m = await _method.invokeMapMethod<String, Object?>('saveImage', {
      'png': png,
      'prefix': prefix,
    });
    if (m == null) return null;
    return ExportDoneEvent(
      m['uri'] as String,
      m['name'] as String,
      0,
      (m['size'] as num).toInt(),
      mime: 'image/png',
    );
  }
}

/// A file brought in from the phone: music, a picture or a small video (already copied into the app).
class PickedMedia {
  const PickedMedia({
    required this.path,
    required this.name,
    required this.kind,
    required this.durationMs,
    required this.width,
    required this.height,
  });

  final String path;
  final String name;

  /// 'audio', 'video' or 'image'.
  final String kind;
  final int durationMs;
  final int width;
  final int height;

  bool get isVideo => kind == 'video';
  bool get isImage => kind == 'image';
  bool get isAudio => kind == 'audio';

  factory PickedMedia.fromMap(Map<String, Object?> m) => PickedMedia(
    path: m['path'] as String,
    name: (m['name'] as String?) ?? '',
    kind: (m['kind'] as String?) ?? 'audio',
    durationMs: ((m['durationMs'] as num?) ?? 0).toInt(),
    width: ((m['width'] as num?) ?? 0).toInt(),
    height: ((m['height'] as num?) ?? 0).toInt(),
  );
}

/// One recognised phrase: [text] was said between [startMs] and [endMs] of the video.
class SttPiece {
  const SttPiece(this.startMs, this.endMs, this.text);
  final int startMs;
  final int endMs;
  final String text;
}

/// Where the speech-to-text job is. [state]: idle, preparing, running, done, error, cancelled.
/// [error] when it failed: no_audio, no_speech, or a system message.
class SttStatus {
  const SttStatus({
    required this.state,
    required this.done,
    required this.total,
    required this.error,
    required this.pieces,
  });

  final String state;
  final int done;
  final int total;
  final String error;
  final List<SttPiece> pieces;

  bool get finished =>
      state == 'done' || state == 'error' || state == 'cancelled';

  factory SttStatus.fromMap(Map<String, Object?> m) => SttStatus(
    state: m['state'] as String,
    done: (m['done'] as num).toInt(),
    total: (m['total'] as num).toInt(),
    error: m['error'] as String? ?? '',
    pieces: [
      for (final p in (m['pieces'] as List? ?? const []))
        SttPiece(
          ((p as Map)['startMs'] as num).toInt(),
          (p['endMs'] as num).toInt(),
          p['text'] as String,
        ),
    ],
  );
}
