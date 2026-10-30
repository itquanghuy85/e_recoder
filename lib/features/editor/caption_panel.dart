import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'caption_models.dart';
import 'caption_style_editor.dart';
import 'editor_controller.dart';

/// Opens the caption panel: one row per subtitle line (text + start/end) with add / delete / turn off.
Future<void> showCaptionPanel(BuildContext context, EditorController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CaptionPanel(controller: c),
  );
}

class CaptionPanel extends StatefulWidget {
  const CaptionPanel({super.key, required this.controller});
  final EditorController controller;

  @override
  State<CaptionPanel> createState() => _CaptionPanelState();
}

class _CaptionPanelState extends State<CaptionPanel> {
  /// 0 = the lines, 1 = the look.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final item = c.captionItem;
        final cues = item?.cues ?? const <CaptionCue>[];
        final hasStyle = item?.cues != null;
        final tab = hasStyle ? _tab : 0;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Space.md,
              0,
              Space.md,
              MediaQuery.viewInsetsOf(context).bottom + Space.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.presetSubtitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (hasStyle) ...[
                  const SizedBox(height: Space.sm),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: Semantics(
                          identifier: 'cap_tab_lines',
                          child: Text(t.captionTabLines),
                        ),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Semantics(
                          identifier: 'cap_tab_style',
                          child: Text(t.captionTabStyle),
                        ),
                      ),
                    ],
                    selected: {tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                ],
                const SizedBox(height: Space.sm),
                if (tab == 1)
                  Flexible(
                    child: SingleChildScrollView(
                      child: CaptionStyleEditor(controller: c),
                    ),
                  )
                else ...[
                  Flexible(
                    child: cues.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Space.lg,
                            ),
                            child: Text(
                              t.captionPanelEmpty,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: cues.length,
                            itemBuilder: (_, i) => _CueRow(
                              key: ValueKey('cue$i'),
                              index: i,
                              cue: cues[i],
                              controller: c,
                            ),
                          ),
                  ),
                  const SizedBox(height: Space.sm),
                  Semantics(
                    identifier: 'caption_add',
                    child: FilledButton.tonal(
                      onPressed: () => c.addCue(),
                      child: Text(t.captionPanelAdd),
                    ),
                  ),
                  if (hasStyle) ...[
                    const SizedBox(height: Space.sm),
                    Semantics(
                      identifier: 'caption_off',
                      child: OutlinedButton(
                        onPressed: c.turnOffCaptions,
                        child: Text(t.captionPanelOff),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CueRow extends StatefulWidget {
  const _CueRow({
    super.key,
    required this.index,
    required this.cue,
    required this.controller,
  });
  final int index;
  final CaptionCue cue;
  final EditorController controller;

  @override
  State<_CueRow> createState() => _CueRowState();
}

class _CueRowState extends State<_CueRow> {
  late final _text = TextEditingController(text: widget.cue.text);
  late final _start = TextEditingController(text: '${widget.cue.startMs}');
  late final _end = TextEditingController(text: '${widget.cue.endMs}');
  final _focus = [FocusNode(), FocusNode(), FocusNode()];

  @override
  void initState() {
    super.initState();
    for (final (i, f) in _focus.indexed) {
      f.addListener(() {
        if (!f.hasFocus) {
          _commit();
        } else if (i > 0) {
          // Numbers are replaced, not edited digit by digit.
          final ctl = i == 1 ? _start : _end;
          ctl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: ctl.text.length,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(_CueRow old) {
    super.didUpdateWidget(old);
    // Follow outside changes (undo, re-sort) but never fight the field being typed in.
    void sync(TextEditingController c, FocusNode f, String v) {
      if (!f.hasFocus && c.text != v) c.text = v;
    }

    sync(_text, _focus[0], widget.cue.text);
    sync(_start, _focus[1], '${widget.cue.startMs}');
    sync(_end, _focus[2], '${widget.cue.endMs}');
  }

  @override
  void dispose() {
    // Closing the sheet while a field still has focus must not drop what was typed.
    final c = widget.controller;
    final i = widget.index;
    final next = _pending();
    if (next != null) scheduleMicrotask(() => c.updateCue(i, next));
    for (final f in _focus) {
      f.dispose();
    }
    _text.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  /// The cue as typed, or null when it equals the stored one.
  CaptionCue? _pending() {
    final s = int.tryParse(_start.text) ?? widget.cue.startMs;
    var e = int.tryParse(_end.text) ?? widget.cue.endMs;
    if (e <= s) e = s + 1;
    final next = widget.cue.copyWith(text: _text.text, startMs: s, endMs: e);
    if (next.text == widget.cue.text &&
        next.startMs == widget.cue.startMs &&
        next.endMs == widget.cue.endMs) {
      return null;
    }
    return next;
  }

  void _commit() {
    final next = _pending();
    if (next != null) widget.controller.updateCue(widget.index, next);
  }

  Widget _num(
    TextEditingController ctl,
    FocusNode f,
    String label,
    String id,
  ) => Expanded(
    child: Semantics(
      identifier: id,
      child: TextField(
        controller: ctl,
        focusNode: f,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, isDense: true),
        onSubmitted: (_) => _commit(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final i = widget.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Semantics(
              identifier: 'cue_text_$i',
              child: TextField(
                controller: _text,
                focusNode: _focus[0],
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (_) => _commit(),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          _num(_start, _focus[1], t.captionPanelStart, 'cue_start_$i'),
          const SizedBox(width: Space.sm),
          _num(_end, _focus[2], t.captionPanelEnd, 'cue_end_$i'),
          Semantics(
            identifier: 'cue_delete_$i',
            child: IconButton(
              tooltip: t.menuDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => widget.controller.removeCue(i),
            ),
          ),
        ],
      ),
    );
  }
}
