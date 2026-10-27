import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

Map<String, dynamic> _arb(String f) =>
    jsonDecode(File('lib/l10n/$f').readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  test('English has exactly the keys of the Vietnamese template', () {
    final vi = _arb('app_vi.arb')..removeWhere((k, _) => k.startsWith('@'));
    final en = _arb('app_en.arb')..removeWhere((k, _) => k.startsWith('@'));
    expect(en.keys.toSet(), vi.keys.toSet());
  });

  test('every translation uses the same placeholders as the template', () {
    final vi = _arb('app_vi.arb');
    final en = _arb('app_en.arb');
    for (final k in vi.keys.where((k) => !k.startsWith('@'))) {
      expect(
        _placeholders(en[k] as String),
        _placeholders(vi[k] as String),
        reason: 'placeholders differ for "$k"',
      );
    }
  });

  testWidgets('English UI when the language is English', (tester) async {
    final (:app, fake: _) = await buildTestApp(locale: const Locale('en'));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.textContaining('1080p · 30 fps · Balanced'), findsOneWidget);
  });
}
