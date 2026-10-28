// Screenshots of the main screens on a real device, for before/after comparisons of a visual change.
//
//   scripts/qa/run_integration.sh <serial> integration_test/ui_audit_test.dart build/ui_after
//
// Lines "STEP <name>" mark a pause in which run_integration.sh takes a screenshot.
import 'dart:io';

import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/editor_screen.dart';
import 'package:e_screen_recorder/features/marker/marker_settings_screen.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:e_screen_recorder/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Finder bySem(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);

Future<void> settle(WidgetTester t, [int ms = 700]) async {
  await t.pump(Duration(milliseconds: ms));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> until(WidgetTester t, Finder f, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 250));
  }
  fail('not found: $f');
}

Future<void> step(WidgetTester t, String name) async {
  // ignore: avoid_print
  print('STEP $name');
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 3500)),
  );
  await t.pump();
}

Widget host(SettingsStore settings, Widget home) => ProviderScope(
  overrides: [settingsStoreProvider.overrideWithValue(settings)],
  child: MaterialApp(
    locale: const Locale('vi'),
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: AppL10n.localizationsDelegates,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ThemeMode.dark,
    home: home,
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screens for the icon audit', (t) async {
    final settings = await SettingsStore.load();
    final dir = await getApplicationSupportDirectory();
    final clip = File('${dir.path}/it_clip.mp4');
    if (!clip.existsSync()) {
      // ignore: avoid_print
      print('STEP need_clip');
      for (var i = 0; i < 120 && !clip.existsSync(); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
      }
    }
    expect(clip.existsSync(), isTrue);

    // Editor: the tool tabs and the panels under them.
    await t.pumpWidget(
      host(
        settings,
        EditorScreen(
          entry: MediaEntry(
            uri: Uri.file(clip.path).toString(),
            name: 'it_clip.mp4',
            durationMs: 8000,
            size: clip.lengthSync(),
            width: 720,
            height: 1600,
            dateAdded: DateTime.now(),
          ),
        ),
      ),
    );
    await until(t, bySem('editor_play'), seconds: 40);
    await settle(t, 1500);
    if (bySem('tool_cut').evaluate().isEmpty) {
      await t.tap(bySem('tools_toggle'));
      await settle(t);
    }
    await step(t, 'editor_cut');
    for (final id in ['marker', 'audio', 'cover', 'text', 'zoom']) {
      await t.tap(bySem('tool_$id'));
      await settle(t);
      await step(t, 'editor_$id');
    }

    // Marker settings.
    await t.pumpWidget(host(settings, const MarkerSettingsScreen()));
    await settle(t, 2000);
    await step(t, 'marker_settings');
  });
}
