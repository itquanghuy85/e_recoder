import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

AudioTrack _voice() => const AudioTrack(
  id: 'v1',
  kind: AudioKind.voice,
  path: '/files/voice.m4a',
  name: 'Voice',
  fileMs: 4000,
);

void main() {
  group('AudioTrack voice work', () {
    test(
      'without effect the original plays; with one the processed file plays',
      () {
        final v = _voice();
        expect(v.playPath, '/files/voice.m4a');
        final done = v.copyWith(
          fx: VoiceFx.deep,
          denoise: Denoise.light,
          fxPath: '/files/voice_fx/a.m4a',
        );
        expect(done.hasVoiceWork, isTrue);
        expect(done.playPath, '/files/voice_fx/a.m4a');
        expect(done.path, '/files/voice.m4a'); // the original is kept
        // a choice whose file is not ready yet never plays a missing file
        expect(v.copyWith(fx: VoiceFx.robot).playPath, '/files/voice.m4a');
      },
    );

    test('is saved and loaded; old projects load without effect', () {
      final v = _voice().copyWith(
        fx: VoiceFx.reverb,
        denoise: Denoise.strong,
        fxPath: '/x.m4a',
      );
      final back = AudioTrack.fromJson(v.toJson());
      expect(back.fx, VoiceFx.reverb);
      expect(back.denoise, Denoise.strong);
      expect(back.fxPath, '/x.m4a');
      final old = AudioTrack.fromJson(_voice().toJson());
      expect(old.fx, VoiceFx.none);
      expect(old.denoise, Denoise.off);
      expect(old.fxPath, isNull);
      expect(_voice().toJson().containsKey('fx'), isFalse);
    });

    test('the exporter is given the processed file', () {
      final p = EditProject.fresh(
        sourceUri: 'x',
        name: 'x',
        durationMs: 10000,
        frameW: 720,
        frameH: 1600,
      ).upsertAudio(_voice().copyWith(fx: VoiceFx.high, fxPath: '/fx.m4a'));
      final clips =
          p.toExportMap(outHeight: 480, bitrate: 1000000)['audioClips']!
              as List;
      expect((clips.single as Map)['path'], '/fx.m4a');
      final plain = p.upsertAudio(_voice());
      expect(
        ((plain.toExportMap(outHeight: 480, bitrate: 1000000)['audioClips']!
                    as List)
                .single
            as Map)['path'],
        '/files/voice.m4a',
      );
    });
  });

  group('setVoiceFx', () {
    late FakeRecorder fake;
    late EditorController c;

    setUp(() {
      fake = FakeRecorder();
      c = EditorController(
        project: EditProject.fresh(
          sourceUri: 'x',
          name: 'x',
          durationMs: 10000,
          frameW: 720,
          frameH: 1600,
        ),
        native: fake,
        store: MemoryProjectStore(),
        autosaveDelay: const Duration(milliseconds: 10),
      );
      c.updateAudio(_voice());
    });

    tearDown(() => c.dispose());

    AudioTrack track() => c.project.audioTracks.single;

    test(
      'processes once, shows busy meanwhile, and is one undo step',
      () async {
        final f = c.setVoiceFx('v1', fx: VoiceFx.chipmunk);
        expect(c.voiceBusy, contains('v1'));
        expect(await f, isTrue);
        expect(c.voiceBusy, isEmpty);
        expect(track().fx, VoiceFx.chipmunk);
        expect(track().fxPath, '/files/voice.m4a.chipmunk.off.m4a');
        expect(fake.calls.where((e) => e.startsWith('processVoice')).length, 1);
        c.undo();
        expect(track().fx, VoiceFx.none);
        expect(track().fxPath, isNull);
      },
    );

    test(
      'effect and noise level combine; the original path is always the source',
      () async {
        await c.setVoiceFx('v1', fx: VoiceFx.echo);
        await c.setVoiceFx('v1', denoise: Denoise.strong);
        expect(track().fx, VoiceFx.echo);
        expect(track().denoise, Denoise.strong);
        expect(track().fxPath, '/files/voice.m4a.echo.strong.m4a');
        expect(fake.calls.last, 'processVoice:echo:strong');
      },
    );

    test(
      'Original + Off restores the untouched recording in one step',
      () async {
        await c.setVoiceFx('v1', fx: VoiceFx.deep, denoise: Denoise.light);
        await c.setVoiceFx('v1', fx: VoiceFx.none);
        expect(track().hasVoiceWork, isTrue); // noise reduction is still on
        final before = fake.calls.length;
        await c.setVoiceFx('v1', denoise: Denoise.off);
        expect(track().hasVoiceWork, isFalse);
        expect(track().fxPath, isNull);
        expect(track().playPath, '/files/voice.m4a');
        expect(
          fake.calls.length,
          before,
          reason: 'restoring needs no processing',
        );
        c.undo();
        expect(track().hasVoiceWork, isTrue);
      },
    );

    test('choosing what is already set does nothing', () async {
      await c.setVoiceFx('v1', fx: VoiceFx.robot);
      final n = fake.calls.length;
      expect(await c.setVoiceFx('v1', fx: VoiceFx.robot), isTrue);
      expect(fake.calls.length, n);
    });

    test('a failure leaves the track as it was and says so', () async {
      fake.voiceFxFails = true;
      expect(await c.setVoiceFx('v1', fx: VoiceFx.robot), isFalse);
      expect(c.voiceFxFailed, isTrue);
      expect(track().fx, VoiceFx.none);
      expect(c.voiceBusy, isEmpty);
      fake.voiceFxFails = false;
      expect(await c.setVoiceFx('v1', fx: VoiceFx.robot), isTrue);
      expect(c.voiceFxFailed, isFalse);
    });

    test('music is never touched', () async {
      c.updateAudio(
        const AudioTrack(
          id: 'm1',
          kind: AudioKind.music,
          path: '/m.mp3',
          name: 'm',
          fileMs: 9000,
        ),
      );
      expect(await c.setVoiceFx('m1', fx: VoiceFx.robot), isFalse);
      expect(fake.calls.where((e) => e.startsWith('processVoice')), isEmpty);
    });
  });
}
