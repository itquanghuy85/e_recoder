import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/formatters.dart';
import '../../core/native_recorder.dart';
import '../../core/video_source.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../editor/editor_screen.dart';
import '../record/recorder_controller.dart';

/// Plays a saved recording. Editing opens from here from G3 on.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.entry});
  final MediaEntry entry;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final VideoPlayerController _c = videoControllerFor(widget.entry.uri);
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    });
    _c
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final c = Theme.of(context).colorScheme;
    final v = _c.value;
    final total = v.duration.inMilliseconds;
    final pos = v.position.inMilliseconds.clamp(0, total == 0 ? 1 : total);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
        actions: [
          Semantics(
            identifier: 'player_edit',
            child: IconButton(
              tooltip: t.menuEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _c.pause();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditorScreen(entry: widget.entry),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: t.menuShare,
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                ref.read(nativeRecorderProvider).share(widget.entry.uri),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _failed
                  ? Center(child: Text(t.playerError))
                  : !v.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : GestureDetector(
                      onTap: () => v.isPlaying ? _c.pause() : _c.play(),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: v.aspectRatio,
                          child: VideoPlayer(_c),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.sm,
                Space.sm,
                Space.lg,
                Space.lg,
              ),
              child: Row(
                children: [
                  Semantics(
                    identifier: 'player_toggle',
                    child: IconButton.filled(
                      key: const ValueKey('player_toggle'),
                      tooltip: v.isPlaying ? t.pauseVideo : t.playVideo,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(56, 56),
                      ),
                      icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: v.isInitialized
                          ? () => v.isPlaying ? _c.pause() : _c.play()
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: pos.toDouble(),
                      max: (total == 0 ? 1 : total).toDouble(),
                      onChanged: v.isInitialized
                          ? (x) => _c.seekTo(Duration(milliseconds: x.round()))
                          : null,
                    ),
                  ),
                  Text(
                    '${formatClock(pos)} / ${formatClock(total)}',
                    style: timecodeStyle(context)
                        .copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
