import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/native_recorder.dart';
import '../record/recorder_controller.dart';

/// All recordings in Movies/E Screen Recorder, newest first.
final mediaListProvider = FutureProvider<List<MediaEntry>>((ref) {
  return ref.watch(nativeRecorderProvider).listMedia();
});

/// Thumbnails are cached per URI for the lifetime of the app.
final thumbnailProvider = FutureProvider.family<Uint8List?, String>((ref, uri) {
  ref.keepAlive();
  return ref.watch(nativeRecorderProvider).thumbnail(uri);
});
