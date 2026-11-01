import '../../core/native_recorder.dart' show SttPiece;
import 'srt.dart';

/// Turns recognised phrases into captions that read well on a phone: at most [maxLines] lines of
/// [maxLine] characters, a long phrase split over several captions that share its time by length,
/// none shorter than [minCueMs] (when its phrase allows) and none overlapping the next.
List<SubtitleCue> layoutCaptions(
  List<SttPiece> pieces, {
  int maxLine = 32,
  int maxLines = 2,
  int minCueMs = 900,
  int gapMs = 40,
  // Spread a long phrase over its captions evenly, so none is left with one stray word.
  bool balance = false,
}) {
  final sorted = [...pieces]..sort((a, b) => a.startMs.compareTo(b.startMs));
  final out = <SubtitleCue>[];
  for (final p in sorted) {
    final words = p.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty || p.endMs <= p.startMs) continue;
    // 1. words into lines, lines into captions
    var caps = _wrap(words, maxLine, maxLines);
    if (balance && caps.length > 1) {
      // Narrowest line width that still needs no more captions than the full width does.
      final total = words.fold<int>(0, (n, w) => n + w.length + 1);
      final longest = words.fold<int>(0, (n, w) => w.length > n ? w.length : n);
      final lowest = (total / (caps.length * maxLines)).ceil();
      for (var w = lowest > longest ? lowest : longest; w < maxLine; w++) {
        final tight = _wrap(words, w, maxLines);
        if (tight.length <= caps.length) {
          caps = tight;
          break;
        }
      }
    }
    // 2. the phrase's time is shared out by text length
    final texts = [for (final c in caps) c.join('\n')];
    final total = texts.fold<int>(0, (s, t) => s + t.length);
    final span = p.endMs - p.startMs;
    var at = p.startMs;
    for (var i = 0; i < texts.length; i++) {
      final share = (span * texts[i].length / total).round();
      final end = i == texts.length - 1 ? p.endMs : at + share;
      out.add((startMs: at, endMs: end, text: texts[i]));
      at = end;
    }
  }
  // 3. no caption too short if there is room, none overlapping the next
  final fixed = <SubtitleCue>[];
  for (var i = 0; i < out.length; i++) {
    var c = out[i];
    final nextStart = i + 1 < out.length ? out[i + 1].startMs : null;
    var end = c.endMs;
    if (end - c.startMs < minCueMs) {
      final want = c.startMs + minCueMs;
      end = nextStart == null ? want : (want < nextStart - gapMs ? want : end);
    }
    if (nextStart != null && end > nextStart - gapMs) {
      end = nextStart - gapMs;
    }
    if (end - c.startMs < 300) end = c.startMs + 300;
    c = (startMs: c.startMs, endMs: end, text: c.text);
    fixed.add(c);
  }
  return fixed;
}

/// [words] into captions of at most [maxLines] lines of [maxLine] characters (a word longer than a
/// line stays whole).
List<List<String>> _wrap(List<String> words, int maxLine, int maxLines) {
  final caps = <List<String>>[];
  var lines = <String>[];
  var line = '';
  void endLine() {
    if (line.isNotEmpty) lines.add(line);
    line = '';
  }

  void endCaption() {
    endLine();
    if (lines.isNotEmpty) caps.add(lines);
    lines = <String>[];
  }

  for (final w in words) {
    final next = line.isEmpty ? w : '$line $w';
    if (next.length <= maxLine || line.isEmpty) {
      line = next;
    } else {
      endLine();
      if (lines.length >= maxLines) endCaption();
      line = w;
    }
  }
  endCaption();
  return caps;
}
