import '../../l10n/app_localizations.dart';
import 'rec_settings.dart';

String resolutionLabel(AppL10n t, Resolution r) => switch (r) {
  Resolution.p720 => t.resolution720,
  Resolution.p1080 => t.resolution1080,
  Resolution.native => t.resolutionNative,
};

String qualityLabel(AppL10n t, Quality q) => switch (q) {
  Quality.low => t.qualityLow,
  Quality.balanced => t.qualityBalanced,
  Quality.high => t.qualityHigh,
};

String audioLabel(AppL10n t, AudioMode a) => switch (a) {
  AudioMode.none => t.audioNone,
  AudioMode.mic => t.audioMic,
  AudioMode.system => t.audioSystem,
  AudioMode.both => t.audioBoth,
};
