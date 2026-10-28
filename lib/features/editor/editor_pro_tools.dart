import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../core/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_inspector.dart';
import 'edit_project.dart';
import 'editor_controller.dart';
import 'editor_tools.dart' show editorSecs, editorSlider, inspectorHeader;

// ---- picture: rotate, crop, output shape, colour ----------------------------------------------

String aspectLabel(AppL10n t, OutAspect a) => switch (a) {
  OutAspect.auto => t.aspectAuto,
  OutAspect.r9x16 => t.aspect916,
  OutAspect.r1x1 => t.aspect11,
  OutAspect.r4x5 => t.aspect45,
  OutAspect.r16x9 => t.aspect169,
};

String presetLabel(AppL10n t, ColorPreset p) => switch (p) {
  ColorPreset.none => t.presetNone,
  ColorPreset.vivid => t.presetVivid,
  ColorPreset.warm => t.presetWarm,
  ColorPreset.cool => t.presetCool,
  ColorPreset.bw => t.presetBw,
  ColorPreset.vintage => t.presetVintage,
  ColorPreset.fade => t.presetFade,
};

class PicturePanel extends StatelessWidget {
  const PicturePanel({super.key, required this.c, required this.video});
  final EditorController c;
  final VideoPlayerController video;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final look = c.look;
    final color = look.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            Semantics(
              identifier: 'pic_rotate',
              child: FilledButton.tonalIcon(
                onPressed: c.rotate90,
                icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                label: Text(t.picRotate),
              ),
            ),
            Semantics(
              identifier: 'pic_crop',
              child: FilledButton.tonalIcon(
                onPressed: () => showCropEditor(context, c, video),
                icon: const Icon(Icons.crop),
                label: Text(t.picCrop),
              ),
            ),
            if (look.isCropped)
              OutlinedButton(
                onPressed: () => c.setCrop(const Rect.fromLTRB(0, 0, 1, 1)),
                child: Text(t.picCropReset),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(t.picAspect, style: tt.titleSmall),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final a in OutAspect.values)
              Semantics(
                identifier: 'aspect_${a.name}',
                child: ChoiceChip(
                  label: Text(aspectLabel(t, a)),
                  selected: look.aspect == a,
                  onSelected: (_) => c.setAspect(a),
                ),
              ),
          ],
        ),
        if (look.aspect != OutAspect.auto) ...[
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.sm,
            children: [
              Semantics(
                identifier: 'aspect_fit',
                child: ChoiceChip(
                  label: Text(t.picFit),
                  selected: !look.fill,
                  onSelected: (_) => c.setFill(false),
                ),
              ),
              Semantics(
                identifier: 'aspect_fill',
                child: ChoiceChip(
                  label: Text(t.picFill),
                  selected: look.fill,
                  onSelected: (_) => c.setFill(true),
                ),
              ),
            ],
          ),
          Text(
            t.picFitHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Space.md),
        Text(t.picFilters, style: tt.titleSmall),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final p in ColorPreset.values)
              Semantics(
                identifier: 'preset_${p.name}',
                child: ChoiceChip(
                  label: Text(presetLabel(t, p)),
                  selected: color == ColorLook.preset(p),
                  onSelected: (_) => c.setColor(ColorLook.preset(p)),
                ),
              ),
          ],
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.colorBrightness,
          value: color.brightness,
          min: -0.5,
          max: 0.5,
          onChanged: (v) =>
              c.setColor(color.copyWith(brightness: v), record: false),
          fmt: (v) => '${(v * 100).round()}',
          id: 'color_brightness',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.colorContrast,
          value: color.contrast,
          min: -0.5,
          max: 0.8,
          onChanged: (v) =>
              c.setColor(color.copyWith(contrast: v), record: false),
          fmt: (v) => '${(v * 100).round()}',
          id: 'color_contrast',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.colorSaturation,
          value: color.saturation,
          min: 0,
          max: 2,
          onChanged: (v) =>
              c.setColor(color.copyWith(saturation: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
          id: 'color_saturation',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.colorWarmth,
          value: color.warmth,
          min: -1,
          max: 1,
          onChanged: (v) =>
              c.setColor(color.copyWith(warmth: v), record: false),
          fmt: (v) => '${(v * 100).round()}',
          id: 'color_warmth',
        ),
        Text(
          t.picRotateNote,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Full-screen crop: the picture (rotated) with a rectangle whose corners and body can be dragged.
Future<void> showCropEditor(
  BuildContext context,
  EditorController c,
  VideoPlayerController video,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CropScreen(c: c, video: video),
    ),
  );
}

