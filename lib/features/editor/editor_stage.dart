import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../marker/marker_preview.dart' show CuePainter;
import '../marker/marker_spec.dart';
import '../marker/marker_sprite.dart';
import '../marker/marker_timing.dart';
import 'edit_project.dart';
import 'editor_controller.dart';
import 'editor_math.dart';
import 'region_preview.dart';

/// Where the picture and the output frame sit on screen, derived from the project's [PictureLook].
///
/// Two coordinate spaces exist, exactly as in the exporter:
///  * PICTURE space: the rotated source frame. Markers, covers and zoom live here.
///  * OUTPUT space: the frame after crop and shape. Text, images, shapes and picture-in-picture live here.
class StageGeometry {
  StageGeometry(this.project, Size box) {
    final o = project.outDims;
    outAspect = o.w / o.h;
    // The output frame fills the box (the caller already gave it the right aspect ratio).
    w = box.width;
    h = box.height;
    final look = project.look;
    final pr = look.pictureRectInOutput(project.frameW, project.frameH);
    pictureRect = Rect.fromLTWH(
      pr.left * w,
      pr.top * h,
      pr.width * w,
      pr.height * h,
    );
    final c = look.crop;
    fullW = pictureRect.width / c.width;
    fullH = pictureRect.height / c.height;
    fullLeft = pictureRect.left - c.left * fullW;
    fullTop = pictureRect.top - c.top * fullH;
    final pic = project.pictureDims;
    kPicture = fullW / pic.w;
    kOutput = w / o.w;
  }

  final EditProject project;
  late final double outAspect;
  late final double w;
  late final double h;

  /// The visible (cropped) part of the picture, in stage pixels.
  late final Rect pictureRect;

  /// The WHOLE rotated picture in stage pixels (larger than [pictureRect] when cropped).
  late final double fullW;
  late final double fullH;
  late final double fullLeft;
  late final double fullTop;

  /// Stage pixels per picture pixel / per output-frame pixel.
  late final double kPicture;
  late final double kOutput;

  /// A point in picture fractions as output fractions.
  Offset pictureToOutput(Offset p) =>
      Offset((fullLeft + p.dx * fullW) / w, (fullTop + p.dy * fullH) / h);
}

/// The preview: the video plus every overlay at the playhead, drawn from the same native
/// bitmaps and the same timing the exporter uses. Selected overlays can be dragged, and markers
/// pinched (scale + rotation).
class EditorStage extends StatefulWidget {
  const EditorStage({
    super.key,
    required this.controller,
    required this.video,
    this.pipVideos = const {},
    this.repaint,
    this.captureKey,
  });
  final EditorController controller;
  final VideoPlayerController video;

  /// One player per picture-in-picture video, by item id (kept in step by the screen).
  final Map<String, VideoPlayerController> pipVideos;

  /// Something else that should redraw the stage (a picture-in-picture player became ready).
  final Listenable? repaint;

  /// Marks the output frame so it can be captured as a picture ("save this frame").
  final GlobalKey? captureKey;

  @override
  State<EditorStage> createState() => _EditorStageState();
}

class _EditorStageState extends State<EditorStage> {
  EditorController get c => widget.controller;

  // gesture bookkeeping
  StageGeometry? _g;
  MarkerItem? _gMarker;
  TextItem? _gText;
  CoverItem? _gCover;
  ZoomItem? _gZoom;
  ImageItem? _gImage;
  ShapeItem? _gShape;
  PipItem? _gPip;

  void _start(ScaleStartDetails d) {
    final id = c.selectedId;
    if (id == null) return;
    c.beginGesture();
    final p = c.project;
    _gMarker = p.markers.where((e) => e.id == id).firstOrNull;
    _gText = p.texts.where((e) => e.id == id).firstOrNull;
    _gCover = p.covers.where((e) => e.id == id).firstOrNull;
    _gZoom = p.zooms.where((e) => e.id == id).firstOrNull;
    _gImage = p.images.where((e) => e.id == id).firstOrNull;
    _gShape = p.shapes.where((e) => e.id == id).firstOrNull;
    _gPip = p.pips.where((e) => e.id == id).firstOrNull;
  }

