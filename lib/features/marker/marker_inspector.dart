import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'marker_spec.dart';

String markerTypeLabel(AppL10n t, MarkerType m) => switch (m) {
  MarkerType.finger => t.markerFinger,
  MarkerType.ripple => t.markerRipple,
  MarkerType.arrow => t.markerArrow,
  MarkerType.circle => t.markerCircle,
  MarkerType.rect => t.markerRect,
  MarkerType.pen => t.markerPen,
  MarkerType.number => t.markerNumber,
};

IconData markerTypeIcon(MarkerType m) => switch (m) {
  MarkerType.finger => Icons.touch_app,
  MarkerType.ripple => Icons.radio_button_checked,
  MarkerType.arrow => Icons.north_west,
  MarkerType.circle => Icons.circle_outlined,
  MarkerType.rect => Icons.crop_square,
  MarkerType.pen => Icons.edit,
  MarkerType.number => Icons.looks_one_outlined,
};

List<String> _colorNames(AppL10n t) => [
  t.colorRed,
  t.colorAmber,
  t.colorGreen,
  t.colorCyan,
  t.colorMagenta,
  t.colorWhite,
  t.colorBlack,
];

/// A row of the marker palette. Selected colour gets a key-cyan ring.
class MarkerColorRow extends StatelessWidget {
  const MarkerColorRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final Color selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final c = Theme.of(context).colorScheme;
    final names = _colorNames(t);
    return Wrap(
      spacing: Space.xs,
      children: [
        for (var i = 0; i < MarkerPalette.colors.length; i++)
          Semantics(
            button: true,
            selected: MarkerPalette.colors[i] == selected,
            label: names[i],
            child: InkResponse(
              radius: 28,
              onTap: () => onChanged(i),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: MarkerPalette.colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MarkerPalette.colors[i] == selected
                            ? c.tertiary
                            : c.outlineVariant,
                        width: MarkerPalette.colors[i] == selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Everything about a marker the user can adjust: colour, stroke, size, rotation, opacity.
/// Used by the settings preview now and by the editor's marker panel later.
class MarkerInspector extends StatelessWidget {
  const MarkerInspector({
    super.key,
    required this.spec,
    required this.onChanged,
  });
  final MarkerSpec spec;
  final ValueChanged<MarkerSpec> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;

    Widget slider(
      String label,
      double value,
      double min,
      double max,
      ValueChanged<double> on, {
      String Function(double)? fmt,
    }) {
      return Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: tt.labelLarge)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: on,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              fmt?.call(value) ?? value.toStringAsFixed(1),
              style: tt.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.markerColor, style: tt.titleSmall),
        MarkerColorRow(
          selected: spec.color,
          onChanged: (i) =>
              onChanged(spec.copyWith(color: MarkerPalette.colors[i])),
        ),
        const SizedBox(height: Space.sm),
        Text(t.markerThickness, style: tt.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final (v, label) in [
              (3.0, t.thicknessThin),
              (5.0, t.thicknessMedium),
              (8.0, t.thicknessThick),
            ])
              ChoiceChip(
                label: Text(label),
                selected: spec.thickness == v,
                onSelected: (_) => onChanged(spec.copyWith(thickness: v)),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        slider(
          t.adjustScale,
          spec.scale,
          0.4,
          3,
          (v) => onChanged(spec.copyWith(scale: v)),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        slider(
          t.adjustRotate,
          spec.rotation,
          -180,
          180,
          (v) => onChanged(spec.copyWith(rotation: v)),
          fmt: (v) => '${v.round()}°',
        ),
        slider(
          t.adjustOpacity,
          spec.opacity,
          0.3,
          1,
          (v) => onChanged(spec.copyWith(opacity: v)),
          fmt: (v) => '${(v * 100).round()}%',
        ),
      ],
    );
  }
}
