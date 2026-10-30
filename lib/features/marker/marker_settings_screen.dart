import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'marker_inspector.dart';
import 'marker_preview.dart';
import 'marker_settings.dart';
import 'marker_spec.dart';
import 'marker_timing.dart';
import '../settings/section_header.dart';
import 'touch_source_section.dart';

/// Demo geometry per tool, all aimed at the mock button at (0.5, 0.55).
MarkerSpec demoMarker(
  MarkerType type, {
  required Color color,
  required double thickness,
}) {
  switch (type) {
    case MarkerType.arrow:
      return MarkerSpec(
        type: type,
        color: color,
        thickness: thickness,
        x0: 0.78,
        y0: 0.74,
        x1: 0.56,
        y1: 0.575,
      );
    case MarkerType.circle:
      return MarkerSpec(
        type: type,
        color: color,
        thickness: thickness,
        x0: 0.28,
        y0: 0.505,
        x1: 0.72,
        y1: 0.595,
      );
    case MarkerType.rect:
      return MarkerSpec(
        type: type,
        color: color,
        thickness: thickness,
        x0: 0.28,
        y0: 0.505,
        x1: 0.72,
        y1: 0.595,
      );
    case MarkerType.pen:
      return MarkerSpec(
        type: type,
        color: color,
        thickness: thickness,
        points: const [
          0.3,
          0.6,
          0.38,
          0.62,
          0.46,
          0.6,
          0.54,
          0.62,
          0.62,
          0.6,
          0.7,
          0.62,
        ],
      );
    default:
      return MarkerSpec(
        type: type,
        color: color,
        thickness: thickness,
        x0: 0.5,
        y0: 0.55,
        x1: 0.5,
        y1: 0.55,
      );
  }
}

class MarkerSettingsScreen extends ConsumerStatefulWidget {
  const MarkerSettingsScreen({super.key});

  @override
  ConsumerState<MarkerSettingsScreen> createState() =>
      _MarkerSettingsScreenState();
}

class _MarkerSettingsScreenState extends ConsumerState<MarkerSettingsScreen> {
  bool _dark = false;
  // Preview-only adjustments (the live tray uses pinch for these).
  double _scale = 1;
  double _rotation = 0;
  double _opacity = 1;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final s = ref.watch(markerSettingsProvider);
    final n = ref.read(markerSettingsProvider.notifier);
    final color = MarkerPalette.colors[s.colorIndex];
    final spec = demoMarker(
      s.tool,
      color: color,
      thickness: s.thickness,
    ).copyWith(scale: _scale, rotation: _rotation, opacity: _opacity);

