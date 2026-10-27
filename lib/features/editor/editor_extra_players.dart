import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'edit_project.dart';
import 'editor_controller.dart';

/// The players that sound or show things besides the main video while the editor plays: music and
/// voice-over tracks, and picture-in-picture videos. They follow the OUTPUT time kept by the
/// playback driver; the main video player is not involved.
class ExtraPlayers extends ChangeNotifier {
  ExtraPlayers(this.c) {
    c.addListener(_onController);
    _onController();
  }

  final EditorController c;

  /// Picture-in-picture video players by item id (the stage draws them).
  final Map<String, VideoPlayerController> pips = {};
  final Map<String, VideoPlayerController> _audio = {};
  final Set<String> _starting = {};
  final Map<String, int> _lastSeekAt = {};
  bool _disposed = false;
  bool _wasPlaying = false;

  Future<void> _open(
    String id,
    String path,
    Map<String, VideoPlayerController> into,
  ) async {
    if (_starting.contains(id) || into.containsKey(id)) return;
    _starting.add(id);
    final v = VideoPlayerController.file(File(path));
    try {
      await v.initialize();
      if (_disposed || !_wanted(id)) {
        await v.dispose();
        return;
      }
      await v.setLooping(false);
      into[id] = v;
      notifyListeners();
    } catch (_) {
      await v.dispose();
    } finally {
      _starting.remove(id);
    }
  }

  bool _wanted(String id) =>
      c.project.audioTracks.any((a) => a.id == id) ||
      c.project.pips.any((p) => p.id == id && p.isVideo);

  void _onController() {
    if (_disposed) return;
    final p = c.project;
    for (final a in p.audioTracks) {
      _open(a.id, a.path, _audio);
    }
    for (final pip in p.pips.where((e) => e.isVideo)) {
      _open(pip.id, pip.path, pips);
    }
    for (final k in _audio.keys.toList()) {
      if (!p.audioTracks.any((a) => a.id == k)) {
        unawaited(_audio.remove(k)?.dispose());
      }
    }
    for (final k in pips.keys.toList()) {
      if (!p.pips.any((e) => e.id == k && e.isVideo)) {
        unawaited(pips.remove(k)?.dispose());
        notifyListeners();
      }
    }
    _follow(p);
  }

  /// Voice-over spans (output time) that lower the music.
  List<(int, int)> _duckRanges(EditProject p) {
    final total = p.outDurationMs;
    return [
      for (final a in p.audioTracks)
        if (a.kind == AudioKind.voice && a.playMs(total) > 0)
          (a.startOutMs, a.startOutMs + a.playMs(total)),
    ];
  }

  void _follow(EditProject p) {
    final out = c.outMs;
    final total = p.outDurationMs;
    final playing = c.playing;
    final duck = _duckRanges(p);
    final now = DateTime.now().millisecondsSinceEpoch;

    Future<void> drive(
      VideoPlayerController v,
      String id, {
      required int startOut,
      required int playLen,
      required int trim,
      required double volume,
      required bool scrubFrame,
    }) async {
      final inside = out >= startOut && out < startOut + playLen;
      final want = trim + (out - startOut);
      if (playing && inside) {
        final pos = v.value.position.inMilliseconds;
        final drift = (pos - want).abs();
        // Start, or catch up when the player has wandered off by more than a moment.
        if (!v.value.isPlaying || drift > 450) {
          if (now - (_lastSeekAt[id] ?? 0) > 250) {
            _lastSeekAt[id] = now;
            await v.seekTo(Duration(milliseconds: want));
          }
          if (!v.value.isPlaying) await v.play();
        }
        await v.setVolume(volume.clamp(0.0, 1.0));
      } else {
        if (v.value.isPlaying) await v.pause();
        // Paused on a frame: show the frame at the playhead (picture-in-picture only).
        if (scrubFrame && inside && now - (_lastSeekAt[id] ?? 0) > 120) {
          _lastSeekAt[id] = now;
          await v.seekTo(Duration(milliseconds: want));
        }
      }
    }

    for (final a in p.audioTracks) {
      final v = _audio[a.id];
      if (v == null || !v.value.isInitialized) continue;
      final len = a.playMs(total);
      final inside = out >= a.startOutMs && out < a.startOutMs + len;
      unawaited(
        drive(
          v,
          a.id,
          startOut: a.startOutMs,
          playLen: len,
          trim: a.trimStartMs,
          volume: inside ? a.gainAt(out - a.startOutMs, len, duck) : 0,
          scrubFrame: false,
        ),
      );
      // A looping music track restarts when the file ends.
      if (playing && inside && a.loop && v.value.position >= v.value.duration) {
        unawaited(v.seekTo(Duration(milliseconds: a.trimStartMs)));
      }
    }
    for (final pip in p.pips.where((e) => e.isVideo)) {
      final v = pips[pip.id];
      if (v == null || !v.value.isInitialized) continue;
      unawaited(
        drive(
          v,
          pip.id,
          startOut: pip.startOutMs,
          playLen: pip.playMs(total),
          trim: pip.trimStartMs,
          volume: pip.volume,
          scrubFrame: true,
        ),
      );
    }
    if (_wasPlaying && !playing) {
      // Playback stopped: everything stops with it.
      for (final v in [..._audio.values, ...pips.values]) {
        if (v.value.isPlaying) unawaited(v.pause());
      }
    }
    _wasPlaying = playing;
  }

  @override
  void dispose() {
    _disposed = true;
    c.removeListener(_onController);
    for (final v in [..._audio.values, ...pips.values]) {
      unawaited(v.dispose());
    }
    _audio.clear();
    pips.clear();
    super.dispose();
  }
}
