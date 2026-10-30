import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../marker/marker_inspector.dart';
import '../marker/marker_spec.dart';
import 'editor_controller.dart';
import 'editor_pro_tools.dart';
import 'auto_caption_sheet.dart';
import 'caption_panel.dart';
import 'srt.dart';
import 'edit_project.dart';
import 'touch_log.dart' show InputMode;

enum EditorTool {
  cut,
  speed,
  transition,
  audio,
  picture,
  marker,
  text,
  overlay,
  cover,
  zoom,
  auto,
}

String toolLabel(AppL10n t, EditorTool e) => switch (e) {
  EditorTool.cut => t.toolCut,
  EditorTool.speed => t.toolSpeed,
  EditorTool.transition => t.toolTransition,
  EditorTool.audio => t.toolAudio,
  EditorTool.picture => t.toolPicture,
  EditorTool.overlay => t.toolOverlay,
  EditorTool.marker => t.toolMarker,
  EditorTool.text => t.toolText,
  EditorTool.cover => t.toolCover,
  EditorTool.zoom => t.toolZoom,
  EditorTool.auto => t.toolAuto,
};

IconData toolIcon(EditorTool e) => switch (e) {
  EditorTool.cut => Icons.content_cut,
  EditorTool.speed => Icons.speed,
  EditorTool.transition => Icons.swap_horiz,
  EditorTool.audio => Icons.volume_up_outlined,
  EditorTool.picture => Icons.tune,
  EditorTool.overlay => Icons.layers_outlined,
  EditorTool.marker => Icons.touch_app_outlined,
  EditorTool.text => Icons.title,
  EditorTool.cover => Icons.visibility_off_outlined,
  EditorTool.zoom => Icons.zoom_in,
  EditorTool.auto => Icons.auto_awesome,
};