    return Scaffold(
      appBar: AppBar(title: Text(t.settingsMarkers)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  t.settingsMarkersHint,
                  style: tt.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(t.markerPreviewTitle, style: tt.titleMedium),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(t.previewLight),
                        ),
                        ButtonSegment(value: true, label: Text(t.previewDark)),
                      ],
                      selected: {_dark},
                      onSelectionChanged: (v) =>
                          setState(() => _dark = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
              ]),
            ),
          ),
          // The preview stays on top while the settings below scroll under it, and shrinks to a
          // band around the marker so every change is visible as it is made.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PreviewHeader(
              background: Theme.of(context).scaffoldBackgroundColor,
              divider: c.outlineVariant,
              toggleLabel: t.previewToggleBackdrop,
              dark: _dark,
              onToggle: () => setState(() => _dark = !_dark),
              preview: MarkerPreview(
                key: ValueKey('preview_${s.tool.name}'),
                spec: spec,
                darkBackdrop: _dark,
                holdMs: s.holdMs,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.lg,
              Space.lg,
              Space.xxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SettingsSectionHeader(
                  step: 1,
                  title: t.markerSecLook,
                  sub: t.markerSecLookSub,
                ),
                Text(t.markerDefaultTool, style: tt.titleSmall),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final m in MarkerType.values)
                      ChoiceChip(
                        avatar: Icon(markerTypeIcon(m), size: 18),
                        label: Text(markerTypeLabel(t, m)),
                        selected: s.tool == m,
                        onSelected: (_) => n.update(s.copyWith(tool: m)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
                MarkerInspector(
                  spec: spec,
                  onChanged: (v) {
                    final ci = MarkerPalette.colors.indexOf(v.color);
                    setState(() {
                      _scale = v.scale;
                      _rotation = v.rotation;
                      _opacity = v.opacity;
                    });
                    if (ci != s.colorIndex || v.thickness != s.thickness) {
                      n.update(
                        s.copyWith(
                          colorIndex: ci < 0 ? s.colorIndex : ci,
                          thickness: v.thickness,
                        ),
                      );
                    }
                  },
                ),
                Text(
                  t.markerAdjustNote,
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: Space.xl),
                SettingsSectionHeader(
                  step: 2,
                  title: t.markerSecTime,
                  sub: t.markerSecTimeSub,
                ),
                Row(
                  children: [
                    Expanded(child: Text(t.markerHold, style: tt.titleMedium)),
                    Text(
                      t.holdSeconds(_secs(s.holdMs)),
                      style: tt.titleSmall?.copyWith(color: c.primary),
                    ),
                  ],
                ),
                Semantics(
                  key: const ValueKey('marker_hold_slider'),
                  identifier: 'marker_hold',
                  child: Slider(
                    value: s.holdMs
                        .clamp(MarkerTiming.minHoldMs, MarkerTiming.maxHoldMs)
                        .toDouble(),
                    min: MarkerTiming.minHoldMs.toDouble(),
                    max: MarkerTiming.maxHoldMs.toDouble(),
                    divisions:
                        (MarkerTiming.maxHoldMs - MarkerTiming.minHoldMs) ~/
                        500,
                    label: t.holdSeconds(_secs(s.holdMs)),
                    onChanged: (v) => n.update(s.copyWith(holdMs: v.round())),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${t.markerHoldShort} · ${_secs(MarkerTiming.minHoldMs)} s',
                      style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                    Text(
                      '${t.markerHoldLong} · ${_secs(MarkerTiming.maxHoldMs)} s',
                      style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  t.markerHoldHint,
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: Space.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.markerAutoExit, style: tt.titleSmall),
                  subtitle: Text(
                    t.markerAutoExitHint,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                  value: s.autoExit,
                  onChanged: (v) => n.update(s.copyWith(autoExit: v)),
                ),
                if (s.autoExit) ...[
                  Text(
                    t.markerExitDelay(
                      (s.exitDelayMs / 1000)
                          .toStringAsFixed(1)
                          .replaceAll('.', ','),
                    ),
                    style: tt.titleSmall,
                  ),
                  Semantics(
                    identifier: 'marker_exit_delay',
                    child: Slider(
                      value: s.exitDelayMs.toDouble(),
                      min: 0,
                      max: 3000,
                      divisions: 30,
                      label: '${s.exitDelayMs} ms',
                      onChanged: (v) =>
                          n.update(s.copyWith(exitDelayMs: v.round())),
                    ),
                  ),
                  Text(
                    t.markerExitDelayHint,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: Space.xl),
                SettingsSectionHeader(
                  step: 3,
                  title: t.markerSecHow,
                  sub: t.markerSecHowSub,
                ),
                _ModeSection(settings: s),
                const SizedBox(height: Space.sm),
                Text(
                  s.mode == MarkMode.dot ? t.markDotNote : t.markCleanNote,
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
                if (s.mode == MarkMode.clean) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    t.markCleanLimit,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: Space.xl),
                SettingsSectionHeader(
                  step: 4,
                  title: t.markerSecAuto,
                  sub: t.markerSecAutoSub,
                ),
                _AutoDirectSection(settings: s),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// 2500 -> "2,5", 3000 -> "3".
  static String _secs(int ms) => ms % 1000 == 0
      ? '${ms ~/ 1000}'
      : (ms / 1000).toStringAsFixed(1).replaceAll('.', ',');
}

/// Pinned header holding the marker preview. Expanded it shows (almost) the whole mock screen;
/// scrolled, it collapses to a band centred on the marker. The preview is laid out once at a fixed
/// size and only the window onto it changes, so nothing reflows or jumps while scrolling.
class _PreviewHeader extends SliverPersistentHeaderDelegate {
  _PreviewHeader({
    required this.background,
    required this.divider,
    required this.toggleLabel,
    required this.dark,
    required this.onToggle,
    required this.preview,
  });

  final Color background;
  final Color divider;
  final String toggleLabel;
  final bool dark;
  final VoidCallback onToggle;
  final Widget preview;

  static const double _max = 252;
  static const double _min = 108;
  static const double _frameW = 190;
  static const double _frameH = _frameW * kPreviewFrameH / kPreviewFrameW;

  @override
  double get maxExtent => _max;

  @override
  double get minExtent => _min;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final extent = (_max - shrinkOffset).clamp(_min, _max);
    // Keep the marker's usual spot (55 % down the frame) in the middle of what is visible.
    final shift = (extent / 2 - 0.55 * _frameH).clamp(extent - _frameH, 0.0);
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: overlapsContent
            ? Border(bottom: BorderSide(color: divider))
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: SizedBox(
                width: _frameW,
                height: extent,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minWidth: _frameW,
                  maxWidth: _frameW,
                  minHeight: _frameH,
                  maxHeight: _frameH,
                  child: Transform.translate(
                    offset: Offset(0, shift),
                    child: preview,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: Space.sm,
            top: Space.xs,
            child: Semantics(
              identifier: 'preview_theme',
              label: toggleLabel,
              button: true,
              child: IconButton.filledTonal(
                onPressed: onToggle,
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_PreviewHeader old) => true;
}

class _ModeSection extends ConsumerWidget {
  const _ModeSection({required this.settings});
  final MarkerSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final n = ref.read(markerSettingsProvider.notifier);
    final corners = [t.cornerTL, t.cornerTR, t.cornerBL, t.cornerBR];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeCard(
          id: 'mode_dot',
          icon: Icons.radio_button_checked,
          title: t.markModeDot,
          hint: t.markModeDotHint,
          selected: settings.mode == MarkMode.dot,
          onTap: () => n.update(settings.copyWith(mode: MarkMode.dot)),
        ),
        const SizedBox(height: Space.sm),
        _ModeCard(
          id: 'mode_clean',
          icon: Icons.visibility_off_outlined,
          title: t.markModeClean,
          hint: t.markModeCleanHint,
          selected: settings.mode == MarkMode.clean,
          onTap: () => n.update(settings.copyWith(mode: MarkMode.clean)),
        ),
        const SizedBox(height: Space.lg),
        Text(t.markCornerTitle, style: tt.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (var i = 0; i < 4; i++)
              Semantics(
                identifier: 'corner_$i',
                child: ChoiceChip(
                  label: Text(corners[i]),
                  selected: settings.corner == i,
                  onSelected: (_) => n.update(settings.copyWith(corner: i)),
                ),
              ),
          ],
        ),
        if (settings.mode == MarkMode.clean)
          SwitchListTile(
            key: const ValueKey('arm_shake'),
            contentPadding: EdgeInsets.zero,
            title: Text(t.markShake, style: tt.titleSmall),
            subtitle: Text(
              t.markShakeHint,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
            value: settings.armShake,
            onChanged: (v) => n.update(settings.copyWith(armShake: v)),
          ),
      ],
    );
  }
}

/// "Automatic editing after recording": what the app does by itself when a clean recording ends. It is
/// its own group (not buried in the marking options) because it is the main reason to record clean.
class _AutoDirectSection extends ConsumerWidget {
  const _AutoDirectSection({required this.settings});
  final MarkerSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final n = ref.read(markerSettingsProvider.notifier);
    if (settings.mode != MarkMode.clean) {
      return Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.markerAutoNeedsClean,
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: Space.sm),
            Semantics(
              identifier: 'auto_switch_clean',
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    n.update(settings.copyWith(mode: MarkMode.clean)),
                icon: const Icon(Icons.visibility_off_outlined),
                label: Text(t.markerAutoSwitch),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // How the editor learns where you tapped, to build the edit from your touches.
        const TouchSourceSection(),
        const SizedBox(height: Space.sm),
        ...[
          Semantics(
            identifier: 'auto_zoom_opt',
            child: CheckboxListTile(
              key: const ValueKey('auto_zoom_setting'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t.autoZoomOpt, style: tt.bodyMedium),
              value: settings.autoZoom,
              onChanged: (v) =>
                  n.update(settings.copyWith(autoZoom: v ?? false)),
            ),
          ),
          CheckboxListTile(
            key: const ValueKey('auto_number_setting'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.autoNumberOpt, style: tt.bodyMedium),
            value: settings.autoNumber,
            onChanged: (v) =>
                n.update(settings.copyWith(autoNumber: v ?? false)),
          ),
          if (settings.autoZoom) ...[
            Text(t.zoomAutoTuning, style: tt.titleSmall),
            _TuneSlider(
              label: t.zoomScale,
              value: settings.zoomScale,
              min: 1.2,
              max: 4,
              text:
                  '${settings.zoomScale.toStringAsFixed(1).replaceAll('.', ',')}×',
              onChanged: (v) => n.update(settings.copyWith(zoomScale: v)),
            ),
            _TuneSlider(
              label: t.zoomIn,
              value: settings.zoomRampMs.toDouble(),
              min: 100,
              max: 2000,
              text:
                  '${(settings.zoomRampMs / 1000).toStringAsFixed(2).replaceAll('.', ',')}s',
              onChanged: (v) =>
                  n.update(settings.copyWith(zoomRampMs: v.round())),
            ),
            _TuneSlider(
              label: t.zoomHold,
              value: settings.zoomHoldMs.toDouble(),
              min: 0,
              max: 5000,
              text:
                  '${(settings.zoomHoldMs / 1000).toStringAsFixed(1).replaceAll('.', ',')}s',
              onChanged: (v) =>
                  n.update(settings.copyWith(zoomHoldMs: v.round())),
            ),
            Text(
              t.zoomTimingHint,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ],
      ],
    );
  }
}

class _TuneSlider extends StatelessWidget {
  const _TuneSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.text,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final String text;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: tt.labelLarge)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(text, style: tt.bodySmall, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });
  final String id;
  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final edge = selected ? c.tertiary : c.outlineVariant;
    return Semantics(
      identifier: id,
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? c.tertiary.withValues(alpha: 0.08)
            : c.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: edge, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: selected ? c.tertiary : c.onSurfaceVariant),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tt.titleSmall),
                      const SizedBox(height: Space.xs),
                      Text(
                        hint,
                        style: tt.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: c.tertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
