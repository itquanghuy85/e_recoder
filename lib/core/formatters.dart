/// 83_000 -> "01:23", 3_725_000 -> "1:02:05". Used with tabular figures.
String formatClock(int ms) {
  final s = ms ~/ 1000;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// Vietnamese decimal comma: 24_500_000 -> "23,4 MB".
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  String f(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  if (bytes >= gb) return '${f(bytes / gb)} GB';
  if (bytes >= mb) return '${f(bytes / mb)} MB';
  if (bytes >= kb) return '${(bytes / kb).round()} KB';
  return '$bytes B';
}

String formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
