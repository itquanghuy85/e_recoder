import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'caption_models.dart';
import 'caption_templates.dart';
import 'editor_controller.dart';

/// The "Templates" tab of the caption panel: every ready-made look drawn with the real native
/// caption renderer (what you see is what the video gets), applied with one tap.
class CaptionTemplatePicker extends StatefulWidget {
  const CaptionTemplatePicker({
    super.key,
    required this.controller,
    this.templates,
  });
  final EditorController controller;

  /// Overrides the bundled templates (tests).
  final Future<List<CaptionTemplate>>? templates;

  @override
  State<CaptionTemplatePicker> createState() => _CaptionTemplatePickerState();
}

class _CaptionTemplatePickerState extends State<CaptionTemplatePicker> {
  late final Future<List<CaptionTemplate>> _templates =
      widget.templates ?? CaptionTemplate.load();

  /// One picture per template id, drawn once.
  final Map<String, Future<({Uint8List png, int w, int h})?>> _pictures = {};

  /// The picture is drawn at 720 px frame width and shown at half size, so it is sharp on a phone.
  static const _frameW = 720;
  static const _scale = 2.0;

  Future<({Uint8List png, int w, int h})?> _picture(
    CaptionTemplate t,
    String sample,
  ) => _pictures.putIfAbsent(t.id, () async {
    try {
      // A short sample: the card shows the look, the caption reveal is shown by the preview.
      return await widget.controller.native.renderCue(
        CaptionCue(text: sample, startMs: 0, endMs: 1).toJson(),
        t.style.toJson(),
        _frameW,
      );
    } catch (_) {
      return null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final c = widget.controller;
    return FutureBuilder<List<CaptionTemplate>>(
      future: _templates,
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) {
          return const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final used = c.captionItem?.captionStyle?.templateId;
            return GridView.builder(
              padding: const EdgeInsets.only(bottom: Space.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Space.sm,
                crossAxisSpacing: Space.sm,
                childAspectRatio: 1.25,
              ),
              itemCount: all.length,
              itemBuilder: (_, i) => _TemplateCard(
                template: all[i],
                name: all[i].nameFor(lang),
                hint: all[i].hintFor(lang),
                selected: used == all[i].id,
                picture: _picture(all[i], t.captionTemplateSample),
                scale: _scale,
                onTap: () => c.setCaptionStyle(all[i].style),
              ),
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.name,
    required this.hint,
    required this.selected,
    required this.picture,
    required this.scale,
    required this.onTap,
  });

  final CaptionTemplate template;
  final String name;
  final String hint;
  final bool selected;
  final Future<({Uint8List png, int w, int h})?> picture;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      identifier: 'tpl_${template.id}',
      button: true,
      selected: selected,
      label: '$name. $hint',
      // Its own Material: an Ink on the sheet's Material would paint outside the scrolling grid.
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(
            color: selected ? cs.tertiary : cs.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  // A busy mid-tone background, like real footage, so a template that only works on
                  // a plain background shows its weakness here.
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF3B6EA5),
                        Color(0xFF8A5CA8),
                        Color(0xFFD9822B),
                      ],
                    ),
                  ),
                  child: Center(
                    child: FutureBuilder<({Uint8List png, int w, int h})?>(
                      future: picture,
                      builder: (context, snap) {
                        final p = snap.data;
                        if (p == null) return const SizedBox.shrink();
                        return Image.memory(
                          p.png,
                          scale: scale,
                          fit: BoxFit.scaleDown,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                color: cs.surfaceContainerHigh,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: tt.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, size: 18, color: cs.tertiary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
