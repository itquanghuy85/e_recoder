import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../record/recorder_controller.dart';
import 'marker_spec.dart';
import 'marker_sprite.dart';
import 'marker_timing.dart';

/// Reference frame the native renderer draws at; the preview scales it to fit.
const int kPreviewFrameW = 720;
const int kPreviewFrameH = 1280;

/// A marker drawn by the native renderer over a mock app screen, looping cue → take → hold → fade.
/// This is also how the editor will show markers: native pixels, Dart timing.
class MarkerPreview extends ConsumerStatefulWidget {
  const MarkerPreview({
    super.key,
    required this.spec,
    this.darkBackdrop = false,
    this.holdMs = 1800,
    this.loop = true,
  });

  final MarkerSpec spec;
  final bool darkBackdrop;
  final int holdMs;
  final bool loop;

  @override
  ConsumerState<MarkerPreview> createState() => _MarkerPreviewState();
}

class _MarkerPreviewState extends ConsumerState<MarkerPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  final Map<(MarkerSpec, int), Future<({Uint8List png, double side})>> _cache =
      {};

  int get _fadeStart => MarkerTiming.cueMs + widget.holdMs;
  int get _totalMs => _fadeStart + MarkerTiming.fadeMs + 500;

  @override
  void initState() {
    super.initState();
    _c.duration = Duration(milliseconds: _totalMs);
  }

  @override
  void didUpdateWidget(MarkerPreview old) {
    super.didUpdateWidget(old);
    _c.duration = Duration(milliseconds: _totalMs);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  void replay() => _restart();

  void _restart() {
    if (MediaQuery.of(context).disableAnimations) {
      // Reduced motion: show the settled marker, no cue ring.
      _c.value = (MarkerTiming.cueMs + 400) / _totalMs;
      _c.stop();
      return;
    }
    widget.loop ? _c.repeat() : _c.forward(from: 0);
  }

  Future<({Uint8List png, double side})> _load(MarkerSpec spec, int phase) {
    return _cache.putIfAbsent((spec, phase), () async {
      final r = await ref
          .read(nativeRecorderProvider)
          .renderMarker(
            spec,
            kPreviewFrameW,
            kPreviewFrameH,
            phaseMs: phase * MarkerTiming.phaseStepMs,
          );
      return (png: r.png, side: r.half * 2);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final dark = widget.darkBackdrop;
    return Semantics(
      label: t.markerPreviewTitle,
      child: AspectRatio(
        aspectRatio: kPreviewFrameW / kPreviewFrameH,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;
              final k = w / kPreviewFrameW; // frame px -> logical px
              final spec = widget.spec;
              final a = spec.anchor;
              return Stack(
                children: [
                  Positioned.fill(
                    child: _MockScreen(dark: dark, label: t.previewMockSave),
                  ),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final ms = (_c.value * _totalMs).round();
                      final fadeStart = spec.type == MarkerType.pen
                          ? MarkerTiming.cueMs + widget.holdMs
                          : _fadeStart;
                      final f = MarkerTiming.frame(
                        spec.type == MarkerType.pen
                            ? ms + MarkerTiming.cueMs
                            : ms,
                        spec.type == MarkerType.pen
                            ? fadeStart + MarkerTiming.cueMs
                            : fadeStart,
                      );
                      return Stack(
                        children: [
                          if (f.cueProgress >= 0)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CuePainter(
                                  spec: spec,
                                  progress: f.cueProgress,
                                  frameW: w,
                                  frameH: h,
                                ),
                              ),
                            ),
                          if (f.bodyAlpha > 0)
                            Positioned.fill(
                              child: MarkerSprite(
                                spec: spec,
                                phase: markerPhase(context, ms),
                                load: (p) => _load(spec, p),
                                builder: (context, png, side) => Stack(
                                  children: [
                                    Positioned(
                                      left: a.x * w - side * k / 2,
                                      top: a.y * h - side * k / 2,
                                      width: side * k,
                                      height: side * k,
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
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Mock of a third-party app screen so legibility can be judged on light and dark content.
class _MockScreen extends StatelessWidget {
  const _MockScreen({required this.dark, required this.label});
  final bool dark;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF14171C) : const Color(0xFFF4F5F7);
    final row = dark ? const Color(0xFF232830) : const Color(0xFFE3E6EB);
    final bar = dark ? const Color(0xFF1D2128) : Colors.white;
    return LayoutBuilder(
      builder: (context, box) {
        return ColoredBox(
          color: bg,
          child: Stack(
            children: [
              Column(
                children: [
                  Container(height: 44, color: bar),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: row,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
              // The target is centred at (0.5, 0.55) of the frame: the markers' demo anchor.
              Positioned(
                left: box.maxWidth / 2 - 70,
                top: box.maxHeight * 0.55 - 22,
                width: 140,
                height: 44,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF3B6FE0)
                        : const Color(0xFF2F63D6),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The converging amber ring; same geometry as MarkerRenderer.drawCue.
class CuePainter extends CustomPainter {
  CuePainter({
    required this.spec,
    required this.progress,
    required this.frameW,
    required this.frameH,
  });

  final MarkerSpec spec;
  final double progress;
  final double frameW;
  final double frameH;

  static const _cue = Color(0xFFFFB938);
  static const _cueLight = Color(0xFFFFD890);
  static const _cueDeep = Color(0xFF9A4F10);

  @override
  void paint(Canvas canvas, Size size) {
    if (spec.type == MarkerType.pen) return;
    final u = frameW / 360;
    final k = spec.scale;
    final p = progress.clamp(0.0, 1.0);
    final alpha = (0.25 + 0.75 * p) * spec.opacity.clamp(0.4, 1.0);
    final a = spec.anchor;
    canvas.save();
    canvas.translate(a.x * frameW, a.y * frameH);
    canvas.rotate(spec.rotation * math.pi / 180);
    canvas.scale(u * k);
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 4.8
      ..color = Colors.black.withValues(alpha: 0.2 * alpha);
    // Sweep gradient that spins while the ring contracts (mirror of MarkerRenderer.cueStroke).
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: [
          _cueLight.withValues(alpha: alpha),
          _cue.withValues(alpha: alpha),
          _cueDeep.withValues(alpha: alpha),
          _cueLight.withValues(alpha: alpha),
        ],
        stops: const [0, 0.3, 0.7, 1],
        transform: GradientRotation(p * 1.5 * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 120));
    if (spec.type == MarkerType.circle || spec.type == MarkerType.rect) {
      final f = 1 + 0.7 * (1 - p);
      final ex = math.max((spec.x1 - spec.x0).abs() * frameW / (2 * u), 6) * f;
      final ey = math.max((spec.y1 - spec.y0).abs() * frameH / (2 * u), 6) * f;
      final r = Rect.fromLTRB(-ex, -ey, ex, ey);
      final path = Path();
      if (spec.type == MarkerType.circle) {
        path.addOval(r);
      } else {
        path.addRRect(RRect.fromRectAndRadius(r, Radius.circular(8 * f)));
      }
      canvas.drawPath(path, halo);
      canvas.drawPath(path, ring);
    } else {
      final base = switch (spec.type) {
        MarkerType.finger => 28.0,
        MarkerType.ripple => 32.0,
        MarkerType.number => 20.0,
        _ => 22.0,
      };
      final r = base * (1 + 1.9 * (1 - p));
      canvas.drawCircle(Offset.zero, r, halo);
      canvas.drawCircle(Offset.zero, r, ring);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CuePainter old) =>
      old.progress != progress || old.spec != spec;
}
