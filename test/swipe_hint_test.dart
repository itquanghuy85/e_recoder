import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/features/editor/swipe_hint.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The picture's Stack with the hint in it, as in the editor.
Future<void> _pump(WidgetTester t, SettingsStore store) => t.pumpWidget(
  ProviderScope(
    overrides: [settingsStoreProvider.overrideWithValue(store)],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: const [
                  Positioned.fill(
                    child: ColoredBox(
                      key: ValueKey('picture'),
                      color: Colors.red,
                    ),
                  ),
                  SwipeHint(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  Future<SettingsStore> store(Map<String, Object> v) async {
    SharedPreferences.setMockInitialValues(v);
    return SettingsStore.load();
  }

  testWidgets(
    'the first times it shows, then fades; the picture never shrinks',
    (t) async {
      final s = await store({});
      await _pump(t, s);
      final full = t.getSize(find.byKey(const ValueKey('picture')));
      expect(full.width, greaterThan(300));
      expect(find.textContaining('Vuốt xuống'), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
      expect(find.textContaining('Vuốt xuống'), findsNothing);
      // the case that blanked the picture: the hint gone, the Stack must keep its size
      expect(t.getSize(find.byKey(const ValueKey('picture'))), full);
    },
  );

  testWidgets('after three times it is not shown, and the picture is whole', (
    t,
  ) async {
    final s = await store({'editor.swipeHints': 3});
    await _pump(t, s);
    expect(find.textContaining('Vuốt xuống'), findsNothing);
    final size = t.getSize(find.byKey(const ValueKey('picture')));
    expect(size.width, greaterThan(300));
    expect(size.height, greaterThan(300));
  });

  testWidgets('it counts how many times it was shown', (t) async {
    final s = await store({});
    await _pump(t, s);
    await t.pump(const Duration(seconds: 6));
    expect(s.getInt('editor.swipeHints', 0), 1);
  });
}
