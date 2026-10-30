import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import '../../core/native_recorder.dart';
import '../marker/marker_spec.dart';
import '../marker/marker_timing.dart';
import 'auto_director.dart';
import 'caption_models.dart';
import 'edit_project.dart';
import 'touch_log.dart';
import 'captions_from_speech.dart';
import 'srt.dart';
import 'export_presets.dart';
import 'project_template.dart';
import 'project_store.dart';

export 'export_presets.dart' show ExportQuality;

enum ExportPhase { idle, running, done, error }

class ExportState {
  const ExportState({
    this.phase = ExportPhase.idle,
    this.progress = 0,
    this.result,
    this.errorCode,
    this.errorMessage,
  });
  final ExportPhase phase;
  final double progress;
  final ExportDoneEvent? result;
  final String? errorCode;

  /// What the exporter said went wrong (shown small under the error, for support).
  final String? errorMessage;
}

class RenderedImage {
  const RenderedImage(this.png, this.w, this.h);
  final Uint8List png;

  /// Size in frame pixels. For markers (square, anchor in the centre) w == h == 2 * half.
  final double w;
  final double h;
}

/// Editing state for one video: the project, selection, playhead, undo/redo, autosave, export.
/// Platform calls go through [NativeRecorder] so the whole thing is testable with a fake.
class EditorController extends ChangeNotifier {
  EditorController({
    required EditProject project,
    required this.native,
    required this.store,
    this.autosaveDelay = const Duration(milliseconds: 500),
  }) {
    _project = project;
    _sub = native.events.listen(_onEvent);
  }

  final NativeRecorder native;
  final ProjectStore store;
  final Duration autosaveDelay;
  late final StreamSubscription<RecEvent> _sub;

  late EditProject _project;
  EditProject get project => _project;

  /// Playhead on the OUTPUT timeline (the edited video), in ms.
  int _outMs = 0;
  int get outMs => _outMs;
  int get sourceMs => _project.outToSource(_outMs);

  bool playing = false;
  String? selectedId;
  int selectedSegment = 0;

  final List<EditProject> _undo = [];
  final List<EditProject> _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  ExportState exportState = const ExportState();

  // ---- waveform -------------------------------------------------------------------------------

  /// Slice length of [waveform].
  static const waveBucketMs = 50;

  /// Peak level (0..1) of the source sound per [waveBucketMs], for the timeline. Null until it has
  /// been read, and for a recording without sound.
  List<double>? waveform;

  /// Reads the waveform in the background; the timeline redraws when it arrives.
  Future<void> loadWaveform() async {
    try {
      final w = await native.waveform(
        _project.sourceUri,
        _project.durationMs,
        waveBucketMs,
      );
      if (_disposed) return;
      waveform = w;
      notifyListeners();
    } catch (_) {
      // No waveform is not an error: the timeline just stays plain.
    }
  }

  // ---- auto direct ----------------------------------------------------------------------------

  DirectorOptions directorOptions = const DirectorOptions();
  bool directing = false;

  /// What the project holds after the last auto-direct pass (zooms, numbered steps, sped-up stretches).
  ({int zooms, int steps, int idle})? lastDirect;

  void setDirectorOptions(DirectorOptions o) {
    directorOptions = o;
    notifyListeners();
  }

