import 'dart:ui' show Color, Rect;

import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/editor/project_template.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

EditProject _base() => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: 10000,
  frameW: 720,
  frameH: 1600,
);

({EditorController c, FakeRecorder fake}) _rig([EditProject? p]) {
  final fake = FakeRecorder();
  final c = EditorController(
    project: p ?? _base(),
    native: fake,
    store: MemoryProjectStore(),
    autosaveDelay: const Duration(days: 1),
  );
  return (c: c, fake: fake);
}

void main() {
  muteAndCalloutTests();
  group('cutting (E1)', () {
    test('split uses the playhead on the OUTPUT timeline', () {
      final r = _rig(_base().duplicateSegment(0));
      r.c.seekOut(14000); // inside the second copy
      r.c.split();
      expect(r.c.project.segments.length, 3);
      expect(r.c.project.segments[1].endMs, 4000);
    });

    test('multi-select applies speed to every selected segment in one undo step', () {
      final r = _rig(_base().splitAt(3000).splitAt(6000));
      r.c.setMultiSelect(true);
      r.c.toggleSegment(2);
      r.c.setSpeed(2);
      expect(r.c.project.segments.map((s) => s.speed), [2, 1, 2]);
      r.c.setMultiSelect(false);
      r.c.undo();
      expect(r.c.project.segments.map((s) => s.speed), [1, 1, 1]);
    });

    test('freeze at the playhead cuts the segment and inserts a still between the halves', () {
      final r = _rig();
      r.c.seekOut(4000);
      r.c.freezeAtPlayhead(ms: 1500);
      final segs = r.c.project.segments;
      expect(segs.length, 3);
      expect(segs[1].isStill, isTrue);
      expect(segs[1].startMs, 4000);
      expect(r.c.project.outDurationMs, 11500);
    });

    test('freeze at the very start goes before the segment', () {
      final r = _rig();
      r.c.freezeAtPlayhead();
      expect(r.c.project.segments.first.isStill, isTrue);
      expect(r.c.project.segments.length, 2);
    });

    test('drag reorder moves the segment and selects it', () {
      final r = _rig(_base().splitAt(4000));
      r.c.moveSegmentTo(1, 0);
      expect(r.c.project.segments.first.startMs, 4000);
      expect(r.c.selectedSegment, 0);
    });

    test('reverse is refused for clips longer than the limit', () {
      final r = _rig(
        EditProject.fresh(
          sourceUri: 'x',
          name: 'x',
          durationMs: 120000,
          frameW: 720,
          frameH: 1600,
        ),
      );
      r.c.setReverse(true);
      expect(r.c.project.segments.first.reverse, isFalse);
      final s = _rig(_base());
      s.c.setReverse(true);
      expect(s.c.project.segments.first.reverse, isTrue);
    });

    test('frame stepping moves one frame', () {
      final r = _rig();
      r.c.stepFrame(3);
      expect(r.c.outMs, 3 * EditorController.frameMs);
    });
  });

  group('picture (E5)', () {
    test('rotate turns 90 degrees at a time and swaps the picture size', () {
      final r = _rig();
      r.c.rotate90();
      expect(r.c.look.rotation, 90);
      expect(r.c.pictureSize.width, 1600);
      r.c.rotate90();
      r.c.rotate90();
      r.c.rotate90();
      expect(r.c.look.rotation, 0);
    });

    test('crop is kept inside the picture and at least 10 percent', () {
      final r = _rig();
      r.c.setCrop(const Rect.fromLTRB(-0.5, 0.2, 0.15, 3));
      final c = r.c.look.crop;
      expect(c.left, 0);
      expect(c.right, closeTo(0.15, 1e-9));
      expect(c.bottom, 1.0);
      r.c.setCrop(const Rect.fromLTRB(0.5, 0.5, 0.52, 0.52));
      expect(r.c.look.crop.width, greaterThanOrEqualTo(0.1 - 1e-9));
    });

    test('the export carries rotation, crop, aspect and the colour matrix', () async {
      final r = _rig();
      r.c.rotate90();
      r.c.setCrop(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
      r.c.setAspect(OutAspect.r1x1);
      r.c.setColor(const ColorLook(saturation: 1.5));
      await r.c.startExport(ExportQuality.original);
      final job = r.fake.lastExportJob!;
      final pic = job['picture']! as Map;
      expect(pic['rotation'], 90);
      expect(pic['srcW'], 720);
      expect((pic['color'] as List).length, 16);
      expect(pic['aspect'], 1.0);
      expect(job['frameW'], 1600); // markers live in the rotated picture
      expect(pic['outW'], pic['outH']);
    });

    test('quality follows the output frame, not the source', () {
      final r = _rig();
      r.c.setCrop(const Rect.fromLTRB(0, 0, 1, 0.5));
      // the output is 720 x 800: 480p means short side 480 -> 480 x 532
      expect(r.c.outHeightFor(ExportQuality.p480), 532);
    });
  });

  group('overlays (E6)', () {
    test('an image, a shape and a picture-in-picture come from the phone picker', () async {
      final r = _rig();
      r.fake.nextPick = const PickedMedia(
        path: '/m/a.png',
        name: 'a.png',
        kind: 'image',
        durationMs: 0,
        width: 400,
        height: 200,
      );
      expect(await r.c.addImageFromPhone(), isTrue);
      expect(r.c.project.images.single.aspect, 2);
      r.c.addShape(ShapeKind.bubble);
      expect(r.c.project.shapes.single.text, isNotEmpty);
      r.fake.nextPick = const PickedMedia(
        path: '/m/p.mp4',
        name: 'p.mp4',
        kind: 'video',
        durationMs: 90000,
        width: 1920,
        height: 1080,
      );
      expect(await r.c.addPipFromPhone(), isTrue);
      expect(r.c.project.pips.single.durMs, EditorController.maxPipMs);
    });

    test('cancelling the picker adds nothing', () async {
      final r = _rig();
      expect(await r.c.addImageFromPhone(), isFalse);
      expect(r.c.project.images, isEmpty);
    });

    test('overlays reach the exporter with their timing', () async {
      final r = _rig();
      r.c.addShape(ShapeKind.arrow);
      r.c.addText();
      await r.c.startExport(ExportQuality.original);
      final job = r.fake.lastExportJob!;
      expect((job['shapes']! as List).length, 1);
      final text = (job['texts']! as List).single as Map;
      expect(text['motion'], isA<Map>());
      expect(text['font'], 'barlow');
    });

    test('step labels are added once per marker and replaced on a second run', () {
      var p = _base().upsertMarker(
        MarkerItem(
          id: 'm1',
          spec: const MarkerSpec(type: MarkerType.number, color: Color(0xFFFF0000), number: 3),
          cueStartMs: 1000,
        ),
      );
      p = AutoDirector.labelSteps(p, 'Bước ');
      p = AutoDirector.labelSteps(p, 'Bước ');
      expect(p.texts.length, 1);
      expect(p.texts.single.text, 'Bước 3');
    });
  });

  group('music and voice (E4)', () {
    test('adding music puts a looping, ducking track at the start', () async {
      final r = _rig();
      r.fake.nextPick = const PickedMedia(
        path: '/m/song.mp3',
        name: 'song.mp3',
        kind: 'audio',
        durationMs: 30000,
        width: 0,
        height: 0,
      );
      expect(await r.c.addMusicFromPhone(), isTrue);
      final t = r.c.project.audioTracks.single;
      expect(t.kind, AudioKind.music);
      expect(t.loop, isTrue);
      expect(t.duck, isTrue);
    });

    test('a voice-over is placed where recording started', () async {
      final r = _rig();
      r.c.seekOut(2500);
      await r.c.startVoice();
      expect(r.c.recordingVoice, isTrue);
      r.c.seekOut(6000);
      r.fake.nextVoice = (path: '/v.m4a', durationMs: 3500);
      await r.c.stopVoice();
      final t = r.c.project.audioTracks.single;
      expect(t.kind, AudioKind.voice);
      expect(t.startOutMs, 2500);
      expect(t.fileMs, 3500);
    });

    test('a too-short voice recording is dropped', () async {
      final r = _rig();
      await r.c.startVoice();
      r.fake.nextVoice = (path: '/v.m4a', durationMs: 120);
      await r.c.stopVoice();
      expect(r.c.project.audioTracks, isEmpty);
    });

    test('tracks and a picture-in-picture sound reach the exporter', () async {
      var p = _base().upsertAudio(
        const AudioTrack(
          id: 'a',
          kind: AudioKind.music,
          path: '/a.mp3',
          name: 'a',
          fileMs: 4000,
          loop: true,
        ),
      );
      p = p.upsertPip(
        const PipItem(
          id: 'p',
          path: '/p.mp4',
          name: 'p',
          isVideo: true,
          fileMs: 5000,
          pxW: 1280,
          pxH: 720,
          volume: 0.8,
          durMs: 3000,
        ),
      );
      final r = _rig(p);
      await r.c.startExport(ExportQuality.original);
      final job = r.fake.lastExportJob!;
      final clips = job['audioClips']! as List;
      expect(clips.length, 2);
      expect((clips[0] as Map)['playMs'], 10000);
      expect((clips[1] as Map)['music'], isFalse);
      expect((job['pips']! as List).single['playMs'], 3000);
    });

    test('normalize sets the volume from the measured loudness', () async {
      final r = _rig();
      r.fake.nextLoudness = -28;
      expect(await r.c.normalizeSelectedVolume(), isTrue);
      // -16 - (-28) = +12 dB = x3.98, capped at 2
      expect(r.c.project.segments.first.volume, 2.0);
      r.fake.nextLoudness = null;
      expect(await r.c.normalizeSelectedVolume(), isFalse);
    });
  });

  group('templates and presets (E7)', () {
    test('a captured style puts look, transitions and captions on another video', () {
      var p = _base().splitAt(5000);
      p = p.copyWith(look: const PictureLook(aspect: OutAspect.r9x16, color: ColorLook(saturation: 1.3)));
      p = p.setAllTransitions(const Transition(TransitionKind.dipBlack, 500));
      p = p.upsertText(const TextItem(id: 't', text: 'Intro', startMs: 0, endMs: 2000, font: TextFont.serif));
      final tpl = ProjectTemplate.capture('tpl1', 'Style', p);

      final other = _base().splitAt(2000).splitAt(7000);
      final r = _rig(other);
      r.c.applyTemplate(tpl);
      final q = r.c.project;
      expect(q.look.aspect, OutAspect.r9x16);
      expect(q.look.color.saturation, 1.3);
      expect(q.segments[1].transition?.kind, TransitionKind.dipBlack);
      expect(q.segments[2].transition?.kind, TransitionKind.dipBlack);
      expect(q.texts.single.text, 'Intro');
      expect(q.texts.single.font, TextFont.serif);
      // footage untouched
      expect(q.segments.length, 3);
      // undoable as one step
      r.c.undo();
      expect(r.c.project.texts, isEmpty);
    });

    test('the template store keeps and removes templates', () async {
      final store = MemoryTemplateStore();
      final tpl = ProjectTemplate.capture('a', 'A', _base());
      await store.save(tpl);
      expect((await store.list()).single.name, 'A');
      await store.delete('a');
      expect(await store.list(), isEmpty);
    });

    test('templates survive JSON', () {
      final tpl = ProjectTemplate.capture(
        'a',
        'A',
        _base().upsertText(const TextItem(id: 't', text: 'x', startMs: 0, endMs: 1000)),
      );
      final back = ProjectTemplate.fromJson(tpl.toJson());
      expect(back.texts.single.text, 'x');
      expect(back.name, 'A');
    });

    test('the share preset squeezes a long video into the cap', () {
      final r = _rig(
        EditProject.fresh(
          sourceUri: 'x',
          name: 'x',
          durationMs: 5 * 60 * 1000,
          frameW: 1080,
          frameH: 2400,
        ),
      );
      final plan = r.c.planFor(ExportQuality.p720, maxBytes: 24 * 1024 * 1024);
      expect(plan.estimatedBytes, lessThanOrEqualTo(24 * 1024 * 1024 * 1.02));
    });
  });
}

void muteAndCalloutTests() {
  group('fast mute and callouts', () {
    test('sound is dropped above 2x when the switch is on, kept otherwise', () {
      var p = _base().setSpeed(0, 3);
      expect(p.effectiveVolume(p.segments.first), 0);
      expect(p.gainOf(p.segments.first, 100), 0);
      p = p.copyWith(muteFast: false);
      expect(p.effectiveVolume(p.segments.first), 1);
      expect(_base().setSpeed(0, 2).effectiveVolume(_base().setSpeed(0, 2).segments.first), 1);
    });

    test('the export sends the effective volume', () async {
      final r = _rig(_base().setSpeed(0, 4));
      await r.c.startExport(ExportQuality.original);
      final seg = (r.fake.lastExportJob!['segments']! as List).single as Map;
      expect(seg['volume'], 0);
    });

    test('a callout opens beside the showing marker, tail pointing at it', () {
      final p = _base().upsertMarker(
        MarkerItem(
          id: 'm',
          spec: const MarkerSpec(
            type: MarkerType.finger,
            color: Color(0xFFFF0000),
            x0: 0.6,
            y0: 0.7,
            x1: 0.6,
            y1: 0.7,
          ),
          cueStartMs: 1000,
        ),
      );
      final r = _rig(p);
      r.c.seekOut(2000);
      r.c.addShape(ShapeKind.bubble);
      final b = r.c.project.shapes.single;
      // the bubble sits above the marker and its tail reaches the marker's place
      expect(b.y, lessThan(0.7));
      expect(b.x + b.tailX, closeTo(0.6, 1e-6));
      expect(b.y + b.tailY, closeTo(0.7, 1e-6));
    });
  });
}