  void _update(ScaleUpdateDetails d) {
    final g = _g;
    if (g == null || g.w <= 0) return;
    // Output-space deltas (text, images, shapes) and picture-space deltas (markers, covers, zoom).
    final ox = d.focalPointDelta.dx / g.w;
    final oy = d.focalPointDelta.dy / g.h;
    final px = d.focalPointDelta.dx / g.fullW;
    final py = d.focalPointDelta.dy / g.fullH;
    final two = d.pointerCount >= 2;
    final p = c.project;
    final m = _gMarker;
    if (m != null) {
      final cur = p.markers.firstWhere((e) => e.id == m.id);
      var s = _translate(cur.spec, px, py);
      if (two) {
        s = s.copyWith(
          scale: (m.spec.scale * d.scale).clamp(0.4, 4.0),
          rotation: m.spec.rotation + d.rotation * 180 / math.pi,
        );
      }
      c.updateMarker(cur.copyWith(spec: s), record: false);
      return;
    }
    final t = _gText;
    if (t != null) {
      final cur = p.texts.firstWhere((e) => e.id == t.id);
      c.updateText(
        cur.copyWith(
          x: (cur.x + ox).clamp(0.0, 1.0),
          y: (cur.y + oy).clamp(0.0, 1.0),
          sizeU: two ? (t.sizeU * d.scale).clamp(8.0, 80.0) : null,
          rotation: two ? t.rotation + d.rotation * 180 / math.pi : null,
        ),
        record: false,
      );
      return;
    }
    final im = _gImage;
    if (im != null) {
      final cur = p.images.firstWhere((e) => e.id == im.id);
      c.updateImage(
        cur.copyWith(
          x: (cur.x + ox).clamp(0.0, 1.0),
          y: (cur.y + oy).clamp(0.0, 1.0),
          widthFrac: two ? (im.widthFrac * d.scale).clamp(0.05, 1.5) : null,
          rotation: two ? im.rotation + d.rotation * 180 / math.pi : null,
        ),
        record: false,
      );
      return;
    }
    final sh = _gShape;
    if (sh != null) {
      final cur = p.shapes.firstWhere((e) => e.id == sh.id);
      c.updateShape(
        cur.copyWith(
          x: (cur.x + ox).clamp(0.0, 1.0),
          y: (cur.y + oy).clamp(0.0, 1.0),
          w: two ? (sh.w * d.scale).clamp(0.05, 1.5) : null,
          h: two ? (sh.h * d.scale).clamp(0.03, 1.5) : null,
          rotation: two ? sh.rotation + d.rotation * 180 / math.pi : null,
        ),
        record: false,
      );
      return;
    }
    final pp = _gPip;
    if (pp != null) {
      final cur = p.pips.firstWhere((e) => e.id == pp.id);
      c.updatePip(
        cur.copyWith(
          x: (cur.x + ox).clamp(0.0, 1.0),
          y: (cur.y + oy).clamp(0.0, 1.0),
          widthFrac: two ? (pp.widthFrac * d.scale).clamp(0.1, 0.9) : null,
        ),
        record: false,
      );
      return;
    }
    final cv = _gCover;
    if (cv != null) {
      final cur = p.covers.firstWhere((e) => e.id == cv.id);
      final r = cur.editRect(c.coverEditEnd);
      final x0 = (r.left + px).clamp(0.0, 1.0 - r.width);
      final y0 = (r.top + py).clamp(0.0, 1.0 - r.height);
      c.updateCover(
        cur.withRect(
          Rect.fromLTWH(x0, y0, r.width, r.height),
          atEnd: c.coverEditEnd,
        ),
        record: false,
      );
      return;
    }
    final z = _gZoom;
    if (z != null) {
      final cur = p.zooms.firstWhere((e) => e.id == z.id);
      c.updateZoom(
        cur.copyWith(
          fx: (cur.fx + px).clamp(0.0, 1.0),
          fy: (cur.fy + py).clamp(0.0, 1.0),
        ),
        record: false,
      );
    }
  }

