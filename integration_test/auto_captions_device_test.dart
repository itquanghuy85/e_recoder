// Automatic captions on the device, through the real editor UI, on a clip with real speech
// (made by scripts/qa/auto_captions_check.sh from the phone's own text-to-speech voice).
//
//   scripts/qa/auto_captions_check.sh <serial> vi      (or en)
import 'dart:io';

import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/editor_screen.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:e_screen_recorder/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const lang = String.fromEnvironment('CAPTION_LANG', defaultValue: 'vi');

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

bool enabled(WidgetTester t, String id) {
  final b = find.descendant(
    of: bySem(id),
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  );
  return b.evaluate().isNotEmpty &&
      t.widget<FilledButton>(b.first).onPressed != null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('automatic captions from real speech ($lang)', (t) async {
    final dir = await getApplicationSupportDirectory();
    final clip = File('${dir.path}/it_speech.mp4');
    if (!clip.existsSync()) {
      // ignore: avoid_print
      print('STEP need_files');
      for (var i = 0; i < 240 && !clip.existsSync(); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
      }
    }
    expect(clip.existsSync(), isTrue);
    final info = await t.runAsync(() => NativeRecorder().mediaInfo(clip.path));
    final entry = MediaEntry(
      uri: Uri.file(clip.path).toString(),
      name: 'it_speech.mp4',
      durationMs: info!.durationMs,
      size: clip.lengthSync(),
      width: 720,
      height: 1600,
      dateAdded: DateTime.now(),
    );
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
    if (bySem('tool_text').evaluate().isEmpty) {
      await t.tap(bySem('tools_toggle'));
      await settle(t);
    }
    await t.tap(bySem('tool_text'));
    await settle(t);
    await t.ensureVisible(bySem('auto_captions'));
    await t.tap(bySem('auto_captions'));
    await settle(t, 1500);

    // the sheet: language, then (if needed) the language pack, then start
    await until(
      t,
      bySem(lang == 'vi' ? 'stt_lang_vi' : 'stt_lang_en'),
      seconds: 20,
    );
    await t.tap(bySem(lang == 'vi' ? 'stt_lang_vi' : 'stt_lang_en'));
    await settle(t, 1200);
    await step(t, 'sheet', holdMs: 2500);
    if (bySem('stt_download').evaluate().isNotEmpty) {
      // ignore: avoid_print
      print(
        'language pack is not on the phone yet: asking the system to download it',
      );
      await t.tap(bySem('stt_download'));
      for (var i = 0; i < 480 && !enabled(t, 'stt_start'); i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
    }
    expect(
      enabled(t, 'stt_start'),
      isTrue,
      reason: 'the language must be ready',
    );
    await t.tap(bySem('stt_start'));
    await t.pump(const Duration(milliseconds: 500));
    expect(bySem('stt_progress'), findsOneWidget);
    await step(t, 'progress', holdMs: 2000);
    for (
      var i = 0;
      i < 4 * 400 && bySem('stt_progress').evaluate().isNotEmpty;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 250));
    }
    await settle(t, 1500);
    expect(bySem('stt_progress'), findsNothing);
    final shown = t.allWidgets
        .whereType<Text>()
        .map((w) => w.data)
        .whereType<String>()
        .where(
          (s) =>
              s.contains('phụ đề') ||
              s.contains('âm thanh') ||
              s.contains('lời nói'),
        )
        .toList();
    // ignore: avoid_print
    print('message: $shown');
    // ignore: avoid_print
    print('sheet closed; waiting for the autosave');
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));

    final saved = await t.runAsync(() => SqliteProjectStore().load(entry.uri));
    final texts = saved!.texts..sort((a, b) => a.startMs.compareTo(b.startMs));
    for (final c in texts) {
      // ignore: avoid_print
      print('CAP ${c.startMs} ${c.endMs} ${c.text.replaceAll('\n', ' | ')}');
    }
    expect(texts, isNotEmpty, reason: 'speech should have become captions');
    for (final c in texts) {
      expect(c.id.startsWith('auto_'), isTrue);
      expect(c.text.split('\n').length, lessThanOrEqualTo(2));
      expect(c.endMs, greaterThan(c.startMs));
    }
    for (var i = 1; i < texts.length; i++) {
      expect(
        texts[i].startMs,
        greaterThanOrEqualTo(texts[i - 1].endMs),
        reason: 'no overlap',
      );
    }

    // ignore: avoid_print
    print('stage: undo');
    // Undo takes them all away in one step, redo brings them back.
    await t.tap(bySem('editor_undo'));
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    final undone = await t.runAsync(() => SqliteProjectStore().load(entry.uri));
    expect(undone!.texts.where((e) => e.id.startsWith('auto_')), isEmpty);
    // ignore: avoid_print
    print('stage: redo');
    await t.tap(bySem('editor_redo'));
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await settle(t);

    // ignore: avoid_print
    print('stage: export');
    // Export: the captions are in the video.
    await t.tap(bySem('editor_export'));
    await settle(t, 1200);
    await t.tap(bySem('quality_p480'));
    await settle(t);
    await t.tap(bySem('export_start'));
    await until(t, bySem('export_view'), seconds: 240);
    await step(t, 'exported', holdMs: 5000);
  });
}
