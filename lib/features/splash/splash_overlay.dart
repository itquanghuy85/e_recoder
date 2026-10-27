import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../../theme/brand_mark.dart';

bool _splashShown = false;

/// Turned on by `main()`; tests leave it off so no widget test waits for the intro.
final splashEnabledProvider = Provider<bool>((ref) => false);

/// The brand intro shown once per cold start, on top of the app (which is already building
/// underneath). It continues the system splash: the same badge in the same place, then rings
/// spread out like a drop on water, the name and promise fade in, and the whole thing dissolves.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key, required this.child});
  final Widget child;

  /// Tests start several apps in one process.
  @visibleForTesting
  static void resetForTest() => _splashShown = false;

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1500);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _active = ref.read(splashEnabledProvider) && !_splashShown;
    if (_active) {
      _splashShown = true;
      _c.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _active = false);
        }
      });
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Tap to skip.
            onTap: () =>
                _c.animateTo(1, duration: const Duration(milliseconds: 150)),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => _SplashFrame(
                t: reduce ? 0.55 : _c.value,
                fadeOut: reduce ? _c.value : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashFrame extends StatelessWidget {
  const _SplashFrame({required this.t, this.fadeOut});

  /// 0..1 over the whole intro.
  final double t;
  final double? fadeOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppL10n.of(context);
    // 0..0.62: rings spread; 0.18..0.5: text fades in; 0.84..1: dissolve.
    final ripple = Curves.easeOutCubic.transform((t / 0.62).clamp(0.0, 1.0));
    final text = Curves.easeOut.transform(((t - 0.18) / 0.32).clamp(0.0, 1.0));
    final out = fadeOut != null
        ? (1 - ((fadeOut! - 0.84) / 0.16).clamp(0.0, 1.0))
        : 1 - ((t - 0.84) / 0.16).clamp(0.0, 1.0);
    return Opacity(
      opacity: out,
      child: ColoredBox(
        color: cs.surface,
        child: LayoutBuilder(
          builder: (context, box) {
            final badge = 192.0;
            final cx = box.maxWidth / 2;
            final cy = box.maxHeight / 2;
            final field = math.min(box.maxWidth * 1.7, 640.0);
            return Stack(
              children: [
                // Rings first so the badge sits on top.
                Positioned(
                  left: cx - field / 2,
                  top: cy - field / 2,
                  width: field,
                  height: field,
                  child: CustomPaint(
                    painter: _RipplePainter(ripple, badge / field),
                  ),
                ),
                Positioned(
                  left: cx - badge / 2,
                  top: cy - badge / 2,
                  width: badge,
                  height: badge,
                  child: const CustomPaint(painter: _BadgePainter()),
                ),
                Positioned(
                  left: Space.xl,
                  right: Space.xl,
                  top: cy + badge / 2 + Space.xl,
                  child: Opacity(
                    opacity: text,
                    child: Transform.translate(
                      offset: Offset(0, (1 - text) * 10),
                      child: Column(
                        children: [
                          Text(
                            l10n.appTitle,
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Space.sm),
                          Text(
                            l10n.splashTagline,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The launcher icon tile, in the place and size of the system splash badge.
class _BadgePainter extends CustomPainter {
  const _BadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    BrandMark.paintIcon(canvas, size, radiusFrac: 0.26);
  }

  @override
  bool shouldRepaint(_BadgePainter old) => false;
}

/// Rings spreading from behind the badge, sweep-gradient like the icon's rings.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.p, this.badgeFrac);
  final double p;
  final double badgeFrac;

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0) return;
    // Three rings leave one after another and fade as they widen.
    for (var i = 0; i < 3; i++) {
      final k = ((p - i * 0.14) / (1 - i * 0.14)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final r =
          size.width / 2 * (badgeFrac * 0.55 + (1 - badgeFrac * 0.55) * k);
      final a = (1 - k) * (0.85 - i * 0.2);
      final centre = size.center(Offset.zero);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 - i * 0.7
        ..shader = SweepGradient(
          colors: [
            BrandMark.key.withValues(alpha: a),
            BrandMark.cue.withValues(alpha: a),
            BrandMark.tally.withValues(alpha: a),
            BrandMark.violet.withValues(alpha: a),
            BrandMark.key.withValues(alpha: a),
          ],
          transform: GradientRotation(i * 1.1 + p * 1.4),
        ).createShader(Rect.fromCircle(center: centre, radius: r));
      canvas.drawCircle(centre, r, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.p != p;
}
