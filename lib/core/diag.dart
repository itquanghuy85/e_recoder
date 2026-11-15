import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One line of the save-path diagnostic: printed, and appended by the Android side to
/// `files/diag.log` (some phones hide an app's logcat lines). Never throws, never awaited by callers.
void diag(String msg) {
  debugPrint('esr.$msg');
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  _send(msg);
}

const _channel = MethodChannel('escreenrecorder/recorder');

Future<void> _send(String msg) async {
  try {
    await _channel.invokeMethod<void>('diag', {'msg': msg});
  } catch (_) {
    // No platform side (tests) or channel not ready: the print above is enough.
  }
}