/// Tool tabs + the panel of the active tool. Each panel is either "add" (nothing selected) or
/// the inspector of the selected clip.
class EditorTools extends StatelessWidget {
  const EditorTools({
    super.key,
    required this.controller,
    required this.tool,
    required this.onTool,
    required this.newMarkerColor,
    required this.newMarkerThickness,
    required this.video,
    this.onRecordVoice,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  /// When true only a slim handle is shown, so the preview gets the room.
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;
  final VideoPlayerController video;

  /// Starts a voice-over (microphone, recording and playback are the screen's business).
  final Future<void> Function()? onRecordVoice;
  final EditorController controller;
  final EditorTool tool;
  final ValueChanged<EditorTool> onTool;
  final Color newMarkerColor;
  final double newMarkerThickness;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'tools_toggle',
          button: true,
          label: collapsed ? t.toolsShow : t.toolsHide,
          child: InkWell(
            onTap: onToggleCollapsed,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(toolIcon(tool), size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: Space.sm),
                  Text(
                    collapsed
                        ? '${toolLabel(t, tool)} · ${t.toolsShow}'
                        : t.toolsHide,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Icon(
                    collapsed ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!collapsed) ...[
          // Every tool is one tap away: two rows, no hidden sideways scrolling.
          for (final row in [
            EditorTool.values.take(6).toList(),
            EditorTool.values.skip(6).toList(),
          ])
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final e in row)
                    Expanded(
                      child: Semantics(
                        identifier: 'tool_${e.name}',
                        button: true,
                        selected: tool == e,
                        child: InkWell(
                          onTap: () => onTool(e),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: tool == e
                                      ? cs.tertiaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  toolIcon(e),
                                  size: 18,
                                  color: tool == e
                                      ? cs.onTertiaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    toolLabel(t, e),
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10,
                                          color: tool == e
                                              ? cs.onSurface
                                              : cs.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // keep the last row's tabs the same width as the first row's
                  for (var i = row.length; i < 6; i++) const Spacer(),
                ],
              ),
            ),
          const Divider(),
          ConstrainedBox(
            constraints: BoxConstraints(
              // A fifth of the screen: the preview above gets the rest (the panel scrolls).
              maxHeight: (MediaQuery.sizeOf(context).height * 0.19).clamp(
                140.0,
                210.0,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                Space.sm,
              ),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => switch (tool) {
                  EditorTool.cut => _CutPanel(c: controller),
                  EditorTool.speed => _SpeedPanel(c: controller),
                  EditorTool.transition => _TransitionPanel(c: controller),
                  EditorTool.audio => _AudioPanel(
                    c: controller,
                    onRecordVoice: onRecordVoice,
                  ),
                  EditorTool.picture => PicturePanel(
                    c: controller,
                    video: video,
                  ),
                  EditorTool.overlay => OverlayPanel(c: controller),
                  EditorTool.marker => _MarkerPanel(
                    c: controller,
                    color: newMarkerColor,
                    thickness: newMarkerThickness,
                  ),
                  EditorTool.text => _TextPanel(c: controller),
                  EditorTool.cover => _CoverPanel(c: controller),
                  EditorTool.zoom => _ZoomPanel(c: controller),
                  EditorTool.auto => _AutoPanel(c: controller),
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---- shared bits ------------------------------------------------------------------------------

Widget editorSlider({
  required BuildContext context,
  required EditorController c,
  required String label,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
  required String Function(double) fmt,
  String? id,
}) {
  final tt = Theme.of(context).textTheme;
  return Row(
    children: [
      SizedBox(width: 76, child: Text(label, style: tt.labelLarge)),
      Expanded(
        child: Semantics(
          identifier: id,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChangeStart: (_) => c.beginGesture(),
            onChanged: onChanged,
            onChangeEnd: (_) => c.flush(),
          ),
        ),
      ),
      SizedBox(
        width: 52,
        child: Text(fmt(value), style: tt.bodySmall, textAlign: TextAlign.end),
      ),
    ],
  );
}

String editorSecs(double ms) =>
    '${(ms / 1000).toStringAsFixed(1).replaceAll('.', ',')}s';

String editorSecs2(double ms) =>
    '${(ms / 1000).toStringAsFixed(2).replaceAll('.', ',')}s';

/// Title row of an inspector with the delete action always in reach (the panel scrolls).
Widget inspectorHeader(BuildContext context, EditorController c, String title) {
  final t = AppL10n.of(context);
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      Semantics(
        identifier: 'overlay_delete',
        child: IconButton(
          tooltip: t.menuDelete,
          color: cs.error,
          onPressed: c.deleteSelectedOverlay,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    ],
  );
}

// ---- cut ----------------------------------------------------------------------------------------

class _CutPanel extends StatelessWidget {
  const _CutPanel({required this.c});
  final EditorController c;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = c.project;
    final many = c.activeSegments.length;
    final canDelete = many < p.segments.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            Semantics(
              identifier: 'cut_split',
              child: FilledButton.tonalIcon(
                onPressed: c.split,
                icon: const Icon(Icons.vertical_split),
                label: Text(t.splitHere),
              ),
            ),
            Semantics(
              identifier: 'cut_delete',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error),
                ),
                onPressed: canDelete ? c.deleteSelectedSegment : null,
                icon: const Icon(Icons.delete_outline),
                label: Text(t.deleteSegment),
              ),
            ),
            Semantics(
              identifier: 'cut_blank',
              child: OutlinedButton.icon(
                onPressed: c.blankSelectedSegment,
                icon: const Icon(Icons.crop_square),
                label: Text(t.editBlank),
              ),
            ),
            Semantics(
              identifier: 'cut_duplicate',
              child: OutlinedButton.icon(
                onPressed: c.duplicateSelectedSegment,
                icon: const Icon(Icons.copy_all_outlined),
                label: Text(t.editDuplicate),
              ),
            ),
            Semantics(
              identifier: 'cut_freeze',
              child: OutlinedButton.icon(
                onPressed: c.freezeAtPlayhead,
                icon: const Icon(Icons.ac_unit),
                label: Text(t.editFreeze),
              ),
            ),
            IconButton.outlined(
              tooltip: t.moveLeft,
              onPressed: c.selectedSegment > 0
                  ? () => c.moveSelectedSegment(-1)
                  : null,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton.outlined(
              tooltip: t.moveRight,
              onPressed: c.selectedSegment < p.segments.length - 1
                  ? () => c.moveSelectedSegment(1)
                  : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            Semantics(
              identifier: 'frame_back',
              child: IconButton.outlined(
                tooltip: t.frameBack,
                onPressed: () => c.stepFrame(-1),
                icon: const Icon(Icons.skip_previous),
              ),
            ),
            Semantics(
              identifier: 'frame_fwd',
              child: IconButton.outlined(
                tooltip: t.frameForward,
                onPressed: () => c.stepFrame(1),
                icon: const Icon(Icons.skip_next),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Semantics(
          identifier: 'cut_multi',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t.editMultiSelect, style: tt.titleSmall),
            subtitle: Text(
              c.multiSelect ? t.editMultiHint : t.reorderHint,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            value: c.multiSelect,
            onChanged: c.setMultiSelect,
          ),
        ),
        Text(
          t.trimHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ---- speed --------------------------------------------------------------------------------------

String _fmtX(double s) =>
    '${s == s.roundToDouble() ? s.toInt() : s.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',')}×';

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel({required this.c});
  final EditorController c;

  static const presets = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0];

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = c.project;
    final seg = p.segments[c.selectedSegment.clamp(0, p.segments.length - 1)];
    if (seg.isStill) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.speedStillHint, style: tt.bodyMedium),
          const SizedBox(height: Space.md),
          editorSlider(
            context: context,
            c: c,
            label: t.freezeLength,
            value: seg.freezeMs.toDouble(),
            min: 200,
            max: 10000,
            onChanged: (v) => c.setFreezeMsLive(v.round()),
            fmt: (v) => editorSecs(v),
            id: 'freeze_length',
          ),
        ],
      );
    }
    // Logarithmic feel for the free slider: 0.1x .. 8x.
    double toSlider(double v) =>
        (math.log(v / 0.1) / math.log(80)).clamp(0.0, 1.0);
    double fromSlider(double s) => 0.1 * math.pow(80, s);
    double snap(double v) => (v * 20).round() / 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.segmentSpeed, style: tt.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final s in presets)
              Semantics(
                identifier: 'speed_${s.toString().replaceAll('.', '_')}',
                child: ChoiceChip(
                  label: Text(_fmtX(s)),
                  selected: !seg.isRamp && seg.speed == s,
                  onSelected: (_) => c.setSpeed(s),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        if (!seg.isRamp)
          editorSlider(
            context: context,
            c: c,
            label: t.speedFree,
            value: toSlider(seg.speed),
            min: 0,
            max: 1,
            onChanged: (v) => c.setSpeedLive(snap(fromSlider(v))),
            fmt: (v) => _fmtX(snap(fromSlider(v))),
            id: 'speed_free',
          ),
        Semantics(
          identifier: 'speed_ramp',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t.speedRamp, style: tt.titleSmall),
            value: seg.isRamp,
            onChanged: (on) {
              if (on) {
                c.setSpeedRamp(seg.speed, (seg.speed * 3).clamp(0.1, 8.0));
              } else {
                c.setSpeed(seg.speed);
              }
            },
          ),
        ),
        if (seg.isRamp) ...[
          editorSlider(
            context: context,
            c: c,
            label: t.speedRampFrom,
            value: toSlider(seg.speed),
            min: 0,
            max: 1,
            onChanged: (v) =>
                c.setSpeedRampLive(snap(fromSlider(v)), seg.speedEnd!),
            fmt: (v) => _fmtX(snap(fromSlider(v))),
            id: 'ramp_from',
          ),
          editorSlider(
            context: context,
            c: c,
            label: t.speedRampTo,
            value: toSlider(seg.speedEnd!),
            min: 0,
            max: 1,
            onChanged: (v) =>
                c.setSpeedRampLive(seg.speed, snap(fromSlider(v))),
            fmt: (v) => _fmtX(snap(fromSlider(v))),
            id: 'ramp_to',
          ),
        ],
        Semantics(
          identifier: 'speed_mute_fast',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t.speedMuteFast, style: tt.titleSmall),
            value: c.project.muteFast,
            onChanged: c.setMuteFast,
          ),
        ),
        Semantics(
          identifier: 'speed_reverse',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t.speedReverse, style: tt.titleSmall),
            subtitle: Text(
              t.speedReverseHint,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            value: seg.reverse,
            onChanged: c.reverseAllowed(seg) ? c.setReverse : null,
          ),
        ),
      ],
    );
  }
}

