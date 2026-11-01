import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'caption_models.dart';

/// A ready-made caption look the person applies with one tap. Loaded from
/// `assets/caption_templates.json` (the schema is documented on [CaptionStyle.fromJson]).
class CaptionTemplate {
  const CaptionTemplate({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.hint,
    required this.hintEn,
    required this.style,
  });

  final String id;
  final String name;
  final String nameEn;
  final String hint;
  final String hintEn;

  /// The look. Its `templateId` is [id], so the picker can mark the one in use.
  final CaptionStyle style;

  /// Name / hint in the app language ("vi" is the template language, anything else uses English).
  String nameFor(String languageCode) => languageCode == 'vi' ? name : nameEn;
  String hintFor(String languageCode) => languageCode == 'vi' ? hint : hintEn;

  factory CaptionTemplate.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final name = j['name'] as String? ?? id;
    final hint = j['hint'] as String? ?? '';
    final style = CaptionStyle.fromJson(
      (j['style'] as Map<String, dynamic>?) ?? const {},
    );
    return CaptionTemplate(
      id: id,
      name: name,
      nameEn: j['nameEn'] as String? ?? name,
      hint: hint,
      hintEn: j['hintEn'] as String? ?? hint,
      style: style.copyWith(templateId: id),
    );
  }

  /// Parses the template file. An entry that cannot be read is skipped, so one bad entry never hides
  /// the others.
  static List<CaptionTemplate> parseAll(String source) {
    final raw = jsonDecode(source);
    if (raw is! List) return const [];
    final out = <CaptionTemplate>[];
    for (final e in raw) {
      try {
        out.add(CaptionTemplate.fromJson(e as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static List<CaptionTemplate>? _cache;

  /// The bundled templates, read once.
  static Future<List<CaptionTemplate>> load({AssetBundle? bundle}) async {
    final cached = _cache;
    if (cached != null && bundle == null) return cached;
    final text = await (bundle ?? rootBundle).loadString(
      'assets/caption_templates.json',
    );
    final all = parseAll(text);
    if (bundle == null) _cache = all;
    return all;
  }
}