class _CropScreen extends StatefulWidget {
  const _CropScreen({required this.c, required this.video});
  final EditorController c;
  final VideoPlayerController video;

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

enum _Handle { none, move, tl, tr, bl, br }

class _CropScreenState extends State<_CropScreen> {
  late Rect _crop = widget.c.look.crop;
  _Handle _h = _Handle.none;
  Rect _start = Rect.zero;
  Size _box = Size.zero;

  static const double minSide = 0.1;

  _Handle _hit(Offset p) {
    final r = Rect.fromLTRB(
      _crop.left * _box.width,
      _crop.top * _box.height,
      _crop.right * _box.width,
      _crop.bottom * _box.height,
    );
    const reach = 34.0;
    if ((p - r.topLeft).distance < reach) return _Handle.tl;
    if ((p - r.topRight).distance < reach) return _Handle.tr;
    if ((p - r.bottomLeft).distance < reach) return _Handle.bl;
    if ((p - r.bottomRight).distance < reach) return _Handle.br;
    return r.contains(p) ? _Handle.move : _Handle.none;
  }

  void _update(Offset delta) {
    final dx = delta.dx / _box.width;
    final dy = delta.dy / _box.height;
    var l = _start.left, t = _start.top, r = _start.right, b = _start.bottom;
    switch (_h) {
      case _Handle.move:
        final w = r - l, h = b - t;
        l = (l + dx).clamp(0.0, 1 - w);
        t = (t + dy).clamp(0.0, 1 - h);
        r = l + w;
        b = t + h;
      case _Handle.tl:
        l = (l + dx).clamp(0.0, r - minSide);
        t = (t + dy).clamp(0.0, b - minSide);
      case _Handle.tr:
        r = (r + dx).clamp(l + minSide, 1.0);
        t = (t + dy).clamp(0.0, b - minSide);
      case _Handle.bl:
        l = (l + dx).clamp(0.0, r - minSide);
        b = (b + dy).clamp(t + minSide, 1.0);
      case _Handle.br:
        r = (r + dx).clamp(l + minSide, 1.0);
        b = (b + dy).clamp(t + minSide, 1.0);
      case _Handle.none:
        return;
    }
    setState(() => _crop = Rect.fromLTRB(l, t, r, b));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    final c = widget.c;
    final pic = c.pictureSize;
    final quarter = (c.look.rotation ~/ 90) % 4;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(t.cropTitle),
        actions: [
          Semantics(
            identifier: 'crop_done',
            child: TextButton(
              onPressed: () {
                c.beginGesture();
                c.setCrop(_crop, record: false);
                c.flush();
                Navigator.of(context).pop();
              },
              child: Text(t.cropDone),
            ),
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: pic.width / pic.height,
          child: LayoutBuilder(
            builder: (context, box) {
              _box = Size(box.maxWidth, box.maxHeight);
              final rect = Rect.fromLTRB(
                _crop.left * _box.width,
                _crop.top * _box.height,
                _crop.right * _box.width,
                _crop.bottom * _box.height,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  _h = _hit(d.localPosition);
                  _start = _crop;
                  _acc = Offset.zero;
                },
                onPanUpdate: (d) {
                  _acc += d.delta;
                  _update(_acc);
                },
                onPanEnd: (_) => _h = _Handle.none,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RotatedBox(
                        quarterTurns: quarter,
                        child: VideoPlayer(widget.video),
                      ),
                    ),
                    // dim everything outside the crop
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DimPainter(rect, Colors.black54),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.tertiary, width: 2),
                          ),
                        ),
                      ),
                    ),
                    for (final o in [
                      rect.topLeft,
                      rect.topRight,
                      rect.bottomLeft,
                      rect.bottomRight,
                    ])
                      Positioned(
                        left: o.dx - 11,
                        top: o.dy - 11,
                        child: IgnorePointer(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: cs.tertiary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Offset _acc = Offset.zero;
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.hole, this.color);
  final Rect hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}

// ---- motion + style controls shared by text, images and shapes ---------------------------------

String enterExitLabel(AppL10n t, EnterExit e) => switch (e) {
  EnterExit.none => t.motionNone,
  EnterExit.fade => t.motionFade,
  EnterExit.pop => t.motionPop,
  EnterExit.slideUp => t.motionSlideUp,
  EnterExit.slideDown => t.motionSlideDown,
  EnterExit.slideLeft => t.motionSlideLeft,
  EnterExit.slideRight => t.motionSlideRight,
};

String easeLabel(AppL10n t, Ease e) => switch (e) {
  Ease.linear => t.easeLinear,
  Ease.easeIn => t.easeIn,
  Ease.easeOut => t.easeOut,
  Ease.easeInOut => t.easeInOut,
};

/// Enter / exit animation, and a keyframe to an end position, for an overlay at ([x], [y]).
class MotionControls extends StatelessWidget {
  const MotionControls({
    super.key,
    required this.motion,
    required this.onChanged,
    required this.x,
    required this.y,
    this.idPrefix = 'motion',
  });

