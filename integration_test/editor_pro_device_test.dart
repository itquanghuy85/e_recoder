// On-device checks of the editor round: play/pause ten times, three clips cut and reordered by a
// long-press drag on the timeline, free rotation of the picture, an overlay with its handles, export.
//
//   scripts/qa/editor_pro_check.sh <serial>
//
// Lines starting "STEP " are printed with a pause after them so the script can take a screenshot.
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

Finder bySem(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);

Future<void> settle(WidgetTester t, [int ms = 600]) async {
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

Future<void> step(WidgetTester t, String name, {int holdMs = 2500}) async {
  // ignore: avoid_print
  print('STEP $name');
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: holdMs)));
  await t.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editor: play x10, reorder 3 clips, tilt, overlay frame, export', (
    t,
  ) async {
    final dir = await getApplicationSupportDirectory();
    final clip = File('${dir.path}/it_clip.mp4');
    if (!clip.existsSync()) {
      // ignore: avoid_print
      print('STEP need_clip ${clip.path}');
      for (var i = 0; i < 120 && !clip.existsSync(); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
      }
    }
    expect(clip.existsSync(), isTrue);
    final entry = MediaEntry(
      uri: Uri.file(clip.path).toString(),
      name: 'it_clip.mp4',
      durationMs: 8000,
      size: clip.lengthSync(),
      width: 720,
      height: 1600,
      dateAdded: DateTime.now(),
    );
    // start from a clean project
    await t.runAsync(() => SqliteProjectStore().delete(entry.uri));
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
    await step(t, 'opened', holdMs: 2500);

    // ---- play / pause ten times, then once more after an edit -------------------------------
    for (var i = 0; i < 10; i++) {
      await t.tap(bySem('editor_play'));
      await t.pump(const Duration(milliseconds: 350));
    }
    await settle(t, 1200);
    // ten taps = back to paused; the button shows "play" and no spinner
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    expect(
      find.descendant(
        of: bySem('editor_play'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    await t.tap(bySem('editor_play'));
    await t.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.pause), findsWidgets, reason: 'playing');
    await t.tap(bySem('editor_play'));
    await settle(t, 800);
    expect(find.byIcon(Icons.play_arrow), findsWidgets);

    // ---- cut into three clips ----------------------------------------------------------------
    if (bySem('cut_split').evaluate().isEmpty) {
      await t.tap(bySem('tool_cut'));
      await settle(t);
    }
    await t.tap(bySem('seek_fwd'));
    await settle(t, 500);
    await t.tap(bySem('cut_split'));
    await settle(t, 500);
    await t.tap(bySem('seek_fwd'));
    await settle(t, 500);
    await t.tap(bySem('cut_split'));
    await settle(t, 800);
    await step(t, 'three_clips', holdMs: 2500);

    // play after the cuts: the button still answers
    await t.tap(bySem('editor_play'));
    await t.pump(const Duration(milliseconds: 800));
    await t.tap(bySem('editor_play'));
    await settle(t, 600);
    expect(find.byIcon(Icons.play_arrow), findsWidgets);

    // ---- long-press the last clip and carry it to the front ----------------------------------
    final tl = t.getRect(bySem('editor_timeline'));
    // the playhead is in the middle; after the second cut it sits at 2 s: the last clip starts there
    await t.tap(bySem('seek_fwd'));
    await settle(t, 500);
    final y = tl.top + 22 + 25; // the video row
    final from = Offset(tl.center.dx + 60, y);
    final g = await t.startGesture(from, pointer: 31);
    await t.pump(const Duration(milliseconds: 700)); // long press
    for (var i = 1; i <= 24; i++) {
      await g.moveTo(Offset(from.dx - i * 12.0, y));
      await t.pump(const Duration(milliseconds: 30));
    }
    await step(t, 'carrying', holdMs: 2000);
    await g.up();
    await settle(t, 1200);
    await step(t, 'reordered', holdMs: 2000);
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
    final saved = await t.runAsync(() => SqliteProjectStore().load(entry.uri));
    final order = [for (final s in saved!.segments) s.startMs];
    // ignore: avoid_print
    print('SEGMENTS $order');
    expect(order.length, 3);
    expect(order.first, greaterThan(order.last), reason: 'last clip moved to the front');

    // ---- free rotation -----------------------------------------------------------------------
    await t.tap(bySem('tool_picture'));
    await settle(t);
    await t.ensureVisible(bySem('pic_tilt'));
    await settle(t, 400);
    final slider = bySem('pic_tilt');
    final sw = t.getSize(slider).width;
    // +30 degrees is 0.83 of the track: from the middle, 0.33 of its width to the right
    await t.drag(slider, Offset(sw * 0.33, 0));
    await settle(t, 1200);
    await step(t, 'tilt30', holdMs: 3000);

    // ---- an overlay and its frame ------------------------------------------------------------
    await t.tap(bySem('tool_text'));
    await settle(t);
    await t.ensureVisible(bySem('add_text'));
    await t.tap(bySem('add_text'));
    await settle(t, 1200);
    await step(t, 'text_frame', holdMs: 3000);

    // ---- export with the tilt ----------------------------------------------------------------
    await t.tap(bySem('editor_export'));
    await settle(t, 1200);
    await t.tap(bySem('quality_p480'));
    await settle(t);
    await t.tap(bySem('export_start'));
    await until(t, bySem('export_view'), seconds: 300);
    await step(t, 'exported', holdMs: 5000);
  });
}
