import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/auto_marks_panel.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/touch_log.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

EditProject _base() => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: 30000,
  frameW: 720,
  frameH: 1600,
);

({EditorController c, FakeRecorder fake}) _rig() {
  final fake = FakeRecorder();
  final c = EditorController(
    project: _base(),
    native: fake,
    store: MemoryProjectStore(),
    autosaveDelay: const Duration(milliseconds: 10),
  );
  addTearDown(c.dispose);
  addTearDown(fake.controller.close);
  return (c: c, fake: fake);
}

/// The same two touches used everywhere: one with a place seen, one whose place was hidden.
void _twoTouches(FakeRecorder fake) {
  fake.touches = const [
    RawTouch(tMs: 3000, x: 0.3, y: 0.6),
    RawTouch(tMs: 9000),
  ];
}

Future<void> _build(EditorController c) => c.directFromTouches(
  options: const DirectorOptions(pauseMs: 0),
  stepPrefix: 'Step ',
);

void main() {
  group('a mark remembers where it came from', () {
    test('old projects load as hand-made, exact marks', () {
      final m = MarkerItem.fromJson({
        'id': 'm1',
        'spec': const MarkerSpec(type: MarkerType.number).toMap(),
        'cueStartMs': 1000,
        'holdMs': 2000,
        'anythingNewer': 42,
      });
      expect(m.source, isNull);
      expect(m.isAuto, isFalse);
      expect(m.estimated, isFalse);
      expect(m.touchMs, isNull);
    });

    test('an automatic, guessed mark survives a save and a load', () {
      final m = MarkerItem(
        id: 'tp_0_3000',
        spec: const MarkerSpec(type: MarkerType.number, x0: 0.5, y0: 0.5),
        cueStartMs: 2400,
        source: MarkerItem.autoSource,
        estimated: true,
        touchMs: 3000,
      );
      final back = MarkerItem.fromJson(m.toJson());
      expect(back.isAuto, isTrue);
      expect(back.estimated, isTrue);
      expect(back.touchMs, 3000);
      // An exact mark does not carry the extra keys at all.
      expect(
        MarkerItem(
          id: 'm2',
          spec: m.spec,
          cueStartMs: 0,
        ).toJson().containsKey('estimated'),
        isFalse,
      );
    });
  });

  group('the find-touches pass leaves a reviewable result', () {
    test('a guessed place is flagged, a seen place is not', () {
      final out = AutoDirector.fromTouches(
        _base(),
        TouchClassifier.classify(const [
          RawTouch(tMs: 3000, x: 0.3, y: 0.6),
          RawTouch(tMs: 9000),
        ]),
        const DirectorOptions(pauseMs: 0),
      );
      expect(out.markers.length, 2);
      expect(out.markers.every((m) => m.isAuto), isTrue);
      expect(out.markers.map((m) => m.estimated), [false, true]);
      expect(out.markers.map((m) => m.touchMs), [3000, 9000]);
    });

    test('a hand-made mark is not part of the review list', () async {
      final (:c, :fake) = _rig();
      _twoTouches(fake);
      await _build(c);
      c.addMarker(MarkerType.circle, color: const Color(0xFFFF0000));
      expect(c.autoMarks.length, 2);
      expect(c.reviewMarks.length, 2);
      expect(c.estimatedMarkCount, 1);
    });
  });

  group('reviewing the automatic marks', () {
    test('turning one off removes it at once and turning it back on restores it', () async {
      final (:c, :fake) = _rig();
      _twoTouches(fake);
      await _build(c);
      final id = c.autoMarks.last.id;

      c.toggleAutoMark(id);
      expect(c.project.markers.length, 1);
      expect(c.autoMarks.length, 1);
      expect(c.reviewMarks.length, 2); // still listed, so it can come back
      expect(c.parkedAutoMarkCount, 1);

      c.toggleAutoMark(id);
      expect(c.project.markers.length, 2);
      expect(c.parkedAutoMarkCount, 0);
    });

    test('a turn-off is one undo step', () async {
      final (:c, :fake) = _rig();
      _twoTouches(fake);
      await _build(c);
      final id = c.autoMarks.last.id;
      c.toggleAutoMark(id);
      expect(c.project.markers.length, 1);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.project.markers.length, 2);
      expect(c.project.markers.any((m) => m.id == id), isTrue);
    });

    test('removing the guessed marks keeps the exact ones, and undo brings them back', () async {
      final (:c, :fake) = _rig();
      _twoTouches(fake);
      await _build(c);
      expect(c.removeEstimatedMarks(), 1);
      expect(c.project.markers.length, 1);
      expect(c.project.markers.every((m) => !m.estimated), isTrue);
      c.undo();
      expect(c.project.markers.length, 2);
      expect(c.estimatedMarkCount, 1);
    });

    test('looking again turns a guessed place into a seen one', () async {
      final (:c, :fake) = _rig();
      _twoTouches(fake);
      await _build(c);
      final guessed = c.project.markers.last;
      expect(guessed.spec.x0, 0.5);

      // The video now yields a place for the moment that had none.
      fake.touchPlaces[9000] = (x: 0.72, y: 0.31);
      expect(await c.relocateEstimatedMarks(), 1);

      expect(c.estimatedMarkCount, 0);
      final moved = c.project.markers.firstWhere((m) => m.touchMs == 9000);
      expect(moved.estimated, isFalse);
      expect(moved.spec.x0, closeTo(0.72, 0.02));
      expect(moved.spec.y0, closeTo(0.31, 0.02));

      // One undo step takes the old, guessed place back.
      c.undo();
      expect(c.estimatedMarkCount, 1);
    });

    test('nothing guessed: looking again does nothing and says so with 0', () async {
      final (:c, :fake) = _rig();
      fake.touches = const [RawTouch(tMs: 3000, x: 0.3, y: 0.6)];
      await _build(c);
      expect(await c.relocateEstimatedMarks(), 0);
      expect(fake.calls.where((e) => e.startsWith('locateTouches')), isEmpty);
    });

    test('a new pass forgets the marks parked by an older one', () async {
      final (:c, :fake) = _rig();
      _twoTouches(fake);
      await _build(c);
      c.toggleAutoMark(c.autoMarks.last.id);
      expect(c.parkedAutoMarkCount, 1);
      await _build(c);
      expect(c.parkedAutoMarkCount, 0);
      expect(c.autoMarks.length, 2);
    });
  });

  testWidgets('the panel lists the marks, calls out a guessed place and turns one off', (
    tester,
  ) async {
    final (:c, :fake) = _rig();
    _twoTouches(fake);
    await _build(c);
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        locale: const Locale('vi'),
        home: Scaffold(
          body: SingleChildScrollView(child: AutoMarksPanel(c: c)),
        ),
      ),
    );

    expect(find.text('Dấu tự động'), findsOneWidget);
    // Two marks heard, one standing on a guessed place.
    expect(find.textContaining('2 lần chạm'), findsOneWidget);
    expect(find.textContaining('1 vị trí ước lượng'), findsOneWidget);
    expect(find.text('Vị trí ước lượng'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(c.project.markers.length, 1);
    // The row stays in the list so the mark can be turned back on.
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.text('Bật lại tất cả'), findsOneWidget);
    // Let the debounced autosave finish so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 50));
  });
}