// ---- transitions --------------------------------------------------------------------------------

String transitionLabel(AppL10n t, TransitionKind k) => switch (k) {
  TransitionKind.none => t.transNone,
  TransitionKind.dipBlack => t.transDipBlack,
  TransitionKind.dipWhite => t.transDipWhite,
  TransitionKind.slideLeft => t.transSlideLeft,
  TransitionKind.slideRight => t.transSlideRight,
  TransitionKind.slideUp => t.transSlideUp,
  TransitionKind.slideDown => t.transSlideDown,
  TransitionKind.zoom => t.transZoom,
};

class _TransitionPanel extends StatelessWidget {
  const _TransitionPanel({required this.c});
  final EditorController c;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = c.project;
    final i = c.selectedSegment.clamp(0, p.segments.length - 1);
    if (p.segments.length < 2) {
      return Text(t.transFirstHint, style: tt.bodyMedium);
    }
    final seg = p.segments[i];
    final cur = seg.transition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (i == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text(
              t.transFirstHint,
              style: tt.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final k in TransitionKind.values)
              Semantics(
                identifier: 'trans_${k.name}',
                child: ChoiceChip(
                  label: Text(transitionLabel(t, k)),
                  selected: (cur?.kind ?? TransitionKind.none) == k,
                  onSelected: i == 0
                      ? null
                      : (_) => c.setTransition(
                          k == TransitionKind.none
                              ? null
                              : Transition(k, cur?.ms ?? 600),
                        ),
                ),
              ),
          ],
        ),
        if (cur != null)
          editorSlider(
            context: context,
            c: c,
            label: t.transLength,
            value: cur.ms.toDouble(),
            min: Transition.minMs.toDouble(),
            max: Transition.maxMs.toDouble(),
            onChanged: (v) =>
                c.setTransitionLive(Transition(cur.kind, v.round())),
            fmt: (v) => editorSecs(v),
            id: 'trans_length',
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                t.transHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (cur != null)
              Semantics(
                identifier: 'trans_all',
                child: TextButton(
                  onPressed: () => c.setAllTransitions(cur),
                  child: Text(t.transApplyAll),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---- audio --------------------------------------------------------------------------------------

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({required this.c, this.onRecordVoice});
  final EditorController c;
  final Future<void> Function()? onRecordVoice;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = c.project;
    final seg = p.segments[c.selectedSegment.clamp(0, p.segments.length - 1)];
    final Widget segment = seg.isStill
        ? Text(t.audioStillHint, style: tt.bodyMedium)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                identifier: 'audio_mute',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(t.audioMute, style: tt.titleSmall),
                  value: seg.volume == 0,
                  onChanged: (on) => c.setSegmentAudio(volume: on ? 0 : 1),
                ),
              ),
              editorSlider(
                context: context,
                c: c,
                label: t.audioVolume,
                value: seg.volume,
                min: 0,
                max: 2,
                onChanged: (v) =>
                    c.setSegmentAudioLive(volume: (v * 20).round() / 20),
                fmt: (v) => '${(v * 100).round()}%',
                id: 'audio_volume',
              ),
              editorSlider(
                context: context,
                c: c,
                label: t.audioFadeIn,
                value: seg.fadeInMs.toDouble(),
                min: 0,
                max: 3000,
                onChanged: (v) => c.setSegmentAudioLive(fadeInMs: v.round()),
                fmt: editorSecs,
                id: 'audio_fade_in',
              ),
              editorSlider(
                context: context,
                c: c,
                label: t.audioFadeOut,
                value: seg.fadeOutMs.toDouble(),
                min: 0,
                max: 3000,
                onChanged: (v) => c.setSegmentAudioLive(fadeOutMs: v.round()),
                fmt: editorSecs,
                id: 'audio_fade_out',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  identifier: 'audio_normalize',
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await c.normalizeSelectedVolume();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? t.audioNormalized : t.audioNoSound,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.graphic_eq),
                    label: Text(t.audioNormalize),
                  ),
                ),
              ),
              Text(
                t.speedReverseHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        segment,
        AudioTracksSection(c: c, onRecordVoice: onRecordVoice),
      ],
    );
  }
}

