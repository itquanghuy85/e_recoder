import 'dart:convert';
import 'dart:typed_data';

/// One subtitle line: shown from [startMs] to [endMs] (milliseconds).
typedef SubtitleCue = ({int startMs, int endMs, String text});

final _timeLine = RegExp(
  r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
);

int _ms(String h, String m, String s, String f) =>
    ((int.parse(h) * 60 + int.parse(m)) * 60 + int.parse(s)) * 1000 +
    int.parse(f.padRight(3, '0'));

/// Parses SubRip (.srt) text. Tolerant: BOM, CRLF, '.' instead of ',', a missing index line,
/// simple <i>/<b>/{\an8} tags. Cues that end before they start are dropped. Result is time-ordered.
List<SubtitleCue> parseSrt(String raw) {
  final text = raw
      .replaceFirst('﻿', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final out = <SubtitleCue>[];
  for (final block in text.split(RegExp(r'\n\s*\n'))) {
    final lines = block.split('\n');
    final at = lines.indexWhere(_timeLine.hasMatch);
    if (at < 0) continue;
    final m = _timeLine.firstMatch(lines[at])!;
    final start = _ms(m[1]!, m[2]!, m[3]!, m[4]!);
    final end = _ms(m[5]!, m[6]!, m[7]!, m[8]!);
    final body = lines
        .skip(at + 1)
        .join('\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\{\\[^}]*\}'), '')
        .trim();
    if (body.isEmpty || end <= start) continue;
    out.add((startMs: start, endMs: end, text: body));
  }
  out.sort((a, b) => a.startMs.compareTo(b.startMs));
  return out;
}

/// Text of a subtitle file from its bytes. Editors save SRT as UTF-8 (with or without a BOM) or UTF-16
/// (Windows Notepad's "Unicode"); anything that is not valid UTF-8 is read as Latin-1 so the timings
/// still parse (accents may then be wrong, which the person sees and fixes in the panel).
String decodeSubtitleBytes(Uint8List b) {
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) return _utf16(b, 2, true);
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) return _utf16(b, 2, false);
  final start = b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF
      ? 3
      : 0;
  try {
    return utf8.decode(b.sublist(start));
  } on FormatException {
    return latin1.decode(b.sublist(start));
  }
}

String _utf16(Uint8List b, int from, bool little) {
  final units = <int>[];
  for (var i = from; i + 1 < b.length; i += 2) {
    units.add(little ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
  }
  return String.fromCharCodes(units);
}
