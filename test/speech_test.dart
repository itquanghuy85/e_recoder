import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/speech_sheet.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

({EditorController c, FakeRecorder fake}) _rig() {
  final fake = FakeRecorder();
  final c = EditorController(
    project: EditProject.fresh(
      sourceUri: 'content://v/1',
      name: 'a.mp4',
      durationMs: 30000,
      frameW: 720,
      frameH: 1600,
    ),
    native: fake,
    store: MemoryProjectStore(),
    autosaveDelay: const Duration(milliseconds: 10),
  );
  addTearDown(c.dispose);
  addTearDown(fake.controller.close);
  return (c: c, fake: fake);
}

void main() {
  test('the spoken text becomes a voice-over at the playhead, one undo step', () async {
    final (:c, :fake) = _rig();
    c.seekOut(4000);
    final ok = await c.addSpokenVoice('  Bấm vào nút Cài đặt  ', lang: 'vi');
    expect(ok, isTrue);
    expect(fake.calls, contains('speakToFile:vi:Bấm vào nút Cài đặt'));
    final a = c.project.audioTracks.single;
    expect(a.kind, AudioKind.voice);
    expect(a.path, '/tts.wav');
    expect(a.fileMs, 2400);
    expect(a.startOutMs, 4000);
    expect(a.name, 'Bấm vào nút Cài đặt');
    expect(c.selectedId, a.id);
    // It is part of the export like any voice-over.
    expect(c.project.toExportMap(outHeight: 1280, bitrate: 4000000).toString(), contains('/tts.wav'));
    c.undo();
    expect(c.project.audioTracks, isEmpty);
  });

  test('empty text does nothing; an engine error is kept for the sheet', () async {
    final (:c, :fake) = _rig();
    expect(await c.addSpokenVoice('   ', lang: 'vi'), isFalse);
    expect(fake.calls.where((e) => e.startsWith('speakToFile')), isEmpty);
    fake.speechError = 'tts_no_lang';
    expect(await c.addSpokenVoice('hello', lang: 'en'), isFalse);
    expect(c.speechError, 'tts_no_lang');
    expect(c.project.audioTracks, isEmpty);
    expect(c.speaking, isFalse);
  });

  test('the text to read: the selected text, else the caption on screen', () {
    final (:c, fake: _) = _rig();
    expect(c.textToSpeak, '');
    c.addText();
    expect(c.textToSpeak, 'Văn bản'); // the new text is selected
    c.select(null);
    expect(c.textToSpeak, 'Văn bản'); // and it is on screen at the playhead
  });

  testWidgets('the sheet reads the text in the chosen language and speed', (
    tester,
  ) async {
    final (:c, :fake) = _rig();
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        locale: const Locale('vi'),
        home: Scaffold(body: SpeechSheet(c: c)),
      ),
    );
    expect(find.text('Đọc chữ thành giọng nói'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Xin chào');
    await tester.tap(find.byKey(const ValueKey('tts_lang_en')));
    await tester.pump();
    await tester.tap(find.text('Tạo giọng đọc'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('speakToFile:en:Xin chào'));
    expect(c.project.audioTracks.single.kind, AudioKind.voice);
  });

  testWidgets('an engine without the language says how to fix it', (
    tester,
  ) async {
    final (:c, :fake) = _rig();
    fake.speechError = 'tts_no_lang';
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        locale: const Locale('vi'),
        home: Scaffold(body: SpeechSheet(c: c)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Xin chào');
    await tester.pump();
    await tester.tap(find.text('Tạo giọng đọc'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa có giọng'), findsOneWidget);
  });
}

