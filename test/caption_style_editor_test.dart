import 'dart:io';

import 'package:e_screen_recorder/core/native_recorder.dart' show PickedMedia;
import 'package:e_screen_recorder/features/editor/caption_models.dart';
import 'package:e_screen_recorder/features/editor/caption_panel.dart';
import 'package:e_screen_recorder/features/editor/caption_style_editor.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

EditorController _controller() {
  final c = EditorController(
    project: EditProject.fresh(
      sourceUri: 'content://v/1',
      name: 'a.mp4',
      durationMs: 20000,
      frameW: 720,
      frameH: 1600,
    ),
    native: FakeRecorder(),
    store: MemoryProjectStore(),
    autosaveDelay: const Duration(milliseconds: 10),
  );
  c.addCue();
  return c;
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: AppL10n.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

CaptionStyle _style(EditorController c) => c.captionItem!.captionStyle!;

void main() {
  late EditorController c;

  setUp(() => c = _controller());
  tearDown(() => c.dispose());

  test('a new caption starts with the readable standard look', () {
    expect(_style(c), CaptionStyle.standard);
    expect(c.captionItem!.y, 0.85);
  });

  test('setCaptionStyle moves the item to the style position', () {
    c.setCaptionStyle(_style(c).copyWith(x: 0.3, y: 0.2));
    expect(c.captionItem!.x, 0.3);
    expect(c.captionItem!.y, 0.2);
  });

  test('an item moved on the stage keeps its place when the look changes', () {
    c.updateText(c.captionItem!.copyWith(x: 0.4, y: 0.6));
    final s = CaptionStyleEditor.styleOf(c.captionItem!);
    expect(s.x, 0.4);
    expect(s.y, 0.6);
    c.setCaptionStyle(s.copyWith(sizeU: 30));
    expect(c.captionItem!.x, 0.4);
    expect(c.captionItem!.y, 0.6);
    expect(_style(c).sizeU, 30);
  });

  test('setCaptionStyle with record false is not an undo step', () {
    final before = c.canUndo;
    c.setCaptionStyle(_style(c).copyWith(sizeU: 40), record: false);
    expect(c.canUndo, before);
    expect(_style(c).sizeU, 40);
  });

  test('turning captions off removes a caption-only item', () {
    expect(c.project.texts.length, 1);
    c.turnOffCaptions();
    expect(c.project.texts, isEmpty);
    expect(c.selectedId, isNull);
  });

  test('turning captions off keeps a text item that has its own text', () {
    c.turnOffCaptions();
    c.updateText(
      const TextItem(id: 't', text: 'Xin chào', startMs: 0, endMs: 1000),
    );
    c.addCue(on: c.project.texts.single);
    expect(c.project.texts.single.cues, isNotNull);
    c.turnOffCaptions();
    expect(c.project.texts.single.text, 'Xin chào');
    expect(c.project.texts.single.cues, isNull);
  });

  group('SRT into captions', () {
    test(
      'lines become caption lines, sorted, clamped and short ones dropped',
      () {
        c.turnOffCaptions();
        final n = c.importCaptionCues([
          (startMs: 4000, endMs: 6000, text: ' Hai '),
          (startMs: 0, endMs: 2000, text: 'Mot'),
          (startMs: 7000, endMs: 7050, text: 'too short'),
          (startMs: 8000, endMs: 9000, text: '   '),
          (startMs: 19000, endMs: 30000, text: 'Cuoi'),
        ]);
        expect(n, 3);
        final cues = c.captionItem!.cues!;
        expect(cues.map((e) => e.text), ['Mot', 'Hai', 'Cuoi']);
        expect(cues.last.endMs, 20000); // clamped to the video
        expect(
          c.captionItem!.captionStyle!.toJson(),
          CaptionStyle.standard.toJson(),
        );
      },
    );

    test('they are added to the lines already there', () {
      expect(c.captionItem!.cues!.length, 1);
      c.importCaptionCues([(startMs: 5000, endMs: 6000, text: 'Them')]);
      expect(c.captionItem!.cues!.length, 2);
      expect(c.project.texts.length, 1);
    });

    test('nothing usable adds nothing', () {
      final before = c.captionItem!.cues!.length;
      expect(c.importCaptionCues(const []), 0);
      expect(c.captionItem!.cues!.length, before);
    });

    testWidgets('the panel button reads the picked file', (tester) async {
      final file = File('${Directory.systemTemp.path}/cap_test.srt')
        ..writeAsStringSync(
          '1\n00:00:01,000 --> 00:00:02,500\nXin chao\n\n'
          '2\n00:00:03,000 --> 00:00:04,000\nTam biet\n',
        );
      addTearDown(() => file.deleteSync());
      final fake = c.native as FakeRecorder;
      fake.nextPick = PickedMedia(
        path: file.path,
        name: 'cap_test.srt',
        kind: 'file',
        durationMs: 0,
        width: 0,
        height: 0,
      );
      await tester.pumpWidget(_host(CaptionPanel(controller: c)));
      // The tap starts real file IO, so it runs outside the fake clock.
      await tester.runAsync(() async {
        await tester.tap(find.text('Nhập phụ đề (.srt)'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(
        c.captionItem!.cues!.map((e) => e.text),
        containsAll(['Xin chao', 'Tam biet']),
      );
      expect(find.text('Đã thêm 2 dòng phụ đề.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  testWidgets('reveal chips change the reveal mode', (tester) async {
    await tester.pumpWidget(_host(CaptionStyleEditor(controller: c)));
    await tester.tap(find.text('Karaoke'));
    await tester.pump();
    expect(_style(c).revealMode, RevealMode.karaokeHighlight);
    await tester.tap(find.text('Hiện hết'));
    await tester.pump();
    expect(_style(c).revealMode, RevealMode.none);
    await tester.pump(
      const Duration(milliseconds: 50),
    ); // lets the autosave timer run
  });

  testWidgets('outline, shadow and box chips switch the look on and off', (
    tester,
  ) async {
    await tester.pumpWidget(_host(CaptionStyleEditor(controller: c)));
    expect(_style(c).outlineWidth, greaterThan(0));
    await tester.tap(find.widgetWithText(FilterChip, 'Viền chữ'));
    await tester.pump();
    expect(_style(c).outlineWidth, 0);
    await tester.tap(find.widgetWithText(FilterChip, 'Viền chữ'));
    await tester.pump();
    expect(_style(c).outlineWidth, greaterThan(0));
    expect(_style(c).outlineColor, isNotNull);

    expect(_style(c).boxColor, isNull);
    await tester.tap(find.widgetWithText(FilterChip, 'Nền chữ'));
    await tester.pump();
    expect(_style(c).boxColor, isNotNull);
    expect(find.text('Màu nền'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Nền chữ'));
    await tester.pump();
    expect(_style(c).boxColor, isNull);
    expect(find.text('Màu nền'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Đổ bóng'));
    await tester.pump();
    expect(_style(c).shadowBlur, 0);
    await tester.pump(
      const Duration(milliseconds: 50),
    ); // lets the autosave timer run
  });

  testWidgets('font and alignment chips write the style', (tester) async {
    await tester.pumpWidget(_host(CaptionStyleEditor(controller: c)));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Phải'));
    await tester.pump();
    expect(_style(c).align, 'right');
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'cap_font_serif',
      ),
    );
    await tester.pump();
    expect(_style(c).fontId, 'serif');
    await tester.pump(
      const Duration(milliseconds: 50),
    ); // lets the autosave timer run
  });

  testWidgets('reset brings back the standard look and keeps nothing else', (
    tester,
  ) async {
    c.setCaptionStyle(
      _style(c).copyWith(sizeU: 40, revealMode: RevealMode.charByChar, y: 0.3),
    );
    await tester.pumpWidget(_host(CaptionStyleEditor(controller: c)));
    await tester.ensureVisible(find.text('Đặt lại kiểu'));
    await tester.tap(find.text('Đặt lại kiểu'));
    await tester.pump();
    expect(
      _style(c).toJson(),
      CaptionStyle.standard.copyWith(x: 0.5, y: 0.85).toJson(),
    );
    await tester.pump(
      const Duration(milliseconds: 50),
    ); // lets the autosave timer run
  });

  testWidgets('the panel shows the style tab only while captions are on', (
    tester,
  ) async {
    await tester.pumpWidget(_host(CaptionPanel(controller: c)));
    expect(find.text('Kiểu'), findsOneWidget);
    await tester.tap(find.text('Kiểu'));
    await tester.pump();
    expect(find.text('Hiệu ứng hiện chữ'), findsOneWidget);
    await tester.tap(find.text('Câu'));
    await tester.pump();
    await tester.tap(find.text('Tắt phụ đề'));
    await tester.pump();
    expect(find.text('Kiểu'), findsNothing);
    await tester.pump(
      const Duration(milliseconds: 50),
    ); // lets the autosave timer run
  });
}