  /// Zoom into markers, renumber steps and speed up still stretches, as one undoable step.
  Future<void> directAuto() async {
    if (directing) return;
    directing = true;
    notifyListeners();
    try {
      final before = _project;
      var ranges = <TimeRange>[];
      if (directorOptions.idle) {
        ranges = await native.analyzeIdle(before.sourceUri, before.durationMs);
      }
      if (_disposed) return;
      final next = AutoDirector.direct(
        _project,
        directorOptions,
        idleRanges: ranges,
      );
      // Totals in the project, not just what this pass added: the recording may already carry zooms.
      lastDirect = (
        zooms: next.zooms.length,
        steps: next.markers
            .where((m) => m.spec.type == MarkerType.number)
            .length,
        idle: next.segments.where((s) => s.speed > 1).length,
      );
      _apply(next);
    } finally {
      directing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// "dots" looks for Android's show-taps spots in the video; anything else only finds when the screen changed.
  String touchMode = 'changes';

  /// What the last "build from touches" found: touches, typing steps, and whether their places were known.
  ({int taps, int typing, bool placed})? lastTouches;

  /// Finds the touches in the video, sorts out typing, and draws marks, captions and freezes from them as
  /// one undoable step. Without a place for the touches only captions and freezes are made.
  Future<void> directFromTouches({
    required DirectorOptions options,
    required String stepPrefix,
  }) async {
    if (directing) return;
    directing = true;
    notifyListeners();
    try {
      final src = _project;
      var raw = await native.scanTouches(
        src.sourceUri,
        src.durationMs,
        mode: touchMode,
      );
      if (raw.isEmpty && touchMode == 'dots') {
        raw = await native.scanTouches(
          src.sourceUri,
          src.durationMs,
          mode: 'changes',
        );
      }
      if (_disposed) return;
      final events = TouchClassifier.classify(raw);
      lastTouches = (
        taps: events.where((e) => e.kind == TouchKind.tap).length,
        typing: events
            .where((e) => e.kind == TouchKind.input)
            .map((e) => e.group)
            .toSet()
            .length,
        placed: events.any((e) => e.hasPosition),
      );
      if (events.isEmpty) return;
      var base = _project;
      if (options.idle) {
        final ranges = await native.analyzeIdle(src.sourceUri, src.durationMs);
        if (_disposed) return;
        base = AutoDirector.speedUpIdle(base, ranges);
      }
      _apply(
        AutoDirector.fromTouches(
          base,
          events,
          options,
          stepPrefix: stepPrefix,
        ),
      );
    } finally {
      directing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Puts the playhead a moment before the first freeze made by the director, so playing shows it.
  void seekToFirstFreeze() {
    final starts = _project.segmentOutStarts;
    for (var i = 0; i < _project.segments.length; i++) {
      if (_project.segments[i].isStill) {
        seekOut((starts[i] - 1200).clamp(0, _project.outDurationMs));
        return;
      }
    }
  }

  Timer? _saveTimer;
  bool _disposed = false;

  // ---- playhead -------------------------------------------------------------------------------

  void seekOut(int ms) {
    _outMs = ms.clamp(0, _project.outDurationMs);
    _syncSegmentSelection();
    notifyListeners();
  }

  /// Called by [PlaybackDriver] with the output time while playing (no re-seek of the player).
  void setOutFromPlayer(int out) {
    _outMs = out.clamp(0, _project.outDurationMs);
    final i = _project.segmentAtOut(_outMs);
    if (i >= 0 && !multiSelect) selectedSegment = i;
    notifyListeners();
  }

  /// One video frame at 30 fps, for frame-accurate stepping.
  static const frameMs = 33;

  void stepFrame(int frames) => seekOut(_outMs + frames * frameMs);

  void _syncSegmentSelection() {
    final i = _project.segmentAtOut(_outMs);
    if (i >= 0 && !multiSelect) selectedSegment = i;
  }

  // ---- multi-selection of segments ------------------------------------------------------------

  bool multiSelect = false;
  final Set<int> multiSelected = {};

  void setMultiSelect(bool on) {
    multiSelect = on;
    multiSelected
      ..clear()
      ..addAll(on ? {selectedSegment} : const <int>{});
    notifyListeners();
  }

  /// Selected segments in sequence order (just the current one when not in multi-select).
  List<int> get activeSegments {
    if (!multiSelect || multiSelected.isEmpty) return [selectedSegment];
    return multiSelected.toList()..sort();
  }

  void toggleSegment(int i) {
    if (!multiSelect) {
      selectSegment(i);
      return;
    }
    if (!multiSelected.remove(i)) multiSelected.add(i);
    if (multiSelected.isEmpty) multiSelected.add(i);
    selectedSegment = i;
    selectedId = null;
    notifyListeners();
  }

  void setPlaying(bool v) {
    if (playing == v) return;
    playing = v;
    notifyListeners();
  }

  // ---- history --------------------------------------------------------------------------------

  void _apply(EditProject next, {bool record = true}) {
    if (identical(next, _project)) return;
    if (record) {
      _undo.add(_project);
      if (_undo.length > 60) _undo.removeAt(0);
      _redo.clear();
    }
    _project = next;
    _outMs = _outMs.clamp(0, _project.outDurationMs);
    if (selectedSegment >= _project.segments.length) {
      selectedSegment = _project.segments.length - 1;
    }
    _scheduleSave();
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_project);
    _project = _undo.removeLast();
    _outMs = _outMs.clamp(0, _project.outDurationMs);
    selectedSegment = selectedSegment.clamp(0, _project.segments.length - 1);
    if (selectedId != null && !_hasOverlay(selectedId!)) selectedId = null;
    _scheduleSave();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_project);
    _project = _redo.removeLast();
    _outMs = _outMs.clamp(0, _project.outDurationMs);
    selectedSegment = selectedSegment.clamp(0, _project.segments.length - 1);
    _scheduleSave();
    notifyListeners();
  }

  bool _hasOverlay(String id) =>
      _project.markers.any((e) => e.id == id) ||
      _project.texts.any((e) => e.id == id) ||
      _project.covers.any((e) => e.id == id) ||
      _project.zooms.any((e) => e.id == id) ||
      _project.images.any((e) => e.id == id) ||
      _project.shapes.any((e) => e.id == id) ||
      _project.pips.any((e) => e.id == id) ||
      _project.audioTracks.any((e) => e.id == id);

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, flush);
  }

  /// Writes the project now (also called when leaving the screen).
  Future<void> flush() async {
    _saveTimer?.cancel();
    await store.save(_project);
  }

  // ---- cutting --------------------------------------------------------------------------------

  /// Cuts the segment under the playhead in two (by output time, so a repeated segment is cut
  /// where the playhead really is).
  void split() {
    final next = _project.splitAtOut(_outMs);
    if (!identical(next, _project)) {
      _apply(next);
      selectedSegment = _project
          .segmentAtOut(_outMs)
          .clamp(0, _project.segments.length - 1);
      multiSelected.clear();
    }
  }

  /// Ripple delete of the selected segment(s): the rest moves up.
  void deleteSelectedSegment() {
    final idx = activeSegments.toSet();
    _apply(
      idx.length > 1
          ? _project.deleteSegments(idx)
          : _project.deleteSegment(idx.first),
    );
    multiSelected.clear();
    if (multiSelect) multiSelected.add(selectedSegment);
  }

