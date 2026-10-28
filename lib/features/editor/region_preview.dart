import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'edit_project.dart';
import 'editor_math.dart';

/// Preview of one [CoverItem] drawn over the picture (the exporter does the same in RegionFx.kt):
/// a solid block, a blur, a mosaic, or - for a spotlight - a dimmed frame with a clear window.
///
/// [fw]/[fh] are the whole picture in stage pixels; the item places itself with the same fractions.
class RegionPreview extends StatelessWidget {
  const RegionPreview({
    super.key,
    required this.item,
    required this.fw,
    required this.fh,
    required this.t,
  });
  final CoverItem item;
  final double fw;
  final double fh;
  final int t;

  Rect get _rect {
    final r = item.rectAt(t);
    return Rect.fromLTRB(r.left * fw, r.top * fh, r.right * fw, r.bottom * fh);
  }

  double get _radius => 6 * fw / 360;

  @override
  Widget build(BuildContext context) {
    final r = _rect;
    switch (item.style) {
      case CoverStyle.solid:
        return Positioned.fromRect(
          rect: r,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
        );
      case CoverStyle.blur:
        // A disc of radius R averages about like a Gaussian with sigma R / 2.
        final sigma = RegionMath.blurRadiusFrac(item.strength) * fw / 2;
        return Positioned.fromRect(
          rect: r,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.clamp,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      case CoverStyle.mosaic:
        return Positioned.fromRect(
          rect: r,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: MosaicBackdrop(
              block: RegionMath.mosaicBlockFrac(item.strength) * fw,
            ),
          ),
        );
      case CoverStyle.spotlight:
        final mix = RegionMath.mix(t, item.startMs, item.endMs);
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SpotlightPainter(
                window: r,
                radius: _radius,
                dim: RegionMath.spotlightDim(item.strength) * mix,
              ),
            ),
          ),
        );
    }
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.window,
    required this.radius,
    required this.dim,
  });
  final Rect window;
  final double radius;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (dim <= 0) return;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(window, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = Color.fromRGBO(0, 0, 0, dim));
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.window != window || old.radius != radius || old.dim != dim;
}

/// Pixelates whatever is behind it. Uses a fragment-shader image filter where the engine supports
/// it (Impeller); elsewhere a strong blur with a faint grid, so the area is still hidden and
/// clearly marked as a mosaic (the exported video always has the real mosaic).
class MosaicBackdrop extends StatefulWidget {
  const MosaicBackdrop({super.key, required this.block});

  /// Cell size in stage pixels.
  final double block;

  @override
  State<MosaicBackdrop> createState() => _MosaicBackdropState();
}

class _MosaicBackdropState extends State<MosaicBackdrop> {
  static Future<ui.FragmentProgram?>? _program;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program ??= ui.FragmentProgram.fromAsset('shaders/mosaic.frag')
        .then<ui.FragmentProgram?>((p) => p)
        .catchError((_) => null);
    _program!.then((p) {
      if (!mounted || p == null) return;
      setState(() => _shader = p.fragmentShader());
    });
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block.clamp(2.0, 400.0);
    final shader = _shader;
    if (shader != null && ui.ImageFilter.isShaderFilterSupported) {
      shader.setFloat(2, block);
      return BackdropFilter(
        filter: ui.ImageFilter.shader(shader),
        child: const SizedBox.expand(),
      );
    }
    return BackdropFilter(
      filter: ui.ImageFilter.blur(
        sigmaX: block * 0.7,
        sigmaY: block * 0.7,
        tileMode: TileMode.clamp,
      ),
      child: CustomPaint(
        painter: _GridPainter(block),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.block);
  final double block;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var x = block; x < size.width; x += block) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = block; y < size.height; y += block) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.block != block;
}
