import 'dart:io';

import 'package:video_player/video_player.dart';

/// A player on a video the app knows by uri: `content://` on Android (picked from the phone or the
/// media store), a `file://` uri or a plain path on iOS and for the app's own files (`contentUri` is
/// Android-only in video_player).
VideoPlayerController videoControllerFor(
  String uri, {
  VideoPlayerOptions? options,
}) {
  final u = Uri.parse(uri);
  if (u.scheme == 'content') {
    return VideoPlayerController.contentUri(u, videoPlayerOptions: options);
  }
  final path = u.scheme == 'file' ? u.toFilePath() : uri;
  return VideoPlayerController.file(File(path), videoPlayerOptions: options);
}
