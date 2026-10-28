// The voice effect through the real editor: choose it in the audio panel, then export, and the
// exported video must carry the PROCESSED voice (checked by scripts/qa/voice_fx_editor_check.sh).
//
//   scripts/qa/voice_fx_editor_check.sh <serial>
import 'dart:io';

import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_screen.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
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
  final texts = t.allWidgets
      .whereType<Text>()
      .map((w) => w.data)
      .whereType<String>()
      .take(30)
      .toList();
  fail('not found: $f; on screen: $texts');
}

Future<void> step(WidgetTester t, String name, {int holdMs = 3000}) async {
  // ignore: avoid_print
  print('STEP $name');
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: holdMs)));
  await t.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'voice effect: panel, busy state, export carries the processed voice',
    (t) async {
      final dir = await getApplicationSupportDirectory();
      final clip = File('${dir.path}/it_clip.mp4');
      final voice = File('${dir.path}/it_voice.m4a');
      if (!clip.existsSync() || !voice.existsSync()) {
        // ignore: avoid_print
        print('STEP need_files');
        for (
          var i = 0;
          i < 120 && !(clip.existsSync() && voice.existsSync());
          i++
        ) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)),
          );
        }
      }
      expect(clip.existsSync() && voice.existsSync(), isTrue);

      // A project whose only sound is a voice-over (1000 Hz); the clip's own sound is muted.
      final entry = MediaEntry(
        uri: Uri.file(clip.path).toString(),
        name: 'it_clip.mp4',
        durationMs: 8000,
        size: clip.lengthSync(),
        width: 720,
        height: 1600,
        dateAdded: DateTime.now(),
      );
      final project =
          EditProject.fresh(
                sourceUri: entry.uri,
                name: entry.name,
                durationMs: 8000,
                frameW: 720,
                frameH: 1600,
              )
              .setAudio(0, volume: 0)
              .upsertAudio(
                AudioTrack(
                  id: 'v1',
                  kind: AudioKind.voice,
                  path: voice.path,
                  name: 'Voice',
                  fileMs: 6000,
                ),
              );
      await t.runAsync(() => SqliteProjectStore().save(project));

      final settings = await SettingsStore.load();
      await t.pumpWidget(
        ProviderScope(
          overrides: [settingsStoreProvider.overrideWithValue(settings)],
          child: MaterialApp(
            locale: const Locale('vi'),
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates,
            theme: buildTheme(Brightness.dark),
            home: EditorScreen(entry: entry),
          ),
        ),
      );
      await until(t, bySem('editor_play'), seconds: 40);
      await settle(t, 1500);
      if (bySem('tool_audio').evaluate().isEmpty) {
        await t.tap(bySem('tools_toggle'));
        await settle(t);
      }
      await t.tap(bySem('tool_audio'));
      await settle(t);

      // Select the voice-over, pick "Deep".
      await until(t, find.text('Voice'));
      await t.ensureVisible(find.text('Voice').first);
      await t.tap(find.text('Voice').first);
      await settle(t);
      await until(t, bySem('voice_fx_deep'));
      await t.ensureVisible(bySem('voice_fx_deep'));
      await step(t, 'fx_panel', holdMs: 2500);
      await t.tap(bySem('voice_fx_deep'));
      await t.pump(const Duration(milliseconds: 200));
      expect(
        bySem('voice_fx_busy'),
        findsOneWidget,
        reason: 'a spinner while the file is processed',
      );
      for (
        var i = 0;
        i < 240 && bySem('voice_fx_busy').evaluate().isNotEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 250));
      }
      expect(bySem('voice_fx_busy'), findsNothing);
      expect(bySem('voice_fx_error'), findsNothing);
      final chip = t.widget<ChoiceChip>(
        find.descendant(
          of: bySem('voice_fx_deep'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip.selected, isTrue);
      await step(t, 'fx_applied', holdMs: 2500);

      // Noise reduction on top, then back to the original: one tap each.
      await t.tap(bySem('voice_dn_light'));
      for (
        var i = 0;
        i < 240 && bySem('voice_fx_busy').evaluate().isNotEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 250));
      }
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(bySem('voice_dn_off'));
      await t.pump(const Duration(milliseconds: 300));
      expect(bySem('voice_fx_error'), findsNothing);

      // Export with "Deep" (the 1000 Hz voice must come out near 780 Hz).
      await t.tap(bySem('editor_export'));
      await settle(t, 1200);
      await t.tap(bySem('quality_p480'));
      await settle(t);
      await t.tap(bySem('export_start'));
      await until(t, bySem('export_view'), seconds: 180);
      await step(t, 'exported', holdMs: 4000);
    },
  );
}
