import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_inspector.dart';
import 'caption_models.dart';
import 'edit_project.dart';
import 'editor_controller.dart';
import 'editor_pro_tools.dart' show fontLabel;
import 'editor_tools.dart' show editorSlider;

/// The "Style" tab of the caption panel: how the caption looks (font, colours, outline, shadow,
/// background, alignment, position) and how it reveals (all at once, word by word, ...).
///
/// Every change goes to [EditorController.setCaptionStyle], so the stage shows it at once through the
/// same native renderer the export uses. Slider drags are one undo step (see `editorSlider`).
class CaptionStyleEditor extends StatelessWidget {
  const CaptionStyleEditor({super.key, required this.controller});
  final EditorController controller;

  static const _boxAlpha = 0xB3;
  static const _black = 0xFF000000;

  /// The caption's style with the item's own position, which the stage and the drag handles use.
  static CaptionStyle styleOf(TextItem item) =>
      (item.captionStyle ?? CaptionStyle.standard).copyWith(
        x: item.x,
        y: item.y,
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _body(context),
  );

  Widget _body(BuildContext context) {
    final c = controller;
    final item = c.captionItem;
    if (item == null || item.cues == null) return const SizedBox.shrink();
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final s = styleOf(item);

    // An edited look is no longer the template it started from.
    void set(CaptionStyle next, {bool drag = false}) => c.setCaptionStyle(
      next.copyWith(templateId: null),
      on: item,
      record: !drag,
    );

    Widget slider({
      required String id,
      required String label,
      required double value,
      required double min,
      required double max,
      required CaptionStyle Function(double) apply,
      String Function(double)? fmt,
    }) => editorSlider(
      context: context,
      c: c,
      id: id,
      label: label,
      value: value,
      min: min,
      max: max,
      onChanged: (v) => set(apply(v), drag: true),
      fmt: fmt ?? (v) => v.round().toString(),
    );

    final outlineOn = s.outlineColor != null && s.outlineWidth > 0;
    final shadowOn = s.shadowColor != null && s.shadowBlur > 0;
    final boxOn = s.boxColor != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.captionReveal, style: tt.titleSmall),
        Wrap(
          spacing: Space.xs,
          children: [
            for (final m in RevealMode.values)
              Semantics(
                identifier: 'reveal_${m.name}',
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_revealLabel(t, m)),
                  selected: s.revealMode == m,
                  onSelected: (_) => set(s.copyWith(revealMode: m)),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(t.textFont, style: tt.titleSmall),
        Wrap(
          spacing: Space.xs,
          children: [
            for (final f in TextFont.values)
              Semantics(
                identifier: 'cap_font_${f.name}',
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(fontLabel(t, f)),
                  selected: s.fontId == f.name,
                  onSelected: (_) => set(s.copyWith(fontId: f.name)),
                ),
              ),
          ],
        ),
        Wrap(
          spacing: Space.sm,
          children: [
            Semantics(
              identifier: 'cap_bold',
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(t.textBold),
                selected: s.bold,
                onSelected: (v) => set(s.copyWith(bold: v)),
              ),
            ),
            Semantics(
              identifier: 'cap_outline',
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(t.textOutline),
                selected: outlineOn,
                onSelected: (v) => set(
                  v
                      ? s.copyWith(
                          outlineColor: s.outlineColor ?? _black,
                          outlineWidth: 2,
                        )
                      : s.copyWith(outlineWidth: 0),
                ),
              ),
            ),
            Semantics(
              identifier: 'cap_shadow',
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(t.textShadow),
                selected: shadowOn,
                onSelected: (v) => set(
                  v
                      ? s.copyWith(shadowColor: 0x99000000, shadowBlur: 3)
                      : s.copyWith(shadowBlur: 0),
                ),
              ),
            ),
            Semantics(
              identifier: 'cap_box',
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(t.textBox),
                selected: boxOn,
                onSelected: (v) => set(
                  v
                      ? s.copyWith(
                          boxColor: (_boxAlpha << 24) | 0x000000,
                          boxRadius: 8,
                        )
                      : s.copyWith(boxColor: null),
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: Space.xs,
          children: [
            for (final a in const ['left', 'center', 'right'])
              Semantics(
                identifier: 'cap_align_$a',
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(switch (a) {
                    'left' => t.alignLeft,
                    'right' => t.alignRight,
                    _ => t.alignCenter,
                  }),
                  selected: s.align == a,
                  onSelected: (_) => set(s.copyWith(align: a)),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(t.markerColor, style: tt.titleSmall),
        MarkerColorRow(
          selected: Color(s.color),
          onChanged: (i) =>
              set(s.copyWith(color: MarkerPalette.colors[i].toARGB32())),
        ),
        slider(
          id: 'cap_size',
          label: t.textSize,
          value: s.sizeU,
          min: 12,
          max: 48,
          apply: (v) => s.copyWith(sizeU: v.roundToDouble()),
        ),
        if (outlineOn) ...[
          slider(
            id: 'cap_outline_w',
            label: t.captionOutlineWidth,
            value: s.outlineWidth,
            min: 0.5,
            max: 6,
            apply: (v) => s.copyWith(outlineWidth: (v * 2).round() / 2),
            fmt: (v) => v.toStringAsFixed(1),
          ),
          Text(t.captionOutlineColor, style: tt.titleSmall),
          MarkerColorRow(
            selected: Color(s.outlineColor ?? _black),
            onChanged: (i) => set(
              s.copyWith(outlineColor: MarkerPalette.colors[i].toARGB32()),
            ),
          ),
        ],
        if (shadowOn)
          slider(
            id: 'cap_shadow_blur',
            label: t.captionShadowBlur,
            value: s.shadowBlur,
            min: 1,
            max: 10,
            apply: (v) => s.copyWith(shadowBlur: v.roundToDouble()),
          ),
        if (boxOn) ...[
          Text(t.captionBoxColor, style: tt.titleSmall),
          MarkerColorRow(
            selected: Color((s.boxColor ?? 0) | 0xFF000000),
            onChanged: (i) => set(
              s.copyWith(
                boxColor:
                    (_boxAlpha << 24) |
                    (MarkerPalette.colors[i].toARGB32() & 0x00FFFFFF),
              ),
            ),
          ),
          slider(
            id: 'cap_box_radius',
            label: t.captionBoxRadius,
            value: s.boxRadius,
            min: 0,
            max: 20,
            apply: (v) => s.copyWith(boxRadius: v.roundToDouble()),
          ),
        ],
        slider(
          id: 'cap_y',
          label: t.captionPosY,
          value: s.y,
          min: 0.05,
          max: 0.95,
          apply: (v) => s.copyWith(y: (v * 100).round() / 100),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        slider(
          id: 'cap_x',
          label: t.captionPosX,
          value: s.x,
          min: 0.1,
          max: 0.9,
          apply: (v) => s.copyWith(x: (v * 100).round() / 100),
          fmt: (v) => '${(v * 100).round()}%',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            identifier: 'cap_reset',
            child: TextButton.icon(
              onPressed: () =>
                  set(CaptionStyle.standard.copyWith(x: 0.5, y: 0.85)),
              icon: const Icon(Icons.restart_alt),
              label: Text(t.captionReset),
            ),
          ),
        ),
      ],
    );
  }

  static String _revealLabel(AppL10n t, RevealMode m) => switch (m) {
    RevealMode.none => t.captionRevealNone,
    RevealMode.wordByWord => t.captionRevealWord,
    RevealMode.charByChar => t.captionRevealChar,
    RevealMode.karaokeHighlight => t.captionRevealKaraoke,
  };
}
