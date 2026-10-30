import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/captions_from_speech.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
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
  group('layoutCaptions', () {
    test('a short phrase is one caption with its own times', () {
      final c = layoutCaptions([
        const SttPiece(1000, 3000, 'Xin chào các bạn'),
      ]);
      expect(c.length, 1);
      expect(c.single.startMs, 1000);
      expect(c.single.endMs, 3000);
      expect(c.single.text, 'Xin chào các bạn');
    });

    test('a long phrase is broken into short lines and captions that share its time', () {
      const text =
          'Hôm nay mình sẽ hướng dẫn các bạn cách quay màn hình điện thoại và thêm phụ đề tự động cho video của mình';
      final c = layoutCaptions([const SttPiece(0, 10000, text)]);
      expect(c.length, greaterThan(1));
      for (final cue in c) {
        final lines = cue.text.split('\n');
        expect(lines.length, lessThanOrEqualTo(2));
        for (final l in lines) {
          expect(l.length, lessThanOrEqualTo(32));
        }
      }
      expect(c.first.startMs, 0);
      expect(c.last.endMs, 10000);
      // contiguous, in order, nothing lost
      for (var i = 1; i < c.length; i++) {
        expect(c[i].startMs, greaterThanOrEqualTo(c[i - 1].endMs));
      }
      expect(c.map((e) => e.text.replaceAll('\n', ' ')).join(' '), text);
    });

    test('a very short phrase is kept readable when there is room, never overlapping the next', () {
      final c = layoutCaptions([
        const SttPiece(0, 300, 'Vâng'),
        const SttPiece(5000, 6000, 'Tiếp theo'),
      ]);
      expect(c[0].endMs - c[0].startMs, greaterThanOrEqualTo(900));
      final tight = layoutCaptions([
        const SttPiece(0, 300, 'Vâng'),
        const SttPiece(500, 1500, 'Tiếp theo'),
      ]);
      expect(tight[0].endMs, lessThanOrEqualTo(tight[1].startMs));
    });

    test('phrases are sorted and empty ones dropped', () {
      final c = layoutCaptions([
        const SttPiece(4000, 5000, 'sau'),
        const SttPiece(1000, 2000, 'trước'),
        const SttPiece(2500, 3500, '   '),
        const SttPiece(6000, 6000, 'rỗng'),
      ]);
      expect(c.map((e) => e.text), ['trước', 'sau']);
    });

    test('a word longer than a line is not cut', () {
      final c = layoutCaptions([SttPiece(0, 2000, 'a' * 50)]);
      expect(c.single.text, 'a' * 50);
    });
  });

  group('layoutCaptions balance', () {
    const phrase =
        'xin chào các bạn hôm nay tôi sẽ hướng dẫn cách quay màn hình điện thoại';

    test(
      'without balance the tail can be one stray word (the old behaviour)',
      () {
        final c = layoutCaptions([SttPiece(0, 7000, phrase)], maxLine: 18);
        expect(c.last.text.split(RegExp(r'\s+')).length, 1);
        expect(c.last.text, 'thoại');
      },
    );

    test(
      'with balance no caption is a stray word and the count does not grow',
      () {
        final plain = layoutCaptions([SttPiece(0, 7000, phrase)], maxLine: 18);
        final c = layoutCaptions(
          [SttPiece(0, 7000, phrase)],
          maxLine: 18,
          balance: true,
        );
        expect(c.length, lessThanOrEqualTo(plain.length));
        for (final cue in c) {
          expect(
            cue.text.split(RegExp(r'\s+')).length,
            greaterThan(2),
            reason: cue.text,
          );
          for (final line in cue.text.split('\n')) {
            expect(line.length, lessThanOrEqualTo(18));
          }
        }
        expect(c.map((e) => e.text.replaceAll('\n', ' ')).join(' '), phrase);
      },
    );

    test('a phrase that fits one caption is left alone', () {
      final c = layoutCaptions(
        [SttPiece(0, 2000, 'xin chào')],
        maxLine: 18,
        balance: true,
      );
      expect(c.single.text, 'xin chào');
    });
  });

  group('generateCaptions', () {
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

    test('listens, polls, and adds the captions as one undo step', () async {
      fake.sttQueue.add(
        const SttStatus(
          state: 'preparing',
          done: 0,
          total: 0,
          error: '',
          pieces: [],
        ),
      );
      fake.sttQueue.add(
        const SttStatus(
          state: 'running',
          done: 1,
          total: 2,
          error: '',
          pieces: [],
        ),
      );
      fake.sttNext = _done(const [
        SttPiece(500, 2500, 'Xin chào'),
        SttPiece(4000, 7000, 'Đây là phụ đề tự động'),
      ]);
      final f = c.generateCaptions('vi-VN');
      expect(c.sttBusy, isTrue);
      expect(await f, 2);
      expect(c.sttBusy, isFalse);
      expect(fake.calls, contains('sttStart:vi-VN'));
      expect(c.project.texts.length, 2);
      expect(c.project.texts.every((t) => t.id.startsWith('auto_')), isTrue);
      expect(c.project.texts.first.text, 'Xin chào');
      expect(c.project.texts.first.startMs, 500);
      expect(c.project.texts.first.y, closeTo(0.86, 1e-9));
      c.undo();
      expect(c.project.texts, isEmpty);
    });

    test(
      'running again replaces the automatic captions and keeps the others',
      () async {
        c.importSubtitles([
          (startMs: 100, endMs: 900, text: 'tay'),
        ]); // an SRT / typed one
        fake.sttNext = _done(const [SttPiece(1000, 2000, 'một')]);
        await c.generateCaptions('vi-VN');
        fake.sttNext = _done(const [
          SttPiece(3000, 4000, 'hai'),
          SttPiece(5000, 6000, 'ba'),
        ]);
        await c.generateCaptions('vi-VN');
        final auto = c.project.texts
            .where((t) => t.id.startsWith('auto_'))
            .toList();
        expect(auto.map((t) => t.text), ['hai', 'ba']);
        expect(
          c.project.texts.where((t) => t.id.startsWith('sub_')).single.text,
          'tay',
        );
      },
    );

    test('says why nothing was made', () async {
      fake.sttNext = const SttStatus(
        state: 'error',
        done: 0,
        total: 0,
        error: 'no_audio',
        pieces: [],
      );
      expect(await c.generateCaptions('vi-VN'), 0);
      expect(c.sttError, 'no_audio');
      expect(c.project.texts, isEmpty);

      fake.sttNext = _done(const []);
      expect(await c.generateCaptions('vi-VN'), 0);
      expect(c.sttError, 'no_speech');

      fake.sttNext = const SttStatus(
        state: 'cancelled',
        done: 1,
        total: 3,
        error: '',
        pieces: [],
      );
      expect(await c.generateCaptions('vi-VN'), 0);
      expect(c.sttError, isNull);
      expect(c.project.texts, isEmpty);
    });

    test('a second request while one runs is ignored', () async {
      fake.sttNext = _done(const [SttPiece(0, 1000, 'x')]);
      final a = c.generateCaptions('vi-VN');
      expect(await c.generateCaptions('en-US'), 0);
      expect(await a, 1);
      expect(fake.calls.where((e) => e.startsWith('sttStart')).length, 1);
    });
  });
}
