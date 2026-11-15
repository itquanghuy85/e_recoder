import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'editor_controller.dart';

/// The words for what one undo step did. Kept next to the sheet so the controller stays free of
/// language.
String editActionLabel(AppL10n t, EditAction a) => switch (a) {
  EditAction.edit => t.actionEdit,
  EditAction.autoDirect => t.actionAutoDirect,
  EditAction.findTouches => t.actionFindTouches,
  EditAction.silenceCut => t.actionSilenceCut,
  EditAction.markers => t.actionMarkers,
  EditAction.captions => t.actionCaptions,
  EditAction.clip => t.actionClip,
  EditAction.text => t.actionText,
  EditAction.look => t.actionLook,
  EditAction.audio => t.actionAudio,
  EditAction.template => t.actionTemplate,
};

/// Opens the edit history: every undoable step, newest first, each one tap away, plus the steps that
/// were undone and can be brought back. Reading only; nothing changes until the person taps.
Future<void> showEditHistorySheet(BuildContext context, EditorController c) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _EditHistorySheet(c: c),
  );
}

class _EditHistorySheet extends StatelessWidget {
  const _EditHistorySheet({required this.c});

  final EditorController c;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final t = AppL10n.of(context);
      final tt = Theme.of(context).textTheme;
      final cs = Theme.of(context).colorScheme;
      final undo = c.undoHistory;
      final redo = c.redoHistory;
      final maxH = MediaQuery.sizeOf(context).height * 0.7;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Text(t.historyTitle, style: tt.titleMedium),
              ),
              const SizedBox(height: Space.xs),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.md,
                          Space.sm,
                          Space.md,
                          0,
                        ),
                        child: Text(
                          t.historyUndoSection,
                          style: tt.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (undo.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.md,
                            vertical: Space.sm,
                          ),
                          child: Text(
                            t.historyEmpty,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (var i = 0; i < undo.length; i++)
                        Semantics(
                          identifier: 'history_step_$i',
                          child: ListTile(
                            dense: true,
                            leading: Text(
                              '${i + 1}',
                              style: tt.labelLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              editActionLabel(t, undo[i]),
                              style: tt.bodyMedium,
                            ),
                            subtitle: i == 0
                                ? Text(
                                    t.historyCurrent,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.primary,
                                    ),
                                  )
                                : null,
                            trailing: Icon(
                              Icons.undo,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            onTap: () {
                              c.jumpBack(i + 1);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      if (redo.isNotEmpty) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.md,
                            Space.xs,
                            Space.md,
                            0,
                          ),
                          child: Text(
                            t.historyRedoSection,
                            style: tt.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (var i = 0; i < redo.length; i++)
                          ListTile(
                            dense: true,
                            enabled: i == 0,
                            leading: Icon(
                              Icons.redo,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            title: Text(
                              editActionLabel(t, redo[i]),
                              style: tt.bodyMedium,
                            ),
                            trailing: i == 0
                                ? FilledButton.tonal(
                                    onPressed: () {
                                      c.redo();
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(t.redo),
                                  )
                                : null,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
