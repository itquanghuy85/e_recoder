import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../../core/diag.dart';
import '../../core/native_recorder.dart';
import '../../core/permissions_gateway.dart';
import '../editor/auto_director.dart';
import '../editor/edit_project.dart';
import '../editor/project_store.dart';
import '../editor/touch_log.dart' show TouchClassifier;
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
    // An event that cannot be read must not end the subscription silently (that would lose every
    // later "saved"): log it and keep listening.
    _sub = _native.events.listen(
      _onEvent,
      onError: (Object e) => diag('event error: $e'),
    );
    ref.onDispose(() => _sub?.cancel());
    // A build cut short by the app being killed is finished now, in the background. A recording
    // saved while Flutter was not listening is picked up too, so the library can never stay stale.
    draftReady = Future<void>.microtask(() async {
      await resumeDraft();
      await syncSaved();
    });
    return const RecorderState();
  }

  /// The last recording saved while this side was not listening (background stop, activity rebuilt).
  /// Announced exactly like a live one; asking twice cannot open the same video twice.
  Future<void> syncSaved() async {
    try {
      final e = await _native.takeLastSaved();
      if (e != null) _onSaved(e);
    } catch (_) {
      // A missing replay only means the library waits for the next refresh.
    }
  }

  void _onEvent(RecEvent e) {
    switch (e) {
      case RecStateEvent():
        state = state.copyWith(phase: e.phase, elapsedMs: e.elapsedMs);
      case RecSavedEvent():
        _onSaved(e);
      case RecErrorEvent():
        state = state.copyWith(notice: ErrorNotice(e.code));
      case ExportProgressEvent() || ExportDoneEvent() || ExportErrorEvent():
        break; // handled by the editor
    }
  }

  /// The last video already announced: a replay coming from both the event stream and
  /// [takeLastSaved] must not open the result screen or build the same draft twice.
  String? _lastSavedUri;

  void _onSaved(RecSavedEvent e) {
    diag(
      'saved uri=${e.uri} indexed=${e.indexed} marks=${e.marks.length} '
      'touches=${e.touches.length} dup=${e.uri == _lastSavedUri}',
    );
    if (e.uri == _lastSavedUri) return;
    _lastSavedUri = e.uri;
    state = state.copyWith(notice: SavedNotice(e.name, e.uri));
    ref.invalidate(mediaListProvider);
    final mk = ref.read(markerSettingsProvider);
    final autoClean =
        mk.mode == MarkMode.clean && mk.touchSource == TouchSource.auto;
    if (e.marks.isNotEmpty || e.touches.isNotEmpty || autoClean) {
      draftReady = _track(e.uri, _saveDraft(e));
    }
  }

  /// The video whose automatic edit is being built right now (null when none). The editor waits for
  /// it instead of opening an empty draft that the build would then overwrite.
  String? draftBuildingFor;

  Future<void> _track(String uri, Future<void> job) async {
    draftBuildingFor = uri;
    try {
      await job;
    } finally {
      if (draftBuildingFor == uri) draftBuildingFor = null;
    }
  }

  /// Done when the automatic edit of the last recording is saved (already done when there is none).
  /// The result screen waits for it before exporting.
  Future<void> draftReady = Future.value();

  /// Touches this close to the end of a recording are the press on stop.
  static const stopTapWindowMs = 1200;

  /// Clean mode: the markers placed while recording become an edit project, with the optional
  /// automatic zoom / step numbering, ready when the user opens the video in the editor.
  Future<void> _saveDraft(RecSavedEvent e) async {
    try {
      final mk = ref.read(markerSettingsProvider);
      final autoClean =
          mk.mode == MarkMode.clean && mk.touchSource == TouchSource.auto;
      // The press on the app's own stop button is heard too: it is not a step of what was recorded.
      final heard = [
        for (final t in e.touches)
          if (t.tMs <= e.durationMs - stopTapWindowMs) t.tMs,
      ];
      final base = EditProject.fresh(
        sourceUri: e.uri,
        name: e.name,
        durationMs: e.durationMs,
        frameW: e.width,
        frameH: e.height,
      );
      var draft = AutoDirector.direct(
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
      // The editor tells "no touches heard" apart from a project that never listened.
      if (autoClean) draft = draft.copyWith(autoHeard: heard.length);
      await ref.read(projectStoreProvider).save(draft);
      // Touches heard while recording: find where they were and build the rest of the edit from
      // them (captions + freezes, and marks + zoom where the place is known), right now, so the
      // video opens in the editor already edited. A failure leaves the draft as it is.
      await _buildFromTouches(draft, e.uri, heard);
    } catch (_) {
      // A failed draft only means the user places the markers by hand in the editor.
    }
  }

  static const _pendingKey = 'draft.pending';

  /// The touches are only in memory until the edit is built from them, and finding where they were
  /// (looking at the frames) takes a while on a long recording. So the job is written down first and
  /// crossed out when done: if the app is killed in between, the next launch finishes it ([resumeDraft]).
  Future<void> _buildFromTouches(
    EditProject draft,
    String uri,
    List<int> heard, {
    int tries = 0,
  }) async {
    if (heard.isEmpty) return;
    final mk = ref.read(markerSettingsProvider);
    final store = ref.read(settingsStoreProvider);
    await store.setString(
      _pendingKey,
      jsonEncode({'uri': uri, 'touches': heard, 'tries': tries}),
    );
    try {
      {
        final placed = await _native.locateTouches(uri, heard);
        final events = TouchClassifier.classify(placed);
        diag(
      'autoMarks heard=${heard.length} placed='
          '${placed.where((p) => p.x != null).length} events=${events.length}',
        );
        if (events.isNotEmpty) {
          final vi = PlatformDispatcher.instance.locale.languageCode == 'vi';
          final options = DirectorOptions(
            zoom: mk.autoZoom,
            number: mk.autoNumber,
            idle: false,
            zoomScale: mk.zoomScale,
            zoomRampMs: mk.zoomRampMs,
            zoomHoldMs: mk.zoomHoldMs,
            pauseMs: mk.pauseMs,
            pauseZoom: mk.pauseZoom,
            inputMode: mk.inputMode,
            markerType: mk.autoMarker,
            markerColor: Color(mk.color),
            markerThickness: mk.thickness,
            markerHoldMs: mk.holdMs,
            typingLabel: vi ? 'Đang nhập…' : 'Typing…',
            typedLabel: vi ? 'Đã nhập' : 'Typed',
          );
          var auto = AutoDirector.fromTouches(
            draft,
            events,
            options,
            stepPrefix: vi ? 'Bước ' : 'Step ',
          );
          // Zoom into the touches whose place is known (fromTouches adds the marks, the freezes and the typing).
          if (mk.autoZoom) auto = AutoDirector.autoZoom(auto, options);
          await ref.read(projectStoreProvider).save(auto);
        }
      }
    } finally {
      await store.remove(_pendingKey);
    }
  }

  /// Finishes the automatic edit of a recording whose build was cut short (the app was killed while it
  /// ran). Done at launch; a job whose project or touches are gone is just dropped.
  Future<void> resumeDraft() async {
    final store = ref.read(settingsStoreProvider);
    final raw = store.getString(_pendingKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final uri = j['uri'] as String;
      final touches = [
        for (final t in j['touches'] as List) (t as num).toInt(),
      ];
      final tries = (j['tries'] as num?)?.toInt() ?? 0;
      final draft = await ref.read(projectStoreProvider).load(uri);
      // Twice is enough: a video that keeps killing the app while it is looked at is left as it is.
      if (draft == null || tries >= 2) {
        await store.remove(_pendingKey);
        return;
      }
      await _buildFromTouches(draft, uri, touches, tries: tries + 1);
    } catch (_) {
      await store.remove(_pendingKey);
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
    final mk = ref.read(markerSettingsProvider);
    // A clean recording that listens to every touch needs the overlay window too. Without the
    // permission the watcher cannot be added and the recording would end with no marks at all.
    final watchesTouches =
        mk.mode == MarkMode.clean && mk.touchSource == TouchSource.auto;
    if ((floatingBar || countdown > 0 || watchesTouches) &&
        !await _native.canOverlay()) {
      await _native.requestOverlay();
      return StartResult.needsOverlay;
    }

    final d = await _native.displayInfo();
    final plan = s.plan(d.width, d.height);
    final aligned = await _native.alignedSize(plan.width, plan.height);
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
        watchTouches:
            mk.mode == MarkMode.clean && mk.touchSource == TouchSource.auto,
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
