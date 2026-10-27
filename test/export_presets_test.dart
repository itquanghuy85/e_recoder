import 'package:e_screen_recorder/features/editor/export_presets.dart';
import 'package:e_screen_recorder/features/editor/picture_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('output size', () {
    test('the quality figure is the short side and never upscales', () {
      expect(ExportPlanner.sizeFor(1080, 2400, ExportQuality.p720), (
        720,
        1600,
      ));
      expect(ExportPlanner.sizeFor(720, 1600, ExportQuality.p1080), (
        720,
        1600,
      ));
      expect(ExportPlanner.sizeFor(1600, 720, ExportQuality.p480), (1066, 480));
      expect(ExportPlanner.sizeFor(721, 1601, ExportQuality.original), (
        720,
        1600,
      ));
    });

    test('sizes are even', () {
      final (w, h) = ExportPlanner.sizeFor(1079, 2399, ExportQuality.p480);
      expect(w % 2, 0);
      expect(h % 2, 0);
    });
  });

  group('plan', () {
    test('without a cap the bitrate follows the pixels', () {
      final p = ExportPlanner.plan(
        frameW: 720,
        frameH: 1600,
        durationMs: 60000,
        quality: ExportQuality.original,
      );
      expect(p.bitrate, ExportPlanner.defaultBitrate(720, 1600));
      expect(p.fitsCap, isTrue);
    });

    test('a short video fits the share cap at full quality', () {
      final p = ExportPlanner.plan(
        frameW: 720,
        frameH: 1600,
        durationMs: 20000,
        quality: ExportQuality.p720,
        maxBytes: 24 * 1024 * 1024,
      );
      expect(p.estimatedBytes, lessThanOrEqualTo(24 * 1024 * 1024));
      expect(p.bitrate, ExportPlanner.defaultBitrate(720, 1600));
      expect(p.fitsCap, isTrue);
    });

    test('a long video is squeezed to meet the cap', () {
      final p = ExportPlanner.plan(
        frameW: 1080,
        frameH: 2400,
        durationMs: 5 * 60 * 1000,
        quality: ExportQuality.p720,
        maxBytes: 24 * 1024 * 1024,
      );
      expect(p.bitrate, lessThan(ExportPlanner.defaultBitrate(720, 1600)));
      expect(p.estimatedBytes, lessThanOrEqualTo(24 * 1024 * 1024 * 1.02));
      expect(p.fitsCap, isTrue);
    });

    test('an hour cannot fit 24 MB: the cap is reported as missed', () {
      final p = ExportPlanner.plan(
        frameW: 720,
        frameH: 1600,
        durationMs: 60 * 60 * 1000,
        quality: ExportQuality.p480,
        maxBytes: 24 * 1024 * 1024,
      );
      expect(p.bitrate, ExportPlanner.minVideoBitrate);
      expect(p.fitsCap, isFalse);
    });
  });

  group('presets', () {
    test('vertical asks for 9:16, share has a cap, gif is gif', () {
      expect(PresetSpec.of(ExportPreset.vertical).aspect, OutAspect.r9x16);
      expect(PresetSpec.of(ExportPreset.share).maxBytes, isNotNull);
      expect(PresetSpec.of(ExportPreset.gif).gif, isTrue);
      expect(PresetSpec.of(ExportPreset.custom).aspect, isNull);
    });
  });
}
