import 'dart:io';
import 'dart:typed_data';

import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/caption_models.dart';
import 'package:e_screen_recorder/features/editor/caption_templates.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:flutter/services.dart' show CachingAssetBundle;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

SttStatus _done(List<SttPiece> p) => SttStatus(
  state: 'done',
  done: p.length,
  total: p.length,
  error: '',
  pieces: p,
);

void main() {
  late FakeRecorder fake;
  late EditorController c;

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
    )..sttPoll = Duration.zero;
  });
  tearDown(() => c.dispose());

  group('generateCaptionCues', () {
    test(
      'makes ONE caption item whose lines carry word timing, in one undo step',
      () async {
        fake.sttNext = _done(const [
          SttPiece(500, 2500, 'Xin chào các bạn'),
          SttPiece(4000, 7000, 'Đây là phụ đề tự động'),
        ]);
        expect(await c.generateCaptionCues('vi-VN'), 2);
        final item = c.project.texts.single;
        expect(
          item.id.startsWith('${EditorController.autoCaptionPrefix}_'),
          isTrue,
        );
        expect(item.text, isEmpty);
        expect(c.selectedId, item.id);
        final cues = item.cues!;
        expect(cues.length, 2);
        for (final cue in cues) {
          expect(cue.words, isNotEmpty);
          expect(cue.words.first.startMs, cue.startMs);
          expect(cue.words.last.endMs, cue.endMs);
          expect(
            cue.words.map((e) => e.text).join(' '),
            cue.text.replaceAll('\n', ' '),
          );
        }
        expect(cues[0].startMs, 500);
        expect(cues[0].words.length, 4);
        expect(item.captionStyle!.revealMode, RevealMode.wordByWord);
        c.undo();
        expect(c.project.texts, isEmpty);
      },
    );

    test(
      'the template look is used, and the item sits where the template puts it',
      () async {
        final all = await CaptionTemplate.load(bundle: _FileBundle());
        final tiktok = all.firstWhere((e) => e.id == 'tiktok');
        fake.sttNext = _done(const [SttPiece(0, 2000, 'Xin chào')]);
        await c.generateCaptionCues('vi-VN', style: tiktok.style);
        final item = c.project.texts.single;
        expect(item.captionStyle!.templateId, 'tiktok');
        expect(item.y, tiktok.style.y);
        expect(item.captionStyle!.sizeU, tiktok.style.sizeU);
      },
    );

    test(
      'long phrases are cut to lines that fit the frame at the style size',
      () async {
        const big = CaptionStyle(sizeU: 36);
        final text = List.filled(20, 'chữ').join(' ');
        fake.sttNext = _done([SttPiece(0, 10000, text)]);
        await c.generateCaptionCues('vi-VN', style: big);
        final cues = c.project.texts.single.cues!;
        expect(cues.length, greaterThan(1));
        final limit = EditorController.captionLineLength(big);
        for (final cue in cues) {
          for (final line in cue.text.split('\n')) {
            expect(line.length, lessThanOrEqualTo(limit));
          }
        }
        // the lines share the phrase's time and do not overlap
        for (var i = 1; i < cues.length; i++) {
          expect(cues[i].startMs, greaterThanOrEqualTo(cues[i - 1].endMs));
        }
      },
    );

    test(
      'making them again replaces the automatic caption and keeps the others',
      () async {
        c.addCue(); // a caption item the person made by hand
        final manual = c.project.texts.single.id;
        fake.sttNext = _done(const [SttPiece(1000, 2000, 'một')]);
        await c.generateCaptionCues('vi-VN');
        fake.sttNext = _done(const [SttPiece(3000, 4000, 'hai')]);
        await c.generateCaptionCues('vi-VN');
        final texts = c.project.texts;
        expect(texts.length, 2);
        expect(texts.where((t) => t.id == manual).length, 1);
        final auto = texts.where(
          (t) => t.id.startsWith('${EditorController.autoCaptionPrefix}_'),
        );
        expect(auto.single.cues!.single.text, 'hai');
      },
    );

    test('says why nothing was made and leaves the project alone', () async {
      fake.sttNext = const SttStatus(
        state: 'error',
        done: 0,
        total: 0,
        error: 'no_audio',
        pieces: [],
      );
      expect(await c.generateCaptionCues('vi-VN'), 0);
      expect(c.sttError, 'no_audio');
      fake.sttNext = _done(const []);
      expect(await c.generateCaptionCues('vi-VN'), 0);
      expect(c.sttError, 'no_speech');
      expect(c.project.texts, isEmpty);
      expect(c.sttBusy, isFalse);
    });

    test(
      'the old way still makes loose captions (nothing was renamed)',
      () async {
        fake.sttNext = _done(const [SttPiece(0, 2000, 'Xin chào')]);
        expect(await c.generateCaptions('vi-VN'), 1);
        expect(c.project.texts.single.id.startsWith('auto_'), isTrue);
        expect(c.project.texts.single.cues, isNull);
      },
    );
  });
}

/// Reads the template file from disk, like the app reads it from its assets.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}
