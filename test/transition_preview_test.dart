import 'dart:convert';

import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_tools.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/transition_preview.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'helpers/fake_recorder.dart';

/// A real 1x1 PNG, so Image.memory decodes it in tests.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  group('timing', () {
    test('hold before, outgoing half, incoming half, hold after', () {
      // cycle 1400, play 600: hold 400 | out 400..700 | in 700..1000 | hold 1000..1400
      final a = transitionPreviewAt(TransitionKind.dipBlack, 100);
      expect(a.incoming, isFalse);
      expect(a.look.isNone, isTrue);
      final mid = transitionPreviewAt(TransitionKind.dipBlack, 699);
      expect(mid.incoming, isFalse);
      expect(mid.look.mul, lessThan(0.05)); // almost black at the cut
      final inn = transitionPreviewAt(TransitionKind.dipBlack, 701);
      expect(inn.incoming, isTrue);
      expect(inn.look.mul, lessThan(0.05));
      final end = transitionPreviewAt(TransitionKind.dipBlack, 1200);
      expect(end.incoming, isTrue);
      expect(end.look.isNone, isTrue);
      // It loops.
      expect(
        transitionPreviewAt(TransitionKind.dipBlack, 1400 + 100).look.isNone,
        isTrue,
      );
    });

    test('the same formula the editor and export use', () {
      for (final k in TransitionKind.values) {
        final p = transitionPreviewAt(k, 400 + 150); // a quarter of the way: outgoing u = 0.5
        final ref = TransitionLook.of(k, 0.5, incoming: false);
        expect(p.look.mul, ref.mul);
        expect(p.look.dx, ref.dx);
        expect(p.look.dy, ref.dy);
        expect(p.look.scale, ref.scale);
      }
    });
  });

  group('panel', () {
    Future<(EditorController, FakeRecorder)> pump(
      WidgetTester tester, {
      required bool frames,
    }) async {
      final fake = FakeRecorder();
      if (frames) fake.frame = _png;
      addTearDown(fake.controller.close);
      final base = EditProject.fresh(
        sourceUri: 'content://v/${frames ? 1 : 2}',
        name: 'a.mp4',
        durationMs: 20000,
        frameW: 720,
        frameH: 1600,
      );
      final c = EditorController(
        project: base.splitAtOut(8000),
        native: fake,
        store: MemoryProjectStore(),
        autosaveDelay: const Duration(milliseconds: 10),
      );
      addTearDown(c.dispose);
      c.seekOut(12000); // in the second clip: its cut is the one being chosen
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditorTools(
                controller: c,
                tool: EditorTool.transition,
                onTool: (_) {},
                newMarkerColor: Colors.red,
                newMarkerThickness: 5,
                video: VideoPlayerController.networkUrl(
                  Uri.parse('file:///x.mp4'),
                ),
                advanced: true,
                onExport: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return (c, fake);
    }

    testWidgets('frames around the cut: every choice is a moving picture', (
      tester,
    ) async {
      final (c, fake) = await pump(tester, frames: true);
      expect(fake.calls.where((e) => e.startsWith('frameAt')).length, 2);
      expect(
        find.byType(TransitionPreview),
        findsNWidgets(TransitionKind.values.length),
      );
      await tester.tap(find.text('Trượt trái'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.project.segments[1].transition?.kind, TransitionKind.slideLeft);
      // Undo brings the cut back; the export formula is untouched by the picker.
      c.undo();
      expect(c.project.segments[1].transition, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('no frames: plain names, still usable', (tester) async {
      final (c, _) = await pump(tester, frames: false);
      expect(find.byType(TransitionPreview), findsNothing);
      expect(find.byType(ChoiceChip), findsWidgets);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Trượt trái'));
      await tester.pump();
      expect(c.project.segments[1].transition?.kind, TransitionKind.slideLeft);
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
