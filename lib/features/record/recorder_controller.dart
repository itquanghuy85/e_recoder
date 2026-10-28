import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/native_recorder.dart';
import '../../core/permissions_gateway.dart';
import '../editor/auto_director.dart';
import '../editor/edit_project.dart';
import '../editor/project_store.dart';
import '../library/media_repository.dart';
import '../marker/marker_settings.dart';
import 'rec_settings.dart';

final nativeRecorderProvider = Provider<NativeRecorder>(
  (ref) => NativeRecorder(),
);

enum StartResult { ok, declined, needsOverlay, micDenied, lowStorage, error }

/// A transient notice the screen shows once (snackbar), then clears.
sealed class RecNotice {
  const RecNotice();
}

class SavedNotice extends RecNotice {
  const SavedNotice(this.name, this.uri);
  final String name;
  final String uri;
}

class ErrorNotice extends RecNotice {
  const ErrorNotice(this.code);
  final String code;
}

class RecorderState {
  const RecorderState({
    this.phase = RecPhase.idle,
    this.elapsedMs = 0,
    this.notice,
  });
  final RecPhase phase;
  final int elapsedMs;
  final RecNotice? notice;

  bool get busy => phase != RecPhase.idle;

  RecorderState copyWith({
    RecPhase? phase,
    int? elapsedMs,
    RecNotice? notice,
    bool clearNotice = false,
  }) => RecorderState(
    phase: phase ?? this.phase,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

class RecorderController extends Notifier<RecorderState> {
  static const _minFreeBytes = 200 * 1024 * 1024;
  StreamSubscription<RecEvent>? _sub;

  NativeRecorder get _native => ref.read(nativeRecorderProvider);

  @override
  RecorderState build() {
    _sub = _native.events.listen(_onEvent);
    ref.onDispose(() => _sub?.cancel());
    return const RecorderState();
  }

  void _onEvent(RecEvent e) {
    switch (e) {
      case RecStateEvent():
        state = state.copyWith(phase: e.phase, elapsedMs: e.elapsedMs);
      case RecSavedEvent():
        state = state.copyWith(notice: SavedNotice(e.name, e.uri));
        ref.invalidate(mediaListProvider);
        if (e.marks.isNotEmpty) unawaited(_saveDraft(e));
      case RecErrorEvent():
        state = state.copyWith(notice: ErrorNotice(e.code));
      case ExportProgressEvent() || ExportDoneEvent() || ExportErrorEvent():
        break; // handled by the editor
    }
  }

  /// Clean mode: the markers placed while recording become an edit project, with the optional
  /// automatic zoom / step numbering, ready when the user opens the video in the editor.
  Future<void> _saveDraft(RecSavedEvent e) async {
    try {
      final mk = ref.read(markerSettingsProvider);
      final base = EditProject.fresh(
        sourceUri: e.uri,
        name: e.name,
        durationMs: e.durationMs,
        frameW: e.width,
        frameH: e.height,
      );
      final draft = AutoDirector.direct(
        AutoDirector.draft(base, e.marks),
        DirectorOptions(
          zoom: mk.autoZoom,
          number: mk.autoNumber,
          idle: false,
          zoomScale: mk.zoomScale,
          zoomRampMs: mk.zoomRampMs,
          zoomHoldMs: mk.zoomHoldMs,
        ),
      );
      await ref.read(projectStoreProvider).save(draft);
    } catch (_) {
      // A failed draft only means the user places the markers by hand in the editor.
    }
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);

  Future<StartResult> start() async {
    if (state.busy) return StartResult.error;
    final s = ref.read(recSettingsProvider);

    final free = await _native.freeSpace();
    if (free >= 0 && free < _minFreeBytes) return StartResult.lowStorage;

    if (s.mic || s.system) {
      final granted = await ref.read(permissionsGatewayProvider).requestMic();
      if (!granted) return StartResult.micDenied;
    }
    // Notification permission is optional: without it the foreground service still runs.
    await ref.read(permissionsGatewayProvider).requestNotifications();

    var floatingBar = s.floatingBar;
    var countdown = s.countdown;
    if ((floatingBar || countdown > 0) && !await _native.canOverlay()) {
      await _native.requestOverlay();
      return StartResult.needsOverlay;
    }

    final d = await _native.displayInfo();
    final plan = s.plan(d.width, d.height);
    final aligned = await _native.alignedSize(plan.width, plan.height);
    final mk = ref.read(markerSettingsProvider);
    final ok = await _native.start(
      StartRequest(
        width: aligned.width,
        height: aligned.height,
        dpi: d.dpi,
        fps: s.fps,
        bitrate: plan.bitrate,
        mic: s.mic,
        system: s.system,
        countdown: countdown,
        floatingBar: floatingBar,
        markerHoldMs: mk.holdMs,
        markerAutoExit: mk.autoExit,
        markerExitDelayMs: mk.exitDelayMs,
        markerColor: mk.color,
        markerThickness: mk.thickness,
        markerTool: mk.tool.wire,
        markMode: mk.mode.name,
        markCorner: mk.corner,
        armShake: mk.armShake,
      ),
    );
    return ok ? StartResult.ok : StartResult.declined;
  }

  Future<void> pause() => _native.pause();
  Future<void> resume() => _native.resume();
  Future<void> stop() => _native.stop();
}

final recorderProvider = NotifierProvider<RecorderController, RecorderState>(
  RecorderController.new,
);
