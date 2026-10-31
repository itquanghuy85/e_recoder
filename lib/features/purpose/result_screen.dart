import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/native_recorder.dart';
import '../../core/video_source.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../editor/edit_project.dart';
import '../editor/editor_controller.dart';
import '../editor/editor_extra_players.dart';
import '../editor/editor_playback.dart';
import '../editor/editor_screen.dart';
import '../editor/editor_stage.dart';
import '../editor/project_store.dart';
import '../library/media_repository.dart';
import '../record/recorder_controller.dart';

/// What a person sees right after recording: the video and three big choices. Nothing is edited here;
/// "Edit more" opens the full editor, "Export now" exports what the recording became (with the automatic
/// edit when there was one) and "Record again" goes back to the recorder.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.entry});
  final MediaEntry entry;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

enum _Phase { building, idle, exporting, done, error }

class _ResultScreenState extends ConsumerState<ResultScreen> {
  VideoPlayerController? _v;
  EditorController? _ctl;
  PlaybackDriver? _driver;
  ExtraPlayers? _extras;
  bool _playerFailed = false;
  bool _seeking = false;
  int _lastSeek = -1;
  _Phase _phase = _Phase.building;
  double _progress = 0;
  String? _exportedName;
  ExportQuality _quality = ExportQuality.original;

  @override
  void initState() {
    super.initState();
    // The automatic edit of a clean recording is saved a moment after the recording; wait for it, so
    // that the preview shows the marks and "Export now" never exports the video before the edit is in
    // place.
    ref.read(recorderProvider.notifier).draftReady.whenComplete(_initPreview);
  }

  /// The preview is the editor's own stage (video plus the marks, zoom and text of the saved edit), so
  /// what is played here is what will be exported. Nothing in it can be touched; a tap plays or pauses.
  Future<void> _initPreview() async {
    if (!mounted) return;
    try {
      final v = videoControllerFor(
        widget.entry.uri,
        options: VideoPlayerOptions(mixWithOthers: true),
      );
      await v.initialize();
      if (!mounted) {
        await v.dispose();
        return;
      }
      final store = ref.read(projectStoreProvider);
      final project =
          await store.load(widget.entry.uri) ??
          EditProject.fresh(
            sourceUri: widget.entry.uri,
            name: widget.entry.name,
            durationMs: v.value.duration.inMilliseconds,
            frameW: v.value.size.width.round(),
            frameH: v.value.size.height.round(),
          );
      if (!mounted) {
        await v.dispose();
        return;
      }
      final c = EditorController(
        project: project,
        native: ref.read(nativeRecorderProvider),
        store: store,
      );
      c.addListener(_onController);
      setState(() {
        _v = v;
        _ctl = c;
        _driver = PlaybackDriver(controller: c, player: VideoPlayerPort(v));
        _extras = ExtraPlayers(c);
        if (_phase == _Phase.building) _phase = _Phase.idle;
      });
      await v.seekTo(Duration.zero);
    } catch (_) {
      if (mounted) {
        setState(() {
          _playerFailed = true;
          if (_phase == _Phase.building) _phase = _Phase.idle;
        });
      }
    }
  }

  @override
  void dispose() {
    _driver?.dispose();
    _extras?.dispose();
    _ctl?.removeListener(_onController);
    _ctl?.dispose();
    _v?.dispose();
    super.dispose();
  }

  void _onController() {
    final c = _ctl;
    if (c == null || !mounted) return;
    if (_phase == _Phase.exporting) _onExport();
    // Scrubbing while paused: keep the frame in step with the playhead.
    if (!c.playing) _seekPlayerTo(c.sourceMs);
    setState(() {});
  }

  Future<void> _seekPlayerTo(int sourceMs) async {
    final v = _v;
    if (v == null || _seeking || (sourceMs - _lastSeek).abs() < 25) return;
    _seeking = true;
    _lastSeek = sourceMs;
    try {
      await v.seekTo(Duration(milliseconds: sourceMs));
    } finally {
      _seeking = false;
    }
  }

