import 'package:e_screen_recorder/features/editor/caption_models.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordTiming.progressAt', () {
    const w = WordTiming(text: 'xin', startMs: 1000, endMs: 2000);

    test('before the word is 0', () => expect(w.progressAt(500), 0));
    test('at the start is 0', () => expect(w.progressAt(1000), 0));
    test('in the middle is half', () => expect(w.progressAt(1500), 0.5));
    test('at the end is 1', () => expect(w.progressAt(2000), 1));
    test('after the word is 1', () => expect(w.progressAt(5000), 1));

    test('a zero-length word is either 0 or 1', () {
      const z = WordTiming(text: 'a', startMs: 500, endMs: 500);
      expect(z.progressAt(499), 0);
      expect(z.progressAt(500), 1);
    });
  });

  group('WordTiming.charProgressAt', () {
    // Four characters over 400 ms: each character owns a 100 ms slice.
    const w = WordTiming(text: 'abcd', startMs: 0, endMs: 400);

    test('first character is due at the start and done at 100 ms', () {
      expect(w.charProgressAt(0, 0), 0);
      expect(w.charProgressAt(50, 0), 0.5);
      expect(w.charProgressAt(100, 0), 1);
    });

    test('middle character covers its own slice', () {
      expect(w.charProgressAt(199, 2), 0);
      expect(w.charProgressAt(250, 2), 0.5);
      expect(w.charProgressAt(300, 2), 1);
    });

    test('last character finishes with the word', () {
      expect(w.charProgressAt(399, 3), 0.99);
      expect(w.charProgressAt(400, 3), 1);
      expect(w.charProgressAt(1000, 3), 1);
    });

    test('out-of-range indexes clamp', () {
      expect(w.charProgressAt(50, -5), w.charProgressAt(50, 0));
      expect(w.charProgressAt(50, 99), w.charProgressAt(50, 3));
    });
  });

  group('CaptionCue', () {
    const cue = CaptionCue(
      text: 'xin chào',
      startMs: 1000,
      endMs: 3000,
      words: [
        WordTiming(text: 'xin', startMs: 1000, endMs: 1800),
        WordTiming(text: 'chào', startMs: 1800, endMs: 3000),
      ],
    );

    test('is active from the start (inclusive) to the end (exclusive)', () {
      expect(cue.isActiveAt(999), isFalse);
      expect(cue.isActiveAt(1000), isTrue);
      expect(cue.isActiveAt(2999), isTrue);
      expect(cue.isActiveAt(3000), isFalse);
    });

    test('survives a JSON round trip', () {
      final back = CaptionCue.fromJson(cue.toJson());
      expect(back.text, cue.text);
      expect(back.startMs, cue.startMs);
      expect(back.endMs, cue.endMs);
      expect(back.words.length, 2);
      expect(back.words[1].text, 'chào');
      expect(back.words[1].startMs, 1800);
      expect(back.words[1].endMs, 3000);
      expect(back.words[1].progressAt(2400), 0.5);
    });

    test('missing words decode as an empty list', () {
      final back = CaptionCue.fromJson({
        'text': 'a',
        'startMs': 0,
        'endMs': 500,
      });
      expect(back.words, isEmpty);
    });

    test('splitEvenly keeps every word and the whole duration', () {
      final words = CaptionCue.splitEvenly('  một  hai ba ', 900, startMs: 100);
      expect(words.map((e) => e.text), ['một', 'hai', 'ba']);
      expect(words.first.startMs, 100);
      expect(words.last.endMs, 1000);
      // No gaps and no overlaps.
      for (var i = 1; i < words.length; i++) {
        expect(words[i].startMs, words[i - 1].endMs);
      }
    });

    test('splitEvenly handles an empty text', () {
      expect(CaptionCue.splitEvenly('   ', 1000), isEmpty);
    });
  });

  group('CaptionStyle', () {
    test('JSON round trip keeps every field', () {
      const s = CaptionStyle(
        fontId: 'inter',
        sizeU: 34,
        color: 0xFFFFD700,
        outlineColor: 0xFF000000,
        outlineWidth: 2,
        shadowColor: 0x99000000,
        shadowBlur: 6,
        boxColor: 0xB3000000,
        boxRadius: 8,
        align: 'left',
        x: 0.2,
        y: 0.9,
        revealMode: RevealMode.karaokeHighlight,
        templateId: 'tiktok-yellow',
      );
      final back = CaptionStyle.fromJson(s.toJson());
      expect(back.fontId, 'inter');
      expect(back.sizeU, 34);
      expect(back.color, 0xFFFFD700);
      expect(back.outlineColor, 0xFF000000);
      expect(back.outlineWidth, 2);
      expect(back.shadowColor, 0x99000000);
      expect(back.shadowBlur, 6);
      expect(back.boxColor, 0xB3000000);
      expect(back.boxRadius, 8);
      expect(back.align, 'left');
      expect(back.x, 0.2);
      expect(back.y, 0.9);
      expect(back.revealMode, RevealMode.karaokeHighlight);
      expect(back.templateId, 'tiktok-yellow');
    });

    test('copyWith can clear optional colours', () {
      const s = CaptionStyle(boxColor: 0xB3000000, outlineColor: 0xFF000000);
      final n = s.copyWith(boxColor: null, outlineColor: null);
      expect(n.boxColor, isNull);
      expect(n.outlineColor, isNull);
    });
  });

  group('TextItem with captions', () {
    const base = TextItem(
      id: 't',
      text: 'hello',
      startMs: 0,
      endMs: 2000,
      fx: TextFx.glow,
    );

    test('no cues: the native payload and JSON look exactly like before', () {
      final native = base.toNative();
      expect(native.containsKey('cues'), isFalse);
      expect(native.containsKey('captionStyle'), isFalse);
      expect(native['fx'], 'glow');

      final back = TextItem.fromJson(base.toJson());
      expect(back.text, 'hello');
      expect(back.fx, TextFx.glow);
      expect(back.cues, isNull);
      expect(back.captionStyle, isNull);
      expect(back.toNative(), base.toNative());
      expect(back.lookKey, base.lookKey);
    });

    test('cues and style survive a JSON round trip', () {
      const cue = CaptionCue(
        text: 'xin chào',
        startMs: 0,
        endMs: 1000,
        words: [WordTiming(text: 'xin', startMs: 0, endMs: 500)],
      );
      const style = CaptionStyle(revealMode: RevealMode.charByChar);
      final item = base.copyWith(
        cues: const [cue],
        captionStyle: style,
      );
      final back = TextItem.fromJson(item.toJson());
      expect(back.cues, isNotNull);
      expect(back.cues!.single.text, 'xin chào');
      expect(back.cues!.single.words.single.text, 'xin');
      expect(back.captionStyle!.revealMode, RevealMode.charByChar);
      expect(back.toNative()['cues'], isA<List<Object>>());
      expect(back.toNative()['captionStyle'], isA<Map<String, Object?>>());
      expect(back.lookKey, item.lookKey);
    });

    test('clearing cues is possible only through a fresh TextItem', () {
      final item = base.copyWith(
        cues: const [CaptionCue(text: 'a', startMs: 0, endMs: 100)],
      );
      expect(item.cues, isNotNull);
      // copyWith without cues keeps them (same convention as every other field).
      expect(item.copyWith(text: 'b').cues, isNotNull);
    });
  });
}
