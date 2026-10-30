// On-device check of the editor preview's two-finger zoom (Maestro cannot make two-finger gestures).
//
//   flutter test integration_test/editor_zoom_test.dart -d <serial>
//
// Needs at least one recording made by the app in the library. The test opens the newest one in the
// editor and drives the real preview with pinch / drag / double-tap, then the full-screen viewer.
// Lines starting "STEP " are printed with a pause after them so a script can take a screenshot.
import 'dart:io';

import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/editor_screen.dart';
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
  final texts = t.allWidgets
      .whereType<Text>()
      .map((w) => w.data)
      .whereType<String>()
      .take(30)
      .toList();
  fail('not found: $f; on screen: $texts');
}

Future<void> step(WidgetTester t, String name, {int holdMs = 2500}) async {
  // ignore: avoid_print
  print('STEP $name');
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: holdMs)));
  await t.pump();
}

/// Two fingers around [centre], [from] px apart then [to] px apart.
Future<void> pinch(
  WidgetTester t,
  Offset centre,
  double from,
  double to,
) async {
  final a = await t.startGesture(centre - Offset(from / 2, 0), pointer: 11);
  final b = await t.startGesture(centre + Offset(from / 2, 0), pointer: 12);
  // Small steps, like a real pinch: the zoom factor counts from where the gesture was recognised.
  for (var i = 1; i <= 40; i++) {
    final w = from + (to - from) * i / 40;
    await a.moveTo(centre - Offset(w / 2, 0));
    await b.moveTo(centre + Offset(w / 2, 0));
    await t.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  await b.up();
  await settle(t);
}

double? zoomShown(WidgetTester t) {
  final badge = find.descendant(
    of: bySem('stage_zoom_reset'),
    matching: find.byType(Text),
  );
  if (badge.evaluate().isEmpty) return null;
  final s = t.widget<Text>(badge.first).data!;
  return double.parse(s.replaceAll('×', '').replaceAll(',', '.').replaceAll('%', '')) / 100;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editor preview: pinch, pan, limits, reset, full screen', (
    t,
  ) async {
    // The library only lists videos this install recorded, so the editor is opened directly on a
    // clip placed in the app's own folder (scripts/qa/push_it_clip.sh does that on request).
    final dir = await getApplicationSupportDirectory();
    final clip = File('${dir.path}/it_clip.mp4');
    if (!clip.existsSync()) {
      // ignore: avoid_print
      print('STEP need_clip ${clip.path}');
      final src = File('/data/local/tmp/it_clip.mp4');
      if (await src.exists()) {
        await src.copy(clip.path);
      }
      for (var i = 0; i < 120 && !clip.existsSync(); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
      }
    }
    expect(clip.existsSync(), isTrue, reason: 'push the clip first');
    final settings = await SettingsStore.load();
    await t.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(settings)],
        child: MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
          theme: buildTheme(Brightness.dark),
          home: EditorScreen(
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
      ),
    );
    await until(t, bySem('editor_play'), seconds: 40);
    await settle(t, 1500);

    // Hide the tool tabs so the preview has the room (as a user zooming would), then pinch inside
    // the picture itself (the frame, not the empty area around it).
    if (bySem('tool_cut').evaluate().isNotEmpty) {
      await t.tap(bySem('tools_toggle'));
      await settle(t, 800);
    }
    final stage = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'EditorStage',
    );
    expect(stage, findsOneWidget);
    final frame = find.descendant(
      of: stage,
      matching: find.byType(AspectRatio),
    );
    final c = t.getCenter(frame);
    final size = t.getSize(frame);
    expect(zoomShown(t), isNull, reason: 'starts at fit');
    await step(t, 'fit', holdMs: 4000);

    // Pinch out: zoomed.
    await pinch(t, c, size.width * 0.2, size.width * 0.8);
    final z1 = zoomShown(t);
    // ignore: avoid_print
    print('zoom after pinch: $z1 (frame ${size.width} x ${size.height} at $c)');
    await step(t, 'pinched', holdMs: 3000);
    expect(z1, isNotNull);
    // fingers went from 20 % to 80 % of the frame width: about 4x, less what the recognition slop ate
    expect(z1!, greaterThan(2.5));
    await step(t, 'zoomed', holdMs: 4000);

    // One-finger drag pans the zoomed view and keeps the zoom.
    final drag = await t.startGesture(c, pointer: 21);
    await drag.moveBy(Offset(-size.width * 0.15, 0));
    await t.pump(const Duration(milliseconds: 16));
    await drag.moveBy(Offset(-size.width * 0.1, 0));
    await t.pump(const Duration(milliseconds: 16));
    await drag.up();
    await settle(t);
    expect(zoomShown(t), z1);
    await step(t, 'panned', holdMs: 4000);

    // Playback and seeking still work while zoomed.
    await t.tap(bySem('editor_play'));
    await t.pump(const Duration(seconds: 1));
    await t.tap(bySem('editor_play'));
    await settle(t);
    await t.tap(bySem('seek_fwd'));
    await settle(t);
    expect(zoomShown(t), z1);

    // The limit is 5x.
    for (var i = 0; i < 3; i++) {
      await pinch(t, c, size.width * 0.2, size.width * 0.9);
    }
    expect(zoomShown(t), 5.0);
    await step(t, 'max', holdMs: 4000);

    // The badge returns to fit.
    await t.tap(bySem('stage_zoom_reset'));
    await settle(t);
    expect(zoomShown(t), isNull);

    // A double tap returns to fit too.
    await pinch(t, c, size.width * 0.2, size.width * 0.8);
    expect(zoomShown(t), isNotNull);
    await t.tapAt(c + const Offset(20, 20));
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(c + const Offset(20, 20));
    await settle(t);
    expect(zoomShown(t), isNull);

    // Pinching in below fit stays at fit.
    await pinch(t, c, size.width * 0.8, size.width * 0.2);
    expect(zoomShown(t), isNull);

    // Full screen keeps working: its own pinch zoom, and no preview badge inside.
    await t.tap(bySem('editor_fullscreen'));
    await settle(t, 1500);
    final view = t.getCenter(find.byType(InteractiveViewer));
    await pinch(t, view, 80, 400);
    expect(
      zoomShown(t),
      isNull,
      reason: 'the full-screen viewer has its own zoom',
    );
    await step(t, 'fullscreen', holdMs: 4000);
    await t.tap(find.byIcon(Icons.fullscreen_exit));
    await settle(t, 1500);
    expect(bySem('editor_play'), findsWidgets);
    // ignore: avoid_print
    print('STEP done');
  });
}