  final ItemMotion motion;
  final ValueChanged<ItemMotion> onChanged;

  /// Where the overlay is now: "set end here" uses it as the final position.
  final double x;
  final double y;
  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget chips(
      String label,
      EnterExit value,
      ValueChanged<EnterExit> set,
      String id,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.labelLarge),
          Wrap(
            spacing: Space.xs,
            runSpacing: 0,
            children: [
              for (final e in EnterExit.values)
                Semantics(
                  identifier: '${idPrefix}_${id}_${e.name}',
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(enterExitLabel(t, e)),
                    selected: value == e,
                    onSelected: (_) => set(e),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.sm),
        Text(t.motionTitle, style: tt.titleSmall),
        chips(
          t.motionEnter,
          motion.enter,
          (e) => onChanged(motion.copyWith(enter: e)),
          'enter',
        ),
        chips(
          t.motionExit,
          motion.exit,
          (e) => onChanged(motion.copyWith(exit: e)),
          'exit',
        ),
        const SizedBox(height: Space.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                motion.hasKeyframe
                    ? '${t.motionKeyframe}: ${((motion.endX ?? x) * 100).round()}%, ${((motion.endY ?? y) * 100).round()}%'
                    : t.motionKeyframe,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Semantics(
              identifier: '${idPrefix}_set_end',
              child: TextButton(
                onPressed: () => onChanged(motion.copyWith(endX: x, endY: y)),
                child: Text(t.motionSetEnd),
              ),
            ),
            if (motion.hasKeyframe)
              TextButton(
                onPressed: () => onChanged(
                  motion.copyWith(
                    endX: null,
                    endY: null,
                    endScale: null,
                    endOpacity: null,
                  ),
                ),
                child: Text(t.motionClear),
              ),
          ],
        ),
        if (motion.hasKeyframe)
          Wrap(
            spacing: Space.xs,
            children: [
              for (final e in Ease.values)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(easeLabel(t, e)),
                  selected: motion.ease == e,
                  onSelected: (_) => onChanged(motion.copyWith(ease: e)),
                ),
            ],
          ),
      ],
    );
  }
}

String fontLabel(AppL10n t, TextFont f) => switch (f) {
  TextFont.barlow => t.fontBarlow,
  TextFont.sans => t.fontSans,
  TextFont.condensed => t.fontCondensed,
  TextFont.serif => t.fontSerif,
  TextFont.mono => t.fontMono,
  TextFont.cursive => t.fontCursive,
};