  /// Delete but keep the time: the segment becomes a black gap of the same length.
  void blankSelectedSegment() {
    var next = _project;
    for (final i in activeSegments) {
      next = next.blankSegment(i);
    }
    _apply(next);
  }

  void duplicateSelectedSegment() {
    final idx = activeSegments;
    var next = _project;
    // Highest index first so earlier indexes stay valid.
    for (final i in idx.reversed) {
      next = next.duplicateSegment(i);
    }
    _apply(next);
    selectedSegment = idx.last + idx.length;
  }

  /// Inserts a freeze frame of the frame under the playhead after the current segment.
  void freezeAtPlayhead({int ms = 2000}) {
    final i = _project.segmentAtOut(_outMs);
    if (i < 0) return;
    final s = _project.segments[i];
    if (s.isStill) return;
    final t = sourceMs.clamp(0, _project.durationMs - 1);
    final start = _project.segmentOutStarts[i];
    final local = _outMs - start;
    var proj = _project;
    var pos = i + 1;
    if (local < EditProject.minSegmentMs) {
      pos = i; // at the very start: the still goes before the segment
    } else if (s.outLengthMs - local >= EditProject.minSegmentMs) {
      proj = proj.splitAtOut(_outMs); // in the middle: cut there first
    }
    _apply(proj.insertFreezeAt(pos, t, ms: ms));
    selectedSegment = pos;
  }

  void setFreezeMs(int ms) => _apply(_project.setFreezeMs(selectedSegment, ms));

  /// Drag-reorder.
  void moveSegmentTo(int from, int to) {
    final next = _project.moveSegmentTo(from, to);
    if (!identical(next, _project)) {
      _apply(next);
      selectedSegment = to;
      multiSelected.clear();
      if (multiSelect) multiSelected.add(to);
    }
  }

  /// Applies [op] to each selected segment as ONE undo step.
  void _eachActive(EditProject Function(EditProject p, int i) op) {
    var next = _project;
    for (final i in activeSegments) {
      next = op(next, i);
    }
    _apply(next);
  }

  /// Same as [_eachActive] but without an undo step (a slider drag is one step, see [beginGesture]).
  void _eachActiveLive(EditProject Function(EditProject p, int i) op) {
    var next = _project;
    for (final i in activeSegments) {
      next = op(next, i);
    }
    _apply(next, record: false);
  }

  void setSpeedLive(double speed) =>
      _eachActiveLive((p, i) => p.setSpeed(i, speed));

  void setSpeedRampLive(double from, double to) =>
      _eachActiveLive((p, i) => p.setSpeedRamp(i, from, to));

  void setFreezeMsLive(int ms) =>
      _apply(_project.setFreezeMs(selectedSegment, ms), record: false);

  void setTransitionLive(Transition t) =>
      _eachActiveLive((p, i) => p.setTransition(i, t));

  void setSegmentAudioLive({double? volume, int? fadeInMs, int? fadeOutMs}) =>
      _eachActiveLive(
        (p, i) => p.setAudio(
          i,
          volume: volume,
          fadeInMs: fadeInMs,
          fadeOutMs: fadeOutMs,
        ),
      );

  /// Longest clip that may be played backwards (the reversed copy is rendered to a temporary file).
  static const maxReverseMs = 30000;

  bool reverseAllowed(Segment s) => s.reverse || s.lengthMs <= maxReverseMs;

  void setSpeed(double speed) => _eachActive((p, i) => p.setSpeed(i, speed));

  void setMuteFast(bool on) => _apply(_project.copyWith(muteFast: on));

  void setSpeedRamp(double from, double to) =>
      _eachActive((p, i) => p.setSpeedRamp(i, from, to));

  void setReverse(bool on) => _eachActive(
    (p, i) => !on || reverseAllowed(p.segments[i]) ? p.setReverse(i, on) : p,
  );

  void setSegmentAudio({double? volume, int? fadeInMs, int? fadeOutMs}) =>
      _eachActive(
        (p, i) => p.setAudio(
          i,
          volume: volume,
          fadeInMs: fadeInMs,
          fadeOutMs: fadeOutMs,
        ),
      );

  /// Transition INTO the selected segment(s).
  void setTransition(Transition? t) =>
      _eachActive((p, i) => p.setTransition(i, t));

  void setAllTransitions(Transition? t) =>
      _apply(_project.setAllTransitions(t));

  void trimSelected({int? startMs, int? endMs}) => _apply(
    _project.trimSegment(selectedSegment, startMs: startMs, endMs: endMs),
  );

  /// Trim while a handle is being dragged: one undo step per drag (see [beginGesture]).
  void trimSegmentLive(int i, {int? startMs, int? endMs}) {
    selectedSegment = i;
    _apply(
      _project.trimSegment(i, startMs: startMs, endMs: endMs),
      record: false,
    );
  }

  void moveSelectedSegment(int delta) {
    final next = _project.moveSegment(selectedSegment, delta);
    if (!identical(next, _project)) {
      _apply(next);
      selectedSegment += delta;
    }
  }

  /// Drops every edit and goes back to the untouched source (still undoable).
  void resetProject() {
    final p = _project;
    selectedId = null;
    selectedSegment = 0;
    _outMs = 0;
    _apply(
      EditProject.fresh(
        sourceUri: p.sourceUri,
        name: p.name,
        durationMs: p.durationMs,
        frameW: p.frameW,
        frameH: p.frameH,
      ),
    );
  }