// ---- markers --------------------------------------------------------------------------------------

class _MarkerPanel extends StatelessWidget {
  const _MarkerPanel({
    required this.c,
    required this.color,
    required this.thickness,
  });
  final EditorController c;
  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sel = c.project.markers
        .where((m) => m.id == c.selectedId)
        .firstOrNull;
    if (sel == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final m in MarkerType.values)
                Semantics(
                  identifier: 'add_marker_${m.name}',
                  button: true,
                  child: ActionChip(
                    avatar: Icon(markerTypeIcon(m), size: 18),
                    label: Text(markerTypeLabel(t, m)),
                    onPressed: () =>
                        c.addMarker(m, color: color, thickness: thickness),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            t.markerAddHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorHeader(context, c, t.toolMarker),
        MarkerInspector(
          spec: sel.spec,
          onChanged: (s) => c.updateMarker(sel.copyWith(spec: s)),
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.clipHold,
          value: sel.holdMs.toDouble(),
          min: 300,
          max: 10000,
          onChanged: (v) =>
              c.updateMarker(sel.copyWith(holdMs: v.round()), record: false),
          fmt: editorSecs,
        ),
      ],
    );
  }
}

// ---- text -------------------------------------------------------------------------------------------

class _TextPanel extends StatefulWidget {
  const _TextPanel({required this.c});
  final EditorController c;

