import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../marker/marker_settings.dart';
import '../record/rec_settings.dart';

/// What the person wants to do with the recorder. Picked once on the first run; each choice is a set of
/// ready settings, so nobody has to know the words "clean recording" or "touch source". The index is
/// what is saved: new values only go at the end.
enum Purpose { tutorial, game, plain }

/// The marker settings a [Purpose] stands for. Pure, so it is unit tested: everything not named here
/// (colour, mark kind, timings) stays as the person had it.
MarkerSettings applyPurposeToMarkers(
  Purpose p,
  MarkerSettings m,
) => switch (p) {
  // Clean recording, listen to every tap, mark each one and zoom in on it afterwards.
  Purpose.tutorial => m.copyWith(
    mode: MarkMode.clean,
    touchSource: TouchSource.auto,
    autoNumber: true,
    autoZoom: true,
  ),
  // Marks drawn by hand while recording (the little dot), no automatic zoom.
  Purpose.game => m.copyWith(
    mode: MarkMode.dot,
    touchSource: TouchSource.off,
    autoNumber: true,
    autoZoom: false,
  ),
  // Everything off: a plain recording.
  Purpose.plain => m.copyWith(
    mode: MarkMode.dot,
    touchSource: TouchSource.off,
    autoNumber: false,
    autoZoom: false,
  ),
};

/// The settings every purpose keeps a copy of: the ones the recorder and the automatic edit read. They
/// stay where they always were (the whole app reads them there); a purpose only swaps them in and out.
const profileKeys = [
  'rec.resolution',
  'rec.fps',
  'rec.quality',
  'rec.audio',
  'rec.countdown',
  'rec.floatingBar',
  'marker.tool',
  'marker.color',
  'marker.thickness',
  'marker.hold',
  'marker.autoExit',
  'marker.exitDelay',
  'marker.mode',
  'marker.corner',
  'marker.armShake',
  'marker.autoZoom',
  'marker.autoNumber',
  'marker.zoomScale',
  'marker.zoomRamp',
  'marker.zoomHold',
  'marker.touchSourceV2',
  'marker.pause',
  'marker.pauseZoom',
  'marker.inputMode',
  'marker.autoType',
];

/// Where the copy of [p]'s settings is saved (a JSON map of [profileKeys] that were set).
String profileKey(Purpose p) => 'purpose.profile.${p.name}';

/// Each purpose remembers its own settings. The ones in use are always those of the chosen purpose:
/// changing purpose saves them as the old purpose's copy and puts the new purpose's copy in place. A
/// purpose used for the first time starts from the settings in use, with its own ready settings on top.
class PurposeNotifier extends Notifier<Purpose> {
  static const key = 'purpose';

  @override
  Purpose build() {
    final i = ref.read(settingsStoreProvider).getInt(key, -1);
    if (i >= 0 && i < Purpose.values.length) return Purpose.values[i];
    // Never chosen (a new install, or the app was in use before purposes): "tutorial", with its settings.
    Future<void>.microtask(() => _start(Purpose.tutorial));
    return Purpose.tutorial;
  }

  Future<void> _start(Purpose p) async {
    await ref.read(settingsStoreProvider).setInt(key, p.index);
    final mk = ref.read(markerSettingsProvider.notifier);
    await mk.update(applyPurposeToMarkers(p, ref.read(markerSettingsProvider)));
  }

  /// Switches to [p]: the settings in use go to the current purpose's copy, [p]'s copy comes in.
  Future<void> choose(Purpose p) async {
    final store = ref.read(settingsStoreProvider);
    if (p == state && store.getInt(key, -1) == p.index) return;
    await _saveCopy(state);
    state = p;
    await store.setInt(key, p.index);
    final copy = store.getString(profileKey(p));
    if (copy == null) {
      final mk = ref.read(markerSettingsProvider.notifier);
      await mk.update(applyPurposeToMarkers(p, ref.read(markerSettingsProvider)));
      await _saveCopy(p);
      return;
    }
    final m = jsonDecode(copy) as Map<String, dynamic>;
    for (final k in profileKeys) {
      await store.setRaw(k, m[k]);
    }
    ref
      ..invalidate(recSettingsProvider)
      ..invalidate(markerSettingsProvider);
  }

  /// Forgets every purpose's settings: all start again from the defaults, with their ready settings.
  Future<void> resetAll() async {
    final store = ref.read(settingsStoreProvider);
    for (final p in Purpose.values) {
      await store.remove(profileKey(p));
    }
    for (final k in profileKeys) {
      await store.remove(k);
    }
    ref
      ..invalidate(recSettingsProvider)
      ..invalidate(markerSettingsProvider);
    await _start(state);
    await _saveCopy(state);
  }

  Future<void> _saveCopy(Purpose p) async {
    final store = ref.read(settingsStoreProvider);
    await store.setString(profileKey(p), jsonEncode({
      for (final k in profileKeys) k: ?store.getRaw(k),
    }));
  }
}

final purposeProvider = NotifierProvider<PurposeNotifier, Purpose>(
  PurposeNotifier.new,
);
