import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'marker_inspector.dart';
import 'marker_preview.dart';
import 'marker_settings.dart';
import 'marker_spec.dart';

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
        children: [
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
                  ButtonSegment(value: false, label: Text(t.previewLight)),
                  ButtonSegment(value: true, label: Text(t.previewDark)),
                ],
                selected: {_dark},
                onSelectionChanged: (v) => setState(() => _dark = v.first),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: MarkerPreview(
                key: ValueKey('preview_${s.tool.name}'),
                spec: spec,
                darkBackdrop: _dark,
                holdMs: s.holdMs,
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          Text(t.markerDefaultTool, style: tt.titleMedium),
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
          const SizedBox(height: Space.xl),
          _ModeSection(settings: s),
          const SizedBox(height: Space.xl),
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
          Text(t.markerHold, style: tt.titleMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final ms in MarkerSettings.holdOptions)
                ChoiceChip(
                  label: Text(
                    t.holdSeconds(
                      ms % 1000 == 0
                          ? '${ms ~/ 1000}'
                          : (ms / 1000).toStringAsFixed(1).replaceAll('.', ','),
                    ),
                  ),
                  selected: s.holdMs == ms,
                  onSelected: (_) => n.update(s.copyWith(holdMs: ms)),
                ),
            ],
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
          const SizedBox(height: Space.sm),
          Text(
            s.mode == MarkMode.dot ? t.markDotNote : t.markCleanNote,
            style: tt.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
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
        Text(t.markModeTitle, style: tt.titleMedium),
        const SizedBox(height: Space.sm),
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
        if (settings.mode == MarkMode.clean) ...[
          const SizedBox(height: Space.sm),
          Text(t.autoAfterRec, style: tt.titleSmall),
          CheckboxListTile(
            key: const ValueKey('auto_zoom_setting'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.autoZoomOpt, style: tt.bodyMedium),
            value: settings.autoZoom,
            onChanged: (v) => n.update(settings.copyWith(autoZoom: v ?? false)),
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
        ],
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
