import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:video_player/video_player.dart';

import 'edit_project.dart';
import 'editor_controller.dart';

/// What the driver needs from a video player (a fake in the tests).
abstract class PlayerPort {
  Future<void> seekTo(int ms);
  Future<void> play();
  Future<void> pause();
  Future<int?> positionMs();
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
}

class VideoPlayerPort implements PlayerPort {
  VideoPlayerPort(this.v);
  final VideoPlayerController v;

  @override
  Future<void> seekTo(int ms) => v.seekTo(Duration(milliseconds: ms));
  @override
  Future<void> play() => v.play();
  @override
  Future<void> pause() => v.pause();
  @override
  Future<int?> positionMs() async => (await v.position)?.inMilliseconds;
  @override
  Future<void> setSpeed(double speed) => v.setPlaybackSpeed(speed);
  @override
  Future<void> setVolume(double volume) => v.setVolume(volume.clamp(0.0, 1.0));
}

/// Plays the EDITED video by driving a player that holds the ORIGINAL file: it walks the segments
/// in sequence order, jumps between them, follows speed ramps, steps backwards through reversed
/// clips and holds freeze frames and blanks. The output time always comes from here, so the
/// playhead, the timeline and the overlays agree whatever the segments look like.
///
/// Only forward clips are timed by the player's own position; stills and reversed clips are timed
/// by a wall clock (a player cannot run backwards or pause on a frame while time passes).
class PlaybackDriver {
  PlaybackDriver({
    required this.controller,
    required this.player,
    int Function()? nowMs,
    this.tickEvery = const Duration(milliseconds: 40),
    this.onExtraPlay,
    this.onExtraPause,
  }) : _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final EditorController controller;
  final PlayerPort player;
  final int Function() _now;
  final Duration tickEvery;

  /// Extra audio tracks (music, voice-over) start and stop with playback: called with the output
  /// time at which playback starts / stops.
  final Future<void> Function(int outMs)? onExtraPlay;
  final Future<void> Function()? onExtraPause;

  Timer? _timer;
  bool _busy = false;
  int _i = 0;
  int _segStartOut = 0;

  // wall clock of a still / reversed segment
  int _wallBase = 0;
  int _wallStart = 0;
  int _lastReverseSeekSource = -1;
  bool _reverseSeeking = false;

  double _appliedSpeed = -1;
  double _appliedVolume = -1;

  EditorController get c => controller;
  EditProject get _p => c.project;
  bool get running => _timer != null;

  Future<void> toggle() => _locked(() => c.playing ? _pause() : _play());

  Future<void> play() => _locked(_play);

  Future<void> pause() => _locked(_pause);

  /// True while a play/pause is being carried out (the button shows it instead of looking dead).
  final busy = ValueNotifier<bool>(false);
  Future<void> _gate = Future.value();
  int _queued = 0;
  bool _disposed = false;

  /// Play and pause run one after the other: a tap that arrives while the previous one is still
  /// seeking would otherwise leave the player running under a paused screen (or the other way round).
  /// Taps beyond one waiting are dropped (a toggle fired ten times in a row stays one waiting).
  Future<void> _locked(Future<void> Function() f) {
    if (_queued >= 2) return _gate;
    _queued++;
    busy.value = true;
    final run = _gate.then((_) async {
      try {
        await f();
      } catch (_) {
        // Whatever the player said, the screen must not stay in "playing" with nothing running.
        _timer?.cancel();
        _timer = null;
        c.setPlaying(false);
        try {
          await player.pause();
        } catch (_) {}
      } finally {
        _queued--;
        if (_queued == 0 && !_disposed) busy.value = false;
      }
    });
    _gate = run;
    return run;
  }

  Future<void> _play() async {
    if (c.playing) return;
    if (c.outMs >= _p.outDurationMs - 50) c.seekOut(0);
    c.setPlaying(true);
    await _enter(_p.segmentAtOut(c.outMs), c.outMs);
    await onExtraPlay?.call(c.outMs);
    _timer?.cancel();
    _timer = Timer.periodic(tickEvery, (_) => tick());
  }

  Future<void> _pause() async {
    _timer?.cancel();
    _timer = null;
    c.setPlaying(false);
    await player.pause();
    await onExtraPause?.call();
  }

  /// Positions the player on the frame of output time [out] (scrubbing while paused).
  Future<void> showFrame(int out) async {
    await player.seekTo(_p.outToSource(out));
  }

  Future<void> _enter(int i, int out) async {
    final p = _p;
    if (i < 0 || i >= p.segments.length) return;
    final s = p.segments[i];
    _i = i;
    _segStartOut = p.segmentOutStarts[i];
    final local = (out - _segStartOut).clamp(0, s.outLengthMs);
    _appliedSpeed = -1;
    _appliedVolume = -1;
    _wallBase = local;
    _wallStart = _now();
    _lastReverseSeekSource = -1;
    if (s.isStill || s.reverse) {
      await player.pause();
      await player.seekTo(s.sourceAtOut(local));
      await _volume(0);
    } else {
      await player.seekTo(s.sourceAtOut(local));
      await _applyForward(s, s.sourceAtOut(local) - s.startMs, local);
      await player.play();
    }
  }

  Future<void> _volume(double g) async {
    if ((g - _appliedVolume).abs() < 0.01) return;
    _appliedVolume = g;
    await player.setVolume(g);
  }

  Future<void> _applyForward(Segment s, int playOffset, int local) async {
    final v = s.speedAtPlay(playOffset.toDouble());
    if (v != _appliedSpeed) {
      _appliedSpeed = v;
      await player.setSpeed(v);
    }
    await _volume(_p.gainOf(s, local));
  }

  /// One step of playback. Public so tests can drive it without timers.
  Future<void> tick() async {
    if (_busy || !c.playing) return;
    _busy = true;
    try {
      await _tick();
    } finally {
      _busy = false;
    }
  }

  Future<void> _tick() async {
    final p = _p;
    if (_i >= p.segments.length) {
      await _finish();
      return;
    }
    final s = p.segments[_i];
    final len = s.outLengthMs;
    int local;
    if (s.isStill || s.reverse) {
      local = _wallBase + (_now() - _wallStart);
      if (s.reverse && !s.isStill) {
        final src = s.sourceAtOut(local.clamp(0, len));
        if (!_reverseSeeking && (src - _lastReverseSeekSource).abs() >= 30) {
          _lastReverseSeekSource = src;
          _reverseSeeking = true;
          unawaited(
            player.seekTo(src).whenComplete(() => _reverseSeeking = false),
          );
        }
      }
    } else {
      final pos = await player.positionMs();
      if (pos == null || !c.playing) return;
      final offset = (pos - s.startMs).clamp(0, s.lengthMs);
      local = s.outAtPlay(offset.toDouble()).round();
      await _applyForward(s, offset, local);
      // Reached the end of this clip (the player stops a few ms early).
      if (pos >= s.endMs - 35) local = len;
    }
    if (local >= len - 15) {
      final next = _i + 1;
      if (next < p.segments.length) {
        c.setOutFromPlayer(_segStartOut + len);
        await _enter(next, _segStartOut + len);
      } else {
        await _finish();
      }
      return;
    }
    c.setOutFromPlayer(_segStartOut + local);
  }

  Future<void> _finish() async {
    await _pause();
    c.seekOut(_p.outDurationMs);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
