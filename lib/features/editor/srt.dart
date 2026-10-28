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