  @override
  State<_TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<_TextPanel> {
  final _ctl = TextEditingController();
  String? _bound;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final c = widget.c;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sel = c.project.texts.where((m) => m.id == c.selectedId).firstOrNull;
    if (sel == null) {
      _bound = null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: 'add_text',
            child: FilledButton.tonalIcon(
              onPressed: c.addText,
              icon: const Icon(Icons.add),
              label: Text(t.textAdd),
            ),
          ),
          const SizedBox(height: Space.sm),
          Semantics(
            identifier: 'caption_panel',
            child: OutlinedButton.icon(
              onPressed: () => showCaptionPanel(context, c),
              icon: const Icon(Icons.closed_caption_outlined),
              label: Text(t.presetSubtitle),
            ),
          ),
          const SizedBox(height: Space.sm),
          Semantics(
            identifier: 'import_srt',
            child: OutlinedButton.icon(
              onPressed: () => importSubtitleFile(context, c),
              icon: const Icon(Icons.subtitles_outlined),
              label: Text(t.subtitlesImport),
            ),
          ),
          const SizedBox(height: Space.sm),
          Semantics(
            identifier: 'auto_captions',
            child: OutlinedButton.icon(
              onPressed: () => showAutoCaptions(context, c),
              icon: const Icon(Icons.auto_awesome),
              label: Text(t.captionsAutoTitle),
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            t.textHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    if (_bound != sel.id) {
      _bound = sel.id;
      _ctl.text = sel.text;
    }
    if (sel.cues != null) {
      // A caption's text, look and timing live in the caption panel; the plain-text controls below
      // would not change it.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inspectorHeader(context, c, t.presetSubtitle),
          Semantics(
            identifier: 'caption_panel',
            child: FilledButton.tonalIcon(
              onPressed: () => showCaptionPanel(context, c),
              icon: const Icon(Icons.closed_caption_outlined),
              label: Text(t.presetSubtitle),
            ),
          ),
        ],
      );
    }
    final len = (sel.endMs - sel.startMs).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorHeader(context, c, t.toolText),
        Semantics(
          identifier: 'text_field',
          child: TextField(
            controller: _ctl,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t.textField,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) =>
                c.updateText(sel.copyWith(text: v), record: false),
            onEditingComplete: c.flush,
          ),
        ),
        const SizedBox(height: Space.sm),
        TextPresetRow(c: c, item: sel),
        const SizedBox(height: Space.sm),
        Semantics(
          identifier: 'caption_panel',
          child: OutlinedButton.icon(
            onPressed: () => showCaptionPanel(context, c),
            icon: const Icon(Icons.closed_caption_outlined),
            label: Text(t.presetSubtitle),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(t.markerColor, style: tt.titleSmall),
        MarkerColorRow(
          selected: sel.color,
          onChanged: (i) =>
              c.updateText(sel.copyWith(color: MarkerPalette.colors[i])),
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.textSize,
          value: sel.sizeU,
          min: 10,
          max: 60,
          onChanged: (v) => c.updateText(sel.copyWith(sizeU: v), record: false),
          fmt: (v) => v.round().toString(),
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.clipLength,
          value: len,
          min: 500,
          max: 15000,
          onChanged: (v) => c.updateText(
            sel.copyWith(endMs: sel.startMs + v.round()),
            record: false,
          ),
          fmt: editorSecs,
        ),
        TextStyleControls(c: c, item: sel),
      ],
    );
  }
}

