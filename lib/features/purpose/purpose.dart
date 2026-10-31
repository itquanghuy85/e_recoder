import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_store.dart';
import '../marker/marker_settings.dart';

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

class PurposeNotifier extends Notifier<Purpose?> {
  static const key = 'purpose';

  @override
  Purpose? build() {
    final i = ref.read(settingsStoreProvider).getInt(key, -1);
    return i >= 0 && i < Purpose.values.length ? Purpose.values[i] : null;
  }

  /// Saves the choice and puts its settings in place.
  Future<void> choose(Purpose p) async {
    state = p;
    await ref.read(settingsStoreProvider).setInt(key, p.index);
    final mk = ref.read(markerSettingsProvider.notifier);
    await mk.update(applyPurposeToMarkers(p, ref.read(markerSettingsProvider)));
  }
}

final purposeProvider = NotifierProvider<PurposeNotifier, Purpose?>(
  PurposeNotifier.new,
);