/// Font, outline, background, shadow, alignment, rotation, opacity and motion of a text.
String textPresetLabel(AppL10n t, TextPreset p) => switch (p) {
  TextPreset.classic => t.presetClassic,
  TextPreset.subtitle => t.presetSubtitle,
  TextPreset.yellow => t.presetYellow,
  TextPreset.neon => t.presetNeon,
  TextPreset.clean => t.presetClean,
  TextPreset.label => t.presetLabel,
};

/// One-tap looks, in a single row that scrolls sideways so it costs one line of the panel.
class TextPresetRow extends StatelessWidget {
  const TextPresetRow({super.key, required this.c, required this.item});
  final EditorController c;
  final TextItem item;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TextPreset.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
        itemBuilder: (_, i) {
          final p = TextPreset.values[i];
          return Semantics(
            identifier: 'text_preset_${p.name}',
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(textPresetLabel(t, p)),
              onPressed: () => c.updateText(p.apply(item)),
            ),
          );
        },
      ),
    );
  }
}

class TextStyleControls extends StatelessWidget {
  const TextStyleControls({super.key, required this.c, required this.item});
  final EditorController c;
  final TextItem item;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    void set(TextItem n, {bool record = true}) =>
        c.updateText(n, record: record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.sm),
        Text(t.textFont, style: tt.titleSmall),
        Wrap(
          spacing: Space.xs,
          runSpacing: 0,
          children: [
            for (final f in TextFont.values)
              Semantics(
                identifier: 'font_${f.name}',
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(fontLabel(t, f)),
                  selected: item.font == f,
                  onSelected: (_) => set(item.copyWith(font: f)),
                ),
              ),
          ],
        ),
        Wrap(
          spacing: Space.sm,
          runSpacing: 0,
          children: [
            FilterChip(
              visualDensity: VisualDensity.compact,
              label: Text(t.textBold),
              selected: item.bold,
              onSelected: (v) => set(item.copyWith(bold: v)),
            ),
            Semantics(
              identifier: 'text_outline',
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(t.textOutline),
                selected: item.outline,
                onSelected: (v) => set(item.copyWith(outline: v)),
              ),
            ),
            Semantics(
              identifier: 'text_box',
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(t.textBox),
                selected: item.box != null,
                onSelected: (v) =>
                    set(item.copyWith(box: v ? const Color(0xB3000000) : null)),
              ),
            ),
            FilterChip(
              visualDensity: VisualDensity.compact,
              label: Text(t.textShadow),
              selected: item.shadow,
              onSelected: (v) => set(item.copyWith(shadow: v)),
            ),
          ],
        ),
        Wrap(
          spacing: Space.xs,
          children: [
            for (final a in TextAlignment.values)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text(switch (a) {
                  TextAlignment.left => t.alignLeft,
                  TextAlignment.center => t.alignCenter,
                  TextAlignment.right => t.alignRight,
                }),
                selected: item.align == a,
                onSelected: (_) => set(item.copyWith(align: a)),
              ),
          ],
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovOpacity,
          value: item.opacity,
          min: 0.1,
          max: 1,
          onChanged: (v) => set(item.copyWith(opacity: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovRotation,
          value: item.rotation.clamp(-180.0, 180.0),
          min: -180,
          max: 180,
          onChanged: (v) =>
              set(item.copyWith(rotation: v.roundToDouble()), record: false),
          fmt: (v) => '${v.round()}°',
        ),
        MotionControls(
          motion: item.motion,
          x: item.x,
          y: item.y,
          idPrefix: 'text_motion',
          onChanged: (m) => set(item.copyWith(motion: m)),
        ),
      ],
    );
  }
}

// ---- overlays: images, shapes, callouts, picture in picture -----------------------------------

String shapeLabel(AppL10n t, ShapeKind k) => switch (k) {
  ShapeKind.rect => t.shapeRect,
  ShapeKind.ellipse => t.shapeEllipse,
  ShapeKind.line => t.shapeLine,
  ShapeKind.arrow => t.shapeArrow,
  ShapeKind.bubble => t.shapeBubble,
};

