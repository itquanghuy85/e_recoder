import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/formatters.dart';
import '../../core/video_source.dart';
import '../../core/native_recorder.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../app/settings_store.dart';
import '../marker/marker_settings.dart';
import '../record/recorder_controller.dart';
import 'auto_director.dart' show DirectorOptions;
import 'edit_project.dart';
import 'editor_controller.dart';
import 'editor_extra_players.dart';
import 'editor_fullscreen.dart';
import 'editor_playback.dart';
import 'editor_pro_tools.dart' show ensureMicrophone;
import 'project_template.dart';
import 'editor_stage.dart';
import 'editor_timeline.dart';
import 'editor_tools.dart';
import 'export_sheet.dart';
import 'project_store.dart';

/// The editor for one recording. The player shows the ORIGINAL file; the cuts, speed changes and
/// overlays are applied on top of it live (and by the exporter for the final video).
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.entry});
  final MediaEntry entry;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  EditorController? _c;
  VideoPlayerController? _v;
  PlaybackDriver? _driver;
  ExtraPlayers? _extras;
  bool _wasPlaying = false;
  bool _failed = false;
  EditorTool _tool = EditorTool.cut;
  bool _toolsHidden = false;
  bool _seeking = false;
  int _lastSeekSource = -1;
  final _timelineKey = GlobalKey<EditorTimelineState>();

  @override
  void initState() {
    super.initState();
    // A notice from the previous screen (e.g. "Đã lưu…") must not cover the tool tabs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    });
    try {
      _toolsHidden = ref
          .read(settingsStoreProvider)
          .getBool('editor.toolsHidden', false);
    } catch (_) {}
    _init();
  }

  Future<void> _init() async {
    try {
      // mixWithOthers: the picture-in-picture and music players must not take the audio focus away
      // from this one (Android would pause it, and the playhead would stand still).
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
      var project = await store.load(widget.entry.uri);
      final size = v.value.size;
      project ??= EditProject.fresh(
        sourceUri: widget.entry.uri,
        name: widget.entry.name,
        durationMs: v.value.duration.inMilliseconds,
        frameW: size.width.round(),
        frameH: size.height.round(),
      );
      final c = EditorController(
        project: project,
        native: ref.read(nativeRecorderProvider),
        store: store,
      );
      final mk = ref.read(markerSettingsProvider);
      c.directorOptions = DirectorOptions(
        zoomScale: mk.zoomScale,
        zoomRampMs: mk.zoomRampMs,
        zoomHoldMs: mk.zoomHoldMs,
      );
      c.addListener(_onController);
      c.loadWaveform();
      setState(() {
        _v = v;
        _c = c;
        _driver = PlaybackDriver(controller: c, player: VideoPlayerPort(v));
        _extras = ExtraPlayers(c);
      });
      await v.seekTo(Duration.zero);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _driver?.dispose();
    _extras?.dispose();
    _c?.removeListener(_onController);
    _c?.dispose();
    _v?.dispose();
    super.dispose();
  }

  // ---- glue between player and controller -----------------------------------------------------

  void _onController() {
    final c = _c;
    final v = _v;
    if (c == null || v == null) return;
    // A selection made on the timeline/preview switches to the matching tool.
    final id = c.selectedId;
    if (id != null) {
      final want = c.project.markers.any((e) => e.id == id)
          ? EditorTool.marker
          : c.project.texts.any((e) => e.id == id)
          ? EditorTool.text
          : c.project.covers.any((e) => e.id == id)
          ? EditorTool.cover
          : c.project.zooms.any((e) => e.id == id)
          ? EditorTool.zoom
          : c.project.images.any((e) => e.id == id) ||
                c.project.shapes.any((e) => e.id == id) ||
                c.project.pips.any((e) => e.id == id)
          ? EditorTool.overlay
          : c.project.audioTracks.any((e) => e.id == id)
          ? EditorTool.audio
          : null;
      if (want != null && want != _tool) setState(() => _tool = want);
    }
    // A voice-over ends when playback ends (the end of the video, or the person pausing).
    if (c.recordingVoice && _wasPlaying && !c.playing) {
      c.stopVoice();
    } else if (!c.recordingVoice && c.playing && _voiceWasRecording) {
      _driver?.pause();
    }
    _wasPlaying = c.playing;
    _voiceWasRecording = c.recordingVoice;
    // Scrubbing / edits while paused: keep the frame in step with the playhead.
    if (!c.playing) _seekPlayerTo(c.sourceMs);
  }

  Future<void> _seekPlayerTo(int sourceMs) async {
    final v = _v;
    if (v == null || _seeking || (sourceMs - _lastSeekSource).abs() < 25) {
      return;
    }
    _seeking = true;
    _lastSeekSource = sourceMs;
    try {
      await v.seekTo(Duration(milliseconds: sourceMs));
    } finally {
      _seeking = false;
      // The playhead may have moved while we were seeking.
      final c = _c;
      if (c != null && !c.playing && (c.sourceMs - sourceMs).abs() > 40) {
        unawaited(_seekPlayerTo(c.sourceMs));
      }
    }
  }

  bool _voiceWasRecording = false;
  final _stageKey = GlobalKey();

  /// Saves the frame under the playhead, with everything drawn over it, as a PNG in the photo library.
  Future<void> _saveStill() async {
    final t = AppL10n.of(context);
    final boundary =
        _stageKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    // Aim for about 1080 px on the short side.
    final shortSide = boundary.size.shortestSide;
    final ratio = shortSide <= 0 ? 1.0 : (1080 / shortSide).clamp(1.0, 4.0);
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final saved = await ref
        .read(nativeRecorderProvider)
        .saveImage(data.buffer.asUint8List(), 'ESR_frame');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved == null ? t.exportError : t.stillSaved)),
    );
  }

  Future<void> _togglePlay() async => _driver?.toggle();

  /// Voice-over: ask for the microphone, start recording and play the video from the playhead.
  Future<void> _recordVoice() async {
    final c = _c;
    final t = AppL10n.of(context);
    if (c == null) return;
    if (!await ensureMicrophone()) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.audioMicDenied)));
      }
      return;
    }
    await _pause();
    await c.startVoice();
    await _driver?.play();
  }

  Future<void> _saveTemplate(EditorController c) async {
    final t = AppL10n.of(context);
    final store = ref.read(templateStoreProvider);
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.templateSave),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(labelText: t.templateName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: Text(t.templateSave),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await store.save(
      ProjectTemplate.capture(
        'tpl_${DateTime.now().microsecondsSinceEpoch}',
        name,
        c.project,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.templateSaved)));
    }
  }

  Future<void> _pickTemplate(EditorController c) async {
    final t = AppL10n.of(context);
    final store = ref.read(templateStoreProvider);
    final all = await store.list();
    if (!mounted) return;
    final picked = await showModalBottomSheet<ProjectTemplate>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: all.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text(t.templateNone),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final tpl in all)
                    ListTile(
                      title: Text(tpl.name),
                      onTap: () => Navigator.pop(ctx, tpl),
                      trailing: IconButton(
                        tooltip: t.templateDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await store.delete(tpl.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
    if (picked == null) return;
    c.applyTemplate(picked);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.templateApplied)));
    }
  }

  Future<void> _pause() async => _driver?.pause();

  Future<void> _confirmReset(EditorController c) async {
    final t = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.resetTitle),
        content: Text(t.resetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          Semantics(
            identifier: 'reset_confirm',
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.resetProject),
            ),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _pause();
      c.resetProject();
    }
  }

  // ---- UI -----------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final c = _c;
    final v = _v;
    if (_failed) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.editorLoadError)),
      );
    }
    if (c == null || v == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.entry.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final mk = ref.watch(markerSettingsProvider);
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) c.flush();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
          actions: [
            ListenableBuilder(
              listenable: c,
              builder: (context, _) => Row(
                children: [
                  Semantics(
                    identifier: 'editor_undo',
                    child: IconButton(
                      tooltip: t.undo,
                      onPressed: c.canUndo ? c.undo : null,
                      icon: const Icon(Icons.undo),
                    ),
                  ),
                  Semantics(
                    identifier: 'editor_redo',
                    child: IconButton(
                      tooltip: t.redo,
                      onPressed: c.canRedo ? c.redo : null,
                      icon: const Icon(Icons.redo),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              identifier: 'editor_menu',
              child: PopupMenuButton<int>(
                tooltip: t.menuMore,
                onSelected: (v) => switch (v) {
                  1 => _saveTemplate(c),
                  2 => _pickTemplate(c),
                  _ => _confirmReset(c),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 1, child: Text(t.templateSave)),
                  PopupMenuItem(value: 2, child: Text(t.templateApply)),
                  PopupMenuItem(value: 0, child: Text(t.resetProject)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Semantics(
                identifier: 'editor_export',
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.tertiary,
                    foregroundColor: cs.onTertiary,
                  ),
                  onPressed: () async {
                    await _pause();
                    if (!context.mounted) return;
                    await showExportSheet(context, c, onSaveStill: _saveStill);
                  },
                  child: Text(t.exportAction),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: cs.surfaceContainerLowest,
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: EditorStage(
                          controller: c,
                          video: v,
                          pipVideos: _extras?.pips ?? const {},
                          repaint: _extras,
                          captureKey: _stageKey,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: Space.sm,
                        child: Semantics(
                          identifier: 'editor_fullscreen',
                          child: IconButton.filledTonal(
                            tooltip: t.enterFullscreen,
                            onPressed: () => showEditorFullscreen(
                              context,
                              controller: c,
                              video: v,
                              pipVideos: _extras?.pips ?? const {},
                              repaint: _extras,
                              onToggle: _togglePlay,
                            ),
                            icon: const Icon(Icons.fullscreen),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _Transport(
                controller: c,
                busy: _driver?.busy,
                onToggle: _togglePlay,
                onZoomOut: () => _timelineKey.currentState?.zoomBy(1 / 1.5),
                onZoomIn: () => _timelineKey.currentState?.zoomBy(1.5),
                onFit: () => _timelineKey.currentState?.zoomToFit(
                  MediaQuery.sizeOf(context).width,
                ),
              ),
              EditorTimeline(key: _timelineKey, controller: c),
              const Divider(),
              EditorTools(
                controller: c,
                tool: _tool,
                onTool: (e) {
                  c.select(null);
                  setState(() => _tool = e);
                },
                newMarkerColor: Color(mk.color),
                newMarkerThickness: mk.thickness,
                video: v,
                onRecordVoice: _recordVoice,
                collapsed: _toolsHidden,
                onToggleCollapsed: () {
                  setState(() => _toolsHidden = !_toolsHidden);
                  ref
                      .read(settingsStoreProvider)
                      .setBool('editor.toolsHidden', _toolsHidden);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final ValueNotifier<bool> _never = ValueNotifier<bool>(false);

class _Transport extends StatelessWidget {
  const _Transport({
    required this.controller,
    required this.onToggle,
    required this.busy,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFit,
  });
  final EditorController controller;
  final VoidCallback onToggle;
  final ValueListenable<bool>? busy;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Row(
            children: [
              Semantics(
                identifier: 'editor_play',
                child: IconButton.filled(
                  tooltip: c.playing ? t.pauseVideo : t.playVideo,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    backgroundColor: cs.tertiary,
                    foregroundColor: cs.onTertiary,
                  ),
                  onPressed: onToggle,
                  icon: ValueListenableBuilder<bool>(
                    valueListenable: busy ?? _never,
                    builder: (_, working, _) => working
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: cs.onTertiary,
                            ),
                          )
                        : Icon(c.playing ? Icons.pause : Icons.play_arrow),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              // The clock gives way (it scales down) before anything can overflow the row.
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: formatClock(c.outMs)),
                        TextSpan(
                          text: ' / ${formatClock(c.project.outDurationMs)}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    style: timecodeStyle(context, size: 13),
                  ),
                ),
              ),
              Semantics(
                identifier: 'seek_back',
                child: IconButton(
                  tooltip: t.seekBack,
                  onPressed: () => c.seekOut(c.outMs - 1000),
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Semantics(
                identifier: 'seek_fwd',
                child: IconButton(
                  tooltip: t.seekForward,
                  onPressed: () => c.seekOut(c.outMs + 1000),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
              IconButton(
                tooltip: t.timelineZoomOut,
                onPressed: onZoomOut,
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                tooltip: t.timelineFit,
                onPressed: onFit,
                icon: const Icon(Icons.fit_screen_outlined),
              ),
              IconButton(
                tooltip: t.timelineZoomIn,
                onPressed: onZoomIn,
                icon: const Icon(Icons.zoom_in),
              ),
            ],
          ),
        );
      },
    );
  }
}
