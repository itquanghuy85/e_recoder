import 'dart:ui' show Color, Rect;

import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:flutter_test/flutter_test.dart';

EditProject _p() => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: 10000,
  frameW: 720,
  frameH: 1600,
);

void main() {
  group('overlay motion (golden values shared with OverlayMotionTest.kt)', () {
    MotionState at(ItemMotion m, int t, {int life = 3000}) =>
        motionAt(m, x: 0.5, y: 0.5, scale: 1, opacity: 1, t: t, lifeMs: life);

    test('fade in and out over the enter/exit time', () {
      const m = ItemMotion.fadeOnly;
      expect(at(m, 0).alpha, closeTo(0, 1e-9));
      expect(at(m, 110).alpha, closeTo(0.75, 1e-6));
      expect(at(m, 1500).alpha, closeTo(1, 1e-9));
      expect(at(m, 2890).alpha, closeTo(0.75, 1e-6));
      expect(at(m, 3001).visible, isFalse);
    });

    test('pop grows from 60 percent', () {
      const m = ItemMotion(enter: EnterExit.pop, exit: EnterExit.none);
      final s = at(m, 110);
      expect(s.scale, closeTo(0.9, 1e-6));
      expect(s.alpha, closeTo(0.75, 1e-6));
    });

    test('slide up enters from below the resting place', () {
      const m = ItemMotion(enter: EnterExit.slideUp, exit: EnterExit.none);
      final s = at(m, 0);
      expect(s.y, closeTo(0.58, 1e-9));
      expect(s.alpha, closeTo(0, 1e-9));
    });

    test('a keyframe moves the overlay across its life', () {
      const m = ItemMotion(
        endX: 0.9,
        ease: Ease.linear,
        enter: EnterExit.none,
        exit: EnterExit.none,
      );
      expect(at(m, 500, life: 1000).x, closeTo(0.7, 1e-9));
      expect(at(m, 0, life: 1000).x, closeTo(0.5, 1e-9));
      expect(at(m, 1000, life: 1000).x, closeTo(0.9, 1e-9));
    });

    test('easing endpoints', () {
      for (final e in Ease.values) {
        expect(applyEase(e, 0), 0);
        expect(applyEase(e, 1), 1);
      }
      expect(applyEase(Ease.easeIn, 0.5), closeTo(0.25, 1e-9));
    });
  });

  group('music ducking (golden values shared with the exporter)', () {
    const ranges = [(1000, 3000)];
    test('quiet during the voice, ramps before and after', () {
      expect(AudioTrack.duckFactor(2000, ranges), closeTo(0.3, 1e-9));
      expect(AudioTrack.duckFactor(1000, ranges), closeTo(0.3, 1e-9));
      expect(AudioTrack.duckFactor(875, ranges), closeTo(0.65, 1e-9));
      expect(AudioTrack.duckFactor(700, ranges), closeTo(1, 1e-9));
      expect(AudioTrack.duckFactor(3125, ranges), closeTo(0.65, 1e-9));
      expect(AudioTrack.duckFactor(3300, ranges), closeTo(1, 1e-9));
    });

    test('a track plays up to the end of the video and loops only music', () {
      const music = AudioTrack(
        id: 'a',
        kind: AudioKind.music,
        path: 'x',
        name: 'x',
        fileMs: 4000,
        startOutMs: 1000,
        loop: true,
      );
      expect(music.playMs(10000), 9000);
      expect(music.copyWith(loop: false).playMs(10000), 4000);
      expect(music.copyWith(startOutMs: 12000).playMs(10000), 0);
    });
  });

  group('picture look', () {
    test('identity keeps the source size', () {
      const l = PictureLook.identity;
      expect(l.outputSize(720, 1600).width, 720);
      expect(l.outputSize(720, 1600).height, 1600);
      expect(l.isIdentity, isTrue);
    });

    test('rotation swaps width and height', () {
      const l = PictureLook(rotation: 90);
      expect(l.pictureSize(720, 1600).width, 1600);
      expect(l.outputSize(720, 1600).height, 720);
    });

    test('crop shrinks the output', () {
      const l = PictureLook(crop: Rect.fromLTRB(0.25, 0.25, 0.75, 0.75));
      expect(l.outputSize(800, 1600).width, 400);
      expect(l.outputSize(800, 1600).height, 800);
    });

    test('a wider output aspect adds bars (grows) or cuts (fill)', () {
      const bars = PictureLook(aspect: OutAspect.r16x9);
      final b = bars.outputSize(720, 1600);
      expect(b.height, 1600);
      expect((b.width / b.height - 16 / 9).abs(), lessThan(0.01));
      final r = bars.pictureRectInOutput(720, 1600);
      expect(r.height, closeTo(1.0, 1e-9));
      expect(r.width, lessThan(1.0));
      const fill = PictureLook(aspect: OutAspect.r16x9, fill: true);
      final f = fill.outputSize(720, 1600);
      expect(f.width, 720);
      expect((f.width / f.height - 16 / 9).abs(), lessThan(0.01));
      expect(fill.pictureRectInOutput(720, 1600).height, greaterThan(1.0));
    });

    test('output sizes are always even', () {
      const l = PictureLook(crop: Rect.fromLTRB(0.1, 0.1, 0.77, 0.83));
      final s = l.outputSize(721, 1601);
      expect(s.width % 2, 0);
      expect(s.height % 2, 0);
    });

    test('a colour look with no changes is the identity matrix', () {
      final m = ColorLook.none.matrix4;
      expect(m, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
      expect(ColorLook.none.flutterMatrix[0], 1);
    });

    test('brightness is an offset, saturation 0 makes grey', () {
      final b = const ColorLook(brightness: 0.2).rows;
      expect(b[3], closeTo(0.2, 1e-9));
      final g = const ColorLook(saturation: 0).rows;
      expect(g[0], closeTo(0.2126, 1e-9));
      expect(g[4], closeTo(0.2126, 1e-9));
      expect(g[9], closeTo(0.7152, 1e-9));
    });

    test(
      'the Flutter matrix and the Media3 matrix come from the same rows',
      () {
        const c = ColorLook(
          brightness: 0.1,
          contrast: 0.3,
          saturation: 1.4,
          warmth: 0.5,
        );
        final r = c.rows;
        final m4 = c.matrix4;
        final fm = c.flutterMatrix;
        // Media3 is column major: element (row, col) is m4[col * 4 + row]
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 3; col++) {
            expect(m4[col * 4 + row], closeTo(r[row * 4 + col], 1e-9));
            expect(fm[row * 5 + col], closeTo(r[row * 4 + col], 1e-9));
          }
          expect(m4[12 + row], closeTo(r[row * 4 + 3], 1e-9));
          expect(fm[row * 5 + 4], closeTo(r[row * 4 + 3] * 255, 1e-6));
        }
      },
    );
  });

  group('project with the new items', () {
    test('everything survives a save and load', () {
      var p = _p();
      p = p.copyWith(
        look: const PictureLook(
          rotation: 90,
          crop: Rect.fromLTRB(0.1, 0.2, 0.9, 0.8),
          aspect: OutAspect.r1x1,
          fill: true,
          color: ColorLook(brightness: 0.1, saturation: 1.3),
        ),
      );
      p = p.upsertText(
        const TextItem(
          id: 't1',
          text: 'Hi',
          startMs: 0,
          endMs: 2000,
          font: TextFont.serif,
          outline: false,
          box: Color(0x88000000),
          shadow: true,
          align: TextAlignment.left,
          rotation: 12,
          motion: ItemMotion(endX: 0.8, enter: EnterExit.pop),
        ),
      );
      p = p.upsertImage(
        const ImageItem(
          id: 'i1',
          path: '/a.png',
          name: 'a.png',
          pxW: 100,
          pxH: 50,
          startMs: 0,
          endMs: 1000,
        ),
      );
      p = p.upsertShape(
        const ShapeItem(
          id: 's1',
          kind: ShapeKind.bubble,
          text: 'Nhấn vào đây',
          startMs: 0,
          endMs: 1000,
        ),
      );
      p = p.upsertAudio(
        const AudioTrack(
          id: 'a1',
          kind: AudioKind.voice,
          path: '/v.m4a',
          name: 'v',
          fileMs: 3000,
        ),
      );
      p = p.upsertPip(
        const PipItem(
          id: 'p1',
          path: '/p.mp4',
          name: 'p',
          isVideo: true,
          fileMs: 5000,
          pxW: 1920,
          pxH: 1080,
        ),
      );
      final q = EditProject.decode(p.encode());
      expect(q.look, p.look);
      expect(q.texts.single.font, TextFont.serif);
      expect(q.texts.single.box, const Color(0x88000000));
      expect(q.texts.single.motion, p.texts.single.motion);
      expect(q.images.single.path, '/a.png');
      expect(q.shapes.single.text, 'Nhấn vào đây');
      expect(q.audioTracks.single.kind, AudioKind.voice);
      expect(q.pips.single.isVideo, isTrue);
    });

    test('removeOverlay finds every kind', () {
      var p = _p()
          .upsertImage(
            const ImageItem(
              id: 'i',
              path: '/x',
              name: 'x',
              pxW: 1,
              pxH: 1,
              startMs: 0,
              endMs: 1,
            ),
          )
          .upsertShape(const ShapeItem(id: 's', startMs: 0, endMs: 1))
          .upsertPip(
            const PipItem(
              id: 'p',
              path: '/p',
              name: 'p',
              isVideo: false,
              fileMs: 0,
              pxW: 1,
              pxH: 1,
            ),
          )
          .upsertAudio(
            const AudioTrack(
              id: 'a',
              kind: AudioKind.music,
              path: '/a',
              name: 'a',
              fileMs: 1,
            ),
          );
      for (final id in ['i', 's', 'p', 'a']) {
        p = p.removeOverlay(id);
      }
      expect(p.images, isEmpty);
      expect(p.shapes, isEmpty);
      expect(p.pips, isEmpty);
      expect(p.audioTracks, isEmpty);
    });
  });
}
