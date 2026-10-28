import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_math.dart';
import 'package:e_screen_recorder/features/editor/editor_stage.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'helpers/fake_recorder.dart';

void main() {
  group('ViewZoom maths', () {
    const box = Size(360, 800);

    test('the touched content point stays under the fingers', () {
      const q = Offset(90, 200);
      final v = ViewZoom.pinch(
        q: q,
        focal: const Offset(90, 200),
        scale: 2,
        box: box,
      );
      expect(v.scale, 2);
      // screen = content * scale + offset must give the focal point back
      expect(q * v.scale + v.offset, const Offset(90, 200));
      expect(v.toContent(const Offset(90, 200)), q);
    });

    test('the scale is limited to 1x..5x', () {
      const q = Offset(180, 400);
      const f = Offset(180, 400);
      expect(ViewZoom.pinch(q: q, focal: f, scale: 20, box: box).scale, 5);
      expect(ViewZoom.pinch(q: q, focal: f, scale: 0.2, box: box).scale, 1);
    });

    test(
      'the picture always covers the box: no margin when panned to an edge',
      () {
        final v = ViewZoom.pinch(
          q: const Offset(0, 0),
          focal: const Offset(
            300,
            700,
          ), // would drag the corner into the middle
          scale: 2,
          box: box,
        );
        expect(v.offset, Offset.zero);
        final far = ViewZoom.pinch(
          q: const Offset(360, 800),
          focal: const Offset(-300, -700),
          scale: 2,
          box: box,
        );
        expect(far.offset, const Offset(-360, -800));
      },
    );

    test('at 1x the offset is always zero', () {
      final v = ViewZoom.pinch(
        q: const Offset(10, 10),
        focal: const Offset(200, 200),
        scale: 1,
        box: box,
      );
      expect(v.offset, Offset.zero);
      expect(v.isZoomed, isFalse);
    });
  });

  group('the preview stage', () {
    late EditorController c;
    late VideoPlayerController video;

    setUp(() {
      c = EditorController(
        project: EditProject.fresh(
          sourceUri: 'content://v/1',
          name: 'a.mp4',
          durationMs: 10000,
          frameW: 720,
          frameH: 1600,
        ),
        native: FakeRecorder(),
        store: MemoryProjectStore(),
        autosaveDelay: const Duration(milliseconds: 10),
      );
      video = VideoPlayerController.networkUrl(
        Uri.parse('https://x.invalid/v.mp4'),
      );
    });

    tearDown(() {
      c.dispose();
      video.dispose();
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 800,
                child: EditorStage(controller: c, video: video),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// Two fingers around [centre], [from] px apart then [to] px apart (horizontal).
    Future<void> pinch(
      WidgetTester tester,
      Offset centre,
      double from,
      double to,
    ) async {
      final a = await tester.startGesture(
        centre - Offset(from / 2, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        centre + Offset(from / 2, 0),
        pointer: 2,
      );
      const steps = 40;
      for (var i = 1; i <= steps; i++) {
        final w = from + (to - from) * i / steps;
        await a.moveTo(centre - Offset(w / 2, 0));
        await b.moveTo(centre + Offset(w / 2, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 400));
    }

    final badge = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == 'stage_zoom_reset',
    );

    testWidgets(
      'pinching out zooms the view, pinching in returns, limited to 5x',
      (tester) async {
        await pump(tester);
        expect(badge, findsNothing);
        await pinch(tester, const Offset(180, 400), 60, 120);
        expect(badge, findsOneWidget);
        expect(find.textContaining('×'), findsWidgets);
        // a huge pinch is stopped at 5x
        await pinch(tester, const Offset(180, 400), 40, 330);
        await pinch(tester, const Offset(180, 400), 40, 330);
        expect(find.text('5,0×'), findsOneWidget);
        // pinching back in to the start returns to fit and the badge goes away
        await pinch(tester, const Offset(180, 400), 330, 20);
        await pinch(tester, const Offset(180, 400), 330, 20);
        await pinch(tester, const Offset(180, 400), 330, 20);
        expect(badge, findsNothing);
      },
    );

    testWidgets('the badge and a double tap both put the view back to fit', (
      tester,
    ) async {
      await pump(tester);
      await pinch(tester, const Offset(180, 400), 60, 160);
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      await tester.pump(const Duration(milliseconds: 400));
      expect(badge, findsNothing);

      await pinch(tester, const Offset(180, 400), 60, 160);
      expect(badge, findsOneWidget);
      final spot =
          tester.getCenter(find.byType(EditorStage)) + const Offset(80, 120);
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 400));
      expect(badge, findsNothing);
    });

    testWidgets(
      'with a layer selected, pinch edits the layer and the view stays put',
      (tester) async {
        c.addText(); // selected
        final before = c.project.texts.single.sizeU;
        await pump(tester);
        await pinch(tester, const Offset(180, 400), 60, 140);
        expect(badge, findsNothing);
        expect(c.project.texts.single.sizeU, greaterThan(before));
      },
    );

    testWidgets('zoomed in, a tap lands on the layer where it is drawn', (
      tester,
    ) async {
      c.addText();
      final id = c.project.texts.single.id;
      c.select(null);
      await pump(tester);
      // Zoom to 2x around (90, 200): content (0.5, 0.5) = (180, 400) now shows at (270, 600).
      await pinch(tester, const Offset(90, 200), 40, 80);
      expect(badge, findsOneWidget);
      final z = tester.state(find.byType(EditorStage));
      expect(z, isNotNull);
      // find where the text really is on screen by reading the zoom badge text
      final scale = double.parse(
        (tester
                .widget<Text>(
                  find.descendant(of: badge, matching: find.byType(Text)),
                )
                .data!)
            .replaceAll('×', '')
            .replaceAll(',', '.'),
      );
      // the pinch started and ended around (90, 200), so that content point stays under it
      final shown =
          Offset(90, 200) +
          (const Offset(180, 400) - const Offset(90, 200)) * scale;
      await tester.tapAt(shown + const Offset(0, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.selectedId, id);
      // the old spot (where the text was at 1x) now shows other content: tapping it deselects
      await tester.tapAt(const Offset(180, 700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.selectedId, isNull);
    });

    testWidgets('zoomed in, dragging a selected layer moves it 1/zoom as far', (
      tester,
    ) async {
      c.addText();
      final id = c.project.texts.single.id;
      c.select(null);
      await pump(tester);
      await pinch(tester, const Offset(180, 400), 40, 80);
      final scale = double.parse(
        (tester
                .widget<Text>(
                  find.descendant(of: badge, matching: find.byType(Text)),
                )
                .data!)
            .replaceAll('×', '')
            .replaceAll(',', '.'),
      );
      c.select(id);
      await tester.pump();
      final x0 = c.project.texts.single.x;
      final g = await tester.startGesture(const Offset(180, 400), pointer: 7);
      await g.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await g.up();
      await tester.pump();
      final moved = c.project.texts.single.x - x0;
      // 80 px of finger travel, 360 px wide stage, 'scale' times magnified
      expect(moved, closeTo(80 / (360 * scale), 0.03));
      expect(c.project.texts.single.id, id);
    });

    testWidgets('the zoom is only a view: the project is unchanged', (
      tester,
    ) async {
      await pump(tester);
      final before = c.project.encode();
      await pinch(tester, const Offset(180, 400), 60, 200);
      expect(badge, findsOneWidget);
      expect(c.project.encode(), before);
      expect(c.canUndo, isFalse);
    });
  });
}
