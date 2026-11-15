import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/silence_cut_panel.dart';
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

({EditorController c, FakeRecorder fake}) _rig([EditProject? project]) {
  final fake = FakeRecorder();
  final c = EditorController(
    project: project ?? _base(),
    native: fake,
    store: MemoryProjectStore(),
    autosaveDelay: const Duration(milliseconds: 10),
  );
  addTearDown(c.dispose);
  addTearDown(fake.controller.close);
  return (c: c, fake: fake);
}

void main() {
  group('AutoDirector.cutRanges', () {
    test('keeps 0.2 s at each end of the cut', () {
      final out = AutoDirector.cutRanges(_base(), const [
        (startMs: 5000, endMs: 15000),
      ]);
      expect(out.segments.length, 2);
      expect(out.segments.first.startMs, 0);
      expect(out.segments.first.endMs, 5200);
      expect(out.segments.last.startMs, 14800);
      expect(out.segments.last.endMs, 30000);
      expect(out.outDurationMs, 20400);
    });

    test('without the pad the whole gap goes', () {
      final out = AutoDirector.cutRanges(_base(), const [
        (startMs: 5000, endMs: 15000),
      ], padMs: 0);
      expect(out.segments.first.endMs, 5000);
      expect(out.segments.last.startMs, 15000);
      expect(out.outDurationMs, 20000);
    });

    test('a range shorter than the smallest clip is left alone', () {
      final before = _base();
      final out = AutoDirector.cutRanges(before, const [
        (startMs: 3000, endMs: 3200),
      ]);
      expect(out.segments.length, before.segments.length);
      expect(out.outDurationMs, before.outDurationMs);
    });

    test('several ranges are cut in order and never overlap', () {
      final out = AutoDirector.cutRanges(_base(), const [
        (startMs: 20000, endMs: 24000),
        (startMs: 4000, endMs: 8000),
      ]);
      expect(out.segments.length, 3);
      final kept = [
        for (final s in out.segments) '${s.startMs}-${s.endMs}',
      ];
      expect(kept, ['0-4200', '7800-20200', '23800-30000']);
      expect(out.outDurationMs, 22800);
    });
  });

  group('the silence panel controller', () {
    test('finding offers the long stretches, selected by default', () async {
      final (:c, :fake) = _rig();
      fake.idleRanges = const [
        (startMs: 5000, endMs: 12000),
        (startMs: 18000, endMs: 19000), // 1 s: below the default 1.5 s
      ];
      await c.findSilence();
      expect(c.idleCandidates!.length, 2);
      expect(c.idlePicked, {0});
      expect(c.pickedSilence.length, 1);
      expect(c.silencePlan().ranges, 1);
      expect(c.silencePlan().removedMs, 6600);
      expect(c.silencePlan().resultMs, 23400);
    });

    test('cutting is one undo step and reports what went', () async {
      final (:c, :fake) = _rig();
      fake.idleRanges = const [(startMs: 5000, endMs: 15000)];
      await c.findSilence();
      final plan = c.applySilenceCut()!;
      expect(plan.ranges, 1);
      expect(c.project.outDurationMs, 20400);
      expect(c.lastSilenceCut!.ranges, 1);
      // The preview is used up: the cut ranges no longer exist.
      expect(c.idleCandidates, isNull);
      c.undo();
      expect(c.project.outDurationMs, 30000);
    });

    test('the kept parts can be sped up, existing speed work is left alone', () async {
      final (:c, :fake) = _rig();
      fake.idleRanges = const [(startMs: 5000, endMs: 15000)];
      await c.findSilence();
      c.setSilenceKeepSpeed(2);
      c.applySilenceCut();
      expect(c.project.outDurationMs, 10200);
      expect(c.project.segments.every((s) => s.speed == 2), isTrue);
    });

    test('nothing picked: plan is empty and nothing changes', () async {
      final (:c, :fake) = _rig();
      fake.idleRanges = const [(startMs: 5000, endMs: 15000)];
      await c.findSilence();
      c.toggleSilenceRange(0);
      expect(c.silencePlan().ranges, 0);
      expect(c.applySilenceCut(), isNull);
      expect(c.project.outDurationMs, 30000);
    });

    test('the threshold slider drops short stretches from the plan', () async {
      final (:c, :fake) = _rig();
      fake.idleRanges = const [(startMs: 5000, endMs: 7900)];
      await c.findSilence();
      expect(c.pickedSilence.length, 1);
      c.setSilenceMin(3000); // the 2.9 s gap is now too short
      expect(c.pickedSilence, isEmpty);
      c.setSilenceMin(500);
      expect(c.pickedSilence.length, 1);
    });

    test('only the part still in the edit is counted as removed', () async {
      // The source is 30 s but the edit keeps only the first 5 s.
      final trimmed = _base().trimSegment(0, endMs: 5000);
      final (:c, :fake) = _rig(trimmed);
      fake.idleRanges = const [(startMs: 5000, endMs: 15000)];
      await c.findSilence();
      expect(c.silencePlan().ranges, 1);
      expect(c.silencePlan().removedMs, 0);
    });
  });

  testWidgets('the panel finds, previews and cuts the quiet stretches', (
    tester,
  ) async {
    final (:c, :fake) = _rig();
    fake.idleRanges = const [(startMs: 5000, endMs: 15000)];
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        locale: const Locale('vi'),
        home: Scaffold(
          body: SingleChildScrollView(child: SilenceCutPanel(c: c)),
        ),
      ),
    );

    expect(find.text('Cắt khoảng lặng'), findsOneWidget);
    await tester.tap(find.text('Tìm khoảng lặng'));
    await tester.pumpAndSettle();
    expect(find.text('Các khoảng sẽ cắt'), findsOneWidget);
    expect(find.text('5,0s – 15,0s · 10,0s'), findsOneWidget);

    await tester.tap(find.text('Cắt các khoảng đã chọn'));
    await tester.pumpAndSettle();
    expect(c.project.outDurationMs, 20400);
    expect(find.text('Đã cắt 1 khoảng lặng.'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
