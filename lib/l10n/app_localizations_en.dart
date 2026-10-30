// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'E Screen Recorder';

  @override
  String get navRecord => 'Record';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get recordStart => 'Start recording';

  @override
  String get recordStop => 'Stop recording';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordResume => 'Resume';

  @override
  String get recentTitle => 'Recent';

  @override
  String get seeAll => 'See all';

  @override
  String get libraryEmptyTitle => 'No videos yet';

  @override
  String get libraryEmptyBody =>
      'Record your first screen and the video will appear here.';

  @override
  String get profileTitle => 'Recording settings';

  @override
  String get resetDefaults => 'Reset to defaults';

  @override
  String get optResolution => 'Resolution';

  @override
  String get optFps => 'Frame rate';

  @override
  String get optQuality => 'Quality';

  @override
  String get optAudio => 'Audio';

  @override
  String get optCountdown => 'Countdown';

  @override
  String get optFloatingBar => 'Markers while recording';

  @override
  String get floatingBarHint =>
      'Turn on to mark while recording (small corner dot or clean recording, chosen in Settings). Turn off to control recording from the notification only.';

  @override
  String get resolution720 => '720p';

  @override
  String get resolution1080 => '1080p';

  @override
  String get resolutionNative => 'Original';

  @override
  String fpsValue(int fps) {
    return '$fps fps';
  }

  @override
  String get qualityLow => 'Light';

  @override
  String get qualityBalanced => 'Balanced';

  @override
  String get qualityHigh => 'Sharp';

  @override
  String get audioNone => 'None';

  @override
  String get audioMic => 'Microphone';

  @override
  String get audioSystem => 'Device audio';

  @override
  String get audioBoth => 'Both';

  @override
  String get countdownOff => 'Off';

  @override
  String countdownSeconds(int n) {
    return '$n s';
  }

  @override
  String profileSummary(String resolution, int fps, String quality) {
    return '$resolution · $fps fps · $quality';
  }

  @override
  String get profileEdit => 'Edit recording settings';

  @override
  String get statusRecording => 'Recording';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusCountdown => 'Starting…';

  @override
  String get statusSaving => 'Saving video…';

  @override
  String get recordingHint =>
      'Open the app you want to record. Tap the small corner dot to mark where you are about to press; long-press the dot for the control bar.';

  @override
  String get recordingHintNoBar =>
      'Open the app you want to record. Control it from the notification.';

  @override
  String get recordingHintClean =>
      'Open the app you want to record. Touch the hidden corner, touch where you are about to press (the phone buzzes), then press for real. Stop from the notification.';

  @override
  String savedSnack(String name) {
    return 'Saved $name';
  }

  @override
  String get actionView => 'View';

  @override
  String get errLowStorage =>
      'Storage is almost full. Free some space and try again.';

  @override
  String get errMic =>
      'Microphone permission is needed to record sound. Choose audio \"None\" or allow it in the device settings.';

  @override
  String get errOverlay =>
      'Permission to display over other apps is needed for the countdown and the floating bar. Turn it on, then come back to the app.';

  @override
  String get errStart => 'Could not start recording. Please try again.';

  @override
  String get errCapture => 'The recording was interrupted.';

  @override
  String get errEmpty => 'The video has no data. Please record again.';

  @override
  String get errSave => 'Could not save the video to the device.';

  @override
  String get pickVideoFromDevice => 'Choose a video from the phone';

  @override
  String get pickVideoFailed => 'This video could not be opened.';

  @override
  String get libraryTitle => 'Library';

  @override
  String get menuShare => 'Share';

  @override
  String get menuRename => 'Rename';

  @override
  String get menuDelete => 'Delete';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuMore => 'More actions';

  @override
  String get renameTitle => 'Rename video';

  @override
  String get renameField => 'Video name';

  @override
  String get deleteTitle => 'Delete this video?';

  @override
  String deleteBody(String name) {
    return '$name will be removed from the device and cannot be restored.';
  }

  @override
  String get deleteDone => 'Video deleted';

  @override
  String get needsPermission =>
      'This video was created by an earlier install, so the system does not allow changing it. Delete it with the device\'s gallery app.';

  @override
  String get genericError => 'Could not do that. Please try again.';

  @override
  String videoMeta(String date, String size) {
    return '$date · $size';
  }

  @override
  String get playerError => 'This video cannot be played.';

  @override
  String get playVideo => 'Play';

  @override
  String get pauseVideo => 'Pause playback';

  @override
  String get settingsMarkers => 'Markers';

  @override
  String get settingsMarkersSub =>
      'Finger, arrow, circle… shown before the tap';

  @override
  String get settingsMarkersHint =>
      'The marker appears in the video before you tap, so viewers know where the tap will land.';

  @override
  String get markerPreviewTitle => 'Preview';

  @override
  String get previewLight => 'Light background';

  @override
  String get previewDark => 'Dark background';

  @override
  String get previewMockSave => 'Save';

  @override
  String get markerDefaultTool => 'Default marker';

  @override
  String get markerFinger => 'Finger';

  @override
  String get markerRipple => 'Tap';

  @override
  String get markerArrow => 'Arrow';

  @override
  String get markerCircle => 'Circle';

  @override
  String get markerRect => 'Box';

  @override
  String get markerPen => 'Pen';

  @override
  String get markerNumber => 'Step number';

  @override
  String get markerColor => 'Colour';

  @override
  String get colorRed => 'Red';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorMagenta => 'Pink';

  @override
  String get colorWhite => 'White';

  @override
  String get colorBlack => 'Black';

  @override
  String get markerThickness => 'Stroke width';

  @override
  String get thicknessThin => 'Thin';

  @override
  String get thicknessMedium => 'Medium';

  @override
  String get thicknessThick => 'Thick';

  @override
  String get adjustScale => 'Size';

  @override
  String get adjustRotate => 'Rotate';

  @override
  String get adjustOpacity => 'Opacity';

  @override
  String get markerAdjustNote =>
      'Size, rotation and opacity are for previewing only. While recording, pinch with two fingers to resize and rotate a marker.';

  @override
  String get markerHold => 'Keep the marker after placing';

  @override
  String get markerHoldShort => 'Short';

  @override
  String get markerHoldLong => 'Long';

  @override
  String get markerHoldHint =>
      'Counted from when you finish placing it. When the time is up the marker fades and disappears, even if you are still in marking mode or have moved to another page.';

  @override
  String get previewToggleBackdrop => 'Switch preview light/dark';

  @override
  String holdSeconds(String s) {
    return '$s s';
  }

  @override
  String get markerAutoExit => 'Leave point mode after placing';

  @override
  String get markerAutoExitHint =>
      'After placing a marker the floating bar goes back to normal so you can tap the real target.';

  @override
  String markerExitDelay(String s) {
    return 'Wait $s s before you can tap';
  }

  @override
  String get markerExitDelayHint =>
      'Time between placing a marker and being able to tap the real target. Shorter is faster, but viewers need a moment to see the marker.';

  @override
  String get captionsAutoTitle => 'Create captions automatically';

  @override
  String get captionsPrivacy =>
      'Speech is recognised on this phone by Android\'s own recogniser. The audio never leaves the device.';

  @override
  String get captionsUnavailable =>
      'This phone cannot recognise speech on the device (needs Android 13 or newer).';

  @override
  String get captionsLanguage => 'Language spoken in the video';

  @override
  String get langVietnamese => 'Tiếng Việt';

  @override
  String get langEnglish => 'English';

  @override
  String get captionsLangReady => 'Ready on this phone.';

  @override
  String get captionsLangDownload =>
      'A language pack is needed. Android downloads it once (it may use the network); after that it runs entirely on the device.';

  @override
  String get captionsLangUnsupported =>
      'This phone does not support this language.';

  @override
  String get captionsDownload => 'Download language pack';

  @override
  String get captionsDownloading => 'Downloading…';

  @override
  String get captionsStart => 'Start creating captions';

  @override
  String get captionsPreparing => 'Extracting the sound…';

  @override
  String captionsProgress(int done, int total) {
    return 'Listening to phrase $done/$total';
  }

  @override
  String captionsCreated(int n) {
    return 'Created $n captions. Edit or delete each one in the Text tab.';
  }

  @override
  String get captionsCancelled => 'Stopped, no captions were added.';

  @override
  String get captionsNoAudio =>
      'This video has no sound. Turn on the microphone or system sound before recording.';

  @override
  String get captionsNoSpeech => 'No speech was heard in the video.';

  @override
  String get captionsFailed =>
      'Captions could not be created. Try again or pick another language.';

  @override
  String get captionsReplaceNote =>
      'Creating again replaces the earlier automatic captions; captions you added or imported from SRT are kept.';

  @override
  String get voiceFxTitle => 'Voice effect';

  @override
  String get fxNone => 'Original';

  @override
  String get fxDeep => 'Deep';

  @override
  String get fxHigh => 'High';

  @override
  String get fxChipmunk => 'Chipmunk';

  @override
  String get fxRobot => 'Robot';

  @override
  String get fxEcho => 'Echo';

  @override
  String get fxReverb => 'Reverb';

  @override
  String get denoiseTitle => 'Noise reduction';

  @override
  String get denoiseOff => 'Off';

  @override
  String get denoiseLight => 'Light';

  @override
  String get denoiseStrong => 'Strong';

  @override
  String get voiceFxBusy => 'Processing voice…';

  @override
  String get voiceFxError => 'This voice file could not be processed.';

  @override
  String get voiceFxHint =>
      'Applied once to the voice file, so the preview and the exported video sound the same. Choose Original + Off to go back to the untouched recording. Background music is not touched.';

  @override
  String get markerBarNote =>
      'The floating bar and markers appear in the video.';

  @override
  String get splashTagline => 'Show viewers where you are about to tap';

  @override
  String get markModeTitle => 'How to mark while recording';

  @override
  String get markModeDot => 'Small dot in a corner';

  @override
  String get markModeDotHint =>
      'Pick the marker first. While recording only a small dot stays: tap it, touch where you are about to press, then press for real. The dot and the marker show in the video.';

  @override
  String get markModeClean => 'Record clean, edit later';

  @override
  String get markModeCleanHint =>
      'Nothing on screen. Touch the hidden corner, touch where you are about to press (the phone buzzes), then press for real. Markers are drawn beautifully in the editor.';

  @override
  String get markCornerTitle => 'Dot and hidden zone position';

  @override
  String get cornerTL => 'Top left';

  @override
  String get cornerTR => 'Top right';

  @override
  String get cornerBL => 'Bottom left';

  @override
  String get cornerBR => 'Bottom right';

  @override
  String get markShake => 'Shake to mark';

  @override
  String get markShakeHint =>
      'Shake twice to start marking. The shake can jolt the video.';

  @override
  String get markDotNote =>
      'Long-press the dot to open the control bar and change the marker (the video pauses while you choose, so the picker never reaches the video).';

  @override
  String get markCleanNote =>
      'Clean mode also has a “Mark” button in the notification. The hidden corner is invisible in the video.';

  @override
  String get toolAuto => 'Auto';

  @override
  String get autoTitle => 'Auto direct';

  @override
  String get autoHint =>
      'Zooms into your markers, renumbers the steps and speeds up stretches where the screen does not change. Everything stays editable and undoable.';

  @override
  String get autoZoomOpt => 'Zoom into markers';

  @override
  String get autoNumberOpt => 'Renumber the steps';

  @override
  String get autoIdleOpt => 'Speed up still stretches';

  @override
  String get autoRun => 'Direct automatically';

  @override
  String get autoRunning => 'Analysing the video…';

  @override
  String autoDone(int zooms, int steps, int idle) {
    return 'Done: $zooms zooms, $steps numbered steps, $idle sped-up stretches.';
  }

  @override
  String get autoNothing =>
      'Nothing more to direct. Add markers or record a longer clip.';

  @override
  String get autoAfterRec => 'After a clean recording';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onbStart => 'Get started';

  @override
  String get onbTitle1 => 'Viewers always know where you are about to tap';

  @override
  String get onbBody1 =>
      'The marker appears first, the screen changes after. Your tutorial videos become much easier to follow.';

  @override
  String get onbTitle2 => 'Three steps to point';

  @override
  String get onbStep1 =>
      'While recording, turn on point mode in the floating bar, pick a marker and place it on the target.';

  @override
  String get onbStep2 =>
      'Point mode switches off after placing. The amber ring closes in on the target and the marker stays for a few seconds.';

  @override
  String get onbStep3 =>
      'Now tap the real target. The viewer already knows where to look.';

  @override
  String get onbTitle3 => 'Allow a few permissions';

  @override
  String get onbBody3 =>
      'We only ask for what is really needed. Your videos always stay on your device.';

  @override
  String get permOverlayTitle => 'Display over other apps';

  @override
  String get permOverlayBody =>
      'To show the floating bar, countdown and markers on the screen while recording.';

  @override
  String get permMicTitle => 'Microphone';

  @override
  String get permMicBody => 'Only used when you choose to record sound.';

  @override
  String get permNotifTitle => 'Notifications';

  @override
  String get permNotifBody => 'Shows Pause and Stop buttons while recording.';

  @override
  String get permBatteryTitle => 'Long recordings without interruptions';

  @override
  String get permBatteryBody =>
      'Some phones (Xiaomi, Oppo, Vivo, Samsung) stop background apps. Open the app settings and set Battery to unrestricted.';

  @override
  String get permGranted => 'Allowed';

  @override
  String get permGrant => 'Allow';

  @override
  String get permOpenSettings => 'Open app settings';

  @override
  String get settingsPermissions => 'Permissions and battery';

  @override
  String get settingsPermissionsSub => 'Check the permissions needed to record';

  @override
  String get settingsGuide => 'How to use';

  @override
  String get settingsGuideSub => 'See how point-ahead markers work again';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacySub => 'Your videos stay on your device';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSub => 'Version and app information';

  @override
  String aboutVersion(String v) {
    return 'Version $v';
  }

  @override
  String get aboutBody =>
      'E Screen Recorder is a free screen recorder with no ads and no account.';

  @override
  String get aboutLicenses =>
      'Barlow font under the SIL OFL licence. The hand icon is based on Material Icons (Apache-2.0).';

  @override
  String get privacyH1 => 'Videos stay on the device';

  @override
  String get privacyP1 =>
      'All videos, editing projects and screenshots are stored on your own device. The app does not upload videos, audio or the screen to any server.';

  @override
  String get privacyH2 => 'No account, no tracking';

  @override
  String get privacyP2 =>
      'The app asks for no sign-in, shows no ads and collects no usage statistics or device identifiers.';

  @override
  String get privacyH3 => 'What permissions are for';

  @override
  String get privacyP3 =>
      'Screen capture: to record what is displayed, after you agree in the system dialog. Microphone: only when you choose to record sound. Display over other apps: to show the control bar and markers. Notifications: to show Pause and Stop.';

  @override
  String get privacyH4 => 'Sensitive content';

  @override
  String get privacyP4 =>
      'A screen recording may contain passwords, messages or phone numbers. Use a cover block in the editor before sharing. The app only shares when you choose Share.';

  @override
  String get privacyH5 => 'Deleting data';

  @override
  String get privacyP5 =>
      'Delete videos in the Library, or uninstall the app to remove editing projects. Exported videos are in Movies/E Screen Recorder and Pictures/E Screen Recorder.';

  @override
  String get toolCut => 'Cut';

  @override
  String get toolMarker => 'Marker';

  @override
  String get toolText => 'Text';

  @override
  String get toolCover => 'Cover';

  @override
  String get toolZoom => 'Zoom';

  @override
  String get splitHere => 'Split here';

  @override
  String get deleteSegment => 'Delete part';

  @override
  String get moveLeft => 'Move part left';

  @override
  String get moveRight => 'Move part right';

  @override
  String get segmentSpeed => 'Speed of this part';

  @override
  String get trimHint =>
      'Tap a part on the timeline, then drag its ends to trim.';

  @override
  String get markerAddHint =>
      'Move the playhead to the exact moment of the tap. The marker appears 0.5 s earlier, then the tap happens.';

  @override
  String get clipHold => 'Keep marker';

  @override
  String get clipLength => 'Duration';

  @override
  String get textAdd => 'Add text';

  @override
  String get textHint =>
      'Text sits on top of the video and is not enlarged by the zoom effect.';

  @override
  String get textField => 'Text';

  @override
  String get textSize => 'Text size';

  @override
  String get coverAdd => 'Add region';

  @override
  String get coverStyleSolid => 'Solid';

  @override
  String get coverStyleBlur => 'Blur';

  @override
  String get coverStyleMosaic => 'Mosaic';

  @override
  String get coverStyleSpotlight => 'Spotlight';

  @override
  String get coverStrength => 'Strength';

  @override
  String get coverMove => 'Move';

  @override
  String get coverMoveHint =>
      'The region glides from the start point to the end point over its whole duration. Pick a point, then drag on the video.';

  @override
  String get coverPointStart => 'Start point';

  @override
  String get coverPointEnd => 'End point';

  @override
  String get coverHint =>
      'Hide phone numbers, passwords… with a solid block, a blur or a mosaic; or dim everything else to spotlight an area. Drag on the video to place it.';

  @override
  String get coverWidth => 'Width';

  @override
  String get coverHeight => 'Height';

  @override
  String get zoomAdd => 'Add zoom';

  @override
  String get zoomHint => 'Zoom into an area, then ease back out.';

  @override
  String get zoomScale => 'Zoom level';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomHold => 'Hold';

  @override
  String get zoomTimingHint =>
      'Zoom in / Zoom out is how long the zoom takes to reach full level and to return; shorter is faster. Hold is how long it stays zoomed after the marker has faded.';

  @override
  String get zoomAutoTuning => 'Fine-tune automatic zoom';

  @override
  String get zoomDragHint =>
      'Drag on the video to choose the area to zoom into.';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get exportAction => 'Export';

  @override
  String get exportTitle => 'Export video';

  @override
  String exportSummary(String duration) {
    return 'Duration $duration';
  }

  @override
  String get exportFormat => 'Format';

  @override
  String get formatMp4 => 'MP4';

  @override
  String get formatGif => 'GIF';

  @override
  String get exportQuality => 'Quality';

  @override
  String get qualityOriginal => 'Original';

  @override
  String get resolution480 => '480p';

  @override
  String get gifHint =>
      'A light GIF without sound. Looks best for clips under 15 seconds.';

  @override
  String get exportStart => 'Start export';

  @override
  String exportRunning(int pct) {
    return 'Exporting $pct%';
  }

  @override
  String get exportDone => 'Export finished';

  @override
  String get exportError => 'Export failed. Please try again.';

  @override
  String timelineSummary(
    int segments,
    int markers,
    int texts,
    int covers,
    int zooms,
  ) {
    return 'Timeline: $segments parts, $markers markers, $texts texts, $covers covers, $zooms zooms';
  }

  @override
  String get selectMode => 'Select';

  @override
  String selectedCount(int n) {
    return '$n selected';
  }

  @override
  String get joinAction => 'Join';

  @override
  String get joinTitle => 'Join videos';

  @override
  String joinSummary(int n) {
    return 'Joining $n videos in the order you picked them.';
  }

  @override
  String get joinDone => 'Join finished';

  @override
  String get resetProject => 'Start over';

  @override
  String get resetTitle => 'Discard all edits?';

  @override
  String get resetBody =>
      'The original video is untouched. You can still tap Undo right after.';

  @override
  String get seekBack => 'Back 1 second';

  @override
  String get seekForward => 'Forward 1 second';

  @override
  String get timelineZoomOut => 'Zoom timeline out';

  @override
  String get timelineZoomIn => 'Zoom timeline in';

  @override
  String get editorLoadError => 'Could not open the video for editing.';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get toolSpeed => 'Speed';

  @override
  String get toolTransition => 'Transitions';

  @override
  String get toolAudio => 'Audio';

  @override
  String get editFreeze => 'Freeze frame';

  @override
  String get editDuplicate => 'Duplicate';

  @override
  String get editBlank => 'Leave blank';

  @override
  String get editMultiSelect => 'Select several';

  @override
  String get editMultiHint =>
      'Tap clips to select them; actions apply to every selected clip.';

  @override
  String get frameBack => 'Back one frame';

  @override
  String get frameForward => 'Forward one frame';

  @override
  String get enterFullscreen => 'Full-screen preview';

  @override
  String get exitFullscreen => 'Exit full screen';

  @override
  String get toolsHide => 'Hide tools';

  @override
  String get toolsShow => 'Show tools';

  @override
  String get presetClassic => 'Classic';

  @override
  String get presetSubtitle => 'Subtitle';

  @override
  String get presetYellow => 'Yellow';

  @override
  String get presetNeon => 'Neon';

  @override
  String get presetClean => 'Clean';

  @override
  String get presetLabel => 'Label';

  @override
  String get subtitlesImport => 'Import subtitles (.srt)';

  @override
  String subtitlesImported(int n) {
    return 'Added $n subtitle lines.';
  }

  @override
  String get subtitlesNone => 'No subtitle lines could be read from this file.';

  @override
  String get timelineFit => 'Fit';

  @override
  String get reorderHint => 'Hold a clip, then slide sideways to reorder.';

  @override
  String get speedFree => 'Free speed';

  @override
  String get speedRamp => 'Ramp the speed';

  @override
  String get speedRampFrom => 'At the start';

  @override
  String get speedRampTo => 'At the end';

  @override
  String get speedReverse => 'Play backwards';

  @override
  String get speedReverseHint =>
      'Reversed clips have no sound and are limited to 30 seconds each.';

  @override
  String get speedStillHint =>
      'This is a freeze frame: only its length can change.';

  @override
  String get freezeLength => 'Freeze length';

  @override
  String get transNone => 'None';

  @override
  String get transDipBlack => 'Dip to black';

  @override
  String get transDipWhite => 'Dip to white';

  @override
  String get transSlideLeft => 'Slide left';

  @override
  String get transSlideRight => 'Slide right';

  @override
  String get transSlideUp => 'Slide up';

  @override
  String get transSlideDown => 'Slide down';

  @override
  String get transZoom => 'Zoom fade';

  @override
  String get transLength => 'Length';

  @override
  String get transApplyAll => 'Apply to every cut';

  @override
  String get transFirstHint =>
      'The first clip has no transition. Select the 2nd clip or later.';

  @override
  String get transHint =>
      'A transition sits where the selected clip begins; the video length does not change.';

  @override
  String get audioVolume => 'Volume';

  @override
  String get audioMute => 'Mute this clip';

  @override
  String get audioFadeIn => 'Fade in';

  @override
  String get audioFadeOut => 'Fade out';

  @override
  String get audioStillHint => 'Freeze frames and blanks have no sound.';

  @override
  String get toolPicture => 'Picture';

  @override
  String get toolOverlay => 'Overlays';

  @override
  String get picRotate => 'Rotate 90°';

  @override
  String get picTilt => 'Free rotation';

  @override
  String get picTiltReset => 'Straighten';

  @override
  String get picCrop => 'Crop';

  @override
  String get picCropReset => 'Remove crop';

  @override
  String get picAspect => 'Output shape';

  @override
  String get aspectAuto => 'Original';

  @override
  String get aspect916 => '9:16';

  @override
  String get aspect11 => '1:1';

  @override
  String get aspect45 => '4:5';

  @override
  String get aspect169 => '16:9';

  @override
  String get picFit => 'Black bars';

  @override
  String get picFill => 'Fill';

  @override
  String get picFitHint =>
      'When the shape differs: add black bars, or fill the frame and cut the excess.';

  @override
  String get picFilters => 'Colour';

  @override
  String get presetNone => 'Original';

  @override
  String get presetVivid => 'Vivid';

  @override
  String get presetWarm => 'Warm';

  @override
  String get presetCool => 'Cool';

  @override
  String get presetBw => 'Black & white';

  @override
  String get presetVintage => 'Vintage';

  @override
  String get presetFade => 'Faded';

  @override
  String get colorBrightness => 'Brightness';

  @override
  String get colorContrast => 'Contrast';

  @override
  String get colorSaturation => 'Saturation';

  @override
  String get colorWarmth => 'Warmth';

  @override
  String get picRotateNote =>
      'Rotate and crop before adding markers; markers already placed may shift.';

  @override
  String get cropTitle => 'Crop the picture';

  @override
  String get cropDone => 'Done';

  @override
  String get ovAddImage => 'Add picture';

  @override
  String get ovAddPip => 'Picture in picture';

  @override
  String get ovPipHint =>
      'Pick a picture or a short video (up to 30 seconds) to show in a corner.';

  @override
  String get shapeRect => 'Rectangle';

  @override
  String get shapeEllipse => 'Circle';

  @override
  String get shapeLine => 'Line';

  @override
  String get shapeArrow => 'Arrow';

  @override
  String get shapeBubble => 'Callout';

  @override
  String get ovWidth => 'Width';

  @override
  String get ovOpacity => 'Opacity';

  @override
  String get ovRotation => 'Rotation';

  @override
  String get ovStroke => 'Line width';

  @override
  String get ovFilled => 'Filled';

  @override
  String get ovBubbleText => 'Callout text';

  @override
  String get ovPipVolume => 'Sound';

  @override
  String get ovPipStart => 'Starts at';

  @override
  String get ovPipLength => 'Length';

  @override
  String get ovHint =>
      'Add pictures, shapes, callouts or picture in picture; drag on the preview to place, pinch to resize and rotate.';

  @override
  String get motionTitle => 'Motion';

  @override
  String get motionEnter => 'Appear';

  @override
  String get motionExit => 'Disappear';

  @override
  String get motionNone => 'None';

  @override
  String get motionFade => 'Fade';

  @override
  String get motionPop => 'Pop';

  @override
  String get motionSlideUp => 'Slide up';

  @override
  String get motionSlideDown => 'Slide down';

  @override
  String get motionSlideLeft => 'Slide left';

  @override
  String get motionSlideRight => 'Slide right';

  @override
  String get motionKeyframe => 'Move to an end position';

  @override
  String get motionSetEnd => 'Use the current position as the end';

  @override
  String get motionClear => 'Remove the movement';

  @override
  String get motionEase => 'Easing';

  @override
  String get easeLinear => 'Even';

  @override
  String get easeIn => 'Slow then fast';

  @override
  String get easeOut => 'Fast then slow';

  @override
  String get easeInOut => 'Smooth';

  @override
  String get textFont => 'Font';

  @override
  String get fontBarlow => 'Barlow';

  @override
  String get fontSans => 'Modern';

  @override
  String get fontCondensed => 'Narrow';

  @override
  String get fontSerif => 'Serif';

  @override
  String get fontMono => 'Monospace';

  @override
  String get fontCursive => 'Handwriting';

  @override
  String get textOutline => 'Outline';

  @override
  String get textBox => 'Background';

  @override
  String get textShadow => 'Shadow';

  @override
  String get textBold => 'Bold';

  @override
  String get textAlignLabel => 'Alignment';

  @override
  String get alignLeft => 'Left';

  @override
  String get alignCenter => 'Centre';

  @override
  String get alignRight => 'Right';

  @override
  String get autoStepLabels => 'Add a Step N label to numbered markers';

  @override
  String get audioTracks => 'Music and voice';

  @override
  String get audioAddMusic => 'Add music from phone';

  @override
  String get audioRecordVoice => 'Record voice';

  @override
  String get audioStopVoice => 'Stop recording';

  @override
  String get audioVoiceHint =>
      'Use headphones so your voice is not mixed with the speaker sound.';

  @override
  String get audioStartAt => 'Starts at';

  @override
  String get audioLoop => 'Repeat until the video ends';

  @override
  String get audioDuck => 'Lower the music while talking';

  @override
  String get audioNormalize => 'Even out the volume';

  @override
  String get audioNormalized => 'Volume evened out';

  @override
  String get audioNoSound => 'This clip has no sound to measure.';

  @override
  String get audioMicDenied =>
      'The microphone permission is needed to record your voice.';

  @override
  String get audioMusicName => 'Music';

  @override
  String get audioVoiceName => 'Voice';

  @override
  String get audioTracksNone => 'No music or voice yet.';

  @override
  String get exportPreset => 'Export preset';

  @override
  String get presetCustom => 'Custom';

  @override
  String get presetYoutube => 'YouTube 1080p';

  @override
  String get presetVertical => 'TikTok / Reels 9:16';

  @override
  String get presetShare => 'Quick share (≤ 24 MB)';

  @override
  String get presetGif => 'GIF';

  @override
  String get presetVerticalNote => 'The output shape will change to 9:16.';

  @override
  String exportEstimate(String size) {
    return 'Estimated size $size';
  }

  @override
  String get exportCapMissed =>
      'Too long to fit 24 MB: quality will be low. Trim the video.';

  @override
  String get exportStill => 'Save this frame as a picture';

  @override
  String get stillSaved => 'Picture saved to your photos';

  @override
  String get exportBackgroundHint =>
      'You can leave the app: a notification tells you when it is done.';

  @override
  String get templateSave => 'Save as template';

  @override
  String get templateApply => 'Use a template';

  @override
  String get templateName => 'Template name';

  @override
  String get templateNone => 'No templates yet.';

  @override
  String get templateApplied => 'Template applied';

  @override
  String get templateSaved => 'Template saved';

  @override
  String get templateDelete => 'Delete template';

  @override
  String get menuTemplates => 'Project templates';

  @override
  String get exportNotifTitle => 'Exporting video';

  @override
  String get exportNotifDone => 'Export finished. Tap to open.';

  @override
  String get exportNotifFailed => 'Export failed.';

  @override
  String get stepLabelPrefix => 'Step ';

  @override
  String get speedMuteFast => 'Mute sound above 2× speed';

  @override
  String get iosNoRecording =>
      'On iPhone the app records its own screen and your voice. Recording other apps and the floating markers over them are Android-only for now.';

  @override
  String get touchSourceTitle => 'Detect touches';

  @override
  String get touchSourceOff => 'Off';

  @override
  String get touchSourceDots => 'Show-taps dots';

  @override
  String get touchSourceManual => 'Manual';

  @override
  String get touchSourceHint =>
      'Dots: the editor finds the white dots of Android\'s “Show taps” in the video and knows when and where you pressed. Manual: shake the phone or use the notification button. Off: nothing is detected. Without either, “Build from touches” still finds when the screen changed, but not where you pressed.';

  @override
  String get touchGuideTitle => 'Turn on Show taps';

  @override
  String get touchGuideStep1 =>
      '1. Turn on developer mode: open About phone and tap Build number 7 times.';

  @override
  String get touchGuideAbout => 'Open About phone';

  @override
  String get touchGuideStep2 =>
      '2. In Developer options, turn on Show taps (Pointer location is not needed).';

  @override
  String get touchGuideDev => 'Open Developer options';

  @override
  String get touchGuideStep3 =>
      '3. Record as usual. The dots show in the video; the editor finds them and can hide them under nicer marks.';

  @override
  String get touchGuideDevOn => 'Developer mode: on';

  @override
  String get touchGuideDevOff => 'Developer mode: off';

  @override
  String get touchGuideTapsOn => 'Show taps: on';

  @override
  String get touchGuideTapsOff => 'Show taps: off';

  @override
  String get touchGuideRecheck => 'Check again';

  @override
  String get inputModeTitle => 'Typing';

  @override
  String get inputModeMerge => 'One step “Typing”';

  @override
  String get inputModePerKey => 'Mark each key (short bursts only)';

  @override
  String get inputModeSkip => 'Leave typing out';

  @override
  String get pauseTitle => 'Freeze at each touch';

  @override
  String get pauseZoomTitle => 'Gentle zoom at touches';

  @override
  String get pauseHint =>
      'The picture freezes for this long at each press (0 = never). Presses closer than 1.5 s share one freeze. Frozen moments are never sped up. The zoom only applies when the place of the press is known.';

  @override
  String get autoFromTouches => 'Build from touches';

  @override
  String get autoFromTouchesRunning => 'Looking for touches…';

  @override
  String get autoTouchesNone => 'No touches found in this video.';

  @override
  String autoTouchesDone(int taps, int typing) {
    return '$taps touches, $typing typing steps.';
  }

  @override
  String get autoTouchesNoPlace =>
      'Only the moments were found, not the places: step captions and freezes, no zoom.';

  @override
  String get autoPreviewPause => 'Preview first freeze';

  @override
  String get typingLabel => 'Typing…';

  @override
  String get typedLabel => 'Typed';

  @override
  String get presetGlow => 'Neon glow';

  @override
  String get presetGradient => 'Gradient';

  @override
  String get presetExtrude => '3D';

  @override
  String get presetHollow => 'Outline';

  @override
  String get presetGlitch => 'Glitch';

  @override
  String get presetSticker => 'Sticker';
}