  MarkerSpec _translate(MarkerSpec s, double dx, double dy) {
    if (s.type == MarkerType.pen) {
      final pts = [
        for (var i = 0; i + 1 < s.points.length; i += 2) ...[
          s.points[i] + dx,
          s.points[i + 1] + dy,
        ],
      ];
      return s.copyWith(points: pts);
    }
    return s.copyWith(
      x0: s.x0 + dx,
      y0: s.y0 + dy,
      x1: s.x1 + dx,
      y1: s.y1 + dy,
    );
  }

  void _end(ScaleEndDetails d) {
    _gMarker = _gText = null;
    _gCover = null;
    _gZoom = null;
    _gImage = null;
    _gShape = null;
    _gPip = null;
    c.flush();
  }

  /// Tap picks the overlay nearest the touch (within reach) at the playhead; empty space deselects.
  void _tap(TapUpDetails d) {
    final g = _g;
    if (g == null || g.w <= 0) return;
    // Compare in OUTPUT fractions; picture-space items are converted first.
    final p = Offset(d.localPosition.dx / g.w, d.localPosition.dy / g.h);
    final t = c.sourceMs;
    final out = c.outMs;
    final pr = c.project;
    String? best;
    var bestDist = 0.12;
    void consider(String id, Offset at) {
      final dist = (at - p).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = id;
      }
    }

