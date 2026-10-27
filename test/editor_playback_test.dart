import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_playback.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

class _Port implements PlayerPort {
  int pos = 0;
  bool playing = false;
  double speed = 1;
  double volume = 1;
  final seeks = <int>[];
  final speeds = <double>[];

  @override
  Future<void> seekTo(int ms) async {
    pos = ms;
    seeks.add(ms);
  }

  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<int?> positionMs() async => pos;
  @override
  Future<void> setSpeed(double s) async {
    speed = s;
    speeds.add(s);
  }

  @override
  Future<void> setVolume(double v) async => volume = v;
}

EditProject _base() => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: 10000,
  frameW: 720,
  frameH: 1600,
);

({EditorController c, _Port port, PlaybackDriver d, _Clock clock}) _rig(
  EditProject p,
) {
  final c = EditorController(
    project: p,
    native: FakeRecorder(),
    store: MemoryProjectStore(),
  );
  final port = _Port();
  final clock = _Clock();
  final d = PlaybackDriver(controller: c, player: port, nowMs: () => clock.t);
  return (c: c, port: port, d: d, clock: clock);
}

class _Clock {
  int t = 0;
}

void main() {
  test('plays forward and follows the player position', () async {
    final r = _rig(_base().setSpeed(0, 2));
    await r.d.play();
    expect(r.port.playing, isTrue);
    expect(r.port.speed, 2);
    r.port.pos = 4000; // the player is 4 s into the source
    await r.d.tick();
    expect(r.c.outMs, 2000);
  });

  test(
    'a segment end jumps to the start of the next one in SEQUENCE order',
    () async {
      var p = _base()
          .splitAt(4000)
          .moveSegmentTo(1, 0); // [4000..10000][0..4000]
      final r = _rig(p);
      await r.d.play();
      expect(r.port.pos, 4000);
      r.port.pos = 9990;
      await r.d.tick();
      expect(r.port.pos, 0); // jumped to the second segment
      expect(r.c.outMs, 6000);
    },
  );

  test('a speed ramp changes the player speed as it goes', () async {
    final r = _rig(_base().setSpeedRamp(0, 1, 4));
    await r.d.play();
    final first = r.port.speed;
    r.port.pos = 9000;
    await r.d.tick();
    expect(r.port.speed, greaterThan(first));
  });

  test('a freeze frame runs on the wall clock and holds one frame', () async {
    var p = _base().splitAt(4000);
    p = p.insertFreeze(0, 4000, ms: 1500);
    final r = _rig(p);
    r.c.seekOut(4000);
    await r.d.play();
    expect(r.port.playing, isFalse);
    expect(r.port.pos, 4000);
    r.clock.t = 700;
    await r.d.tick();
    expect(r.c.outMs, 4700);
    expect(r.port.pos, 4000);
    r.clock.t = 1600; // past the end of the still
    await r.d.tick();
    expect(r.port.pos, 4000); // next segment starts at source 4000
    expect(r.port.playing, isTrue);
  });

  test('a reversed clip steps backwards through the source', () async {
    final r = _rig(_base().setReverse(0, true));
    await r.d.play();
    expect(r.port.pos, 10000);
    r.clock.t = 2000;
    await r.d.tick();
    expect(r.c.outMs, 2000);
    expect(r.port.pos, closeTo(8000, 40));
    expect(r.port.playing, isFalse);
  });

  test('segment volume and fades reach the player', () async {
    final r = _rig(_base().setAudio(0, volume: 0.5, fadeInMs: 1000));
    await r.d.play();
    expect(r.port.volume, closeTo(0, 0.01)); // start of the fade-in
    r.port.pos = 2000;
    await r.d.tick();
    expect(r.port.volume, closeTo(0.5, 0.01));
  });

  test('playback stops at the end and parks the playhead there', () async {
    final r = _rig(_base());
    await r.d.play();
    r.port.pos = 9990;
    await r.d.tick();
    expect(r.c.playing, isFalse);
    expect(r.c.outMs, 10000);
  });
}