IconData shapeIcon(ShapeKind k) => switch (k) {
  ShapeKind.rect => Icons.crop_square,
  ShapeKind.ellipse => Icons.circle_outlined,
  ShapeKind.line => Icons.horizontal_rule,
  ShapeKind.arrow => Icons.arrow_right_alt,
  ShapeKind.bubble => Icons.chat_bubble_outline,
};

class OverlayPanel extends StatefulWidget {
  const OverlayPanel({super.key, required this.c});
  final EditorController c;

  @override
  State<OverlayPanel> createState() => _OverlayPanelState();
}

class _OverlayPanelState extends State<OverlayPanel> {
  final _bubbleCtl = TextEditingController();
  String? _bound;

  @override
  void dispose() {
    _bubbleCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final c = widget.c;
    final p = c.project;
    final img = p.images.where((e) => e.id == c.selectedId).firstOrNull;
    final shape = p.shapes.where((e) => e.id == c.selectedId).firstOrNull;
    final pip = p.pips.where((e) => e.id == c.selectedId).firstOrNull;

    if (img != null) return _imageInspector(context, c, img);
    if (shape != null) return _shapeInspector(context, c, shape);
    if (pip != null) return _pipInspector(context, c, pip);
    _bound = null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            Semantics(
              identifier: 'add_image',
              child: FilledButton.tonalIcon(
                onPressed: c.addImageFromPhone,
                icon: const Icon(Icons.image_outlined),
                label: Text(t.ovAddImage),
              ),
            ),
            Semantics(
              identifier: 'add_pip',
              child: FilledButton.tonalIcon(
                onPressed: c.addPipFromPhone,
                icon: const Icon(Icons.picture_in_picture_alt_outlined),
                label: Text(t.ovAddPip),
              ),
            ),
            for (final k in ShapeKind.values)
              Semantics(
                identifier: 'add_shape_${k.name}',
                child: ActionChip(
                  avatar: Icon(shapeIcon(k), size: 18),
                  label: Text(shapeLabel(t, k)),
                  onPressed: () => c.addShape(k),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          t.ovHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _imageInspector(
    BuildContext context,
    EditorController c,
    ImageItem im,
  ) {
    final t = AppL10n.of(context);
    void set(ImageItem n, {bool record = true}) =>
        c.updateImage(n, record: record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorHeader(context, c, t.ovAddImage),
        editorSlider(
          context: context,
          c: c,
          label: t.ovWidth,
          value: im.widthFrac,
          min: 0.05,
          max: 1.2,
          onChanged: (v) => set(im.copyWith(widthFrac: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovOpacity,
          value: im.opacity,
          min: 0.1,
          max: 1,
          onChanged: (v) => set(im.copyWith(opacity: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovRotation,
          value: im.rotation.clamp(-180.0, 180.0),
          min: -180,
          max: 180,
          onChanged: (v) =>
              set(im.copyWith(rotation: v.roundToDouble()), record: false),
          fmt: (v) => '${v.round()}°',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.clipLength,
          value: (im.endMs - im.startMs).toDouble(),
          min: 500,
          max: 15000,
          onChanged: (v) =>
              set(im.copyWith(endMs: im.startMs + v.round()), record: false),
          fmt: editorSecs,
        ),
        MotionControls(
          motion: im.motion,
          x: im.x,
          y: im.y,
          idPrefix: 'image_motion',
          onChanged: (m) => set(im.copyWith(motion: m)),
        ),
      ],
    );
  }

  Widget _shapeInspector(
    BuildContext context,
    EditorController c,
    ShapeItem sh,
  ) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    void set(ShapeItem n, {bool record = true}) =>
        c.updateShape(n, record: record);
    if (_bound != sh.id) {
      _bound = sh.id;
      _bubbleCtl.text = sh.text;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorHeader(context, c, shapeLabel(t, sh.kind)),
        if (sh.kind == ShapeKind.bubble)
          Semantics(
            identifier: 'bubble_text',
            child: TextField(
              controller: _bubbleCtl,
              decoration: InputDecoration(
                labelText: t.ovBubbleText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => set(sh.copyWith(text: v), record: false),
              onEditingComplete: c.flush,
            ),
          ),
        const SizedBox(height: Space.sm),
        Text(t.markerColor, style: tt.titleSmall),
        MarkerColorRow(
          selected: sh.color,
          onChanged: (i) => set(sh.copyWith(color: MarkerPalette.colors[i])),
        ),
        if (sh.kind != ShapeKind.bubble)
          editorSlider(
            context: context,
            c: c,
            label: t.ovStroke,
            value: sh.strokeU,
            min: 1,
            max: 16,
            onChanged: (v) => set(sh.copyWith(strokeU: v), record: false),
            fmt: (v) => v.round().toString(),
          ),
        if (sh.kind == ShapeKind.rect || sh.kind == ShapeKind.ellipse)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t.ovFilled, style: tt.titleSmall),
            value: sh.filled,
            onChanged: (v) => set(sh.copyWith(filled: v)),
          ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovWidth,
          value: sh.w,
          min: 0.05,
          max: 1.2,
          onChanged: (v) => set(sh.copyWith(w: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovOpacity,
          value: sh.opacity,
          min: 0.1,
          max: 1,
          onChanged: (v) => set(sh.copyWith(opacity: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovRotation,
          value: sh.rotation.clamp(-180.0, 180.0),
          min: -180,
          max: 180,
          onChanged: (v) =>
              set(sh.copyWith(rotation: v.roundToDouble()), record: false),
          fmt: (v) => '${v.round()}°',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.clipLength,
          value: (sh.endMs - sh.startMs).toDouble(),
          min: 500,
          max: 15000,
          onChanged: (v) =>
              set(sh.copyWith(endMs: sh.startMs + v.round()), record: false),
          fmt: editorSecs,
        ),
        MotionControls(
          motion: sh.motion,
          x: sh.x,
          y: sh.y,
          idPrefix: 'shape_motion',
          onChanged: (m) => set(sh.copyWith(motion: m)),
        ),
      ],
    );
  }

  Widget _pipInspector(BuildContext context, EditorController c, PipItem pip) {
    final t = AppL10n.of(context);
    final total = c.project.outDurationMs;
    void set(PipItem n, {bool record = true}) => c.updatePip(n, record: record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorHeader(context, c, t.ovAddPip),
        editorSlider(
          context: context,
          c: c,
          label: t.ovWidth,
          value: pip.widthFrac,
          min: 0.1,
          max: 0.9,
          onChanged: (v) => set(pip.copyWith(widthFrac: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovPipStart,
          value: pip.startOutMs.toDouble(),
          min: 0,
          max: total.toDouble().clamp(1, double.infinity),
          onChanged: (v) =>
              set(pip.copyWith(startOutMs: v.round()), record: false),
          fmt: editorSecs,
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovPipLength,
          value: pip.durMs.toDouble(),
          min: 500,
          max: pip.isVideo
              ? (pip.fileMs - pip.trimStartMs).toDouble().clamp(501, 30000)
              : 15000,
          onChanged: (v) => set(pip.copyWith(durMs: v.round()), record: false),
          fmt: editorSecs,
        ),
        if (pip.isVideo)
          editorSlider(
            context: context,
            c: c,
            label: t.ovPipVolume,
            value: pip.volume,
            min: 0,
            max: 1,
            onChanged: (v) => set(pip.copyWith(volume: v), record: false),
            fmt: (v) => '${(v * 100).round()}%',
          ),
        editorSlider(
          context: context,
          c: c,
          label: t.ovOpacity,
          value: pip.opacity,
          min: 0.2,
          max: 1,
          onChanged: (v) => set(pip.copyWith(opacity: v), record: false),
          fmt: (v) => '${(v * 100).round()}%',
        ),
      ],
    );
  }
}

// ---- audio tracks: music and voice-over ------------------------------------------------------

/// The music / voice-over part of the audio tool: add, record, and tune the selected track.
class AudioTracksSection extends StatelessWidget {
  const AudioTracksSection({super.key, required this.c, this.onRecordVoice});
  final EditorController c;

  /// Starts the voice-over: the screen asks for the microphone, starts recording and plays the video.
  final Future<void> Function()? onRecordVoice;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = c.project;
    final sel = p.audioTracks.where((a) => a.id == c.selectedId).firstOrNull;
    final total = p.outDurationMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(t.audioTracks, style: tt.titleSmall),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            Semantics(
              identifier: 'audio_add_music',
              child: FilledButton.tonalIcon(
                onPressed: c.addMusicFromPhone,
                icon: const Icon(Icons.library_music_outlined),
                label: Text(t.audioAddMusic),
              ),
            ),
            Semantics(
              identifier: 'audio_voice',
              child: c.recordingVoice
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      onPressed: () async {
                        await c.stopVoice();
                      },
                      icon: const Icon(Icons.stop),
                      label: Text(t.audioStopVoice),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: onRecordVoice,
                      icon: const Icon(Icons.mic_none),
                      label: Text(t.audioRecordVoice),
                    ),
            ),
          ],
        ),
        if (p.audioTracks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              t.audioTracksNone,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        for (final a in p.audioTracks)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: a.id == c.selectedId,
            leading: Icon(
              a.kind == AudioKind.music ? Icons.music_note : Icons.mic,
            ),
            title: Text(
              a.name.isEmpty
                  ? (a.kind == AudioKind.music
                        ? t.audioMusicName
                        : t.audioVoiceName)
                  : a.name,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${formatClock(a.startOutMs)} - ${formatClock(a.endOutMs(total))}',
            ),
            onTap: () => c.select(a.id),
          ),
        if (sel != null) ...[
          inspectorHeader(
            context,
            c,
            sel.kind == AudioKind.music ? t.audioMusicName : t.audioVoiceName,
          ),
          editorSlider(
            context: context,
            c: c,
            label: t.audioStartAt,
            value: sel.startOutMs.toDouble(),
            min: 0,
            max: (total - 200).toDouble().clamp(1, double.infinity),
            onChanged: (v) => c.updateAudio(
              sel.copyWith(startOutMs: v.round()),
              record: false,
            ),
            fmt: editorSecs,
          ),
          editorSlider(
            context: context,
            c: c,
            label: t.audioVolume,
            value: sel.volume,
            min: 0,
            max: 2,
            onChanged: (v) => c.updateAudio(
              sel.copyWith(volume: (v * 20).round() / 20),
              record: false,
            ),
            fmt: (v) => '${(v * 100).round()}%',
          ),
          editorSlider(
            context: context,
            c: c,
            label: t.audioFadeIn,
            value: sel.fadeInMs.toDouble(),
            min: 0,
            max: 3000,
            onChanged: (v) =>
                c.updateAudio(sel.copyWith(fadeInMs: v.round()), record: false),
            fmt: editorSecs,
          ),
          editorSlider(
            context: context,
            c: c,
            label: t.audioFadeOut,
            value: sel.fadeOutMs.toDouble(),
            min: 0,
            max: 3000,
            onChanged: (v) => c.updateAudio(
              sel.copyWith(fadeOutMs: v.round()),
              record: false,
            ),
            fmt: editorSecs,
          ),
          if (sel.kind == AudioKind.music) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.audioLoop, style: tt.titleSmall),
              value: sel.loop,
              onChanged: (v) => c.updateAudio(sel.copyWith(loop: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.audioDuck, style: tt.titleSmall),
              value: sel.duck,
              onChanged: (v) => c.updateAudio(sel.copyWith(duck: v)),
            ),
          ],
        ],
        if (c.recordingVoice)
          Text(
            t.audioVoiceHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// Asks for the microphone; true when it can be used.
Future<bool> ensureMicrophone() async {
  var s = await Permission.microphone.status;
  if (!s.isGranted) s = await Permission.microphone.request();
  return s.isGranted;
}

/// Thumbnail row helper for lists of picked files (kept here so panels stay small).
Widget fileThumb(String path, {double size = 40}) => ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: Image.file(
    File(path),
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
  ),
);
