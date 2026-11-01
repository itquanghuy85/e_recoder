import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'caption_models.dart';
import 'caption_panel.dart';
import 'caption_templates.dart';
import 'editor_controller.dart';

/// Opens the "automatic captions" sheet: language, what is needed, progress. The recognition runs on
/// the phone (Android's own recogniser): no audio is sent anywhere.
Future<void> showAutoCaptions(BuildContext context, EditorController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AutoCaptionSheet(controller: c),
  );
}

class AutoCaptionSheet extends StatefulWidget {
  const AutoCaptionSheet({super.key, required this.controller});
  final EditorController controller;

  @override
  State<AutoCaptionSheet> createState() => _AutoCaptionSheetState();
}

class _AutoCaptionSheetState extends State<AutoCaptionSheet> {
  static const langs = ['vi-VN', 'en-US'];
  String _lang = 'vi-VN';
  ({bool available, Map<String, String> languages})? _support;
  bool _downloading = false;
  bool _useTemplate = true;
  Timer? _poll;

  EditorController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await c.native.sttSupport(langs);
    if (!mounted) return;
    setState(() {
      _support = s;
      // Start with a language that works, Vietnamese first.
      if (s.languages[_lang] == 'unsupported') {
        _lang = langs.firstWhere(
          (l) => s.languages[l] != 'unsupported',
          orElse: () => _lang,
        );
      }
    });
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    await c.native.sttDownload(_lang);
    // The system downloads it by itself; ask again until the language is there.
    _poll?.cancel();
    var tries = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      tries++;
      await _refresh();
      if (!mounted) return;
      if (_support?.languages[_lang] == 'installed' || tries > 60) {
        t.cancel();
        setState(() => _downloading = false);
      }
    });
  }

  Future<void> _start() async {
    final t = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final context0 = context;
    // The look the captions start with: the TikTok template (the first one when it is missing).
    CaptionStyle? look;
    if (_useTemplate) {
      final all = await CaptionTemplate.load();
      if (all.isNotEmpty) {
        look =
            (all.where((e) => e.id == 'tiktok').firstOrNull ?? all.first).style;
      }
    }
    final n = await c.generateCaptionCues(_lang, style: look);
    if (!mounted) return;
    final err = c.sttError;
    nav.pop();
    if (n > 0 && context0.mounted) {
      // Straight to the templates, so the person can change the look at once.
      unawaited(showCaptionPanel(nav.context, c, initialTab: 1));
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n > 0
              ? t.captionsCreatedCues(n)
              : switch (err) {
                  null => t.captionsCancelled,
                  'no_audio' => t.captionsNoAudio,
                  'no_speech' => t.captionsNoSpeech,
                  _ => t.captionsFailed,
                },
        ),
      ),
    );
  }

  String _langName(AppL10n t, String l) =>
      l == 'vi-VN' ? t.langVietnamese : t.langEnglish;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sup = _support;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final busy = c.sttBusy;
        final state = sup?.languages[_lang];
        final p = c.sttProgress;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.captionsAutoTitle, style: tt.titleLarge),
                const SizedBox(height: Space.xs),
                Text(
                  t.captionsPrivacy,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: Space.md),
                if (sup == null)
                  const Center(child: CircularProgressIndicator())
                else if (!sup.available)
                  Semantics(
                    identifier: 'stt_unavailable',
                    child: Text(t.captionsUnavailable, style: tt.bodyMedium),
                  )
                else ...[
                  Text(t.captionsLanguage, style: tt.titleSmall),
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.sm,
                    children: [
                      for (final l in langs)
                        Semantics(
                          identifier: l == 'vi-VN'
                              ? 'stt_lang_vi'
                              : 'stt_lang_en',
                          child: ChoiceChip(
                            label: Text(_langName(t, l)),
                            selected: _lang == l,
                            onSelected: busy
                                ? null
                                : (_) => setState(() => _lang = l),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(switch (state) {
                    'installed' => t.captionsLangReady,
                    'downloadable' => t.captionsLangDownload,
                    _ => t.captionsLangUnsupported,
                  }, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: Space.md),
                  if (busy) ...[
                    Semantics(
                      identifier: 'stt_progress',
                      liveRegion: true,
                      child: Text(
                        p == null || p.total == 0
                            ? t.captionsPreparing
                            : t.captionsProgress(p.done, p.total),
                        style: tt.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    LinearProgressIndicator(
                      value: p == null || p.total == 0
                          ? null
                          : p.done / p.total,
                    ),
                    const SizedBox(height: Space.md),
                    Semantics(
                      identifier: 'stt_cancel',
                      child: OutlinedButton(
                        onPressed: c.cancelCaptions,
                        child: Text(t.cancel),
                      ),
                    ),
                  ] else if (state == 'downloadable')
                    Semantics(
                      identifier: 'stt_download',
                      child: FilledButton.icon(
                        onPressed: _downloading ? null : _download,
                        icon: _downloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(
                          _downloading
                              ? t.captionsDownloading
                              : t.captionsDownload,
                        ),
                      ),
                    )
                  else
                    Semantics(
                      identifier: 'stt_start',
                      child: FilledButton.icon(
                        onPressed: state == 'installed' ? _start : null,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(t.captionsStart),
                      ),
                    ),
                  Semantics(
                    identifier: 'stt_use_template',
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _useTemplate,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => _useTemplate = v),
                      title: Text(t.captionsApplyTemplate),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    t.captionsReplaceNote,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
