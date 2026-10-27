import 'package:e_screen_recorder/core/formatters.dart';
import 'package:e_screen_recorder/features/record/rec_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecSettings.plan', () {
    test('scales a 1080x2400 screen to a 720 short side', () {
      const s = RecSettings(resolution: Resolution.p720);
      final p = s.plan(1080, 2400);
      expect(p.width, 720);
      expect(p.height, 1600);
    });

    test('never upscales', () {
      const s = RecSettings(resolution: Resolution.p1080);
      final p = s.plan(720, 1600);
      expect((p.width, p.height), (720, 1600));
    });

    test('native keeps the display size', () {
      const s = RecSettings(resolution: Resolution.native);
      final p = s.plan(1440, 3200);
      expect((p.width, p.height), (1440, 3200));
    });

    test('landscape uses the short side too', () {
      const s = RecSettings(resolution: Resolution.p720);
      final p = s.plan(2400, 1080);
      expect((p.width, p.height), (1600, 720));
    });

    test('bitrate grows with fps and quality and stays inside the clamp', () {
      const base = RecSettings(
        resolution: Resolution.p1080,
        quality: Quality.balanced,
      );
      final b30 = base.plan(1080, 2400).bitrate;
      final b60 = base.copyWith(fps: 60).plan(1080, 2400).bitrate;
      final high = base
          .copyWith(quality: Quality.high)
          .plan(1080, 2400)
          .bitrate;
      expect(b60, greaterThan(b30));
      expect(high, greaterThan(b30));
      final huge = const RecSettings(
        resolution: Resolution.native,
        fps: 60,
        quality: Quality.high,
      ).plan(4000, 8000);
      expect(huge.bitrate, 25000000);
      final tiny = const RecSettings(quality: Quality.low).plan(100, 100);
      expect(tiny.bitrate, 1500000);
    });

    test('audio mode flags', () {
      expect(const RecSettings(audio: AudioMode.both).mic, isTrue);
      expect(const RecSettings(audio: AudioMode.both).system, isTrue);
      expect(const RecSettings(audio: AudioMode.none).mic, isFalse);
      expect(const RecSettings(audio: AudioMode.system).mic, isFalse);
    });
  });

  group('formatters', () {
    test('clock', () {
      expect(formatClock(0), '00:00');
      expect(formatClock(83000), '01:23');
      expect(formatClock(3725000), '1:02:05');
    });

    test('bytes use a decimal comma', () {
      expect(formatBytes(24 * 1024 * 1024), '24,0 MB');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3,0 GB');
    });
  });
}
