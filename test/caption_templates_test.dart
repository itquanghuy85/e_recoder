import 'dart:io';

import 'package:e_screen_recorder/features/editor/caption_models.dart';
import 'package:e_screen_recorder/features/editor/caption_template_picker.dart';
import 'package:e_screen_recorder/features/editor/caption_templates.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

List<CaptionTemplate> _bundled() => CaptionTemplate.parseAll(
  File('assets/caption_templates.json').readAsStringSync(),
);

void main() {
  group('bundled templates', () {
    final all = _bundled();

    test('there are 12, each with a unique id', () {
      expect(all.length, 12);
      expect(all.map((e) => e.id).toSet().length, 12);
    });

    test('each one is a real, distinct look', () {
      final looks = all
          .map((e) => (e.style.toJson()..remove('templateId')).toString())
          .toSet();
      expect(looks.length, 12);
    });

    test('names and hints exist in both languages', () {
      for (final t in all) {
        expect(t.name, isNotEmpty, reason: t.id);
        expect(t.nameEn, isNotEmpty, reason: t.id);
        expect(t.hint, isNotEmpty, reason: t.id);
        expect(t.hintEn, isNotEmpty, reason: t.id);
        expect(t.nameFor('vi'), t.name);
        expect(t.nameFor('en'), t.nameEn);
      }
      expect(all.map((e) => e.nameEn).toSet().length, 12);
    });

    test('fonts are ones the app has, sizes fit the editor sliders', () {
      final fonts = TextFont.values.map((e) => e.name).toSet();
      for (final t in all) {
        expect(fonts, contains(t.style.fontId), reason: t.id);
        expect(t.style.sizeU, inInclusiveRange(12, 48), reason: t.id);
        expect(t.style.y, inInclusiveRange(0.05, 0.95), reason: t.id);
        expect(t.style.x, inInclusiveRange(0.1, 0.9), reason: t.id);
        expect(
          ['left', 'center', 'right'],
          contains(t.style.align),
          reason: t.id,
        );
      }
    });

    test('every look stays readable: outline, box or shadow', () {
      for (final t in all) {
        final s = t.style;
        final outline = s.outlineColor != null && s.outlineWidth >= 1.5;
        final box = s.boxColor != null && (s.boxColor! >>> 24) >= 0xB0;
        final shadow = s.shadowColor != null && s.shadowBlur >= 3;
        expect(
          outline || box || shadow,
          isTrue,
          reason: '${t.id} has nothing behind the text',
        );
      }
    });

    test('the four reveal modes are all used', () {
      expect(
        all.map((e) => e.style.revealMode).toSet(),
        RevealMode.values.toSet(),
      );
    });

    test('templates carry their id so the picker can mark the one in use', () {
      for (final t in all) {
        expect(t.style.templateId, t.id);
      }
    });

    test('the standard template is the look a new caption starts with', () {
      final std = all.firstWhere((e) => e.id == 'standard').style.toJson();
      final base = CaptionStyle.standard
          .copyWith(templateId: 'standard')
          .toJson();
      std.remove('y');
      base.remove('y');
      expect(std, base);
    });
  });

  group('parseAll', () {
    test('a bad entry is skipped, the rest still load', () {
      final list = CaptionTemplate.parseAll(
        '[{"id":"a","name":"A","style":{}},{"nope":1},{"id":"b","style":{"sizeU":30}}]',
      );
      expect(list.map((e) => e.id), ['a', 'b']);
      expect(list.last.style.sizeU, 30);
      expect(list.last.name, 'b');
    });

    test('something that is not a list gives nothing', () {
      expect(CaptionTemplate.parseAll('{}'), isEmpty);
    });
  });

  group('picker', () {
    late EditorController c;
    late FakeRecorder fake;

    setUp(() {
      fake = FakeRecorder();
      c = EditorController(
        project: EditProject.fresh(
          sourceUri: 'content://v/1',
          name: 'a.mp4',
          durationMs: 20000,
          frameW: 720,
          frameH: 1600,
        ),
        native: fake,
        store: MemoryProjectStore(),
        autosaveDelay: const Duration(milliseconds: 10),
      );
      c.addCue();
    });
    tearDown(() => c.dispose());

    /// A tall window, so the grid builds all twelve cards.
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Widget host() => MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      home: Scaffold(
        body: CaptionTemplatePicker(
          controller: c,
          templates: Future.value(_bundled()),
        ),
      ),
    );

    testWidgets('one tap applies a template: look, position and mark', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.text('Karaoke vàng'), findsOneWidget);
      await tester.tap(find.text('Karaoke vàng'));
      await tester.pump();
      final s = c.captionItem!.captionStyle!;
      expect(s.templateId, 'karaoke-gold');
      expect(s.revealMode, RevealMode.karaokeHighlight);
      expect(c.captionItem!.y, s.y); // the item moved to the template position
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('each card is drawn by the native caption renderer', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();
      expect(fake.calls.where((e) => e == 'renderCue').length, 12);
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
