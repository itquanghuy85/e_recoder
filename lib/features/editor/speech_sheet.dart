import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import 'editor_controller.dart';

/// Text to speech: the phone's own voice reads a text, and the result becomes a voice-over at the
/// playhead. Prefilled with the selected text or the caption on screen.
Future<void> showSpeechSheet(BuildContext context, EditorController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SpeechSheet(c: c),
  );
}

class SpeechSheet extends StatefulWidget {
  const SpeechSheet({super.key, required this.c});
  final EditorController c;

  @override
  State<SpeechSheet> createState() => _SpeechSheetState();
}

class _SpeechSheetState extends State<SpeechSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.c.textToSpeak,
  );
  String? _lang;
  double _rate = 1;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _error(AppL10n t, String? code) => switch (code) {
    'tts_unavailable' => t.ttsNoEngine,
    'tts_no_lang' => t.ttsNoLang,
    _ => t.ttsFailed,
  };

  Future<void> _make() async {
    final t = AppL10n.of(context);
    final m = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final lang = _lang ?? Localizations.localeOf(context).languageCode;
    final ok = await widget.c.addSpokenVoice(
      _text.text,
      lang: lang,
      rate: _rate,
    );
    if (!mounted) return;
    if (ok) {
      nav.pop();
      m.showSnackBar(SnackBar(content: Text(t.ttsDone)));
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final lang = _lang ?? Localizations.localeOf(context).languageCode;
    return AnimatedBuilder(
      animation: widget.c,
      builder: (context, _) {
        final busy = widget.c.speaking;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            Space.lg,
            0,
            Space.lg,
            Space.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.ttsTitle, style: tt.titleMedium),
              const SizedBox(height: Space.xs),
              Text(
                t.ttsHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: Space.md),
              Semantics(
                identifier: 'tts_text',
                child: TextField(
                  controller: _text,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: t.ttsField,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(t.ttsLanguage, style: tt.labelLarge),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final (code, label) in const [
                    ('vi', 'Tiếng Việt'),
                    ('en', 'English'),
                  ])
                    ChoiceChip(
                      key: ValueKey('tts_lang_$code'),
                      label: Text(label),
                      selected: lang == code,
                      onSelected: (_) => setState(() => _lang = code),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(t.ttsSpeed, style: tt.labelLarge),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final (v, label) in [
                    (0.8, t.ttsSlow),
                    (1.0, t.ttsNormal),
                    (1.25, t.ttsFast),
                  ])
                    ChoiceChip(
                      key: ValueKey('tts_rate_$v'),
                      label: Text(label),
                      selected: _rate == v,
                      onSelected: (_) => setState(() => _rate = v),
                    ),
                ],
              ),
              if (widget.c.speechError != null && !busy) ...[
                const SizedBox(height: Space.sm),
                Semantics(
                  identifier: 'tts_error',
                  liveRegion: true,
                  child: Text(
                    _error(t, widget.c.speechError),
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              ],
              const SizedBox(height: Space.md),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  identifier: 'tts_make',
                  child: FilledButton.icon(
                    onPressed: busy || _text.text.trim().isEmpty ? null : _make,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.record_voice_over_outlined),
                    label: Text(busy ? t.ttsWorking : t.ttsCreate),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
