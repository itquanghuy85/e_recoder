import 'dart:ui' show Offset, Rect, Size;

import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_stage.dart';
import 'package:flutter_test/flutter_test.dart';

EditProject _p([PictureLook look = PictureLook.identity]) => EditProject.fresh(
  sourceUri: 'x',
  name: 'x',
  durationMs: 5000,
  frameW: 720,
  frameH: 1600,
).copyWith(look: look);

void main() {
  test('identity: the picture fills the stage and both spaces coincide', () {
    final g = StageGeometry(_p(), const Size(360, 800));
    expect(g.pictureRect, const Rect.fromLTWH(0, 0, 360, 800));
    expect(g.fullW, 360);
    expect(g.fullLeft, 0);
    expect(g.kPicture, closeTo(0.5, 1e-9));
    expect(g.kOutput, closeTo(0.5, 1e-9));
    expect(g.pictureToOutput(const Offset(0.25, 0.75)), const Offset(0.25, 0.75));
  });

  test('a crop zooms the whole picture up and shifts it so only the crop shows', () {
    final look = const PictureLook(crop: Rect.fromLTRB(0.25, 0.25, 0.75, 0.75));
    final p = _p(look);
    final o = p.outDims; // 360 x 800 (half of each side)
    final g = StageGeometry(p, Size(o.w / 2, o.h / 2));
    expect(g.pictureRect.width, g.w);
    expect(g.fullW, closeTo(g.w * 2, 1e-9));
    expect(g.fullLeft, closeTo(-0.25 * g.fullW, 1e-9));
    // the crop's own centre is the middle of the stage
    final c = g.pictureToOutput(const Offset(0.5, 0.5));
    expect(c.dx, closeTo(0.5, 1e-9));
    expect(c.dy, closeTo(0.5, 1e-9));
    // a point on the left edge of the crop lands on the left edge of the output
    expect(g.pictureToOutput(const Offset(0.25, 0.25)).dx, closeTo(0, 1e-9));
  });

  test('rotation changes the picture size but the output follows it', () {
    final p = _p(const PictureLook(rotation: 90));
    expect(p.pictureDims.w, 1600);
    expect(p.outDims.h, 720);
    final g = StageGeometry(p, const Size(800, 360));
    expect(g.kPicture, closeTo(0.5, 1e-9));
  });

  test('a wider output shape leaves bars: the picture sits centred and smaller', () {
    final p = _p(const PictureLook(aspect: OutAspect.r16x9));
    final o = p.outDims;
    final g = StageGeometry(p, Size(o.w / 4, o.h / 4));
    expect(g.pictureRect.height, closeTo(g.h, 1e-6));
    expect(g.pictureRect.width, lessThan(g.w));
    expect(g.pictureRect.center.dx, closeTo(g.w / 2, 1e-6));
  });

  test('fill: the picture covers the whole output and overflows it', () {
    final p = _p(const PictureLook(aspect: OutAspect.r16x9, fill: true));
    final o = p.outDims;
    final g = StageGeometry(p, Size(o.w / 4, o.h / 4));
    expect(g.pictureRect.width, closeTo(g.w, 1e-6));
    expect(g.pictureRect.height, greaterThan(g.h));
  });
}
