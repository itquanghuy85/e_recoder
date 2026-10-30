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
    this.viewZoom = true,
  });
  final EditorController controller;

  /// Two-finger zoom and pan of the preview (only for looking; never saved or exported). Only
  /// active while no overlay is selected: with one selected, pinch edits that overlay instead.
  /// Off in the full-screen viewer, which has its own zoom.
  final bool viewZoom;
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

  // view zoom (look only)
  ViewZoom _view = const ViewZoom();
  bool _viewMode = false;
  double _viewScale0 = 1;
  Offset _viewQ = Offset.zero;
  DateTime? _lastTapAt;
  Offset _lastTapPos = Offset.zero;

  ViewZoom get _z => widget.viewZoom ? _view : const ViewZoom();

  Offset? _downAt;
  int _fingers = 0;

  // handles of the selected overlay (resize, rotate) and the snap guides shown while dragging
  _Handle _handle = _Handle.none;
  int _hCorner = 0;
  double _hDist0 = 1;
  double _hBase = 1;
  double _hBase2 = 1;
  double _hRot0 = 0;
  double _hAngle0 = 0;
  Offset _hCenter = Offset.zero;
  double _hHalfW = 0;
  double _hHalfH = 0;
  List<double> _guideX = const [];
  List<double> _guideY = const [];

  static const double _snapTol = 0.012;

  /// Moves [v] (a centre, in frame fractions) so that its centre or an edge sits on 0 / 0.5 / 1 when it
  /// is within the tolerance; returns the new value and records the line to draw.
  double _snapAxis(double v, double half, List<double> guides) {
    var best = v;
    var bestD = _snapTol;
    double? line;
    void tryTarget(double edge, double target) {
      final d = (edge - target).abs();
      if (d < bestD) {
        bestD = d;
        best = v + (target - edge);
        line = target;
      }
    }

    tryTarget(v, 0.5);
    tryTarget(v - half, 0);
    tryTarget(v + half, 1);
    tryTarget(v - half, 0.5);
    tryTarget(v + half, 0.5);
    if (line != null) guides.add(line!);
    return best;
  }

  Rect _fromPicture(StageGeometry g, Rect pr) => Rect.fromLTRB(
    g.fullLeft + pr.left * g.fullW,
    g.fullTop + pr.top * g.fullH,
    g.fullLeft + pr.right * g.fullW,
    g.fullTop + pr.bottom * g.fullH,
  );

  /// The overlay's frame on the stage (stage pixels), or null when it has none.
  _Frame? _frameOf(EditProject p, String id, StageGeometry g) {
    final m = p.markers.where((e) => e.id == id).firstOrNull;
    if (m != null) {
      final sp = m.spec;
      if (sp.type == MarkerType.circle || sp.type == MarkerType.rect) {
        return _Frame(
          _fromPicture(
            g,
            Rect.fromLTRB(
              math.min(sp.x0, sp.x1),
              math.min(sp.y0, sp.y1),
              math.max(sp.x0, sp.x1),
              math.max(sp.y0, sp.y1),
            ),
          ).inflate(6),
          0,
          kind: _FrameKind.rect,
        );
      }
      if (sp.type == MarkerType.pen) return null;
      final a = sp.anchor;
      final side = 90 * g.kPicture * math.max(1, sp.scale);
      return _Frame(
        Rect.fromCenter(
          center: Offset(g.fullLeft + a.x * g.fullW, g.fullTop + a.y * g.fullH),
          width: side,
          height: side,
        ),
        sp.rotation,
        kind: _FrameKind.scaleRotate,
      );
    }
    final tx = p.texts.where((e) => e.id == id).firstOrNull;
    if (tx != null) {
      return _Frame(
        Rect.fromCenter(
          center: Offset(tx.x * g.w, tx.y * g.h),
          width: math.max(60, tx.text.length * tx.sizeU * 0.55 * g.kOutput),
          height: tx.sizeU * 1.5 * g.kOutput,
        ),
        tx.rotation,
        kind: _FrameKind.scaleRotate,
      );
    }
    final im = p.images.where((e) => e.id == id).firstOrNull;
    if (im != null) {
      final cw = im.widthFrac * g.w;
      return _Frame(
        Rect.fromCenter(
          center: Offset(im.x * g.w, im.y * g.h),
          width: cw,
          height: cw / im.aspect,
        ),
        im.rotation,
        kind: _FrameKind.scaleRotate,
      );
    }
    final sh = p.shapes.where((e) => e.id == id).firstOrNull;
    if (sh != null) {
      return _Frame(
        Rect.fromCenter(
          center: Offset(sh.x * g.w, sh.y * g.h),
          width: sh.w * g.w,
          height: sh.h * g.h,
        ),
        sh.rotation,
        kind: _FrameKind.scaleRotate,
      );
    }
    final pip = p.pips.where((e) => e.id == id).firstOrNull;
    if (pip != null) {
      final cw = pip.widthFrac * g.w;
      return _Frame(
        Rect.fromCenter(
          center: Offset(pip.x * g.w, pip.y * g.h),
          width: cw,
          height: cw / pip.aspect,
        ),
        0,
        kind: _FrameKind.scale,
      );
    }
    final cv = p.covers.where((e) => e.id == id).firstOrNull;
    if (cv != null) {
      return _Frame(
        _fromPicture(g, cv.editRect(c.coverEditEnd)),
        0,
        kind: _FrameKind.rect,
      );
    }
    return null;
  }

  /// Handle under [at] (stage pixels, before the view zoom) for the selected overlay.
  bool _grabHandle(Offset at) {
    final g = _g;
    final id = c.selectedId;
    if (g == null || id == null) return false;
    final f = _frameOf(c.project, id, g);
    if (f == null) return false;
    // Small frames keep most of their body for dragging: the handles' reach shrinks with the frame.
    final reach = math.max(
      10 / _z.scale,
      math.min(24 / _z.scale, 0.4 * math.min(f.rect.width, f.rect.height)),
    );
    final corners = f.corners();
    for (var i = 0; i < 4; i++) {
      if ((corners[i] - at).distance <= reach) {
        _handle = _Handle.corner;
        _hCorner = i;
        _hCenter = f.rect.center;
        _hDist0 = math.max(8, (at - _hCenter).distance);
        _hRot0 = f.rot;
        return true;
      }
    }
    if (f.kind == _FrameKind.scaleRotate) {
      final r = f.rotateHandle(f.rotateAbove());
      if ((r - at).distance <= reach) {
        _handle = _Handle.rotate;
        _hCenter = f.rect.center;
        _hRot0 = f.rot;
        _hAngle0 = math.atan2(at.dy - _hCenter.dy, at.dx - _hCenter.dx);
        return true;
      }
    }
    return false;
  }

  void _dragHandle(Offset at) {
    final g = _g;
    final id = c.selectedId;
    if (g == null || id == null) return;
    final p = c.project;
    if (_handle == _Handle.rotate) {
      final a = math.atan2(at.dy - _hCenter.dy, at.dx - _hCenter.dx);
      var deg = _hRot0 + (a - _hAngle0) * 180 / math.pi;
      // Click into place on the upright positions.
      final near = (deg / 45).round() * 45.0;
      if ((deg - near).abs() < 4) deg = near;
      deg = ((deg + 180) % 360) - 180;
      final m = p.markers.where((e) => e.id == id).firstOrNull;
      if (m != null) {
        c.updateMarker(
          m.copyWith(spec: m.spec.copyWith(rotation: deg)),
          record: false,
        );
      }
      final t = p.texts.where((e) => e.id == id).firstOrNull;
      if (t != null) c.updateText(t.copyWith(rotation: deg), record: false);
      final im = p.images.where((e) => e.id == id).firstOrNull;
      if (im != null) c.updateImage(im.copyWith(rotation: deg), record: false);
      final sh = p.shapes.where((e) => e.id == id).firstOrNull;
      if (sh != null) c.updateShape(sh.copyWith(rotation: deg), record: false);
      return;
    }
    // corner: scale by the distance from the centre, or move the corner of a rectangle
    final k = ((at - _hCenter).distance / _hDist0).clamp(0.1, 10.0);
    final m = p.markers.where((e) => e.id == id).firstOrNull;
    if (m != null) {
      final sp = m.spec;
      if (sp.type == MarkerType.circle || sp.type == MarkerType.rect) {
        final px = ((at.dx - g.fullLeft) / g.fullW).clamp(0.0, 1.0);
        final py = ((at.dy - g.fullTop) / g.fullH).clamp(0.0, 1.0);
        final r = _moveCorner(
          Rect.fromLTRB(
            math.min(sp.x0, sp.x1),
            math.min(sp.y0, sp.y1),
            math.max(sp.x0, sp.x1),
            math.max(sp.y0, sp.y1),
          ),
          _hCorner,
          px,
          py,
        );
        c.updateMarker(
          m.copyWith(
            spec: sp.copyWith(x0: r.left, y0: r.top, x1: r.right, y1: r.bottom),
          ),
          record: false,
        );
      } else {
        c.updateMarker(
          m.copyWith(spec: sp.copyWith(scale: (_hBase * k).clamp(0.4, 4.0))),
          record: false,
        );
      }
      return;
    }
    final t = p.texts.where((e) => e.id == id).firstOrNull;
    if (t != null) {
      c.updateText(
        t.copyWith(sizeU: (_hBase * k).clamp(8.0, 80.0)),
        record: false,
      );
      return;
    }
    final im = p.images.where((e) => e.id == id).firstOrNull;
    if (im != null) {
      c.updateImage(
        im.copyWith(widthFrac: (_hBase * k).clamp(0.05, 1.5)),
        record: false,
      );
      return;
    }
    final sh = p.shapes.where((e) => e.id == id).firstOrNull;
    if (sh != null) {
      c.updateShape(
        sh.copyWith(
          w: (_hBase * k).clamp(0.05, 1.5),
          h: (_hBase2 * k).clamp(0.03, 1.5),
        ),
        record: false,
      );
      return;
    }
    final pp = p.pips.where((e) => e.id == id).firstOrNull;
    if (pp != null) {
      c.updatePip(
        pp.copyWith(widthFrac: (_hBase * k).clamp(0.1, 0.9)),
        record: false,
      );
      return;
    }
    final cv = p.covers.where((e) => e.id == id).firstOrNull;
    if (cv != null) {
      final px = ((at.dx - g.fullLeft) / g.fullW).clamp(0.0, 1.0);
      final py = ((at.dy - g.fullTop) / g.fullH).clamp(0.0, 1.0);
      final r = _moveCorner(cv.editRect(c.coverEditEnd), _hCorner, px, py);
      c.updateCover(cv.withRect(r, atEnd: c.coverEditEnd), record: false);
    }
  }

  /// [r] with its corner [i] (0 = top left, clockwise) moved to ([x], [y]), at least 3 % wide/high.
  Rect _moveCorner(Rect r, int i, double x, double y) {
    const minSide = 0.03;
    var l = r.left, t = r.top, rr = r.right, b = r.bottom;
    if (i == 0 || i == 3) {
      l = math.min(x, rr - minSide);
    } else {
      rr = math.max(x, l + minSide);
    }
    if (i == 0 || i == 1) {
      t = math.min(y, b - minSide);
    } else {
      b = math.max(y, t + minSide);
    }
    return Rect.fromLTRB(l, t, rr, b);
  }

  void _resetView() {
    if (_view.isZoomed) setState(() => _view = const ViewZoom());
  }

  void _start(ScaleStartDetails d) {
    final id = c.selectedId;
    _viewMode = id == null && widget.viewZoom;
    if (_viewMode) {
      // Nothing selected: pinch and drag move the VIEW, not the project.
      _viewScale0 = _view.scale;
      _viewQ = _view.toContent(d.localFocalPoint);
      return;
    }
    if (id == null) return;
    c.beginGesture();
    final p = c.project;
    _handle = _Handle.none;
    // The gesture is recognised after the finger has moved; the handle is looked for where it LANDED.
    if (d.pointerCount == 1 &&
        _grabHandle(_z.toContent(_downAt ?? d.localFocalPoint))) {
      final tx = p.texts.where((e) => e.id == id).firstOrNull;
      final im = p.images.where((e) => e.id == id).firstOrNull;
      final sh = p.shapes.where((e) => e.id == id).firstOrNull;
      final pp = p.pips.where((e) => e.id == id).firstOrNull;
      final mk = p.markers.where((e) => e.id == id).firstOrNull;
      _hBase =
          tx?.sizeU ??
          im?.widthFrac ??
          sh?.w ??
          pp?.widthFrac ??
          mk?.spec.scale ??
          1;
      _hBase2 = sh?.h ?? 1;
      return;
    }
    final g0 = _g;
    final fr = g0 == null ? null : _frameOf(p, id, g0);
    _hHalfW = fr == null || g0 == null ? 0 : fr.rect.width / 2 / g0.w;
    _hHalfH = fr == null || g0 == null ? 0 : fr.rect.height / 2 / g0.h;
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
    if (_viewMode) {
      final next = ViewZoom.pinch(
        q: _viewQ,
        focal: d.localFocalPoint,
        scale: _viewScale0 * d.scale,
        box: Size(g.w, g.h),
      );
      if (next != _view) setState(() => _view = next);
      return;
    }
    if (_handle != _Handle.none) {
      _dragHandle(_z.toContent(d.localFocalPoint));
      return;
    }
    // Output-space deltas (text, images, shapes) and picture-space deltas (markers, covers, zoom).
    // A finger moves 1/zoom as far in the content when the view is zoomed in.
    final vz = _z.scale;
    final ox = d.focalPointDelta.dx / (g.w * vz);
    final oy = d.focalPointDelta.dy / (g.h * vz);
    final px = d.focalPointDelta.dx / (g.fullW * vz);
    final py = d.focalPointDelta.dy / (g.fullH * vz);
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
      final sn = _snapMove(cur.x + ox, cur.y + oy, two);
      c.updateText(
        cur.copyWith(
          x: sn.dx,
          y: sn.dy,
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
      final sn = _snapMove(cur.x + ox, cur.y + oy, two);
      c.updateImage(
        cur.copyWith(
          x: sn.dx,
          y: sn.dy,
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
      final sn = _snapMove(cur.x + ox, cur.y + oy, two);
      c.updateShape(
        cur.copyWith(
          x: sn.dx,
          y: sn.dy,
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
      final sn = _snapMove(cur.x + ox, cur.y + oy, two);
      c.updatePip(
        cur.copyWith(
          x: sn.dx,
          y: sn.dy,
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

  /// A dragged centre, snapped to the middle and the edges of the frame (not while pinching).
  Offset _snapMove(double x, double y, bool pinching) {
    final gx = <double>[];
    final gy = <double>[];
    final nx = pinching
        ? x.clamp(0.0, 1.0)
        : _snapAxis(x.clamp(0.0, 1.0), _hHalfW, gx).clamp(0.0, 1.0);
    final ny = pinching
        ? y.clamp(0.0, 1.0)
        : _snapAxis(y.clamp(0.0, 1.0), _hHalfH, gy).clamp(0.0, 1.0);
    if (!_sameLines(gx, _guideX) || !_sameLines(gy, _guideY)) {
      setState(() {
        _guideX = gx;
        _guideY = gy;
      });
    }
    return Offset(nx, ny);
  }

  bool _sameLines(List<double> a, List<double> b) =>
      a.length == b.length && (a.isEmpty || a.first == b.first);

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
    _viewMode = false;
    _handle = _Handle.none;
    if (_guideX.isNotEmpty || _guideY.isNotEmpty) {
      setState(() {
        _guideX = const [];
        _guideY = const [];
      });
    }
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
    // A tap on a handle of the selected overlay keeps it selected.
    if (c.selectedId != null && _grabHandle(_z.toContent(d.localPosition))) {
      _handle = _Handle.none;
      return;
    }
    // A quick second tap near the first puts a zoomed view back to fit.
    final now = DateTime.now();
    final last = _lastTapAt;
    if (widget.viewZoom &&
        last != null &&
        now.difference(last) < const Duration(milliseconds: 320) &&
        (d.localPosition - _lastTapPos).distance < 48) {
      _lastTapAt = null;
      _resetView();
      return;
    }
    _lastTapAt = now;
    _lastTapPos = d.localPosition;
    // Compare in OUTPUT fractions; picture-space items are converted first. The touch is mapped
    // through the view zoom, and the reach shrinks with it so a zoomed view stays precise.
    final z = _z;
    final at = z.toContent(d.localPosition);
    final p = Offset(at.dx / g.w, at.dy / g.h);
    final t = c.sourceMs;
    final out = c.outMs;
    final pr = c.project;
    String? best;
    var bestDist = 0.12 / z.scale;
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
                final z = _z;
                // The capture boundary sits INSIDE the zoom, so "save this frame" is never zoomed.
                final stage = Listener(
                  onPointerDown: (e) {
                    if (_fingers == 0) _downAt = e.localPosition;
                    _fingers++;
                  },
                  onPointerUp: (_) => _fingers = math.max(0, _fingers - 1),
                  onPointerCancel: (_) => _fingers = math.max(0, _fingers - 1),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _tap,
                    onScaleStart: _start,
                    onScaleUpdate: _update,
                    onScaleEnd: _end,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(z.offset.dx, z.offset.dy, 0, 1)
                        ..scaleByDouble(z.scale, z.scale, 1, 1),
                      child: RepaintBoundary(
                        key: widget.captureKey,
                        child: _frame(context, p, g, cs),
                      ),
                    ),
                  ),
                );
                // The same widget tree at every zoom: if the gesture detector were re-created when the
                // badge appears, the pinch in progress would be cut off right at its start.
                return Stack(
                  children: [
                    Positioned.fill(child: stage),
                    if (z.isZoomed)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: _ZoomBadge(scale: z.scale, onReset: _resetView),
                      ),
                  ],
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
    // Clip.none so the whole canvas (video + blank space on both sides) can be zoomed and panned.
    final content = Stack(
      clipBehavior: Clip.none,
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
      clipBehavior: Clip.none,
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
    Widget video = widget.video.value.isInitialized && !blank
        ? RotatedBox(quarterTurns: quarter, child: VideoPlayer(widget.video))
        : const ColoredBox(color: Colors.black);
    if (p.look.tilt.abs() >= 0.05 && !blank) {
      // Free rotation, enlarged just enough that no empty corner shows (same maths as the exporter).
      final zoomFill = p.look.tiltZoom(p.frameW, p.frameH);
      video = ClipRect(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(zoomFill, zoomFill, 1, 1)
            ..rotateZ(p.look.tilt * math.pi / 180),
          child: video,
        ),
      );
    }

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

  /// Frame around the selected overlay with handles (corners resize, the knob above turns it) and the
  /// snap guides while it is dragged. Handles keep their on-screen size whatever the view zoom.
  List<Widget> _selection(
    EditProject p,
    String id,
    StageGeometry g,
    ColorScheme cs,
  ) {
    final out = <Widget>[];
    final inv = 1 / _z.scale;
    for (final x in _guideX) {
      out.add(
        Positioned(
          left: x * g.w - 0.5 * inv,
          top: 0,
          bottom: 0,
          width: inv,
          child: IgnorePointer(child: ColoredBox(color: cs.tertiary)),
        ),
      );
    }
    for (final y in _guideY) {
      out.add(
        Positioned(
          top: y * g.h - 0.5 * inv,
          left: 0,
          right: 0,
          height: inv,
          child: IgnorePointer(child: ColoredBox(color: cs.tertiary)),
        ),
      );
    }
    final f = _frameOf(p, id, g);
    Rect? r = f?.rect;
    var rot = f?.rot ?? 0;
    var kind = f?.kind ?? _FrameKind.none;
    final z = p.zooms.where((e) => e.id == id).firstOrNull;
    if (z != null) {
      final half = 0.5 / z.scale;
      final cx = z.fx.clamp(half, 1 - half);
      final cy = z.fy.clamp(half, 1 - half);
      r = _fromPicture(
        g,
        Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
      );
      rot = 0;
      kind = _FrameKind.none;
    }
    if (r == null) return out;
    final dot = 14 * inv;
    final above = _Frame(r, rot, kind: kind).rotateAbove();
    final handles = kind != _FrameKind.none;
    out.add(
      Positioned.fromRect(
        rect: r,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: rot * math.pi / 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.tertiary, width: 1.6 * inv),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (handles)
                  for (final o in [
                    Offset.zero,
                    Offset(r.width, 0),
                    Offset(r.width, r.height),
                    Offset(0, r.height),
                  ])
                    Positioned(
                      left: o.dx - dot / 2,
                      top: o.dy - dot / 2,
                      width: dot,
                      height: dot,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.tertiary,
                            width: 2 * inv,
                          ),
                        ),
                      ),
                    ),
                if (kind == _FrameKind.scaleRotate) ...[
                  Positioned(
                    left: r.width / 2 - 0.5 * inv,
                    top: above ? -26 * inv : r.height,
                    width: inv,
                    height: 26 * inv,
                    child: ColoredBox(color: cs.tertiary),
                  ),
                  Positioned(
                    left: r.width / 2 - dot / 2,
                    top: above
                        ? -26 * inv - dot / 2
                        : r.height + 26 * inv - dot / 2,
                    width: dot,
                    height: dot,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.tertiary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2 * inv),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return out;
  }
}

enum _Handle { none, corner, rotate }

/// What the handles of an overlay frame do.
enum _FrameKind {
  none,

  /// Corners scale around the centre (picture-in-picture).
  scale,

  /// Corners scale, the knob turns it (text, image, shape, marker).
  scaleRotate,

  /// Corners move a rectangle's corner (covers, circles, boxes).
  rect,
}

class _Frame {
  _Frame(this.rect, this.rot, {required this.kind});
  final Rect rect;

  /// Degrees clockwise.
  final double rot;
  final _FrameKind kind;

  Offset _turn(Offset local) {
    final a = rot * math.pi / 180;
    final dx = local.dx - rect.center.dx;
    final dy = local.dy - rect.center.dy;
    return Offset(
      rect.center.dx + dx * math.cos(a) - dy * math.sin(a),
      rect.center.dy + dx * math.sin(a) + dy * math.cos(a),
    );
  }

  /// Corners in stage pixels, top left first, clockwise.
  List<Offset> corners() => [
    _turn(rect.topLeft),
    _turn(rect.topRight),
    _turn(rect.bottomRight),
    _turn(rect.bottomLeft),
  ];

  /// The knob sits above the frame unless that would leave the stage.
  bool rotateAbove() => _turn(rect.topCenter).dy > 40;

  Offset rotateHandle(bool above) => _turn(
    above
        ? rect.topCenter.translate(0, -26)
        : rect.bottomCenter.translate(0, 26),
  );
}

/// Shown while the preview is zoomed: the zoom factor, tap to go back to fit.
class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.scale, required this.onReset});
  final double scale;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'stage_zoom_reset',
      button: true,
      label: '${(scale * 100).toStringAsFixed(0)}%',
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onReset,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fit_screen_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${(scale * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
