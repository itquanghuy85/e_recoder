import 'dart:convert';
import 'dart:typed_data';

import 'package:e_screen_recorder/features/editor/srt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const srt =
      '1\n00:00:01,000 --> 00:00:03,000\nXin chào\n\n'
      '2\n00:00:04,000 --> 00:00:06,000\nTạm biệt\n\n'
      '3\n00:00:07,000 --> 00:00:09,000\nCảm ơn\n';

  void expectThree(String text) {
    final cues = parseSrt(text);
    expect(cues.map((e) => e.text), ['Xin chào', 'Tạm biệt', 'Cảm ơn']);
    expect(cues.first.startMs, 1000);
    expect(cues.last.endMs, 9000);
  }

  test(
    'plain UTF-8',
    () =>
        expectThree(decodeSubtitleBytes(Uint8List.fromList(utf8.encode(srt)))),
  );

  test('UTF-8 with a BOM', () {
    expectThree(
      decodeSubtitleBytes(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(srt)]),
      ),
    );
  });

  test('UTF-16 little endian with a BOM (Windows "Unicode")', () {
    final units = srt.codeUnits;
    final b = <int>[0xFF, 0xFE];
    for (final u in units) {
      b
        ..add(u & 0xFF)
        ..add(u >> 8);
    }
    expectThree(decodeSubtitleBytes(Uint8List.fromList(b)));
  });

  test('UTF-16 big endian with a BOM', () {
    final b = <int>[0xFE, 0xFF];
    for (final u in srt.codeUnits) {
      b
        ..add(u >> 8)
        ..add(u & 0xFF);
    }
    expectThree(decodeSubtitleBytes(Uint8List.fromList(b)));
  });

  test('bytes that are not UTF-8 still give the timings', () {
    // "Tạm biệt" in a legacy 8-bit code page: 0xE1 0xBA alone is not valid UTF-8.
    final b = Uint8List.fromList([
      ...latin1.encode('1\n00:00:01,000 --> 00:00:02,000\nT'),
      0xE1,
      ...latin1.encode('m\n'),
    ]);
    final cues = parseSrt(decodeSubtitleBytes(b));
    expect(cues.single.startMs, 1000);
    expect(cues.single.endMs, 2000);
  });

  test('CRLF line ends and a missing index line parse', () {
    final cues = parseSrt(
      '00:00:01,000 --> 00:00:02,000\r\nMot\r\n\r\n00:00:03,000 --> 00:00:04,000\r\nHai\r\n',
    );
    expect(cues.map((e) => e.text), ['Mot', 'Hai']);
  });
}
