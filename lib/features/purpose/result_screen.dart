import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/native_recorder.dart';
import '../../core/video_source.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../editor/edit_project.dart';
import '../editor/editor_controller.dart';
import '../editor/editor_screen.dart';
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
  late final VideoPlayerController _v = videoControllerFor(widget.entry.uri);
  bool _playerFailed = false;
  _Phase _phase = _Phase.building;
  double _progress = 0;
  String? _exportedName;
  EditorController? _export;

  @override
  void initState() {
    super.initState();
    _v
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object _) {
          if (mounted) setState(() => _playerFailed = true);
        });
    _v.addListener(() {
      if (mounted) setState(() {});
    });
    // The automatic edit of a clean recording is saved a moment after the recording; wait for it, so
    // that "Export now" never exports the video before the edit is in place.
    ref.read(recorderProvider.notifier).draftReady.whenComplete(() {
      if (mounted && _phase == _Phase.building) {
        setState(() => _phase = _Phase.idle);
      }
    });
  }

  @override
  void dispose() {
    _export?.removeListener(_onExport);
    _export?.dispose();
    _v.dispose();
    super.dispose();
  }

  Future<void> _exportNow() async {
    final store = ref.read(projectStoreProvider);
    final e = widget.entry;
    final project =
        await store.load(widget.entry.uri) ??
        EditProject.fresh(
          sourceUri: widget.entry.uri,
          name: widget.entry.name,
          durationMs: e.durationMs,
          frameW: e.width,
          frameH: e.height,
        );
    if (!mounted) return;
    _v.pause();
    final c = EditorController(
      project: project,
      native: ref.read(nativeRecorderProvider),
      store: store,
    );
    c.addListener(_onExport);
    _export?.dispose();
    _export = c;
    setState(() {
      _phase = _Phase.exporting;
      _progress = 0;
    });
    await c.startExport(ExportQuality.original);
  }

  void _onExport() {
    final s = _export?.exportState;
    if (s == null || !mounted) return;
    switch (s.phase) {
      case ExportPhase.running:
        setState(() => _progress = s.progress);
      case ExportPhase.done:
        ref.invalidate(mediaListProvider);
        setState(() {
          _phase = _Phase.done;
          _exportedName = s.result?.name;
        });
      case ExportPhase.error:
        setState(() => _phase = _Phase.error);
      case ExportPhase.idle:
        break;
    }
  }

  void _edit() {
    _v.pause();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(entry: widget.entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final v = _v.value;
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
                Expanded(
                  child: _playerFailed
                      ? Center(child: Text(t.resultPreviewError))
                      : !v.isInitialized
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                          key: const ValueKey('result_preview'),
                          onTap: () => v.isPlaying ? _v.pause() : _v.play(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: AspectRatio(
                                  aspectRatio: v.aspectRatio,
                                  child: VideoPlayer(_v),
                                ),
                              ),
                              if (!v.isPlaying)
                                Icon(
                                  Icons.play_circle_fill,
                                  size: 64,
                                  color: c.onSurface.withValues(alpha: 0.7),
                                ),
                            ],
                          ),
                        ),
                ),
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
