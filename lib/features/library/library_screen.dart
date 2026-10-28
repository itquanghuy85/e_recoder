import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/native_recorder.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../editor/editor_screen.dart';
import '../record/recorder_controller.dart';
import 'join_sheet.dart';
import 'media_repository.dart';
import 'media_tile.dart';
import 'player_screen.dart';

enum _Action { share, edit, rename, delete }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// URIs picked for joining, in pick order. Empty = normal mode; non-empty = selection mode.
  final List<String> _picked = [];
  bool _selecting = false;

  void _toggle(MediaEntry e) {
    setState(() {
      if (!_picked.remove(e.uri)) _picked.add(e.uri);
    });
  }

  void _exitSelection() => setState(() {
    _picked.clear();
    _selecting = false;
  });

  Future<void> _rename(MediaEntry e) async {
    final t = AppL10n.of(context);
    final base = e.name.replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '');
    final ctl = TextEditingController(text: base);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.renameTitle),
        content: TextField(
          key: const ValueKey('rename_field'),
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(labelText: t.renameField),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == base) return;
    final r = await ref.read(nativeRecorderProvider).rename(e.uri, name);
    ref.invalidate(mediaListProvider);
    if (mounted && r != 'ok') {
      _toast(r == 'needs_permission' ? t.needsPermission : t.genericError);
    }
  }

  Future<void> _delete(MediaEntry e) async {
    final t = AppL10n.of(context);
    final c = Theme.of(context).colorScheme;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteTitle),
        content: Text(t.deleteBody(e.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          // Destructive action stays outlined: it never reads as the primary choice.
          Semantics(
            identifier: 'delete_confirm',
            child: OutlinedButton(
              key: const ValueKey('delete_confirm'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.error,
                side: BorderSide(color: c.error),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.menuDelete),
            ),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final r = await ref.read(nativeRecorderProvider).delete(e.uri);
    ref.invalidate(mediaListProvider);
    if (!mounted) return;
    _toast(
      r == 'ok'
          ? t.deleteDone
          : (r == 'needs_permission' ? t.needsPermission : t.genericError),
    );
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  /// One video from the phone, opened straight in the editor: not copied, the gallery is not scanned.
  Future<void> _pickFromPhone() async {
    final t = AppL10n.of(context);
    try {
      final e = await ref.read(nativeRecorderProvider).pickVideoToEdit();
      if (e == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditorScreen(entry: e)),
      );
    } catch (_) {
      if (mounted) _toast(t.pickVideoFailed);
    }
  }

  void _open(MediaEntry e) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => PlayerScreen(entry: e)));

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final list = ref.watch(mediaListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              identifier: 'library_pick_video',
              child: OutlinedButton.icon(
                onPressed: _pickFromPhone,
                icon: const Icon(Icons.video_file_outlined),
                label: Text(t.pickVideoFromDevice),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(mediaListProvider.future),
            child: list.when(
              data: (items) => items.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.xl,
                            160,
                            Space.xl,
                            Space.xl,
                          ),
                          child: Column(
                            children: [
                              Text(t.libraryEmptyTitle, style: tt.titleLarge),
                              const SizedBox(height: Space.sm),
                              Text(
                                t.libraryEmptyBody,
                                style: tt.bodyMedium?.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        Space.lg,
                        Space.sm,
                        Space.xl,
                      ),
                      itemCount: items.length + 1,
                      separatorBuilder: (_, i) =>
                          i == 0 ? const SizedBox.shrink() : const Divider(),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selecting
                                        ? t.selectedCount(_picked.length)
                                        : t.libraryTitle,
                                    style: tt.headlineSmall,
                                  ),
                                ),
                                if (!_selecting && items.length > 1)
                                  Semantics(
                                    identifier: 'library_select',
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          setState(() => _selecting = true),
                                      icon: const Icon(Icons.checklist),
                                      label: Text(t.selectMode),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                        final e = items[i - 1];
                        final order = _picked.indexOf(e.uri);
                        return MediaTile(
                          entry: e,
                          selecting: _selecting,
                          selectionNumber: order < 0 ? null : order + 1,
                          onTap: () => _selecting ? _toggle(e) : _open(e),
                          onLongPress: _selecting
                              ? null
                              : () => setState(() {
                                  _selecting = true;
                                  _picked.add(e.uri);
                                }),
                          trailing: _selecting
                              ? const SizedBox(width: Space.sm)
                              : PopupMenuButton<_Action>(
                                  tooltip: t.menuMore,
                                  onSelected: (a) {
                                    switch (a) {
                                      case _Action.share:
                                        ref
                                            .read(nativeRecorderProvider)
                                            .share(e.uri);
                                      case _Action.edit:
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                EditorScreen(entry: e),
                                          ),
                                        );
                                      case _Action.rename:
                                        _rename(e);
                                      case _Action.delete:
                                        _delete(e);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: _Action.edit,
                                      child: Text(t.menuEdit),
                                    ),
                                    PopupMenuItem(
                                      value: _Action.share,
                                      child: Text(t.menuShare),
                                    ),
                                    PopupMenuItem(
                                      value: _Action.rename,
                                      child: Text(t.menuRename),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: _Action.delete,
                                      child: Text(t.menuDelete),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(t.genericError)),
            ),
          ),
        ),
        if (_selecting)
          Material(
            color: c.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.sm,
              ),
              child: Row(
                children: [
                  TextButton(onPressed: _exitSelection, child: Text(t.cancel)),
                  const Spacer(),
                  Semantics(
                    identifier: 'library_join',
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.tertiary,
                        foregroundColor: c.onTertiary,
                      ),
                      onPressed: _picked.length >= 2
                          ? () async {
                              final entries =
                                  (list.value ?? const [])
                                      .where((e) => _picked.contains(e.uri))
                                      .toList()
                                    ..sort(
                                      (a, b) => _picked
                                          .indexOf(a.uri)
                                          .compareTo(_picked.indexOf(b.uri)),
                                    );
                              _exitSelection();
                              await showJoinSheet(context, entries);
                            }
                          : null,
                      icon: const Icon(Icons.merge_type),
                      label: Text(t.joinAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