  Future<void> _exportNow() async {
    final store = ref.read(projectStoreProvider);
    // The preview may not have come up (a video that cannot be played); the export does not need it.
    var c = _ctl;
    if (c == null) {
      final e = widget.entry;
      final project =
          await store.load(e.uri) ??
          EditProject.fresh(
            sourceUri: e.uri,
            name: e.name,
            durationMs: e.durationMs,
            frameW: e.width,
            frameH: e.height,
          );
      if (!mounted) return;
      c = EditorController(
        project: project,
        native: ref.read(nativeRecorderProvider),
        store: store,
      )..addListener(_onController);
      _ctl = c;
    }
    await _driver?.pause();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.exporting;
      _progress = 0;
    });
    await c.startExport(_quality);
  }

  void _onExport() {
    final s = _ctl?.exportState;
    if (s == null) return;
    switch (s.phase) {
      case ExportPhase.running:
        _progress = s.progress;
      case ExportPhase.done:
        ref.invalidate(mediaListProvider);
        _phase = _Phase.done;
        _exportedName = s.result?.name;
      case ExportPhase.error:
        _phase = _Phase.error;
      case ExportPhase.idle:
        break;
    }
  }

  String _qualityLabel(AppL10n t, ExportQuality q) => switch (q) {
    ExportQuality.original => t.qualityOriginal,
    ExportQuality.p1080 => t.resolution1080,
    ExportQuality.p720 => t.resolution720,
    ExportQuality.p480 => t.resolution480,
  };

  void _edit() {
    _driver?.pause();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(entry: widget.entry),
      ),
    );
  }

  Widget _preview(AppL10n t, ColorScheme c, bool busy) {
    final ctl = _ctl;
    final v = _v;
    if (_playerFailed) return Center(child: Text(t.resultPreviewError));
    if (ctl == null || v == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final total = ctl.project.outDurationMs;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: EditorStage(
                    controller: ctl,
                    video: v,
                    pipVideos: _extras?.pips ?? const {},
                    repaint: _extras,
                    viewZoom: false,
                  ),
                ),
              ),
              Positioned.fill(
                child: Semantics(
                  identifier: 'result_preview',
                  button: true,
                  child: GestureDetector(
                    key: const ValueKey('result_preview'),
                    behavior: HitTestBehavior.opaque,
                    onTap: busy ? null : () => _driver?.toggle(),
                    child: Center(
                      child: ctl.playing
                          ? const SizedBox.shrink()
                          : Icon(
                              Icons.play_circle_fill,
                              size: 64,
                              color: c.onSurface.withValues(alpha: 0.7),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Slider(
          key: const ValueKey('result_seek'),
          value: ctl.outMs.clamp(0, total).toDouble(),
          max: total.clamp(1, 1 << 30).toDouble(),
          onChanged: busy
              ? null
              : (x) async {
                  await _driver?.pause();
                  ctl.seekOut(x.round());
                },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final busy = _phase == _Phase.exporting;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(t.resultTitle),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.entry.name,
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.sm),
                Expanded(child: _preview(t, c, busy)),
                const SizedBox(height: Space.md),
                SizedBox(
                  height: 28,
                  child: switch (_phase) {
                    _Phase.building => Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: Space.sm),
                        Text(t.resultBuilding, style: tt.bodyMedium),
                      ],
                    ),
                    _Phase.exporting => Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(value: _progress),
                        ),
                        const SizedBox(width: Space.sm),
                        Text(t.resultExporting, style: tt.bodyMedium),
                      ],
                    ),
                    _Phase.done => Text(
                      key: const ValueKey('result_done'),
                      t.resultExported(_exportedName ?? ''),
                      style: tt.bodyMedium?.copyWith(color: c.tertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    _Phase.error => Text(
                      key: const ValueKey('result_error'),
                      t.resultExportFailed,
                      style: tt.bodyMedium?.copyWith(color: c.error),
                    ),
                    _Phase.idle => const SizedBox.shrink(),
                  },
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(t.exportQuality, style: tt.bodyMedium),
                    for (final q in ExportQuality.values)
                      Semantics(
                        identifier: 'result_quality_${q.name}',
                        child: ChoiceChip(
                          key: ValueKey('result_quality_${q.name}'),
                          label: Text(_qualityLabel(t, q)),
                          selected: _quality == q,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => _quality = q),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Semantics(
                  identifier: 'result_export',
                  child: FilledButton(
                    key: const ValueKey('result_export'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: _phase == _Phase.idle || _phase == _Phase.error
                        ? _exportNow
                        : null,
                    child: Text(t.resultExport),
                  ),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        identifier: 'result_edit',
                        child: OutlinedButton(
                          key: const ValueKey('result_edit'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: busy ? null : _edit,
                          child: Text(t.resultEdit),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Semantics(
                        identifier: 'result_back',
                        child: OutlinedButton(
                          key: const ValueKey('result_back'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: Text(t.resultBack),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
