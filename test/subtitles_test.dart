import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/srt.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void main() {
  group('parseSrt', () {
    test('reads indexes, times and multi-line text', () {
      final cues = parseSrt(
        '1\n00:00:01,000 --> 00:00:03,500\nXin chào\nbạn\n\n'
        '2\n00:01:00,250 --> 00:01:02,000\nBước 2\n',
      );
      expect(cues.length, 2);
      expect(cues[0].startMs, 1000);
      expect(cues[0].endMs, 3500);
      expect(cues[0].text, 'Xin chào\nbạn');
      expect(cues[1].startMs, 60250);
    });

    test('tolerates BOM, CRLF, dots, missing index and tags', () {
      final cues = parseSrt(
        '﻿00:00:00.5 --> 00:00:01.5\r\n<i>{\\an8}Hi</i>\r\n\r\n',
      );
      expect(cues.single.startMs, 500);
      expect(cues.single.endMs, 1500);
      expect(cues.single.text, 'Hi');
    });

    test('drops empty or backwards cues and sorts by time', () {
      final cues = parseSrt(
        '1\n00:00:05,000 --> 00:00:06,000\nlate\n\n'
        '2\n00:00:02,000 --> 00:00:01,000\nbackwards\n\n'
        '3\n00:00:00,000 --> 00:00:01,000\n\n\n'
        '4\n00:00:01,000 --> 00:00:02,000\nearly\n',
      );
      expect(cues.map((c) => c.text), ['early', 'late']);
    });

    test('garbage gives no cues', () => expect(parseSrt('hello'), isEmpty));
  });

  group('captions', () {
    late EditorController c;
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
    });
    tearDown(() => c.dispose());

    test(
      'import adds boxed captions in one undo step and clamps to the clip',
      () {
        final n = c.importSubtitles([
          (startMs: 500, endMs: 2000, text: 'a'),
          (startMs: 9000, endMs: 15000, text: 'b'),
          (startMs: 12000, endMs: 13000, text: 'outside'),
        ]);
        expect(n, 2);
        expect(c.project.texts.length, 2);
        expect(c.project.texts[1].endMs, 10000);
        expect(c.project.texts.first.box, isNotNull);
        expect(c.project.texts.first.y, closeTo(0.86, 1e-9));
        c.undo();
        expect(c.project.texts, isEmpty);
      },
    );

    test('a preset changes the look only', () {
      const t = TextItem(
        id: 't',
        text: 'x',
        startMs: 100,
        endMs: 900,
        x: .2,
        y: .3,
      );
      final y = TextPreset.yellow.apply(t);
      expect(y.color, const Color(0xFFFFD60A));
      expect(y.text, 'x');
      expect(y.startMs, 100);
      expect(y.x, .2);
      expect(TextPreset.subtitle.apply(y).box, isNotNull);
      expect(
        TextPreset.classic.apply(TextPreset.subtitle.apply(t)).box,
        isNull,
      );
    });
  });
}
