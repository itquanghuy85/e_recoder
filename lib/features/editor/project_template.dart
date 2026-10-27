import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_project.dart';

/// A reusable "style" of an edit: how the picture looks, how the cuts join, the sound levels and the
/// text / shape overlays (placed relative to the START of the new video). It never carries footage.
class ProjectTemplate {
  const ProjectTemplate({
    required this.id,
    required this.name,
    this.look = PictureLook.identity,
    this.transition,
    this.segmentVolume = 1,
    this.texts = const [],
    this.shapes = const [],
    this.musicVolume,
    this.musicDuck = true,
  });

  final String id;
  final String name;
  final PictureLook look;

  /// Applied to every cut of the new video.
  final Transition? transition;
  final double segmentVolume;

  /// Overlays with times counted from the start of the output video.
  final List<TextItem> texts;
  final List<ShapeItem> shapes;
  final double? musicVolume;
  final bool musicDuck;

  /// Captures the style of [p]. Overlay times become output-timeline times so they can be replayed.
  factory ProjectTemplate.capture(String id, String name, EditProject p) {
    TextItem t(TextItem x) => x.copyWith(
      startMs: p.sourceToOut(x.startMs),
      endMs: p.sourceToOut(x.endMs),
    );
    ShapeItem sh(ShapeItem x) => x.copyWith(
      startMs: p.sourceToOut(x.startMs),
      endMs: p.sourceToOut(x.endMs),
    );
    final cuts = [
      for (var i = 1; i < p.segments.length; i++) p.segments[i].transition,
    ];
    return ProjectTemplate(
      id: id,
      name: name,
      look: p.look,
      transition: cuts.whereType<Transition>().firstOrNull,
      segmentVolume: p.segments.isEmpty ? 1 : p.segments.first.volume,
      texts: p.texts.map(t).toList(),
      shapes: p.shapes.map(sh).toList(),
      musicVolume: p.audioTracks
          .where((a) => a.kind == AudioKind.music)
          .firstOrNull
          ?.volume,
      musicDuck:
          p.audioTracks
              .where((a) => a.kind == AudioKind.music)
              .firstOrNull
              ?.duck ??
          true,
    );
  }

  /// Puts this style on [p]. The cuts and footage of [p] are untouched; overlays are clamped to its length.
  EditProject applyTo(EditProject p, {required String Function() newId}) {
    var out = p.copyWith(look: look);
    out = out.setAllTransitions(transition);
    if (segmentVolume != 1) {
      var segs = [...out.segments];
      for (var i = 0; i < segs.length; i++) {
        if (!segs[i].isStill) segs[i] = segs[i].copyWith(volume: segmentVolume);
      }
      out = out.copyWith(segments: segs);
    }
    final total = out.outDurationMs;
    int src(int outMs) => out.outToSource(outMs.clamp(0, total));
    for (final x in texts) {
      if (x.startMs >= total) continue;
      final s = src(x.startMs);
      final e = src(x.endMs);
      out = out.upsertText(
        x
            .copyWith(startMs: s, endMs: e > s + 300 ? e : s + 300)
            .withId(newId()),
      );
    }
    for (final x in shapes) {
      if (x.startMs >= total) continue;
      final s = src(x.startMs);
      final e = src(x.endMs);
      out = out.upsertShape(
        x
            .copyWith(startMs: s, endMs: e > s + 300 ? e : s + 300)
            .withId(newId()),
      );
    }
    // Music already in the project follows the template's level.
    if (musicVolume != null) {
      out = out.copyWith(
        audioTracks: [
          for (final a in out.audioTracks)
            a.kind == AudioKind.music
                ? a.copyWith(volume: musicVolume, duck: musicDuck)
                : a,
        ],
      );
    }
    return out;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'look': look.toJson(),
    if (transition != null) 'transition': transition!.toJson(),
    'segmentVolume': segmentVolume,
    'texts': texts.map((e) => e.toJson()).toList(),
    'shapes': shapes.map((e) => e.toJson()).toList(),
    'musicVolume': ?musicVolume,
    'musicDuck': musicDuck,
  };

  factory ProjectTemplate.fromJson(Map<String, dynamic> j) => ProjectTemplate(
    id: j['id'] as String,
    name: j['name'] as String,
    look: PictureLook.fromJson(j['look'] as Map<String, dynamic>?),
    transition: Transition.fromJson(j['transition']),
    segmentVolume: (j['segmentVolume'] as num?)?.toDouble() ?? 1,
    texts: ((j['texts'] as List?) ?? const [])
        .map((e) => TextItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    shapes: ((j['shapes'] as List?) ?? const [])
        .map((e) => ShapeItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    musicVolume: (j['musicVolume'] as num?)?.toDouble(),
    musicDuck: j['musicDuck'] as bool? ?? true,
  );
}

extension on TextItem {
  TextItem withId(String id) => TextItem(
    id: id,
    text: text,
    color: color,
    sizeU: sizeU,
    x: x,
    y: y,
    startMs: startMs,
    endMs: endMs,
    bold: bold,
    font: font,
    outline: outline,
    box: box,
    shadow: shadow,
    align: align,
    rotation: rotation,
    opacity: opacity,
    motion: motion,
  );
}

extension on ShapeItem {
  ShapeItem withId(String id) => ShapeItem(
    id: id,
    kind: kind,
    x: x,
    y: y,
    w: w,
    h: h,
    color: color,
    strokeU: strokeU,
    filled: filled,
    text: text,
    textColor: textColor,
    tailX: tailX,
    tailY: tailY,
    rotation: rotation,
    opacity: opacity,
    startMs: startMs,
    endMs: endMs,
    motion: motion,
  );
}

/// Where templates are kept (on this phone only).
abstract class TemplateStore {
  Future<List<ProjectTemplate>> list();
  Future<void> save(ProjectTemplate t);
  Future<void> delete(String id);
}

final templateStoreProvider = Provider<TemplateStore>(
  (ref) => PrefsTemplateStore(),
);

class PrefsTemplateStore implements TemplateStore {
  static const _key = 'editor_templates_v1';

  Future<List<ProjectTemplate>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          ProjectTemplate.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<ProjectTemplate> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<ProjectTemplate>> list() => _read();

  @override
  Future<void> save(ProjectTemplate t) async {
    final all = await _read();
    final i = all.indexWhere((e) => e.id == t.id);
    if (i < 0) {
      all.add(t);
    } else {
      all[i] = t;
    }
    await _write(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = await _read()
      ..removeWhere((e) => e.id == id);
    await _write(all);
  }
}

class MemoryTemplateStore implements TemplateStore {
  final Map<String, ProjectTemplate> data = {};

  @override
  Future<List<ProjectTemplate>> list() async => data.values.toList();
  @override
  Future<void> save(ProjectTemplate t) async => data[t.id] = t;
  @override
  Future<void> delete(String id) async => data.remove(id);
}
