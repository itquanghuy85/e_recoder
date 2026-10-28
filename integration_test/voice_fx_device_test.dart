// Runs every voice effect and noise level on real files on the device (the native audio code:
// MediaCodec decode, Sonic pitch, DSP, AAC encode) and prints where each result went.
//
//   scripts/qa/voice_fx_check.sh <serial>      (makes the sources, runs this, analyses the results)
import 'dart:io';

import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every effect and noise level on every source', (t) async {
    final dir = await getApplicationSupportDirectory();
    final sources = ['it_tone', 'it_noisy', 'it_speech'];
    for (var i = 0; i < 120; i++) {
      if (sources.every((s) => File('${dir.path}/$s.m4a').existsSync())) break;
      if (i == 0) {
        // ignore: avoid_print
        print('STEP need_voice');
      }
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
    }
    final native = NativeRecorder();
    final fxs = ['none', 'deep', 'high', 'chipmunk', 'robot', 'echo', 'reverb'];
    final dns = ['off', 'light', 'strong'];
    await t.runAsync(() async {
      for (final s in sources) {
        final src = '${dir.path}/$s.m4a';
        for (final fx in fxs) {
          for (final dn in dns) {
            if (fx == 'none' && dn == 'off') continue;
            // The effects matter on the tone, the noise on the noisy file, everything on speech.
            if (s == 'it_tone' && dn != 'off') continue;
            if (s == 'it_noisy' && fx != 'none' && fx != 'deep') continue;
            final sw = Stopwatch()..start();
            final out = await native.processVoice(src, fx, dn);
            // ignore: avoid_print
            print('OUT $s $fx $dn $out ${sw.elapsedMilliseconds}ms');
            expect(File(out).existsSync(), isTrue);
          }
        }
      }
      // asking again is instant and returns the same file
      final a = await native.processVoice(
        '${dir.path}/it_speech.m4a',
        'robot',
        'light',
      );
      final sw = Stopwatch()..start();
      final b = await native.processVoice(
        '${dir.path}/it_speech.m4a',
        'robot',
        'light',
      );
      expect(b, a);
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
    // ignore: avoid_print
    print('STEP done');
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 12)));
  });
}
