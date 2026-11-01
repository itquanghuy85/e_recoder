import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:flutter_test/flutter_test.dart';

/// Projects saved before captions existed must open and save unchanged, with all six old effects.
void main() {
  Map<String, dynamic> oldText(String fx) => {
    'id': 't_$fx',
    'text': 'Văn bản',
    'color': 0xFFFFFFFF,
    'sizeU': 20.0,
    'x': 0.5,
    'y': 0.5,
    'startMs': 0,
    'endMs': 3000,
    'bold': true,
    'font': 'barlow',
    'outline': true,
    'shadow': false,
    'align': 'center',
    'rotation': 0.0,
    'opacity': 1.0,
    'fx': fx,
  };

  test(
    'a text saved before captions loads with no cues and no caption style',
    () {
      for (final fx in TextFx.values) {
        final t = TextItem.fromJson(oldText(fx.name));
        expect(t.fx, fx);
        expect(t.cues, isNull);
        expect(t.captionStyle, isNull);
      }
    },
  );

  test('the old text effects are all still there', () {
    expect(
      TextFx.values.map((e) => e.name),
      containsAll([
        'none',
        'glow',
        'gradient',
        'extrude',
        'hollow',
        'glitch',
        'sticker',
      ]),
    );
  });

  test(
    'saving an old text adds no caption keys, for the file and for the export',
    () {
      final t = TextItem.fromJson(oldText('glow'));
      expect(t.toJson().containsKey('cues'), isFalse);
      expect(t.toJson().containsKey('captionStyle'), isFalse);
      expect(t.toNative().containsKey('cues'), isFalse);
      expect(t.toNative().containsKey('captionStyle'), isFalse);
    },
  );

  test('a whole old project survives a save and load', () {
    final p = EditProject.fresh(
      sourceUri: 'content://v/1',
      name: 'a.mp4',
      durationMs: 5000,
      frameW: 720,
      frameH: 1280,
    ).upsertText(TextItem.fromJson(oldText('sticker')));
    final back = EditProject.decode(p.encode());
    expect(back.texts.single.fx, TextFx.sticker);
    expect(back.texts.single.text, 'Văn bản');
    expect(back.encode(), p.encode());
  });

  test('a caption survives a save and load with its look', () {
    final item = TextItem.fromJson({
      ...oldText('none'),
      'text': '',
      'cues': [
        {
          'text': 'Xin chào',
          'startMs': 0,
          'endMs': 1000,
          'words': [
            {'text': 'Xin', 'startMs': 0, 'endMs': 500},
            {'text': 'chào', 'startMs': 500, 'endMs': 1000},
          ],
        },
      ],
      'captionStyle': {
        'fontId': 'serif',
        'revealMode': 'karaokeHighlight',
        'templateId': 'cinema',
      },
    });
    final p = EditProject.fresh(
      sourceUri: 'content://v/1',
      name: 'a.mp4',
      durationMs: 5000,
      frameW: 720,
      frameH: 1280,
    ).upsertText(item);
    final back = EditProject.decode(p.encode()).texts.single;
    expect(back.cues!.single.words.length, 2);
    expect(back.captionStyle!.fontId, 'serif');
    expect(back.captionStyle!.templateId, 'cinema');
  });
}
