import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'editor_controller.dart';
import 'editor_stage.dart';

/// Full-screen view of the preview: rotates freely, pinch to zoom, with play and a seek bar.
/// It shows the same stage the editor does, so overlays and cuts look exactly as they will export.
Future<void> showEditorFullscreen(
  BuildContext context, {
  required EditorController controller,
  required VideoPlayerController video,
  required Map<String, VideoPlayerController> pipVideos,
  required Listenable? repaint,
  required VoidCallback onToggle,
}) async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  if (!context.mounted) return;
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenPage(
          controller: controller,
          video: video,
          pipVideos: pipVideos,
          repaint: repaint,
          onToggle: onToggle,
        ),
      ),
    );
  } finally {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const []);
  }
}

class _FullscreenPage extends StatefulWidget {
  const _FullscreenPage({
    required this.controller,
    required this.video,
    required this.pipVideos,
    required this.repaint,
    required this.onToggle,
  });
  final EditorController controller;
  final VideoPlayerController video;
  final Map<String, VideoPlayerController> pipVideos;
  final Listenable? repaint;
  final VoidCallback onToggle;

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  bool _controls = true;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => setState(() => _controls = !_controls),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: EditorStage(
                    controller: c,
                    video: widget.video,
                    pipVideos: widget.pipVideos,
                    repaint: widget.repaint,
                  ),
                ),
              ),
            ),
          ),
          if (_controls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) {
                  final total = c.project.outDurationMs;
                  return Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            color: Colors.white,
                            tooltip: c.playing ? t.pauseVideo : t.playVideo,
                            onPressed: widget.onToggle,
                            icon: Icon(
                              c.playing ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                          Text(
                            formatClock(c.outMs),
                            style: timecodeStyle(
                              context,
                              size: 13,
                            ).copyWith(color: Colors.white),
                          ),
                          Expanded(
                            child: Slider(
                              value: c.outMs.clamp(0, total).toDouble(),
                              max: total <= 0 ? 1 : total.toDouble(),
                              onChanged: (v) => c.seekOut(v.round()),
                            ),
                          ),
                          Text(
                            formatClock(total),
                            style: timecodeStyle(
                              context,
                              size: 13,
                            ).copyWith(color: Colors.white70),
                          ),
                          IconButton(
                            color: Colors.white,
                            tooltip: t.exitFullscreen,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.fullscreen_exit),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