/// Picks a .srt file and turns every cue into a caption (one undo step).
Future<void> importSubtitleFile(
  BuildContext context,
  EditorController c,
) async {
  final t = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await c.native.pickMedia('file');
  if (picked == null) return;
  var n = 0;
  try {
    final text = await File(picked.path).readAsString();
    n = c.importSubtitles(parseSrt(text));
  } catch (_) {}
  messenger.showSnackBar(
    SnackBar(content: Text(n > 0 ? t.subtitlesImported(n) : t.subtitlesNone)),
  );
}

IconData coverStyleIcon(CoverStyle s) => switch (s) {
  CoverStyle.solid => Icons.crop_square,
  CoverStyle.blur => Icons.blur_on,
  CoverStyle.mosaic => Icons.grid_view,
  CoverStyle.spotlight => Icons.center_focus_strong_outlined,
};

String coverStyleLabel(AppL10n t, CoverStyle s) => switch (s) {
  CoverStyle.solid => t.coverStyleSolid,
  CoverStyle.blur => t.coverStyleBlur,
  CoverStyle.mosaic => t.coverStyleMosaic,
  CoverStyle.spotlight => t.coverStyleSpotlight,
};

// ---- cover ------------------------------------------------------------------------------------------

class _CoverPanel extends StatelessWidget {
  const _CoverPanel({required this.c});
  final EditorController c;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sel = c.project.covers.where((m) => m.id == c.selectedId).firstOrNull;
    if (sel == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.coverAdd, style: tt.titleSmall),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (final s in CoverStyle.values)
                Semantics(
                  identifier: s == CoverStyle.solid
                      ? 'add_cover'
                      : 'add_cover_${s.name}',
                  child: ActionChip(
                    avatar: Icon(coverStyleIcon(s), size: 18),
                    label: Text(coverStyleLabel(t, s)),
                    onPressed: () => c.addCover(s),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            t.coverHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    final len = (sel.endMs - sel.startMs).toDouble();
    final atEnd = c.coverEditEnd && sel.end != null;
    final rect = sel.editRect(atEnd);
    final w = rect.width;
    final h = rect.height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorHeader(context, c, t.toolCover),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CoverStyle.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
            itemBuilder: (_, i) {
              final s = CoverStyle.values[i];
              return Semantics(
                identifier: 'cover_style_${s.name}',
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(coverStyleIcon(s), size: 16),
                  label: Text(coverStyleLabel(t, s)),
                  selected: sel.style == s,
                  onSelected: (_) => c.updateCover(sel.copyWith(style: s)),
                ),
              );
            },
          ),
        ),
        Semantics(
          identifier: 'cover_move',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              t.coverMove,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: sel.end != null,
            onChanged: (on) {
              c.setCoverEditEnd(on);
              c.updateCover(
                sel.copyWith(
                  // Start the end point a little lower so the glide is visible straight away.
                  end: on
                      ? sel.startRect.shift(
                          Offset(0, math.min(0.15, 1 - sel.y1)),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        if (sel.end != null)
          Wrap(
            spacing: Space.xs,
            children: [
              Semantics(
                identifier: 'cover_edit_start',
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(t.coverPointStart),
                  selected: !c.coverEditEnd,
                  onSelected: (_) => c.setCoverEditEnd(false),
                ),
              ),
              Semantics(
                identifier: 'cover_edit_end',
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(t.coverPointEnd),
                  selected: c.coverEditEnd,
                  onSelected: (_) => c.setCoverEditEnd(true),
                ),
              ),
            ],
          ),
        if (sel.style != CoverStyle.solid)
          editorSlider(
            context: context,
            c: c,
            id: 'cover_strength',
            label: t.coverStrength,
            value: sel.strength,
            min: 0,
            max: 1,
            onChanged: (v) =>
                c.updateCover(sel.copyWith(strength: v), record: false),
            fmt: (v) => '${(v * 100).round()}%',
          ),
        editorSlider(
          context: context,
          c: c,
          label: t.coverWidth,
          value: w,
          min: 0.05,
          max: 1,
          onChanged: (v) {
            final x0 = rect.left.clamp(0.0, 1.0 - v);
            c.updateCover(
              sel.withRect(
                Rect.fromLTWH(x0, rect.top, v, rect.height),
                atEnd: atEnd,
              ),
              record: false,
            );
          },
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.coverHeight,
          value: h,
          min: 0.02,
          max: 1,
          onChanged: (v) {
            final y0 = rect.top.clamp(0.0, 1.0 - v);
            c.updateCover(
              sel.withRect(
                Rect.fromLTWH(rect.left, y0, rect.width, v),
                atEnd: atEnd,
              ),
              record: false,
            );
          },
          fmt: (v) => '${(v * 100).round()}%',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.clipLength,
          value: len,
          min: 500,
          max: 30000,
          onChanged: (v) => c.updateCover(
            sel.copyWith(endMs: sel.startMs + v.round()),
            record: false,
          ),
          fmt: editorSecs,
        ),
        if (sel.end != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              t.coverMoveHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

// ---- zoom -------------------------------------------------------------------------------------------

class _ZoomPanel extends StatelessWidget {
  const _ZoomPanel({required this.c});
  final EditorController c;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sel = c.project.zooms.where((m) => m.id == c.selectedId).firstOrNull;
    if (sel == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: 'add_zoom',
            child: FilledButton.tonalIcon(
              onPressed: c.addZoom,
              icon: const Icon(Icons.add),
              label: Text(t.zoomAdd),
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            t.zoomHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    final len = (sel.endMs - sel.startMs).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorHeader(context, c, t.toolZoom),
        editorSlider(
          context: context,
          c: c,
          label: t.zoomScale,
          value: sel.scale,
          min: 1.3,
          max: 4,
          onChanged: (v) => c.updateZoom(sel.copyWith(scale: v), record: false),
          fmt: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}×',
        ),
        editorSlider(
          context: context,
          c: c,
          label: t.clipLength,
          value: len,
          min: 800,
          max: 15000,
          onChanged: (v) => c.updateZoom(
            sel.copyWith(endMs: sel.startMs + v.round()),
            record: false,
          ),
          fmt: editorSecs,
        ),
        editorSlider(
          context: context,
          c: c,
          id: 'zoom_in_ms',
          label: t.zoomIn,
          value: sel.inMs.toDouble(),
          min: 0,
          max: 2000,
          onChanged: (v) =>
              c.updateZoom(sel.copyWith(inMs: v.round()), record: false),
          fmt: editorSecs2,
        ),
        editorSlider(
          context: context,
          c: c,
          id: 'zoom_out_ms',
          label: t.zoomOut,
          value: sel.outMs.toDouble(),
          min: 0,
          max: 2000,
          onChanged: (v) =>
              c.updateZoom(sel.copyWith(outMs: v.round()), record: false),
          fmt: editorSecs2,
        ),
        const SizedBox(height: Space.sm),
        Text(
          t.zoomDragHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ---- auto direct ------------------------------------------------------------------------------

class _AutoPanel extends StatelessWidget {
  const _AutoPanel({required this.c});
  final EditorController c;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final o = c.directorOptions;
    final last = c.lastDirect;
    Widget option(String id, String label, bool value, ValueChanged<bool> on) =>
        Semantics(
          identifier: id,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(label, style: tt.bodyMedium),
            value: value,
            onChanged: c.directing ? null : (v) => on(v ?? false),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.autoHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (last != null && !c.directing) ...[
          Semantics(
            identifier: 'auto_result',
            liveRegion: true,
            child: Text(
              last.zooms <= 0 && last.idle <= 0 && last.steps <= 0
                  ? t.autoNothing
                  : t.autoDone(last.zooms, last.steps, last.idle),
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
        const SizedBox(height: Space.sm),
        Semantics(
          identifier: 'auto_run',
          child: FilledButton.icon(
            onPressed: c.directing ? null : c.directAuto,
            icon: c.directing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(c.directing ? t.autoRunning : t.autoRun),
          ),
        ),
        option(
          'auto_zoom',
          t.autoZoomOpt,
          o.zoom,
          (v) => c.setDirectorOptions(o.copyWith(zoom: v)),
        ),
        option(
          'auto_number',
          t.autoNumberOpt,
          o.number,
          (v) => c.setDirectorOptions(o.copyWith(number: v)),
        ),
        option(
          'auto_idle',
          t.autoIdleOpt,
          o.idle,
          (v) => c.setDirectorOptions(o.copyWith(idle: v)),
        ),
        option(
          'auto_step_label',
          t.autoStepLabels,
          o.stepLabel != null,
          (v) => c.setDirectorOptions(
            o.copyWith(stepLabel: v ? t.stepLabelPrefix : null),
          ),
        ),
        const Divider(),
        Semantics(
          identifier: 'auto_touches_run',
          child: OutlinedButton.icon(
            onPressed: c.directing
                ? null
                : () => c.directFromTouches(
                    options: o.copyWith(
                      typingLabel: t.typingLabel,
                      typedLabel: t.typedLabel,
                    ),
                    stepPrefix: t.stepLabelPrefix,
                  ),
            icon: const Icon(Icons.touch_app),
            label: Text(c.directing ? t.autoFromTouchesRunning : t.autoFromTouches),
          ),
        ),
        if (c.lastTouches != null && !c.directing)
          Semantics(
            identifier: 'auto_touches_result',
            liveRegion: true,
            child: Text(
              c.lastTouches!.taps + c.lastTouches!.typing == 0
                  ? t.autoTouchesNone
                  : '${t.autoTouchesDone(c.lastTouches!.taps, c.lastTouches!.typing)}'
                        '${c.lastTouches!.placed ? '' : ' ${t.autoTouchesNoPlace}'}',
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
        editorSlider(
          context: context,
          c: c,
          id: 'auto_pause',
          label: t.pauseTitle,
          value: o.pauseMs.toDouble(),
          min: 0,
          max: 1500,
          onChanged: (v) => c.setDirectorOptions(o.copyWith(pauseMs: v.round())),
          fmt: editorSecs2,
        ),
        editorSlider(
          context: context,
          c: c,
          id: 'auto_pause_zoom',
          label: t.pauseZoomTitle,
          value: o.pauseZoom,
          min: 1,
          max: 1.5,
          onChanged: (v) => c.setDirectorOptions(
            o.copyWith(pauseZoom: v < 1.1 ? 1.0 : v.clamp(1.2, 1.5)),
          ),
          fmt: (v) => v < 1.1 ? '—' : '${v.toStringAsFixed(1).replaceAll('.', ',')}×',
        ),
        Text(t.inputModeTitle, style: tt.labelLarge),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final (m, label) in [
              (InputMode.merge, t.inputModeMerge),
              (InputMode.perKey, t.inputModePerKey),
              (InputMode.skip, t.inputModeSkip),
            ])
              Semantics(
                identifier: 'auto_input_${m.name}',
                child: ChoiceChip(
                  label: Text(label),
                  selected: o.inputMode == m,
                  onSelected: c.directing
                      ? null
                      : (_) => c.setDirectorOptions(o.copyWith(inputMode: m)),
                ),
              ),
          ],
        ),
        Text(
          t.pauseHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (c.project.segments.any((s) => s.isStill))
          TextButton.icon(
            onPressed: c.seekToFirstFreeze,
            icon: const Icon(Icons.play_circle_outline),
            label: Text(t.autoPreviewPause),
          ),
        if (o.zoom) ...[
          Text(t.zoomAutoTuning, style: tt.labelLarge),
          editorSlider(
            context: context,
            c: c,
            id: 'auto_zoom_scale',
            label: t.zoomScale,
            value: o.zoomScale,
            min: 1.2,
            max: 4,
            onChanged: (v) => c.setDirectorOptions(o.copyWith(zoomScale: v)),
            fmt: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}×',
          ),
          editorSlider(
            context: context,
            c: c,
            id: 'auto_zoom_ramp',
            label: t.zoomIn,
            value: o.zoomRampMs.toDouble(),
            min: 100,
            max: 2000,
            onChanged: (v) =>
                c.setDirectorOptions(o.copyWith(zoomRampMs: v.round())),
            fmt: editorSecs2,
          ),
          editorSlider(
            context: context,
            c: c,
            id: 'auto_zoom_hold',
            label: t.zoomHold,
            value: o.zoomHoldMs.toDouble(),
            min: 0,
            max: 5000,
            onChanged: (v) =>
                c.setDirectorOptions(o.copyWith(zoomHoldMs: v.round())),
            fmt: editorSecs,
          ),
          Text(
            t.zoomTimingHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
