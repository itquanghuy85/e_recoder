import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/native_recorder.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../record/recorder_controller.dart';
import 'media_repository.dart';
import 'player_screen.dart';

/// Joins recordings back to back into one new video (no overlays), in the order given.
Future<void> showJoinSheet(BuildContext context, List<MediaEntry> entries) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => _JoinSheet(entries: entries),
    );

class _JoinSheet extends ConsumerStatefulWidget {
  const _JoinSheet({required this.entries});
  final List<MediaEntry> entries;

  @override
  ConsumerState<_JoinSheet> createState() => _JoinSheetState();
}

enum _Phase { running, done, error }

class _JoinSheetState extends ConsumerState<_JoinSheet> {
  StreamSubscription<RecEvent>? _sub;
  _Phase _phase = _Phase.running;
  double _progress = 0;
  ExportDoneEvent? _result;

  @override
  void initState() {
    super.initState();
    final native = ref.read(nativeRecorderProvider);
    _sub = native.events.listen((e) {
      if (!mounted) return;
      switch (e) {
        case ExportProgressEvent():
          setState(() => _progress = e.value);
        case ExportDoneEvent():
          ref.invalidate(mediaListProvider);
          setState(() {
            _phase = _Phase.done;
            _result = e;
          });
        case ExportErrorEvent():
          setState(() => _phase = _Phase.error);
        default:
          break;
      }
    });
    _start(native);
  }

  Future<void> _start(NativeRecorder native) async {
    final first = widget.entries.first;
    final bitrate = (first.width * first.height * 30 * 0.07).round().clamp(
      1500000,
      25000000,
    );
    try {
      await native.startExport({
        'sourceUri': first.uri,
        'frameW': first.width,
        'frameH': first.height,
        'outHeight': 0,
        'bitrate': bitrate,
        'namePrefix': 'ESR_join',
        'segments': [
          for (final e in widget.entries)
            {'startMs': 0, 'endMs': e.durationMs, 'speed': 1.0, 'uri': e.uri},
        ],
        'markers': <Object>[],
        'texts': <Object>[],
        'covers': <Object>[],
        'zooms': <Object>[],
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final native = ref.read(nativeRecorderProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.xl,
        Space.xl,
        Space.xl,
        Space.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.joinTitle, style: tt.titleLarge),
          const SizedBox(height: Space.sm),
          Text(
            t.joinSummary(widget.entries.length),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: Space.lg),
          switch (_phase) {
            _Phase.running => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  identifier: 'join_progress',
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: Space.md),
                Text(t.exportRunning((_progress * 100).round())),
                const SizedBox(height: Space.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () async {
                      await native.cancelExport();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(t.cancel),
                  ),
                ),
              ],
            ),
            _Phase.error => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.exportError,
                  style: tt.bodyMedium?.copyWith(color: cs.error),
                ),
                const SizedBox(height: Space.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.close),
                  ),
                ),
              ],
            ),
            _Phase.done => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: cs.tertiary),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text(t.joinDone, style: tt.titleMedium)),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  '${_result!.name} · ${formatBytes(_result!.size)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: Space.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.close),
                    ),
                    const SizedBox(width: Space.sm),
                    Semantics(
                      identifier: 'join_view',
                      child: FilledButton(
                        onPressed: () {
                          final r = _result!;
                          final first = widget.entries.first;
                          final entry = MediaEntry(
                            uri: r.uri,
                            name: r.name,
                            durationMs: r.durationMs,
                            size: r.size,
                            width: first.width,
                            height: first.height,
                            dateAdded: DateTime.now(),
                          );
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlayerScreen(entry: entry),
                            ),
                          );
                        },
                        child: Text(t.actionView),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}