    for (final m in pr.markers) {
      if (t >= m.cueStartMs && t <= m.endMs) {
        final a = m.spec.anchor;
        consider(m.id, g.pictureToOutput(Offset(a.x, a.y)));
      }
    }
    for (final x in pr.covers) {
      if (t >= x.startMs && t <= x.endMs) {
        consider(
          x.id,
          g.pictureToOutput(Offset((x.x0 + x.x1) / 2, (x.y0 + x.y1) / 2)),
        );
      }
    }
    for (final x in pr.zooms) {
      if (t >= x.startMs && t <= x.endMs) {
        consider(x.id, g.pictureToOutput(Offset(x.fx, x.fy)));
      }
    }
    for (final x in pr.texts) {
      if (t >= x.startMs && t <= x.endMs) consider(x.id, Offset(x.x, x.y));
    }
    for (final x in pr.images) {
      if (t >= x.startMs && t <= x.endMs) consider(x.id, Offset(x.x, x.y));
    }
    for (final x in pr.shapes) {
      if (t >= x.startMs && t <= x.endMs) consider(x.id, Offset(x.x, x.y));
    }
    for (final x in pr.pips) {
      if (out >= x.startOutMs &&
          out <= x.startOutMs + x.playMs(pr.outDurationMs)) {
        consider(x.id, Offset(x.x, x.y));
      }
    }
    c.select(best);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([c, widget.video, ?widget.repaint]),
      builder: (context, _) {
        final p = c.project;
        final o = p.outDims;
        final aspect = o.w / o.h;
        return Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: LayoutBuilder(
              builder: (context, box) {
                final g = StageGeometry(p, Size(box.maxWidth, box.maxHeight));
                _g = g;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _tap,
                  onScaleStart: _start,
                  onScaleUpdate: _update,
                  onScaleEnd: _end,
                  child: RepaintBoundary(
                    key: widget.captureKey,
                    child: ClipRect(child: _frame(context, p, g, cs)),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _frame(
    BuildContext context,
    EditProject p,
    StageGeometry g,
    ColorScheme cs,
  ) {
    final selected = c.selectedId;
    final t = c.sourceMs;
    final segIdx = p.segmentAtOut(c.outMs);
    final blank = segIdx >= 0 && p.segments[segIdx].blank;
    final look = p.transitionLookAt(c.outMs);

    // What is drawn inside the output frame, before the colour look and the transition.
    final content = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        _pictureLayer(p, g, t, blank, selected, cs),
        ..._outputLayer(p, g, t, selected, cs),
      ],
    );

    Widget framed = content;
    if (!p.look.color.isNone) {
      framed = ColorFiltered(
        colorFilter: ColorFilter.matrix(p.look.color.flutterMatrix),
        child: framed,
      );
    }
    framed = _transitioned(look, g.w, g.h, framed);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: framed),
        if (selected != null) ..._selection(p, selected, g, cs),
      ],
    );
  }

  /// The video, covers, markers and zoom, in PICTURE space, cropped into the output frame.
  Widget _pictureLayer(
    EditProject p,
    StageGeometry g,
    int t,
    bool blank,
    String? selected,
    ColorScheme cs,
  ) {
    final fw = g.fullW;
    final fh = g.fullH;
    final k = g.kPicture;
    final zoomSelected = p.zooms.any((z) => z.id == selected);
    final zoom = zoomSelected
        ? (scale: 1.0, cx: 0.5, cy: 0.5)
        : zoomAt(p.zooms, t);
    final quarter = (p.look.rotation ~/ 90) % 4;
    final video = widget.video.value.isInitialized && !blank
        ? RotatedBox(quarterTurns: quarter, child: VideoPlayer(widget.video))
        : const ColoredBox(color: Colors.black);

    Widget scene = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: video),
        for (final cv in p.covers)
          if (t >= cv.startMs && t <= cv.endMs)
            RegionPreview(item: cv, fw: fw, fh: fh, t: t),
        for (final m in p.markers) ..._marker(m, t, fw, fh, k),
      ],
    );
    if (zoom.scale > 1.0001) {
      scene = ClipRect(
        child: Transform(
          transform: Matrix4.identity()
            ..translateByDouble(fw / 2, fh / 2, 0, 1)
            ..scaleByDouble(zoom.scale, zoom.scale, 1, 1)
            ..translateByDouble(-zoom.cx * fw, -zoom.cy * fh, 0, 1),
          child: scene,
        ),
      );
    }
    // Crop + shape: only the cropped part shows, inside the rectangle the picture occupies.
    return Positioned.fromRect(
      rect: g.pictureRect,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: fw,
          maxWidth: fw,
          minHeight: fh,
          maxHeight: fh,
          child: Transform.translate(
            offset: Offset(
              g.fullLeft - g.pictureRect.left,
              g.fullTop - g.pictureRect.top,
            ),
            child: SizedBox(width: fw, height: fh, child: scene),
          ),
        ),
      ),
    );
  }

  /// Images, shapes, text and picture-in-picture, in OUTPUT space.
  List<Widget> _outputLayer(
    EditProject p,
    StageGeometry g,
    int t,
    String? selected,
    ColorScheme cs,
  ) {
    final out = c.outMs;
    return [
      for (final im in p.images)
        if (t >= im.startMs && t <= im.endMs) _imageWidget(im, g, t),
      for (final sh in p.shapes)
        if (t >= sh.startMs && t <= sh.endMs) _shapeWidget(sh, g, t),
      for (final x in p.texts)
        if (t >= x.startMs && t <= x.endMs) _textWidget(x, g, t),
      for (final pip in p.pips)
        if (out >= pip.startOutMs &&
            out <= pip.startOutMs + pip.playMs(p.outDurationMs))
          _pipWidget(pip, g, out),
    ];
  }

  /// Places [child] (sized [cw] x [ch] stage pixels) at the motion state of an overlay.
  Widget _placed(
    Widget child,
    double cw,
    double ch,
    MotionState st,
    double rotation,
    StageGeometry g,
  ) {
    if (!st.visible) return const SizedBox.shrink();
    return Positioned(
      left: st.x * g.w - cw / 2,
      top: st.y * g.h - ch / 2,
      width: cw,
      height: ch,
      child: IgnorePointer(
        child: Opacity(
          opacity: st.alpha,
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: Transform.scale(scale: st.scale, child: child),
          ),
        ),
      ),
    );
  }

  Widget _imageWidget(ImageItem im, StageGeometry g, int t) {
    final st = motionAt(
      im.motion,
      x: im.x,
      y: im.y,
      scale: 1,
      opacity: im.opacity,
      t: t - im.startMs,
      lifeMs: im.endMs - im.startMs,
    );
    final cw = im.widthFrac * g.w;
    final ch = cw / im.aspect;
    return _placed(
      Image.file(File(im.path), fit: BoxFit.fill, gaplessPlayback: true),
      cw,
      ch,
      st,
      im.rotation,
      g,
    );
  }

  Widget _shapeWidget(ShapeItem sh, StageGeometry g, int t) {
    final st = motionAt(
      sh.motion,
      x: sh.x,
      y: sh.y,
      scale: 1,
      opacity: sh.opacity,
      t: t - sh.startMs,
      lifeMs: sh.endMs - sh.startMs,
    );
    return FutureBuilder<RenderedImage>(
      future: c.shapeImage(sh),
      builder: (context, snap) {
        final img = snap.data;
        if (img == null) return const SizedBox.shrink();
        return _placed(
          Image.memory(
            img.png,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
          img.w * g.kOutput,
          img.h * g.kOutput,
          st,
          sh.rotation,
          g,
        );
      },
    );
  }

  Widget _textWidget(TextItem x, StageGeometry g, int t) {
    final st = motionAt(
      x.motion,
      x: x.x,
      y: x.y,
      scale: 1,
      opacity: x.opacity,
      t: t - x.startMs,
      lifeMs: x.endMs - x.startMs,
    );
    return FutureBuilder<RenderedImage>(
      future: c.textImage(x),
      builder: (context, snap) {
        final img = snap.data;
        if (img == null) return const SizedBox.shrink();
        return _placed(
          Image.memory(
            img.png,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
          img.w * g.kOutput,
          img.h * g.kOutput,
          st,
          x.rotation,
          g,
        );
      },
    );
  }

  Widget _pipWidget(PipItem pip, StageGeometry g, int out) {
    final cw = pip.widthFrac * g.w;
    final ch = cw / pip.aspect;
    final end = pip.startOutMs + pip.playMs(c.project.outDurationMs);
    final fade = math.min(out - pip.startOutMs, end - out).clamp(0, 160) / 160;
    final st = MotionState(pip.x, pip.y, 1, pip.opacity * fade);
    final v = widget.pipVideos[pip.id];
    final Widget child = pip.isVideo
        ? (v != null && v.value.isInitialized
              ? VideoPlayer(v)
              : const ColoredBox(color: Colors.black54))
        : Image.file(File(pip.path), fit: BoxFit.fill, gaplessPlayback: true);
    return _placed(child, cw, ch, st, 0, g);
  }

  /// The picture as a transition shows it: same maths as TransitionEffect.kt (colour mul/add, shift, scale)
  /// over black, so what slides out of the frame leaves black behind it, as in the export.
  Widget _transitioned(TransitionLook look, double w, double h, Widget child) {
    if (look.isNone) return child;
    Widget r = child;
    if (look.mul != 1 || look.add != 0) {
      final m = look.mul;
      final a = look.add * 255;
      r = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          m, 0, 0, 0, a, //
          0, m, 0, 0, a,
          0, 0, m, 0, a,
          0, 0, 0, 1, 0,
        ]),
        child: r,
      );
    }
    if (look.dx != 0 || look.dy != 0 || look.scale != 1) {
      r = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(look.dx * w / 2, -look.dy * h / 2, 0, 1)
          ..scaleByDouble(look.scale, look.scale, 1, 1),
        child: r,
      );
    }
    return ColoredBox(color: Colors.black, child: r);
  }

  List<Widget> _marker(MarkerItem m, int t, double w, double h, double k) {
    final spec = m.spec;
    var rel = t - m.cueStartMs;
    var fadeStart = MarkerTiming.cueMs + m.holdMs;
    if (spec.type == MarkerType.pen) {
      rel += MarkerTiming.cueMs;
      fadeStart += MarkerTiming.cueMs;
    }
    final f = MarkerTiming.frame(rel, fadeStart);
    if (rel < 0 || f.done) return const [];
    final a = spec.anchor;
    return [
      if (f.cueProgress >= 0)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CuePainter(
                spec: spec,
                progress: f.cueProgress,
                frameW: w,
                frameH: h,
              ),
            ),
          ),
        ),
      if (f.bodyAlpha > 0)
        Positioned.fill(
          child: IgnorePointer(
            child: MarkerSprite(
              spec: spec,
              phase: markerPhase(context, rel),
              load: (p) async {
                final img = await c.markerImage(spec, p);
                return (png: img.png, side: img.w);
              },
              builder: (context, png, imgSide) {
                final side = imgSide * k;
                return Stack(
                  children: [
                    Positioned(
                      left: a.x * w - side / 2,
                      top: a.y * h - side / 2,
                      width: side,
                      height: side,
                      child: Opacity(
                        opacity: f.bodyAlpha.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: f.bodyScale,
                          child: Image.memory(
                            png,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
    ];
  }

  /// Key-cyan outline around the selected overlay so it is obvious what a drag will move.
  List<Widget> _selection(
    EditProject p,
    String id,
    StageGeometry g,
    ColorScheme cs,
  ) {
    Rect? r;
    // picture-space items: map the picture rectangle into stage pixels
    Rect fromPicture(Rect pr) => Rect.fromLTRB(
      g.fullLeft + pr.left * g.fullW,
      g.fullTop + pr.top * g.fullH,
      g.fullLeft + pr.right * g.fullW,
      g.fullTop + pr.bottom * g.fullH,
    );
    final m = p.markers.where((e) => e.id == id).firstOrNull;
    if (m != null) {
      final a = m.spec.anchor;
      final side = 90 * g.kPicture * math.max(1, m.spec.scale);
      final centre = Offset(
        g.fullLeft + a.x * g.fullW,
        g.fullTop + a.y * g.fullH,
      );
      r = Rect.fromCenter(center: centre, width: side, height: side);
      if (m.spec.type == MarkerType.circle || m.spec.type == MarkerType.rect) {
        r = fromPicture(
          Rect.fromLTRB(
            math.min(m.spec.x0, m.spec.x1),
            math.min(m.spec.y0, m.spec.y1),
            math.max(m.spec.x0, m.spec.x1),
            math.max(m.spec.y0, m.spec.y1),
          ),
        ).inflate(6);
      }
    }
    final tx = p.texts.where((e) => e.id == id).firstOrNull;
    if (tx != null) {
      r = Rect.fromCenter(
        center: Offset(tx.x * g.w, tx.y * g.h),
        width: math.max(60, tx.text.length * tx.sizeU * 0.55 * g.kOutput),
        height: tx.sizeU * 1.5 * g.kOutput,
      );
    }
    final im = p.images.where((e) => e.id == id).firstOrNull;
    if (im != null) {
      final cw = im.widthFrac * g.w;
      r = Rect.fromCenter(
        center: Offset(im.x * g.w, im.y * g.h),
        width: cw,
        height: cw / im.aspect,
      );
    }
    final sh = p.shapes.where((e) => e.id == id).firstOrNull;
    if (sh != null) {
      r = Rect.fromCenter(
        center: Offset(sh.x * g.w, sh.y * g.h),
        width: sh.w * g.w,
        height: sh.h * g.h,
      );
    }
    final pip = p.pips.where((e) => e.id == id).firstOrNull;
    if (pip != null) {
      final cw = pip.widthFrac * g.w;
      r = Rect.fromCenter(
        center: Offset(pip.x * g.w, pip.y * g.h),
        width: cw,
        height: cw / pip.aspect,
      );
    }
    final cv = p.covers.where((e) => e.id == id).firstOrNull;
    if (cv != null) {
      r = fromPicture(cv.editRect(c.coverEditEnd));
    }
    final z = p.zooms.where((e) => e.id == id).firstOrNull;
    if (z != null) {
      final half = 0.5 / z.scale;
      final cx = z.fx.clamp(half, 1 - half);
      final cy = z.fy.clamp(half, 1 - half);
      r = fromPicture(
        Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
      );
    }
    if (r == null) return const [];
    return [
      Positioned.fromRect(
        rect: r,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: cs.tertiary, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    ];
  }
}