  void selectSegment(int i) {
    selectedSegment = i.clamp(0, _project.segments.length - 1);
    selectedId = null;
    notifyListeners();
  }

  void select(String? id) {
    selectedId = id;
    coverEditEnd = false;
    notifyListeners();
  }

  /// A region that moves has two rectangles; this says which one the panel and dragging edit.
  bool coverEditEnd = false;

  void setCoverEditEnd(bool v) {
    coverEditEnd = v;
    notifyListeners();
  }

  // ---- overlays -------------------------------------------------------------------------------

  int _idCounter = 0;
  String _newId(String p) =>
      '$p${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  /// Adds a marker so its TAKE lands on the playhead: the cue ring starts [cueMs] earlier,
  /// which is what lets the viewer see where the press is going to happen.
  void addMarker(
    MarkerType type, {
    required Color color,
    double thickness = 5,
  }) {
    final take = sourceMs;
    final cue = (take - MarkerTiming.cueMs).clamp(0, _project.durationMs);
    final spec = _defaultSpec(
      type,
      color,
      thickness,
    ).copyWith(number: type == MarkerType.number ? _project.nextStepNumber : 1);
    final item = MarkerItem(id: _newId('m'), spec: spec, cueStartMs: cue);
    _apply(_project.upsertMarker(item));
    selectedId = item.id;
    notifyListeners();
  }

  static MarkerSpec _defaultSpec(MarkerType t, Color color, double th) {
    switch (t) {
      case MarkerType.arrow:
        return MarkerSpec(
          type: t,
          color: color,
          thickness: th,
          x0: 0.72,
          y0: 0.62,
          x1: 0.52,
          y1: 0.48,
        );
      case MarkerType.circle:
        return MarkerSpec(
          type: t,
          color: color,
          thickness: th,
          x0: 0.3,
          y0: 0.44,
          x1: 0.7,
          y1: 0.56,
        );
      case MarkerType.rect:
        return MarkerSpec(
          type: t,
          color: color,
          thickness: th,
          x0: 0.3,
          y0: 0.44,
          x1: 0.7,
          y1: 0.56,
        );
      case MarkerType.pen:
        return MarkerSpec(
          type: t,
          color: color,
          thickness: th,
          points: const [
            0.3,
            0.55,
            0.38,
            0.57,
            0.46,
            0.55,
            0.54,
            0.57,
            0.62,
            0.55,
            0.7,
            0.57,
          ],
        );
      default:
        return MarkerSpec(
          type: t,
          color: color,
          thickness: th,
          x0: 0.5,
          y0: 0.5,
          x1: 0.5,
          y1: 0.5,
        );
    }
  }

  void updateMarker(MarkerItem m, {bool record = true}) =>
      _apply(_project.upsertMarker(m), record: record);

  void addText() {
    final s = sourceMs;
    final item = TextItem(
      id: _newId('t'),
      text: 'Văn bản',
      startMs: s,
      endMs: (s + 3000).clamp(0, _project.durationMs),
    );
    _apply(_project.upsertText(item));
    selectedId = item.id;
    notifyListeners();
  }

  /// Adds one caption per cue (bottom of the frame, boxed), as ONE undoable step. Cues are in
  /// source time and are clamped to the clip; returns how many were added.
  int importSubtitles(
    List<SubtitleCue> cues, {
    String idPrefix = 'sub',
    bool replaceSamePrefix = false,
  }) {
    var p = _project;
    if (replaceSamePrefix) {
      p = p.copyWith(
        texts: p.texts.where((t) => !t.id.startsWith('${idPrefix}_')).toList(),
      );
    }
    var n = 0;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (final cue in cues) {
      final start = cue.startMs.clamp(0, p.durationMs);
      final end = cue.endMs.clamp(0, p.durationMs);
      if (end - start < 100) continue;
      p = p.upsertText(
        TextPreset.subtitle.apply(
          TextItem(
            id: '${idPrefix}_${stamp}_${n++}',
            text: cue.text,
            startMs: start,
            endMs: end,
            y: 0.86,
          ),
        ),
      );
    }
    if (n > 0) {
      _apply(p);
      notifyListeners();
    }
    return n;
  }

  // ---- automatic captions (speech to text, on the device) --------------------------------------

  bool sttBusy = false;
  SttStatus? sttProgress;

  /// Why the last run made no captions: null (cancelled or fine), 'no_audio', 'no_speech', or a
  /// system message.
  String? sttError;

  /// How often the running job is asked for progress (tests make it 0).
  Duration sttPoll = const Duration(milliseconds: 400);

  /// Listens to the sound of the video (on the phone), cuts it into phrases and puts captions on the
  /// timeline as ONE undoable step, replacing the captions of an earlier automatic run. Returns how
  /// many captions were made (0 when cancelled or nothing was heard; see [sttError]).
  Future<int> generateCaptions(String lang) async {
    if (sttBusy) return 0;
    sttBusy = true;
    sttError = null;
    sttProgress = null;
    notifyListeners();
    try {
      await native.sttStart(_project.sourceUri, lang);
      while (true) {
        await Future<void>.delayed(sttPoll);
        if (_disposed) return 0;
        final s = await native.sttStatus();
        sttProgress = s;
        notifyListeners();
        if (s.finished) break;
      }
      final s = sttProgress!;
      if (s.state == 'cancelled') return 0;
      if (s.state == 'error') {
        sttError = s.error.isEmpty ? 'error' : s.error;
        return 0;
      }
      final cues = layoutCaptions(s.pieces);
      if (cues.isEmpty) {
        sttError = 'no_speech';
        return 0;
      }
      return importSubtitles(cues, idPrefix: 'auto', replaceSamePrefix: true);
    } catch (e) {
      sttError = 'error';
      return 0;
    } finally {
      sttBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> cancelCaptions() => native.sttCancel();

  void updateText(TextItem t, {bool record = true}) =>
      _apply(_project.upsertText(t), record: record);

  // ---- captions (progressive subtitles) -------------------------------------------------------

  /// Sets [cues] on [item] without the `Object?` cast at every call site. `null` turns captions off.
  TextItem withCues(TextItem item, List<CaptionCue>? cues) =>
      item.copyWith(cues: cues);

  /// Sets [style] on [item] without the `Object?` cast at every call site. `null` clears it.
  TextItem withCaptionStyle(TextItem item, CaptionStyle? style) =>
      item.copyWith(captionStyle: style);

  /// The selected text item, if one is selected.
  TextItem? get selectedTextItem =>
      _project.texts.where((t) => t.id == selectedId).firstOrNull;

  /// The text item captions are shown / edited on: the selected text, else the first one that
  /// already carries cues.
  TextItem? get captionItem =>
      selectedTextItem ??
      _project.texts.where((t) => t.cues != null).firstOrNull;

  TextItem _newCaptionItem() => TextItem(
    id: _newId('cap'),
    text: '',
    startMs: 0,
    endMs: math.max(1, _project.durationMs),
    y: 0.85,
    cues: const [],
  );

  static int _byStart(CaptionCue a, CaptionCue b) =>
      a.startMs.compareTo(b.startMs);

  /// Adds a cue at the playhead (3 s by default) to [on], or to the current caption item.
  /// Creates a caption item when there is none.
  void addCue({CaptionCue? cue, TextItem? on}) {
    final item = on ?? captionItem ?? _newCaptionItem();
    final dur = _project.durationMs;
    final start = sourceMs.clamp(0, dur <= 0 ? 0 : dur - 1);
    final from = cue?.startMs ?? start;
    final to = cue?.endMs ?? math.min(dur, start + 3000);
    final added =
        cue ??
        CaptionCue(
          text: 'Câu mới',
          startMs: from,
          endMs: to <= from ? from + 1 : to,
        );
    selectedId = item.id;
    updateText(withCues(item, [...?item.cues, added]..sort(_byStart)));
  }

  /// Replaces cue [index] of [on] (or the current caption item).
  void updateCue(int index, CaptionCue cue, {TextItem? on}) {
    final item = on ?? captionItem;
    final cues = item?.cues;
    if (item == null || cues == null || index < 0 || index >= cues.length) {
      return;
    }
    final next = [...cues]..[index] = cue;
    updateText(withCues(item, next..sort(_byStart)));
  }

  /// Removes cue [index] of [on] (or the current caption item).
  void removeCue(int index, {TextItem? on}) {
    final item = on ?? captionItem;
    final cues = item?.cues;
    if (item == null || cues == null || index < 0 || index >= cues.length) {
      return;
    }
    updateText(withCues(item, [...cues]..removeAt(index)));
  }

  /// Replaces the cue list of the caption item. Empty keeps captions on (nothing shows);
  /// `null` turns them off (Phase 1 look). Used by the caption panel.
  void setCues(List<CaptionCue>? cues, {TextItem? on}) {
    final item = on ?? captionItem ?? _newCaptionItem();
    selectedId = item.id;
    updateText(withCues(item, cues));
  }

  /// Style of the caption text (font, colour, position, reveal mode).
  void setCaptionStyle(CaptionStyle? style, {TextItem? on}) {
    final item = on ?? captionItem;
    if (item == null) return;
    updateText(withCaptionStyle(item, style));
  }

  void addCover([CoverStyle style = CoverStyle.solid]) {
    final s = sourceMs;
    // A spotlight needs a window you can see into; the others start as a strip over one line of text.
    final spot = style == CoverStyle.spotlight;
    final item = CoverItem(
      id: _newId('c'),
      style: style,
      y0: spot ? 0.35 : 0.45,
      y1: spot ? 0.65 : 0.55,
      startMs: s,
      endMs: (s + 3000).clamp(0, _project.durationMs),
    );
    _apply(_project.upsertCover(item));
    selectedId = item.id;
    notifyListeners();
  }

  void updateCover(CoverItem c, {bool record = true}) =>
      _apply(_project.upsertCover(c), record: record);

  void addZoom() {
    final s = sourceMs;
    final item = ZoomItem(
      id: _newId('z'),
      startMs: s,
      endMs: (s + 2500).clamp(0, _project.durationMs),
    );
    _apply(_project.upsertZoom(item));
    selectedId = item.id;
    notifyListeners();
  }

  void updateZoom(ZoomItem z, {bool record = true}) =>
      _apply(_project.upsertZoom(z), record: record);

  void deleteSelectedOverlay() {
    final id = selectedId;
    if (id == null) return;
    selectedId = null;
    _apply(_project.removeOverlay(id));
  }

  /// A drag/slider gesture is many updates: record one undo step at its start.
  void beginGesture() {
    _undo.add(_project);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  /// Puts a saved style on this edit as one undoable step.
  void applyTemplate(ProjectTemplate t) {
    _apply(t.applyTo(_project, newId: () => _newId('tpl')));
  }

  // ---- picture look (rotate, crop, output shape, colour) --------------------------------------

  PictureLook get look => _project.look;

  /// Size of the picture after rotation (where markers, covers and zoom live), in source pixels.
  Size get pictureSize => look.pictureSize(_project.frameW, _project.frameH);

  /// Size of the output frame (where text, images and shapes live), in source pixels.
  Size get outFrameSize => look.outputSize(_project.frameW, _project.frameH);

  void setLook(PictureLook l, {bool record = true}) =>
      _apply(_project.copyWith(look: l), record: record);

  void rotate90() =>
      setLook(look.copyWith(rotation: (look.rotation + 90) % 360));

  /// Free turn (degrees clockwise, -45..45) on top of the 90° steps.
  void setTilt(double degrees, {bool record = true}) =>
      setLook(look.copyWith(tilt: degrees.clamp(-45.0, 45.0)), record: record);

  /// Crop in fractions of the rotated picture; kept at least 10 % wide/high and inside the picture.
  void setCrop(Rect r, {bool record = true}) {
    const minSide = 0.1;
    final l = r.left.clamp(0.0, 1 - minSide);
    final t = r.top.clamp(0.0, 1 - minSide);
    final rr = r.right.clamp(l + minSide, 1.0);
    final b = r.bottom.clamp(t + minSide, 1.0);
    setLook(look.copyWith(crop: Rect.fromLTRB(l, t, rr, b)), record: record);
  }

  void setAspect(OutAspect a) => setLook(look.copyWith(aspect: a));
  void setFill(bool fill) => setLook(look.copyWith(fill: fill));

  void setColor(ColorLook c, {bool record = true}) =>
      setLook(look.copyWith(color: c), record: record);

  // ---- images, shapes, picture-in-picture -----------------------------------------------------

  /// [maxLifeMs] keeps a new overlay inside the video.
  int _life(int ms) {
    final s = sourceMs;
    return (s + ms).clamp(0, _project.durationMs);
  }

  Future<bool> addImageFromPhone() async {
    final m = await native.pickMedia('image');
    if (m == null || _disposed) return false;
    final s = sourceMs;
    final item = ImageItem(
      id: _newId('i'),
      path: m.path,
      name: m.name,
      pxW: m.width,
      pxH: m.height,
      startMs: s,
      endMs: _life(3000) <= s + 300 ? (s + 3000) : _life(3000),
    );
    _apply(_project.upsertImage(item));
    selectedId = item.id;
    notifyListeners();
    return true;
  }

  void updateImage(ImageItem i, {bool record = true}) =>
      _apply(_project.upsertImage(i), record: record);

  /// A point in picture fractions as output-frame fractions (crop and shape included).
  Offset _pictureToOutput(Offset p) {
    final l = _project.look;
    final r = l.pictureRectInOutput(_project.frameW, _project.frameH);
    final c = l.crop;
    final u = (p.dx - c.left) / c.width;
    final v = (p.dy - c.top) / c.height;
    return Offset(r.left + u * r.width, r.top + v * r.height);
  }

  void addShape(ShapeKind kind) {
    final s = sourceMs;
    var x = 0.5, y = 0.5, tailX = -0.15, tailY = 0.18;
    if (kind == ShapeKind.bubble) {
      // A callout opens next to the marker that is showing, its tail pointing at it.
      final m = _project.markers
          .where((m) => s >= m.cueStartMs && s <= m.endMs)
          .firstOrNull;
      if (m != null) {
        final a = _pictureToOutput(Offset(m.spec.anchor.x, m.spec.anchor.y));
        final bx = a.dx.clamp(0.25, 0.75);
        final by = a.dy > 0.3 ? a.dy - 0.16 : a.dy + 0.16;
        x = bx;
        y = by.clamp(0.08, 0.92);
        tailX = a.dx - x;
        tailY = a.dy - y;
      }
    }
    final item = ShapeItem(
      x: x,
      y: y,
      tailX: tailX,
      tailY: tailY,
      id: _newId('s'),
      kind: kind,
      w: kind == ShapeKind.line || kind == ShapeKind.arrow ? 0.3 : 0.4,
      h: kind == ShapeKind.bubble
          ? 0.1
          : kind == ShapeKind.line || kind == ShapeKind.arrow
          ? 0.12
          : 0.18,
      text: kind == ShapeKind.bubble ? 'Nhấn vào đây' : '',
      startMs: s,
      endMs: _life(3000) <= s + 300 ? (s + 3000) : _life(3000),
    );
    _apply(_project.upsertShape(item));
    selectedId = item.id;
    notifyListeners();
  }

  void updateShape(ShapeItem i, {bool record = true}) =>
      _apply(_project.upsertShape(i), record: record);

  Future<bool> addPipFromPhone() async {
    final m = await native.pickMedia('visual');
    if (m == null || _disposed) return false;
    final item = PipItem(
      id: _newId('p'),
      path: m.path,
      name: m.name,
      isVideo: m.isVideo,
      fileMs: m.isVideo ? m.durationMs : 0,
      pxW: m.width,
      pxH: m.height,
      startOutMs: _outMs,
      durMs: m.isVideo ? m.durationMs.clamp(500, maxPipMs) : 4000,
    );
    _apply(_project.upsertPip(item));
    selectedId = item.id;
    notifyListeners();
    return true;
  }

  /// Longest picture-in-picture video (its frames are sampled before the export).
  static const maxPipMs = 30000;

  void updatePip(PipItem p, {bool record = true}) =>
      _apply(_project.upsertPip(p), record: record);

  // ---- music and voice-over -------------------------------------------------------------------

  Future<bool> addMusicFromPhone() async {
    final m = await native.pickMedia('audio');
    if (m == null || _disposed) return false;
    final t = AudioTrack(
      id: _newId('a'),
      kind: AudioKind.music,
      path: m.path,
      name: m.name,
      fileMs: m.durationMs,
      startOutMs: 0,
      volume: 0.6,
      fadeOutMs: 800,
      loop: true,
    );
    _apply(_project.upsertAudio(t));
    selectedId = t.id;
    notifyListeners();
    return true;
  }

  void updateAudio(AudioTrack a, {bool record = true}) =>
      _apply(_project.upsertAudio(a), record: record);

  /// Voice-over tracks that are being processed (the panel shows a spinner for them).
  final Set<String> voiceBusy = {};

  /// Set when the last voice processing failed (cleared by the next try).
  bool voiceFxFailed = false;

  /// Applies a voice effect and/or noise reduction to a voice-over, ONCE: the processed file replaces
  /// the original in the preview and in the export, and the original stays to go back to. The whole
  /// change is one undo step, made when the file is ready. Returns false when nothing was changed.
  Future<bool> setVoiceFx(String id, {VoiceFx? fx, Denoise? denoise}) async {
    final cur = _project.audioTracks.where((a) => a.id == id).firstOrNull;
    if (cur == null || cur.kind != AudioKind.voice) return false;
    final nextFx = fx ?? cur.fx;
    final nextDn = denoise ?? cur.denoise;
    if (nextFx == cur.fx && nextDn == cur.denoise) return true;
    if (nextFx == VoiceFx.none && nextDn == Denoise.off) {
      updateAudio(
        cur.copyWith(fx: VoiceFx.none, denoise: Denoise.off, fxPath: null),
      );
      return true;
    }
    if (voiceBusy.contains(id)) return false;
    voiceBusy.add(id);
    voiceFxFailed = false;
    notifyListeners();
    try {
      final file = await native.processVoice(
        cur.path,
        nextFx.name,
        nextDn.name,
      );
      if (_disposed) return false;
      final now = _project.audioTracks.where((a) => a.id == id).firstOrNull;
      if (now == null) return false;
      updateAudio(now.copyWith(fx: nextFx, denoise: nextDn, fxPath: file));
      return true;
    } catch (_) {
      voiceFxFailed = true;
      return false;
    } finally {
      voiceBusy.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  bool recordingVoice = false;
  int _voiceStartOut = 0;

  /// Starts recording the voice-over at the playhead. The caller starts playback (the video plays
  /// while the person speaks).
  Future<void> startVoice() async {
    if (recordingVoice) return;
    _voiceStartOut = _outMs;
    await native.startVoice();
    recordingVoice = true;
    notifyListeners();
  }

  /// Stops the voice-over and puts it on the timeline where it started.
  Future<void> stopVoice() async {
    if (!recordingVoice) return;
    recordingVoice = false;
    final r = await native.stopVoice();
    if (_disposed) return;
    if (r != null && r.durationMs > 300) {
      final t = AudioTrack(
        id: _newId('a'),
        kind: AudioKind.voice,
        path: r.path,
        name: 'Voice',
        fileMs: r.durationMs,
        startOutMs: _voiceStartOut,
      );
      _apply(_project.upsertAudio(t));
      selectedId = t.id;
    }
    notifyListeners();
  }

  /// Evens out the volume of the selected segment(s) to a common loudness (-16 dBFS RMS), where the
  /// segment has sound. Returns false when there is nothing to measure.
  Future<bool> normalizeSelectedVolume() async {
    var next = _project;
    var any = false;
    for (final i in activeSegments) {
      final s = _project.segments[i];
      if (s.isStill || s.reverse) continue;
      final db = await native.loudness(_project.sourceUri, s.startMs, s.endMs);
      if (db == null) continue;
      any = true;
      final gain = math.pow(10, (-16 - db) / 20).toDouble();
      next = next.setAudio(i, volume: gain.clamp(0.1, 2.0));
    }
    if (!any || _disposed) return false;
    _apply(next);
    return true;
  }

  // ---- overlay images rendered natively (shapes) ----------------------------------------------

  final Map<String, Future<RenderedImage>> _shapeImages = {};

  Future<RenderedImage> shapeImage(ShapeItem s) {
    final o = outFrameSize;
    final key = '${s.lookKey}|${o.width}x${o.height}';
    return _shapeImages.putIfAbsent(key, () async {
      final r = await native.renderShape(
        s.toNative(),
        o.width.round(),
        o.height.round(),
      );
      return RenderedImage(r.png, r.w.toDouble(), r.h.toDouble());
    });
  }

  // ---- rendered overlay images (native, cached) -----------------------------------------------

  final Map<(MarkerSpec, int), Future<RenderedImage>> _markerImages = {};
  final Map<String, Future<RenderedImage>> _textImages = {};
  final Map<String, Future<RenderedImage>> _coverImages = {};

  /// Marker body at the project's frame size; the bitmap is a square centred on the anchor.
  Future<RenderedImage> markerImage(MarkerSpec spec, [int phase = 0]) {
    // Geometry does not change the bitmap's look but does change its size, so key on all of it;
    // [phase] picks one step of the water loop (see MarkerTiming.phaseIndex).
    return _markerImages.putIfAbsent((spec, phase), () async {
      final pic = _project.pictureDims;
      final r = await native.renderMarker(
        spec,
        pic.w,
        pic.h,
        phaseMs: phase * MarkerTiming.phaseStepMs,
      );
      return RenderedImage(r.png, r.half * 2, r.half * 2);
    });
  }

  Future<RenderedImage> textImage(TextItem t) {
    // Text lives in the OUTPUT frame, so its size follows the output width (crop and aspect included).
    final o = outFrameSize;
    final key = '${t.lookKey}|${o.width}';
    return _textImages.putIfAbsent(key, () async {
      final r = await native.renderText(t.toNative(), o.width.round());
      return RenderedImage(r.png, r.w.toDouble(), r.h.toDouble());
    });
  }

  // Small LRU: a caption changes picture only when the active cue changes, so a few entries are plenty.
  static const _cueCacheMax = 8;
  final Map<String, Future<RenderedImage>> _cueImages = {};

  /// The picture of the cue showing at [sourceMs] for [t], or null when no cue is active.
  Future<RenderedImage?> cueImage(TextItem t, int sourceMs) async {
    final cues = t.cues;
    if (cues == null) return null;
    final i = cues.indexWhere((e) => e.isActiveAt(sourceMs));
    if (i < 0) return null;
    final cue = cues[i];
    final style = t.captionStyle;
    final w = outFrameSize.width.round();
    final key = '${style?.toJson()}|${cue.toJson()}|$w';
    var f = _cueImages.remove(key);
    f ??= () async {
      final r = await native.renderCue(cue.toJson(), style?.toJson(), w);
      return RenderedImage(r.png, r.w.toDouble(), r.h.toDouble());
    }();
    _cueImages[key] = f;
    while (_cueImages.length > _cueCacheMax) {
      _cueImages.remove(_cueImages.keys.first);
    }
    try {
      return await f;
    } catch (_) {
      _cueImages.remove(key);
      return null;
    }
  }

  Future<RenderedImage> coverImage(CoverItem c) {
    final key = '${c.x1 - c.x0}|${c.y1 - c.y0}|${c.color.toARGB32()}';
    return _coverImages.putIfAbsent(key, () async {
      final pic = _project.pictureDims;
      final r = await native.renderCover(c.toNative(), pic.w, pic.h);
      return RenderedImage(r.png, r.w.toDouble(), r.h.toDouble());
    });
  }

  // ---- export ---------------------------------------------------------------------------------

  /// Height of the exported frame for [q], or 0 to keep the output frame as it is. The "p" figure is the
  /// short side of the OUTPUT frame (after crop and shape), never upscaled.
  int outHeightFor(ExportQuality q) {
    final o = _project.outDims;
    final (w, h) = ExportPlanner.sizeFor(o.w, o.h, q);
    return (w == o.w && h == o.h) ? 0 : h;
  }

  /// Size, bitrate and file-size estimate for [q] (and an optional cap on the file size).
  ExportPlan planFor(ExportQuality q, {int? maxBytes}) {
    final o = _project.outDims;
    return ExportPlanner.plan(
      frameW: o.w,
      frameH: o.h,
      durationMs: _project.outDurationMs,
      quality: q,
      maxBytes: maxBytes,
      hasAudio: true,
    );
  }

  Future<void> startExport(
    ExportQuality q, {
    bool gif = false,
    int? maxBytes,
  }) async {
    final plan = planFor(q, maxBytes: maxBytes);
    final height = outHeightFor(q);
    exportState = const ExportState(phase: ExportPhase.running);
    notifyListeners();
    await flush();
    try {
      await native.startExport(
        _project.toExportMap(
          outHeight: height,
          bitrate: plan.bitrate,
          gif: gif,
        ),
      );
    } catch (e) {
      exportState = const ExportState(
        phase: ExportPhase.error,
        errorCode: 'start_failed',
      );
      notifyListeners();
    }
  }

  Future<void> cancelExport() async {
    await native.cancelExport();
    exportState = const ExportState();
    notifyListeners();
  }

  void dismissExport() {
    exportState = const ExportState();
    notifyListeners();
  }

  void _onEvent(RecEvent e) {
    if (_disposed) return;
    switch (e) {
      case ExportProgressEvent():
        if (exportState.phase == ExportPhase.running) {
          exportState = ExportState(
            phase: ExportPhase.running,
            progress: e.value,
          );
          notifyListeners();
        }
      case ExportDoneEvent():
        exportState = ExportState(
          phase: ExportPhase.done,
          progress: 1,
          result: e,
        );
        notifyListeners();
      case ExportErrorEvent():
        exportState = ExportState(
          phase: ExportPhase.error,
          errorCode: e.code,
          errorMessage: e.message,
        );
        notifyListeners();
      default:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // A voice-over still recording must not outlive the screen.
    if (recordingVoice) unawaited(native.stopVoice());
    _saveTimer?.cancel();
    _sub.cancel();
    // Fire and forget: the project must survive leaving the screen.
    unawaited(store.save(_project));
    super.dispose();
  }
}
