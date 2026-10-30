import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'E Screen Recorder'**
  String get appTitle;

  /// No description provided for @navRecord.
  ///
  /// In vi, this message translates to:
  /// **'Quay'**
  String get navRecord;

  /// No description provided for @navLibrary.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện'**
  String get navLibrary;

  /// No description provided for @navSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get navSettings;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @close.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get close;

  /// No description provided for @recordStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu quay'**
  String get recordStart;

  /// No description provided for @recordStop.
  ///
  /// In vi, this message translates to:
  /// **'Dừng quay'**
  String get recordStop;

  /// No description provided for @recordPause.
  ///
  /// In vi, this message translates to:
  /// **'Tạm dừng'**
  String get recordPause;

  /// No description provided for @recordResume.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get recordResume;

  /// No description provided for @recentTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gần đây'**
  String get recentTitle;

  /// No description provided for @seeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get seeAll;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có video nào'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Quay màn hình đầu tiên của bạn, video sẽ nằm ở đây.'**
  String get libraryEmptyBody;

  /// No description provided for @profileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cấu hình quay'**
  String get profileTitle;

  /// No description provided for @resetDefaults.
  ///
  /// In vi, this message translates to:
  /// **'Khôi phục mặc định'**
  String get resetDefaults;

  /// No description provided for @optResolution.
  ///
  /// In vi, this message translates to:
  /// **'Độ phân giải'**
  String get optResolution;

  /// No description provided for @optFps.
  ///
  /// In vi, this message translates to:
  /// **'Tốc độ khung hình'**
  String get optFps;

  /// No description provided for @optQuality.
  ///
  /// In vi, this message translates to:
  /// **'Chất lượng'**
  String get optQuality;

  /// No description provided for @optAudio.
  ///
  /// In vi, this message translates to:
  /// **'Âm thanh'**
  String get optAudio;

  /// No description provided for @optCountdown.
  ///
  /// In vi, this message translates to:
  /// **'Đếm ngược'**
  String get optCountdown;

  /// No description provided for @optFloatingBar.
  ///
  /// In vi, this message translates to:
  /// **'Dấu đánh dấu khi quay'**
  String get optFloatingBar;

  /// No description provided for @floatingBarHint.
  ///
  /// In vi, this message translates to:
  /// **'Bật để đánh dấu khi quay (chấm nhỏ ở góc hoặc quay sạch, chọn trong Cài đặt). Tắt để chỉ điều khiển bằng thông báo.'**
  String get floatingBarHint;

  /// No description provided for @resolution720.
  ///
  /// In vi, this message translates to:
  /// **'720p'**
  String get resolution720;

  /// No description provided for @resolution1080.
  ///
  /// In vi, this message translates to:
  /// **'1080p'**
  String get resolution1080;

  /// No description provided for @resolutionNative.
  ///
  /// In vi, this message translates to:
  /// **'Gốc'**
  String get resolutionNative;

  /// No description provided for @fpsValue.
  ///
  /// In vi, this message translates to:
  /// **'{fps} fps'**
  String fpsValue(int fps);

  /// No description provided for @qualityLow.
  ///
  /// In vi, this message translates to:
  /// **'Nhẹ'**
  String get qualityLow;

  /// No description provided for @qualityBalanced.
  ///
  /// In vi, this message translates to:
  /// **'Cân bằng'**
  String get qualityBalanced;

  /// No description provided for @qualityHigh.
  ///
  /// In vi, this message translates to:
  /// **'Nét'**
  String get qualityHigh;

  /// No description provided for @audioNone.
  ///
  /// In vi, this message translates to:
  /// **'Không có'**
  String get audioNone;

  /// No description provided for @audioMic.
  ///
  /// In vi, this message translates to:
  /// **'Micro'**
  String get audioMic;

  /// No description provided for @audioSystem.
  ///
  /// In vi, this message translates to:
  /// **'Âm thanh máy'**
  String get audioSystem;

  /// No description provided for @audioBoth.
  ///
  /// In vi, this message translates to:
  /// **'Cả hai'**
  String get audioBoth;

  /// No description provided for @countdownOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt'**
  String get countdownOff;

  /// No description provided for @countdownSeconds.
  ///
  /// In vi, this message translates to:
  /// **'{n} giây'**
  String countdownSeconds(int n);

  /// No description provided for @profileSummary.
  ///
  /// In vi, this message translates to:
  /// **'{resolution} · {fps} fps · {quality}'**
  String profileSummary(String resolution, int fps, String quality);

  /// No description provided for @profileEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh cấu hình quay'**
  String get profileEdit;

  /// No description provided for @statusRecording.
  ///
  /// In vi, this message translates to:
  /// **'Đang quay'**
  String get statusRecording;

  /// No description provided for @statusPaused.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạm dừng'**
  String get statusPaused;

  /// No description provided for @statusCountdown.
  ///
  /// In vi, this message translates to:
  /// **'Sắp quay…'**
  String get statusCountdown;

  /// No description provided for @statusSaving.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu video…'**
  String get statusSaving;

  /// No description provided for @recordingHint.
  ///
  /// In vi, this message translates to:
  /// **'Mở ứng dụng bạn muốn quay. Bấm chấm nhỏ ở góc để đánh dấu chỗ sắp bấm; nhấn giữ chấm để mở thanh điều khiển.'**
  String get recordingHint;

  /// No description provided for @recordingHintNoBar.
  ///
  /// In vi, this message translates to:
  /// **'Mở ứng dụng bạn muốn quay. Điều khiển bằng thông báo.'**
  String get recordingHintNoBar;

  /// No description provided for @recordingHintClean.
  ///
  /// In vi, this message translates to:
  /// **'Mở ứng dụng bạn muốn quay. Chạm vùng ẩn ở góc, chạm chỗ sắp bấm (máy rung nhẹ), rồi bấm thật. Dừng bằng thông báo.'**
  String get recordingHintClean;

  /// No description provided for @savedSnack.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu {name}'**
  String savedSnack(String name);

  /// No description provided for @actionView.
  ///
  /// In vi, this message translates to:
  /// **'Xem'**
  String get actionView;

  /// No description provided for @errLowStorage.
  ///
  /// In vi, this message translates to:
  /// **'Bộ nhớ sắp đầy. Hãy giải phóng dung lượng rồi quay lại.'**
  String get errLowStorage;

  /// No description provided for @errMic.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền micro để quay có tiếng. Chọn âm thanh \"Không có\" hoặc cấp quyền trong Cài đặt của máy.'**
  String get errMic;

  /// No description provided for @errOverlay.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền hiển thị trên ứng dụng khác để dùng đếm ngược và thanh nổi. Bật quyền rồi quay lại ứng dụng.'**
  String get errOverlay;

  /// No description provided for @errStart.
  ///
  /// In vi, this message translates to:
  /// **'Không bắt đầu quay được. Hãy thử lại.'**
  String get errStart;

  /// No description provided for @errCapture.
  ///
  /// In vi, this message translates to:
  /// **'Quá trình quay bị gián đoạn.'**
  String get errCapture;

  /// No description provided for @errEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Video không có dữ liệu. Hãy quay lại.'**
  String get errEmpty;

  /// No description provided for @errSave.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được video vào bộ nhớ máy.'**
  String get errSave;

  /// No description provided for @pickVideoFromDevice.
  ///
  /// In vi, this message translates to:
  /// **'Chọn video từ máy'**
  String get pickVideoFromDevice;

  /// No description provided for @pickVideoFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được video này.'**
  String get pickVideoFailed;

  /// No description provided for @libraryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện'**
  String get libraryTitle;

  /// No description provided for @menuShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ'**
  String get menuShare;

  /// No description provided for @menuRename.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tên'**
  String get menuRename;

  /// No description provided for @menuDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get menuDelete;

  /// No description provided for @menuEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get menuEdit;

  /// No description provided for @menuMore.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác khác'**
  String get menuMore;

  /// No description provided for @renameTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tên video'**
  String get renameTitle;

  /// No description provided for @renameField.
  ///
  /// In vi, this message translates to:
  /// **'Tên video'**
  String get renameField;

  /// No description provided for @deleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá video này?'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In vi, this message translates to:
  /// **'{name} sẽ bị xoá khỏi máy và không khôi phục được.'**
  String deleteBody(String name);

  /// No description provided for @deleteDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá video'**
  String get deleteDone;

  /// No description provided for @needsPermission.
  ///
  /// In vi, this message translates to:
  /// **'Video này do bản cài trước tạo nên hệ thống không cho sửa. Hãy xoá bằng ứng dụng Thư viện của máy.'**
  String get needsPermission;

  /// No description provided for @genericError.
  ///
  /// In vi, this message translates to:
  /// **'Không thực hiện được. Hãy thử lại.'**
  String get genericError;

  /// No description provided for @videoMeta.
  ///
  /// In vi, this message translates to:
  /// **'{date} · {size}'**
  String videoMeta(String date, String size);

  /// No description provided for @playerError.
  ///
  /// In vi, this message translates to:
  /// **'Không phát được video này.'**
  String get playerError;

  /// No description provided for @playVideo.
  ///
  /// In vi, this message translates to:
  /// **'Phát'**
  String get playVideo;

  /// No description provided for @pauseVideo.
  ///
  /// In vi, this message translates to:
  /// **'Dừng phát'**
  String get pauseVideo;

  /// No description provided for @settingsMarkers.
  ///
  /// In vi, this message translates to:
  /// **'Dấu đánh dấu'**
  String get settingsMarkers;

  /// No description provided for @settingsMarkersSub.
  ///
  /// In vi, this message translates to:
  /// **'Ngón tay, mũi tên, vòng tròn… báo trước chỗ sắp bấm'**
  String get settingsMarkersSub;

  /// No description provided for @settingsMarkersHint.
  ///
  /// In vi, this message translates to:
  /// **'Dấu hiện lên và được ghi vào video trước khi bạn bấm, để người xem biết sẽ bấm vào đâu.'**
  String get settingsMarkersHint;

  /// No description provided for @markerPreviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem thử'**
  String get markerPreviewTitle;

  /// No description provided for @previewLight.
  ///
  /// In vi, this message translates to:
  /// **'Nền sáng'**
  String get previewLight;

  /// No description provided for @previewDark.
  ///
  /// In vi, this message translates to:
  /// **'Nền tối'**
  String get previewDark;

  /// No description provided for @previewMockSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get previewMockSave;

  /// No description provided for @markerDefaultTool.
  ///
  /// In vi, this message translates to:
  /// **'Dấu mặc định'**
  String get markerDefaultTool;

  /// No description provided for @markerFinger.
  ///
  /// In vi, this message translates to:
  /// **'Ngón tay'**
  String get markerFinger;

  /// No description provided for @markerRipple.
  ///
  /// In vi, this message translates to:
  /// **'Chạm'**
  String get markerRipple;

  /// No description provided for @markerArrow.
  ///
  /// In vi, this message translates to:
  /// **'Mũi tên'**
  String get markerArrow;

  /// No description provided for @markerCircle.
  ///
  /// In vi, this message translates to:
  /// **'Vòng tròn'**
  String get markerCircle;

  /// No description provided for @markerRect.
  ///
  /// In vi, this message translates to:
  /// **'Khung'**
  String get markerRect;

  /// No description provided for @markerPen.
  ///
  /// In vi, this message translates to:
  /// **'Bút'**
  String get markerPen;

  /// No description provided for @markerNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số bước'**
  String get markerNumber;

  /// No description provided for @markerColor.
  ///
  /// In vi, this message translates to:
  /// **'Màu'**
  String get markerColor;

  /// No description provided for @colorRed.
  ///
  /// In vi, this message translates to:
  /// **'Đỏ'**
  String get colorRed;

  /// No description provided for @colorAmber.
  ///
  /// In vi, this message translates to:
  /// **'Vàng'**
  String get colorAmber;

  /// No description provided for @colorGreen.
  ///
  /// In vi, this message translates to:
  /// **'Xanh lá'**
  String get colorGreen;

  /// No description provided for @colorCyan.
  ///
  /// In vi, this message translates to:
  /// **'Xanh lơ'**
  String get colorCyan;

  /// No description provided for @colorMagenta.
  ///
  /// In vi, this message translates to:
  /// **'Hồng'**
  String get colorMagenta;

  /// No description provided for @colorWhite.
  ///
  /// In vi, this message translates to:
  /// **'Trắng'**
  String get colorWhite;

  /// No description provided for @colorBlack.
  ///
  /// In vi, this message translates to:
  /// **'Đen'**
  String get colorBlack;

  /// No description provided for @markerThickness.
  ///
  /// In vi, this message translates to:
  /// **'Độ dày nét'**
  String get markerThickness;

  /// No description provided for @thicknessThin.
  ///
  /// In vi, this message translates to:
  /// **'Mảnh'**
  String get thicknessThin;

  /// No description provided for @thicknessMedium.
  ///
  /// In vi, this message translates to:
  /// **'Vừa'**
  String get thicknessMedium;

  /// No description provided for @thicknessThick.
  ///
  /// In vi, this message translates to:
  /// **'Dày'**
  String get thicknessThick;

  /// No description provided for @adjustScale.
  ///
  /// In vi, this message translates to:
  /// **'Cỡ'**
  String get adjustScale;

  /// No description provided for @adjustRotate.
  ///
  /// In vi, this message translates to:
  /// **'Xoay'**
  String get adjustRotate;

  /// No description provided for @adjustOpacity.
  ///
  /// In vi, this message translates to:
  /// **'Độ trong'**
  String get adjustOpacity;

  /// No description provided for @markerAdjustNote.
  ///
  /// In vi, this message translates to:
  /// **'Cỡ, xoay và độ trong chỉ để xem thử. Khi quay, hãy chụm hai ngón để đổi cỡ và xoay dấu.'**
  String get markerAdjustNote;

  /// No description provided for @markerHold.
  ///
  /// In vi, this message translates to:
  /// **'Giữ dấu sau khi đặt xong'**
  String get markerHold;

  /// No description provided for @markerHoldShort.
  ///
  /// In vi, this message translates to:
  /// **'Ngắn'**
  String get markerHoldShort;

  /// No description provided for @markerHoldLong.
  ///
  /// In vi, this message translates to:
  /// **'Dài'**
  String get markerHoldLong;

  /// No description provided for @markerHoldHint.
  ///
  /// In vi, this message translates to:
  /// **'Tính từ lúc đặt xong. Hết thời gian dấu mờ dần rồi biến mất, kể cả khi bạn vẫn ở chế độ đánh dấu hoặc đã chuyển sang trang khác.'**
  String get markerHoldHint;

  /// No description provided for @previewToggleBackdrop.
  ///
  /// In vi, this message translates to:
  /// **'Đổi nền xem thử sáng/tối'**
  String get previewToggleBackdrop;

  /// No description provided for @holdSeconds.
  ///
  /// In vi, this message translates to:
  /// **'{s} giây'**
  String holdSeconds(String s);

  /// No description provided for @markerAutoExit.
  ///
  /// In vi, this message translates to:
  /// **'Tự thoát chế độ chỉ điểm sau khi đặt'**
  String get markerAutoExit;

  /// No description provided for @markerAutoExitHint.
  ///
  /// In vi, this message translates to:
  /// **'Đặt dấu xong, thanh nổi trở về bình thường để bạn bấm thật vào đích.'**
  String get markerAutoExitHint;

  /// No description provided for @markerExitDelay.
  ///
  /// In vi, this message translates to:
  /// **'Chờ {s} giây rồi mới cho bấm'**
  String markerExitDelay(String s);

  /// No description provided for @markerExitDelayHint.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian từ lúc đặt dấu đến lúc bạn bấm thật được. Càng ngắn càng nhanh, nhưng dấu cần đủ lâu để người xem kịp nhìn.'**
  String get markerExitDelayHint;

  /// No description provided for @captionsAutoTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo phụ đề tự động'**
  String get captionsAutoTitle;

  /// No description provided for @captionsPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Nhận dạng giọng nói ngay trên điện thoại bằng bộ nhận dạng của Android. Âm thanh không rời khỏi máy.'**
  String get captionsPrivacy;

  /// No description provided for @captionsUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Điện thoại này chưa hỗ trợ nhận dạng giọng nói trên máy (cần Android 13 trở lên).'**
  String get captionsUnavailable;

  /// No description provided for @captionsLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ trong video'**
  String get captionsLanguage;

  /// No description provided for @langVietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get langVietnamese;

  /// No description provided for @langEnglish.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @captionsLangReady.
  ///
  /// In vi, this message translates to:
  /// **'Đã có trên máy, dùng được ngay.'**
  String get captionsLangReady;

  /// No description provided for @captionsLangDownload.
  ///
  /// In vi, this message translates to:
  /// **'Cần tải gói ngôn ngữ. Android tự tải một lần, có thể dùng mạng; sau đó chạy hoàn toàn trên máy.'**
  String get captionsLangDownload;

  /// No description provided for @captionsLangUnsupported.
  ///
  /// In vi, this message translates to:
  /// **'Điện thoại chưa hỗ trợ ngôn ngữ này.'**
  String get captionsLangUnsupported;

  /// No description provided for @captionsDownload.
  ///
  /// In vi, this message translates to:
  /// **'Tải gói ngôn ngữ'**
  String get captionsDownload;

  /// No description provided for @captionsDownloading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải…'**
  String get captionsDownloading;

  /// No description provided for @captionsStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu tạo phụ đề'**
  String get captionsStart;

  /// No description provided for @captionsPreparing.
  ///
  /// In vi, this message translates to:
  /// **'Đang tách âm thanh…'**
  String get captionsPreparing;

  /// No description provided for @captionsProgress.
  ///
  /// In vi, this message translates to:
  /// **'Đang nghe đoạn {done}/{total}'**
  String captionsProgress(int done, int total);

  /// No description provided for @captionsCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo {n} dòng phụ đề. Sửa hoặc xoá từng dòng trong tab Chữ.'**
  String captionsCreated(int n);

  /// No description provided for @captionsCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã dừng, chưa thêm phụ đề nào.'**
  String get captionsCancelled;

  /// No description provided for @captionsNoAudio.
  ///
  /// In vi, this message translates to:
  /// **'Video này không có âm thanh. Khi quay hãy bật micro hoặc âm thanh hệ thống.'**
  String get captionsNoAudio;

  /// No description provided for @captionsNoSpeech.
  ///
  /// In vi, this message translates to:
  /// **'Không nghe thấy lời nói nào trong video.'**
  String get captionsNoSpeech;

  /// No description provided for @captionsFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tạo được phụ đề. Thử lại hoặc chọn ngôn ngữ khác.'**
  String get captionsFailed;

  /// No description provided for @captionsReplaceNote.
  ///
  /// In vi, this message translates to:
  /// **'Tạo lại sẽ thay các phụ đề tự động trước đó; phụ đề bạn tự thêm hoặc nhập từ SRT được giữ nguyên.'**
  String get captionsReplaceNote;

  /// No description provided for @voiceFxTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu ứng giọng'**
  String get voiceFxTitle;

  /// No description provided for @fxNone.
  ///
  /// In vi, this message translates to:
  /// **'Gốc'**
  String get fxNone;

  /// No description provided for @fxDeep.
  ///
  /// In vi, this message translates to:
  /// **'Trầm'**
  String get fxDeep;

  /// No description provided for @fxHigh.
  ///
  /// In vi, this message translates to:
  /// **'Cao'**
  String get fxHigh;

  /// No description provided for @fxChipmunk.
  ///
  /// In vi, this message translates to:
  /// **'Sóc chuột'**
  String get fxChipmunk;

  /// No description provided for @fxRobot.
  ///
  /// In vi, this message translates to:
  /// **'Robot'**
  String get fxRobot;

  /// No description provided for @fxEcho.
  ///
  /// In vi, this message translates to:
  /// **'Echo'**
  String get fxEcho;

  /// No description provided for @fxReverb.
  ///
  /// In vi, this message translates to:
  /// **'Vang'**
  String get fxReverb;

  /// No description provided for @denoiseTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giảm ồn'**
  String get denoiseTitle;

  /// No description provided for @denoiseOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt'**
  String get denoiseOff;

  /// No description provided for @denoiseLight.
  ///
  /// In vi, this message translates to:
  /// **'Nhẹ'**
  String get denoiseLight;

  /// No description provided for @denoiseStrong.
  ///
  /// In vi, this message translates to:
  /// **'Mạnh'**
  String get denoiseStrong;

  /// No description provided for @voiceFxBusy.
  ///
  /// In vi, this message translates to:
  /// **'Đang xử lý giọng…'**
  String get voiceFxBusy;

  /// No description provided for @voiceFxError.
  ///
  /// In vi, this message translates to:
  /// **'Không xử lý được file giọng này.'**
  String get voiceFxError;

  /// No description provided for @voiceFxHint.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng một lần lên file giọng nên xem trước và video xuất nghe giống nhau. Chọn Gốc + Tắt để quay về bản gốc. Không đụng tới nhạc nền.'**
  String get voiceFxHint;

  /// No description provided for @markerBarNote.
  ///
  /// In vi, this message translates to:
  /// **'Thanh nổi và dấu sẽ hiện trong video.'**
  String get markerBarNote;

  /// No description provided for @splashTagline.
  ///
  /// In vi, this message translates to:
  /// **'Cho người xem biết trước chỗ bạn sắp bấm'**
  String get splashTagline;

  /// No description provided for @markModeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cách đánh dấu khi quay'**
  String get markModeTitle;

  /// No description provided for @markModeDot.
  ///
  /// In vi, this message translates to:
  /// **'Chấm nhỏ ở góc'**
  String get markModeDot;

  /// No description provided for @markModeDotHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn dấu trước. Khi quay chỉ còn một chấm nhỏ: bấm chấm, chạm vào chỗ sắp bấm, rồi mới bấm thật. Chấm và dấu hiện trong video.'**
  String get markModeDotHint;

  /// No description provided for @markModeClean.
  ///
  /// In vi, this message translates to:
  /// **'Quay sạch, dựng sau'**
  String get markModeClean;

  /// No description provided for @markModeCleanHint.
  ///
  /// In vi, this message translates to:
  /// **'Màn hình không có gì chen vào. Chạm vùng ẩn ở góc, chạm chỗ sắp bấm (máy rung nhẹ), rồi bấm thật. Dấu được vẽ đẹp trong trình chỉnh sửa.'**
  String get markModeCleanHint;

  /// No description provided for @markCornerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí chấm và vùng ẩn'**
  String get markCornerTitle;

  /// No description provided for @cornerTL.
  ///
  /// In vi, this message translates to:
  /// **'Trên trái'**
  String get cornerTL;

  /// No description provided for @cornerTR.
  ///
  /// In vi, this message translates to:
  /// **'Trên phải'**
  String get cornerTR;

  /// No description provided for @cornerBL.
  ///
  /// In vi, this message translates to:
  /// **'Dưới trái'**
  String get cornerBL;

  /// No description provided for @cornerBR.
  ///
  /// In vi, this message translates to:
  /// **'Dưới phải'**
  String get cornerBR;

  /// No description provided for @markShake.
  ///
  /// In vi, this message translates to:
  /// **'Lắc máy để đánh dấu'**
  String get markShake;

  /// No description provided for @markShakeHint.
  ///
  /// In vi, this message translates to:
  /// **'Lắc hai lần để bắt đầu đánh dấu. Cú lắc có thể làm rung video.'**
  String get markShakeHint;

  /// No description provided for @markDotNote.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn giữ chấm để mở thanh điều khiển và đổi dấu (video tạm dừng khi chọn dấu, nên bảng chọn không lọt vào video).'**
  String get markDotNote;

  /// No description provided for @markCleanNote.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ sạch cũng có nút “Đánh dấu” trong thông báo. Vùng ẩn ở góc không nhìn thấy trong video.'**
  String get markCleanNote;

  /// No description provided for @toolAuto.
  ///
  /// In vi, this message translates to:
  /// **'Tự động'**
  String get toolAuto;

  /// No description provided for @autoTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dựng tự động'**
  String get autoTitle;

  /// No description provided for @autoHint.
  ///
  /// In vi, this message translates to:
  /// **'Tự phóng to vào chỗ đánh dấu, đánh số lại các bước và tua nhanh đoạn màn hình đứng yên. Mọi thứ vẫn sửa và hoàn tác được.'**
  String get autoHint;

  /// No description provided for @autoZoomOpt.
  ///
  /// In vi, this message translates to:
  /// **'Phóng to vào dấu'**
  String get autoZoomOpt;

  /// No description provided for @autoNumberOpt.
  ///
  /// In vi, this message translates to:
  /// **'Đánh số lại các bước'**
  String get autoNumberOpt;

  /// No description provided for @autoIdleOpt.
  ///
  /// In vi, this message translates to:
  /// **'Tua nhanh đoạn đứng yên'**
  String get autoIdleOpt;

  /// No description provided for @autoRun.
  ///
  /// In vi, this message translates to:
  /// **'Dựng tự động'**
  String get autoRun;

  /// No description provided for @autoRunning.
  ///
  /// In vi, this message translates to:
  /// **'Đang phân tích video…'**
  String get autoRunning;

  /// No description provided for @autoDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong: {zooms} phóng to, {steps} bước đánh số, {idle} đoạn tua nhanh.'**
  String autoDone(int zooms, int steps, int idle);

  /// No description provided for @autoNothing.
  ///
  /// In vi, this message translates to:
  /// **'Không có gì để dựng thêm. Hãy thêm dấu hoặc quay đoạn dài hơn.'**
  String get autoNothing;

  /// No description provided for @autoAfterRec.
  ///
  /// In vi, this message translates to:
  /// **'Sau khi quay sạch'**
  String get autoAfterRec;

  /// No description provided for @onbSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp'**
  String get onbNext;

  /// No description provided for @onbStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu dùng'**
  String get onbStart;

  /// No description provided for @onbTitle1.
  ///
  /// In vi, this message translates to:
  /// **'Người xem luôn biết bạn sắp bấm vào đâu'**
  String get onbTitle1;

  /// No description provided for @onbBody1.
  ///
  /// In vi, this message translates to:
  /// **'Dấu hiện lên trước, màn hình đổi sau. Video hướng dẫn của bạn dễ theo dõi hơn nhiều.'**
  String get onbBody1;

  /// No description provided for @onbTitle2.
  ///
  /// In vi, this message translates to:
  /// **'Ba bước để chỉ điểm'**
  String get onbTitle2;

  /// No description provided for @onbStep1.
  ///
  /// In vi, this message translates to:
  /// **'Khi đang quay, bật chế độ chỉ điểm trên thanh nổi, chọn dấu rồi đặt lên đích.'**
  String get onbStep1;

  /// No description provided for @onbStep2.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ tự tắt sau khi đặt. Dấu vòng vàng thu vào đích, rồi giữ lại vài giây.'**
  String get onbStep2;

  /// No description provided for @onbStep3.
  ///
  /// In vi, this message translates to:
  /// **'Bấm thật vào đích. Người xem đã biết cần nhìn vào đâu.'**
  String get onbStep3;

  /// No description provided for @onbTitle3.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép vài quyền'**
  String get onbTitle3;

  /// No description provided for @onbBody3.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ xin những quyền thật sự cần. Video luôn nằm trên máy của bạn.'**
  String get onbBody3;

  /// No description provided for @permOverlayTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hiện trên ứng dụng khác'**
  String get permOverlayTitle;

  /// No description provided for @permOverlayBody.
  ///
  /// In vi, this message translates to:
  /// **'Để hiện thanh nổi, đếm ngược và dấu đánh dấu trên màn hình lúc quay.'**
  String get permOverlayBody;

  /// No description provided for @permMicTitle.
  ///
  /// In vi, this message translates to:
  /// **'Micro'**
  String get permMicTitle;

  /// No description provided for @permMicBody.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ dùng khi bạn chọn quay có tiếng.'**
  String get permMicBody;

  /// No description provided for @permNotifTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get permNotifTitle;

  /// No description provided for @permNotifBody.
  ///
  /// In vi, this message translates to:
  /// **'Hiện nút Tạm dừng và Dừng khi đang quay.'**
  String get permNotifBody;

  /// No description provided for @permBatteryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quay lâu không bị ngắt'**
  String get permBatteryTitle;

  /// No description provided for @permBatteryBody.
  ///
  /// In vi, this message translates to:
  /// **'Một số máy (Xiaomi, Oppo, Vivo, Samsung) tự tắt ứng dụng chạy nền. Vào cài đặt ứng dụng và đặt Pin thành không hạn chế.'**
  String get permBatteryBody;

  /// No description provided for @permGranted.
  ///
  /// In vi, this message translates to:
  /// **'Đã cấp'**
  String get permGranted;

  /// No description provided for @permGrant.
  ///
  /// In vi, this message translates to:
  /// **'Cấp quyền'**
  String get permGrant;

  /// No description provided for @permOpenSettings.
  ///
  /// In vi, this message translates to:
  /// **'Mở cài đặt ứng dụng'**
  String get permOpenSettings;

  /// No description provided for @settingsPermissions.
  ///
  /// In vi, this message translates to:
  /// **'Quyền và pin'**
  String get settingsPermissions;

  /// No description provided for @settingsPermissionsSub.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra các quyền cần để quay'**
  String get settingsPermissionsSub;

  /// No description provided for @settingsGuide.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn'**
  String get settingsGuide;

  /// No description provided for @settingsGuideSub.
  ///
  /// In vi, this message translates to:
  /// **'Xem lại cách dùng dấu báo trước'**
  String get settingsGuideSub;

  /// No description provided for @settingsPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Quyền riêng tư'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacySub.
  ///
  /// In vi, this message translates to:
  /// **'Video ở lại trên máy của bạn'**
  String get settingsPrivacySub;

  /// No description provided for @settingsAbout.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSub.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản và thông tin ứng dụng'**
  String get settingsAboutSub;

  /// No description provided for @aboutVersion.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản {v}'**
  String aboutVersion(String v);

  /// No description provided for @aboutBody.
  ///
  /// In vi, this message translates to:
  /// **'E Screen Recorder là ứng dụng quay màn hình miễn phí, không quảng cáo, không cần tài khoản.'**
  String get aboutBody;

  /// No description provided for @aboutLicenses.
  ///
  /// In vi, this message translates to:
  /// **'Phông chữ Barlow theo giấy phép SIL OFL. Biểu tượng bàn tay dựa trên Material Icons (Apache-2.0).'**
  String get aboutLicenses;

  /// No description provided for @privacyH1.
  ///
  /// In vi, this message translates to:
  /// **'Video ở lại trên máy'**
  String get privacyH1;

  /// No description provided for @privacyP1.
  ///
  /// In vi, this message translates to:
  /// **'Mọi video, dự án chỉnh sửa và ảnh chụp đều được lưu trên chính thiết bị của bạn. Ứng dụng không tải video, âm thanh hay màn hình lên máy chủ nào.'**
  String get privacyP1;

  /// No description provided for @privacyH2.
  ///
  /// In vi, this message translates to:
  /// **'Không tài khoản, không theo dõi'**
  String get privacyH2;

  /// No description provided for @privacyP2.
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng không yêu cầu đăng nhập, không có quảng cáo và không thu thập số liệu sử dụng hay định danh thiết bị.'**
  String get privacyP2;

  /// No description provided for @privacyH3.
  ///
  /// In vi, this message translates to:
  /// **'Quyền dùng để làm gì'**
  String get privacyH3;

  /// No description provided for @privacyP3.
  ///
  /// In vi, this message translates to:
  /// **'Quay màn hình: để ghi lại nội dung hiển thị khi bạn đồng ý trong hộp thoại của hệ thống. Micro: chỉ khi bạn chọn quay có tiếng. Hiện trên ứng dụng khác: để hiện thanh điều khiển và dấu đánh dấu. Thông báo: để hiện nút Tạm dừng và Dừng.'**
  String get privacyP3;

  /// No description provided for @privacyH4.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung nhạy cảm'**
  String get privacyH4;

  /// No description provided for @privacyP4.
  ///
  /// In vi, this message translates to:
  /// **'Video quay màn hình có thể chứa mật khẩu, tin nhắn hay số điện thoại. Hãy dùng khối che trong trình chỉnh sửa trước khi chia sẻ. Ứng dụng chỉ chia sẻ khi bạn chọn Chia sẻ.'**
  String get privacyP4;

  /// No description provided for @privacyH5.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dữ liệu'**
  String get privacyH5;

  /// No description provided for @privacyP5.
  ///
  /// In vi, this message translates to:
  /// **'Xoá video trong Thư viện hoặc gỡ cài đặt ứng dụng để xoá dự án chỉnh sửa. Video đã xuất nằm trong thư mục Movies/E Screen Recorder và Pictures/E Screen Recorder.'**
  String get privacyP5;

  /// No description provided for @toolCut.
  ///
  /// In vi, this message translates to:
  /// **'Cắt'**
  String get toolCut;

  /// No description provided for @toolMarker.
  ///
  /// In vi, this message translates to:
  /// **'Dấu'**
  String get toolMarker;

  /// No description provided for @toolText.
  ///
  /// In vi, this message translates to:
  /// **'Chữ'**
  String get toolText;

  /// No description provided for @toolCover.
  ///
  /// In vi, this message translates to:
  /// **'Che'**
  String get toolCover;

  /// No description provided for @toolZoom.
  ///
  /// In vi, this message translates to:
  /// **'Phóng'**
  String get toolZoom;

  /// No description provided for @splitHere.
  ///
  /// In vi, this message translates to:
  /// **'Cắt tại đây'**
  String get splitHere;

  /// No description provided for @deleteSegment.
  ///
  /// In vi, this message translates to:
  /// **'Xoá đoạn'**
  String get deleteSegment;

  /// No description provided for @moveLeft.
  ///
  /// In vi, this message translates to:
  /// **'Dịch đoạn sang trái'**
  String get moveLeft;

  /// No description provided for @moveRight.
  ///
  /// In vi, this message translates to:
  /// **'Dịch đoạn sang phải'**
  String get moveRight;

  /// No description provided for @segmentSpeed.
  ///
  /// In vi, this message translates to:
  /// **'Tốc độ đoạn này'**
  String get segmentSpeed;

  /// No description provided for @trimHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm đoạn trên timeline rồi kéo hai đầu để cắt bớt.'**
  String get trimHint;

  /// No description provided for @markerAddHint.
  ///
  /// In vi, this message translates to:
  /// **'Đưa đầu phát tới đúng lúc bạn bấm. Dấu sẽ hiện báo trước 0,5 giây, rồi mới tới lúc bấm.'**
  String get markerAddHint;

  /// No description provided for @clipHold.
  ///
  /// In vi, this message translates to:
  /// **'Giữ dấu'**
  String get clipHold;

  /// No description provided for @clipLength.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng'**
  String get clipLength;

  /// No description provided for @textAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chữ'**
  String get textAdd;

  /// No description provided for @textHint.
  ///
  /// In vi, this message translates to:
  /// **'Chữ nằm trên video và không bị phóng to theo hiệu ứng phóng.'**
  String get textHint;

  /// No description provided for @textField.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung'**
  String get textField;

  /// No description provided for @textSize.
  ///
  /// In vi, this message translates to:
  /// **'Cỡ chữ'**
  String get textSize;

  /// No description provided for @coverAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vùng'**
  String get coverAdd;

  /// No description provided for @coverStyleSolid.
  ///
  /// In vi, this message translates to:
  /// **'Khối đặc'**
  String get coverStyleSolid;

  /// No description provided for @coverStyleBlur.
  ///
  /// In vi, this message translates to:
  /// **'Làm mờ'**
  String get coverStyleBlur;

  /// No description provided for @coverStyleMosaic.
  ///
  /// In vi, this message translates to:
  /// **'Mosaic'**
  String get coverStyleMosaic;

  /// No description provided for @coverStyleSpotlight.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu điểm'**
  String get coverStyleSpotlight;

  /// No description provided for @coverStrength.
  ///
  /// In vi, this message translates to:
  /// **'Cường độ'**
  String get coverStrength;

  /// No description provided for @coverMove.
  ///
  /// In vi, this message translates to:
  /// **'Di chuyển'**
  String get coverMove;

  /// No description provided for @coverMoveHint.
  ///
  /// In vi, this message translates to:
  /// **'Vùng trượt mượt từ điểm đầu tới điểm cuối trong suốt thời gian của nó. Chọn điểm rồi kéo trên video.'**
  String get coverMoveHint;

  /// No description provided for @coverPointStart.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đầu'**
  String get coverPointStart;

  /// No description provided for @coverPointEnd.
  ///
  /// In vi, this message translates to:
  /// **'Điểm cuối'**
  String get coverPointEnd;

  /// No description provided for @coverHint.
  ///
  /// In vi, this message translates to:
  /// **'Che số điện thoại, mật khẩu… bằng khối đặc, làm mờ hoặc mosaic; hoặc làm tối phần còn lại để nhấn mạnh một vùng (tiêu điểm). Kéo trên video để đặt vị trí.'**
  String get coverHint;

  /// No description provided for @coverWidth.
  ///
  /// In vi, this message translates to:
  /// **'Rộng'**
  String get coverWidth;

  /// No description provided for @coverHeight.
  ///
  /// In vi, this message translates to:
  /// **'Cao'**
  String get coverHeight;

  /// No description provided for @zoomAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phóng to'**
  String get zoomAdd;

  /// No description provided for @zoomHint.
  ///
  /// In vi, this message translates to:
  /// **'Phóng to vào một vùng rồi thu lại êm ái.'**
  String get zoomHint;

  /// No description provided for @zoomScale.
  ///
  /// In vi, this message translates to:
  /// **'Mức phóng'**
  String get zoomScale;

  /// No description provided for @zoomIn.
  ///
  /// In vi, this message translates to:
  /// **'Phóng vào'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In vi, this message translates to:
  /// **'Thu lại'**
  String get zoomOut;

  /// No description provided for @zoomHold.
  ///
  /// In vi, this message translates to:
  /// **'Giữ thêm'**
  String get zoomHold;

  /// No description provided for @zoomTimingHint.
  ///
  /// In vi, this message translates to:
  /// **'Phóng vào/Thu lại là thời gian để phóng tới mức đầy đủ và để trở về; càng ngắn càng nhanh. Giữ thêm là thời gian vẫn phóng sau khi dấu đã mờ.'**
  String get zoomTimingHint;

  /// No description provided for @zoomAutoTuning.
  ///
  /// In vi, this message translates to:
  /// **'Tinh chỉnh phóng tự động'**
  String get zoomAutoTuning;

  /// No description provided for @zoomDragHint.
  ///
  /// In vi, this message translates to:
  /// **'Kéo trên video để chọn vùng sẽ phóng vào.'**
  String get zoomDragHint;

  /// No description provided for @undo.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In vi, this message translates to:
  /// **'Làm lại'**
  String get redo;

  /// No description provided for @exportAction.
  ///
  /// In vi, this message translates to:
  /// **'Xuất'**
  String get exportAction;

  /// No description provided for @exportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xuất video'**
  String get exportTitle;

  /// No description provided for @exportSummary.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng {duration}'**
  String exportSummary(String duration);

  /// No description provided for @exportFormat.
  ///
  /// In vi, this message translates to:
  /// **'Định dạng'**
  String get exportFormat;

  /// No description provided for @formatMp4.
  ///
  /// In vi, this message translates to:
  /// **'MP4'**
  String get formatMp4;

  /// No description provided for @formatGif.
  ///
  /// In vi, this message translates to:
  /// **'GIF'**
  String get formatGif;

  /// No description provided for @exportQuality.
  ///
  /// In vi, this message translates to:
  /// **'Chất lượng'**
  String get exportQuality;

  /// No description provided for @qualityOriginal.
  ///
  /// In vi, this message translates to:
  /// **'Gốc'**
  String get qualityOriginal;

  /// No description provided for @resolution480.
  ///
  /// In vi, this message translates to:
  /// **'480p'**
  String get resolution480;

  /// No description provided for @gifHint.
  ///
  /// In vi, this message translates to:
  /// **'GIF nhẹ, không có tiếng. Đẹp nhất với đoạn ngắn dưới 15 giây.'**
  String get gifHint;

  /// No description provided for @exportStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu xuất'**
  String get exportStart;

  /// No description provided for @exportRunning.
  ///
  /// In vi, this message translates to:
  /// **'Đang xuất {pct}%'**
  String exportRunning(int pct);

  /// No description provided for @exportDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã xuất xong'**
  String get exportDone;

  /// No description provided for @exportError.
  ///
  /// In vi, this message translates to:
  /// **'Xuất không thành công. Hãy thử lại.'**
  String get exportError;

  /// No description provided for @timelineSummary.
  ///
  /// In vi, this message translates to:
  /// **'Dòng thời gian: {segments} đoạn, {markers} dấu, {texts} chữ, {covers} khối che, {zooms} phóng to'**
  String timelineSummary(
    int segments,
    int markers,
    int texts,
    int covers,
    int zooms,
  );

  /// No description provided for @selectMode.
  ///
  /// In vi, this message translates to:
  /// **'Chọn'**
  String get selectMode;

  /// No description provided for @selectedCount.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn {n}'**
  String selectedCount(int n);

  /// No description provided for @joinAction.
  ///
  /// In vi, this message translates to:
  /// **'Ghép'**
  String get joinAction;

  /// No description provided for @joinTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ghép video'**
  String get joinTitle;

  /// No description provided for @joinSummary.
  ///
  /// In vi, this message translates to:
  /// **'Ghép {n} video theo thứ tự đã chọn.'**
  String joinSummary(int n);

  /// No description provided for @joinDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghép xong'**
  String get joinDone;

  /// No description provided for @resetProject.
  ///
  /// In vi, this message translates to:
  /// **'Làm lại từ đầu'**
  String get resetProject;

  /// No description provided for @resetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ mọi chỉnh sửa?'**
  String get resetTitle;

  /// No description provided for @resetBody.
  ///
  /// In vi, this message translates to:
  /// **'Video gốc không bị ảnh hưởng. Bạn vẫn có thể bấm Hoàn tác ngay sau đó.'**
  String get resetBody;

  /// No description provided for @seekBack.
  ///
  /// In vi, this message translates to:
  /// **'Lùi 1 giây'**
  String get seekBack;

  /// No description provided for @seekForward.
  ///
  /// In vi, this message translates to:
  /// **'Tiến 1 giây'**
  String get seekForward;

  /// No description provided for @timelineZoomOut.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhỏ timeline'**
  String get timelineZoomOut;

  /// No description provided for @timelineZoomIn.
  ///
  /// In vi, this message translates to:
  /// **'Phóng to timeline'**
  String get timelineZoomIn;

  /// No description provided for @editorLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được video để chỉnh sửa.'**
  String get editorLoadError;

  /// No description provided for @settingsTheme.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In vi, this message translates to:
  /// **'Theo hệ thống'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get themeDark;

  /// No description provided for @toolSpeed.
  ///
  /// In vi, this message translates to:
  /// **'Tốc độ'**
  String get toolSpeed;

  /// No description provided for @toolTransition.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển cảnh'**
  String get toolTransition;

  /// No description provided for @toolAudio.
  ///
  /// In vi, this message translates to:
  /// **'Âm thanh'**
  String get toolAudio;

  /// No description provided for @editFreeze.
  ///
  /// In vi, this message translates to:
  /// **'Đóng băng khung'**
  String get editFreeze;

  /// No description provided for @editDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Nhân đôi'**
  String get editDuplicate;

  /// No description provided for @editBlank.
  ///
  /// In vi, this message translates to:
  /// **'Để trống'**
  String get editBlank;

  /// No description provided for @editMultiSelect.
  ///
  /// In vi, this message translates to:
  /// **'Chọn nhiều'**
  String get editMultiSelect;

  /// No description provided for @editMultiHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm các đoạn để chọn; thao tác áp cho tất cả đoạn đã chọn.'**
  String get editMultiHint;

  /// No description provided for @frameBack.
  ///
  /// In vi, this message translates to:
  /// **'Lùi 1 khung hình'**
  String get frameBack;

  /// No description provided for @frameForward.
  ///
  /// In vi, this message translates to:
  /// **'Tiến 1 khung hình'**
  String get frameForward;

  /// No description provided for @enterFullscreen.
  ///
  /// In vi, this message translates to:
  /// **'Xem toàn màn hình'**
  String get enterFullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In vi, this message translates to:
  /// **'Thoát toàn màn hình'**
  String get exitFullscreen;

  /// No description provided for @toolsHide.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn công cụ'**
  String get toolsHide;

  /// No description provided for @toolsShow.
  ///
  /// In vi, this message translates to:
  /// **'Hiện công cụ'**
  String get toolsShow;

  /// No description provided for @presetClassic.
  ///
  /// In vi, this message translates to:
  /// **'Cổ điển'**
  String get presetClassic;

  /// No description provided for @presetSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Phụ đề'**
  String get presetSubtitle;

  /// No description provided for @presetYellow.
  ///
  /// In vi, this message translates to:
  /// **'Vàng'**
  String get presetYellow;

  /// No description provided for @presetNeon.
  ///
  /// In vi, this message translates to:
  /// **'Neon'**
  String get presetNeon;

  /// No description provided for @presetClean.
  ///
  /// In vi, this message translates to:
  /// **'Gọn'**
  String get presetClean;

  /// No description provided for @presetLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhãn'**
  String get presetLabel;

  /// No description provided for @subtitlesImport.
  ///
  /// In vi, this message translates to:
  /// **'Nhập phụ đề (.srt)'**
  String get subtitlesImport;

  /// No description provided for @subtitlesImported.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm {n} dòng phụ đề.'**
  String subtitlesImported(int n);

  /// No description provided for @subtitlesNone.
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được dòng phụ đề nào trong tệp này.'**
  String get subtitlesNone;

  /// No description provided for @timelineFit.
  ///
  /// In vi, this message translates to:
  /// **'Vừa khung'**
  String get timelineFit;

  /// No description provided for @reorderHint.
  ///
  /// In vi, this message translates to:
  /// **'Giữ một đoạn rồi trượt ngang để đổi thứ tự.'**
  String get reorderHint;

  /// No description provided for @speedFree.
  ///
  /// In vi, this message translates to:
  /// **'Tốc độ tự do'**
  String get speedFree;

  /// No description provided for @speedRamp.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tốc độ dần'**
  String get speedRamp;

  /// No description provided for @speedRampFrom.
  ///
  /// In vi, this message translates to:
  /// **'Đầu đoạn'**
  String get speedRampFrom;

  /// No description provided for @speedRampTo.
  ///
  /// In vi, this message translates to:
  /// **'Cuối đoạn'**
  String get speedRampTo;

  /// No description provided for @speedReverse.
  ///
  /// In vi, this message translates to:
  /// **'Chạy ngược'**
  String get speedReverse;

  /// No description provided for @speedReverseHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạy ngược không có tiếng và tối đa 30 giây cho mỗi đoạn.'**
  String get speedReverseHint;

  /// No description provided for @speedStillHint.
  ///
  /// In vi, this message translates to:
  /// **'Đây là khung đóng băng: chỉ chỉnh được thời lượng.'**
  String get speedStillHint;

  /// No description provided for @freezeLength.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng đóng băng'**
  String get freezeLength;

  /// No description provided for @transNone.
  ///
  /// In vi, this message translates to:
  /// **'Không'**
  String get transNone;

  /// No description provided for @transDipBlack.
  ///
  /// In vi, this message translates to:
  /// **'Mờ qua đen'**
  String get transDipBlack;

  /// No description provided for @transDipWhite.
  ///
  /// In vi, this message translates to:
  /// **'Mờ qua trắng'**
  String get transDipWhite;

  /// No description provided for @transSlideLeft.
  ///
  /// In vi, this message translates to:
  /// **'Trượt trái'**
  String get transSlideLeft;

  /// No description provided for @transSlideRight.
  ///
  /// In vi, this message translates to:
  /// **'Trượt phải'**
  String get transSlideRight;

  /// No description provided for @transSlideUp.
  ///
  /// In vi, this message translates to:
  /// **'Trượt lên'**
  String get transSlideUp;

  /// No description provided for @transSlideDown.
  ///
  /// In vi, this message translates to:
  /// **'Trượt xuống'**
  String get transSlideDown;

  /// No description provided for @transZoom.
  ///
  /// In vi, this message translates to:
  /// **'Phóng mờ'**
  String get transZoom;

  /// No description provided for @transLength.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng'**
  String get transLength;

  /// No description provided for @transApplyAll.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng mọi điểm cắt'**
  String get transApplyAll;

  /// No description provided for @transFirstHint.
  ///
  /// In vi, this message translates to:
  /// **'Đoạn đầu không có chuyển cảnh. Chọn đoạn từ thứ 2 trở đi.'**
  String get transFirstHint;

  /// No description provided for @transHint.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển cảnh nằm ở chỗ nối vào đoạn đang chọn; tổng thời lượng video không đổi.'**
  String get transHint;

  /// No description provided for @audioVolume.
  ///
  /// In vi, this message translates to:
  /// **'Âm lượng'**
  String get audioVolume;

  /// No description provided for @audioMute.
  ///
  /// In vi, this message translates to:
  /// **'Tắt tiếng đoạn này'**
  String get audioMute;

  /// No description provided for @audioFadeIn.
  ///
  /// In vi, this message translates to:
  /// **'Mờ vào'**
  String get audioFadeIn;

  /// No description provided for @audioFadeOut.
  ///
  /// In vi, this message translates to:
  /// **'Mờ ra'**
  String get audioFadeOut;

  /// No description provided for @audioStillHint.
  ///
  /// In vi, this message translates to:
  /// **'Khung đóng băng và đoạn trống không có tiếng.'**
  String get audioStillHint;

  /// No description provided for @toolPicture.
  ///
  /// In vi, this message translates to:
  /// **'Hình'**
  String get toolPicture;

  /// No description provided for @toolOverlay.
  ///
  /// In vi, this message translates to:
  /// **'Lớp phủ'**
  String get toolOverlay;

  /// No description provided for @picRotate.
  ///
  /// In vi, this message translates to:
  /// **'Xoay 90°'**
  String get picRotate;

  /// No description provided for @picTilt.
  ///
  /// In vi, this message translates to:
  /// **'Xoay tự do'**
  String get picTilt;

  /// No description provided for @picTiltReset.
  ///
  /// In vi, this message translates to:
  /// **'Làm thẳng'**
  String get picTiltReset;

  /// No description provided for @picCrop.
  ///
  /// In vi, this message translates to:
  /// **'Cắt khung'**
  String get picCrop;

  /// No description provided for @picCropReset.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ cắt khung'**
  String get picCropReset;

  /// No description provided for @picAspect.
  ///
  /// In vi, this message translates to:
  /// **'Tỉ lệ khung xuất'**
  String get picAspect;

  /// No description provided for @aspectAuto.
  ///
  /// In vi, this message translates to:
  /// **'Gốc'**
  String get aspectAuto;

  /// No description provided for @aspect916.
  ///
  /// In vi, this message translates to:
  /// **'9:16'**
  String get aspect916;

  /// No description provided for @aspect11.
  ///
  /// In vi, this message translates to:
  /// **'1:1'**
  String get aspect11;

  /// No description provided for @aspect45.
  ///
  /// In vi, this message translates to:
  /// **'4:5'**
  String get aspect45;

  /// No description provided for @aspect169.
  ///
  /// In vi, this message translates to:
  /// **'16:9'**
  String get aspect169;

  /// No description provided for @picFit.
  ///
  /// In vi, this message translates to:
  /// **'Viền đen'**
  String get picFit;

  /// No description provided for @picFill.
  ///
  /// In vi, this message translates to:
  /// **'Lấp đầy'**
  String get picFill;

  /// No description provided for @picFitHint.
  ///
  /// In vi, this message translates to:
  /// **'Khung khác tỉ lệ: thêm viền đen hoặc lấp đầy và cắt phần thừa.'**
  String get picFitHint;

  /// No description provided for @picFilters.
  ///
  /// In vi, this message translates to:
  /// **'Màu sắc'**
  String get picFilters;

  /// No description provided for @presetNone.
  ///
  /// In vi, this message translates to:
  /// **'Gốc'**
  String get presetNone;

  /// No description provided for @presetVivid.
  ///
  /// In vi, this message translates to:
  /// **'Rực rỡ'**
  String get presetVivid;

  /// No description provided for @presetWarm.
  ///
  /// In vi, this message translates to:
  /// **'Ấm'**
  String get presetWarm;

  /// No description provided for @presetCool.
  ///
  /// In vi, this message translates to:
  /// **'Lạnh'**
  String get presetCool;

  /// No description provided for @presetBw.
  ///
  /// In vi, this message translates to:
  /// **'Đen trắng'**
  String get presetBw;

  /// No description provided for @presetVintage.
  ///
  /// In vi, this message translates to:
  /// **'Hoài cổ'**
  String get presetVintage;

  /// No description provided for @presetFade.
  ///
  /// In vi, this message translates to:
  /// **'Nhạt'**
  String get presetFade;

  /// No description provided for @colorBrightness.
  ///
  /// In vi, this message translates to:
  /// **'Độ sáng'**
  String get colorBrightness;

  /// No description provided for @colorContrast.
  ///
  /// In vi, this message translates to:
  /// **'Tương phản'**
  String get colorContrast;

  /// No description provided for @colorSaturation.
  ///
  /// In vi, this message translates to:
  /// **'Bão hoà'**
  String get colorSaturation;

  /// No description provided for @colorWarmth.
  ///
  /// In vi, this message translates to:
  /// **'Nhiệt độ'**
  String get colorWarmth;

  /// No description provided for @picRotateNote.
  ///
  /// In vi, this message translates to:
  /// **'Xoay và cắt khung nên làm trước khi thêm dấu; dấu đã đặt có thể lệch.'**
  String get picRotateNote;

  /// No description provided for @cropTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cắt khung hình'**
  String get cropTitle;

  /// No description provided for @cropDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get cropDone;

  /// No description provided for @ovAddImage.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh'**
  String get ovAddImage;

  /// No description provided for @ovAddPip.
  ///
  /// In vi, this message translates to:
  /// **'Hình trong hình'**
  String get ovAddPip;

  /// No description provided for @ovPipHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh hoặc video ngắn (tối đa 30 giây) đặt ở góc màn hình.'**
  String get ovPipHint;

  /// No description provided for @shapeRect.
  ///
  /// In vi, this message translates to:
  /// **'Khung chữ nhật'**
  String get shapeRect;

  /// No description provided for @shapeEllipse.
  ///
  /// In vi, this message translates to:
  /// **'Hình tròn'**
  String get shapeEllipse;

  /// No description provided for @shapeLine.
  ///
  /// In vi, this message translates to:
  /// **'Đường thẳng'**
  String get shapeLine;

  /// No description provided for @shapeArrow.
  ///
  /// In vi, this message translates to:
  /// **'Mũi tên'**
  String get shapeArrow;

  /// No description provided for @shapeBubble.
  ///
  /// In vi, this message translates to:
  /// **'Chú thích'**
  String get shapeBubble;

  /// No description provided for @ovWidth.
  ///
  /// In vi, this message translates to:
  /// **'Độ rộng'**
  String get ovWidth;

  /// No description provided for @ovOpacity.
  ///
  /// In vi, this message translates to:
  /// **'Độ mờ'**
  String get ovOpacity;

  /// No description provided for @ovRotation.
  ///
  /// In vi, this message translates to:
  /// **'Xoay'**
  String get ovRotation;

  /// No description provided for @ovStroke.
  ///
  /// In vi, this message translates to:
  /// **'Độ dày nét'**
  String get ovStroke;

  /// No description provided for @ovFilled.
  ///
  /// In vi, this message translates to:
  /// **'Tô đầy'**
  String get ovFilled;

  /// No description provided for @ovBubbleText.
  ///
  /// In vi, this message translates to:
  /// **'Chữ trong chú thích'**
  String get ovBubbleText;

  /// No description provided for @ovPipVolume.
  ///
  /// In vi, this message translates to:
  /// **'Âm thanh'**
  String get ovPipVolume;

  /// No description provided for @ovPipStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu tại'**
  String get ovPipStart;

  /// No description provided for @ovPipLength.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng'**
  String get ovPipLength;

  /// No description provided for @ovHint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh, hình vẽ, chú thích hoặc hình trong hình; kéo trên màn hình để đặt vị trí, chụm hai ngón để đổi cỡ và xoay.'**
  String get ovHint;

  /// No description provided for @motionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển động'**
  String get motionTitle;

  /// No description provided for @motionEnter.
  ///
  /// In vi, this message translates to:
  /// **'Xuất hiện'**
  String get motionEnter;

  /// No description provided for @motionExit.
  ///
  /// In vi, this message translates to:
  /// **'Biến mất'**
  String get motionExit;

  /// No description provided for @motionNone.
  ///
  /// In vi, this message translates to:
  /// **'Không'**
  String get motionNone;

  /// No description provided for @motionFade.
  ///
  /// In vi, this message translates to:
  /// **'Mờ dần'**
  String get motionFade;

  /// No description provided for @motionPop.
  ///
  /// In vi, this message translates to:
  /// **'Nảy lên'**
  String get motionPop;

  /// No description provided for @motionSlideUp.
  ///
  /// In vi, this message translates to:
  /// **'Trượt lên'**
  String get motionSlideUp;

  /// No description provided for @motionSlideDown.
  ///
  /// In vi, this message translates to:
  /// **'Trượt xuống'**
  String get motionSlideDown;

  /// No description provided for @motionSlideLeft.
  ///
  /// In vi, this message translates to:
  /// **'Trượt trái'**
  String get motionSlideLeft;

  /// No description provided for @motionSlideRight.
  ///
  /// In vi, this message translates to:
  /// **'Trượt phải'**
  String get motionSlideRight;

  /// No description provided for @motionKeyframe.
  ///
  /// In vi, this message translates to:
  /// **'Di chuyển đến vị trí cuối'**
  String get motionKeyframe;

  /// No description provided for @motionSetEnd.
  ///
  /// In vi, this message translates to:
  /// **'Đặt vị trí hiện tại làm điểm cuối'**
  String get motionSetEnd;

  /// No description provided for @motionClear.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chuyển động'**
  String get motionClear;

  /// No description provided for @motionEase.
  ///
  /// In vi, this message translates to:
  /// **'Nhịp chuyển động'**
  String get motionEase;

  /// No description provided for @easeLinear.
  ///
  /// In vi, this message translates to:
  /// **'Đều'**
  String get easeLinear;

  /// No description provided for @easeIn.
  ///
  /// In vi, this message translates to:
  /// **'Chậm rồi nhanh'**
  String get easeIn;

  /// No description provided for @easeOut.
  ///
  /// In vi, this message translates to:
  /// **'Nhanh rồi chậm'**
  String get easeOut;

  /// No description provided for @easeInOut.
  ///
  /// In vi, this message translates to:
  /// **'Mượt'**
  String get easeInOut;

  /// No description provided for @textFont.
  ///
  /// In vi, this message translates to:
  /// **'Phông chữ'**
  String get textFont;

  /// No description provided for @fontBarlow.
  ///
  /// In vi, this message translates to:
  /// **'Barlow'**
  String get fontBarlow;

  /// No description provided for @fontSans.
  ///
  /// In vi, this message translates to:
  /// **'Hiện đại'**
  String get fontSans;

  /// No description provided for @fontCondensed.
  ///
  /// In vi, this message translates to:
  /// **'Hẹp'**
  String get fontCondensed;

  /// No description provided for @fontSerif.
  ///
  /// In vi, this message translates to:
  /// **'Có chân'**
  String get fontSerif;

  /// No description provided for @fontMono.
  ///
  /// In vi, this message translates to:
  /// **'Đơn cách'**
  String get fontMono;

  /// No description provided for @fontCursive.
  ///
  /// In vi, this message translates to:
  /// **'Viết tay'**
  String get fontCursive;

  /// No description provided for @textOutline.
  ///
  /// In vi, this message translates to:
  /// **'Viền chữ'**
  String get textOutline;

  /// No description provided for @textBox.
  ///
  /// In vi, this message translates to:
  /// **'Nền chữ'**
  String get textBox;

  /// No description provided for @textShadow.
  ///
  /// In vi, this message translates to:
  /// **'Đổ bóng'**
  String get textShadow;

  /// No description provided for @textBold.
  ///
  /// In vi, this message translates to:
  /// **'In đậm'**
  String get textBold;

  /// No description provided for @textAlignLabel.
  ///
  /// In vi, this message translates to:
  /// **'Căn lề'**
  String get textAlignLabel;

  /// No description provided for @alignLeft.
  ///
  /// In vi, this message translates to:
  /// **'Trái'**
  String get alignLeft;

  /// No description provided for @alignCenter.
  ///
  /// In vi, this message translates to:
  /// **'Giữa'**
  String get alignCenter;

  /// No description provided for @alignRight.
  ///
  /// In vi, this message translates to:
  /// **'Phải'**
  String get alignRight;

  /// No description provided for @autoStepLabels.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chữ Bước N cho dấu số'**
  String get autoStepLabels;

  /// No description provided for @audioTracks.
  ///
  /// In vi, this message translates to:
  /// **'Nhạc và giọng nói'**
  String get audioTracks;

  /// No description provided for @audioAddMusic.
  ///
  /// In vi, this message translates to:
  /// **'Thêm nhạc từ máy'**
  String get audioAddMusic;

  /// No description provided for @audioRecordVoice.
  ///
  /// In vi, this message translates to:
  /// **'Thu giọng nói'**
  String get audioRecordVoice;

  /// No description provided for @audioStopVoice.
  ///
  /// In vi, this message translates to:
  /// **'Dừng thu'**
  String get audioStopVoice;

  /// No description provided for @audioVoiceHint.
  ///
  /// In vi, this message translates to:
  /// **'Nên dùng tai nghe để giọng nói không lẫn tiếng từ loa.'**
  String get audioVoiceHint;

  /// No description provided for @audioStartAt.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu tại'**
  String get audioStartAt;

  /// No description provided for @audioLoop.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại đến hết video'**
  String get audioLoop;

  /// No description provided for @audioDuck.
  ///
  /// In vi, this message translates to:
  /// **'Hạ nhạc khi có giọng nói'**
  String get audioDuck;

  /// No description provided for @audioNormalize.
  ///
  /// In vi, this message translates to:
  /// **'Chuẩn hoá âm lượng'**
  String get audioNormalize;

  /// No description provided for @audioNormalized.
  ///
  /// In vi, this message translates to:
  /// **'Đã chuẩn hoá âm lượng'**
  String get audioNormalized;

  /// No description provided for @audioNoSound.
  ///
  /// In vi, this message translates to:
  /// **'Đoạn này không có tiếng để đo.'**
  String get audioNoSound;

  /// No description provided for @audioMicDenied.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền micro để thu giọng nói.'**
  String get audioMicDenied;

  /// No description provided for @audioMusicName.
  ///
  /// In vi, this message translates to:
  /// **'Nhạc'**
  String get audioMusicName;

  /// No description provided for @audioVoiceName.
  ///
  /// In vi, this message translates to:
  /// **'Giọng nói'**
  String get audioVoiceName;

  /// No description provided for @audioTracksNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nhạc hay giọng nói.'**
  String get audioTracksNone;

  /// No description provided for @exportPreset.
  ///
  /// In vi, this message translates to:
  /// **'Mẫu xuất'**
  String get exportPreset;

  /// No description provided for @presetCustom.
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chọn'**
  String get presetCustom;

  /// No description provided for @presetYoutube.
  ///
  /// In vi, this message translates to:
  /// **'YouTube 1080p'**
  String get presetYoutube;

  /// No description provided for @presetVertical.
  ///
  /// In vi, this message translates to:
  /// **'TikTok / Reels 9:16'**
  String get presetVertical;

  /// No description provided for @presetShare.
  ///
  /// In vi, this message translates to:
  /// **'Gửi nhanh (≤ 24 MB)'**
  String get presetShare;

  /// No description provided for @presetGif.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh GIF'**
  String get presetGif;

  /// No description provided for @presetVerticalNote.
  ///
  /// In vi, this message translates to:
  /// **'Khung xuất sẽ đổi sang 9:16.'**
  String get presetVerticalNote;

  /// No description provided for @exportEstimate.
  ///
  /// In vi, this message translates to:
  /// **'Dung lượng ước tính {size}'**
  String exportEstimate(String size);

  /// No description provided for @exportCapMissed.
  ///
  /// In vi, this message translates to:
  /// **'Video quá dài để vừa 24 MB: chất lượng sẽ thấp. Hãy cắt ngắn bớt.'**
  String get exportCapMissed;

  /// No description provided for @exportStill.
  ///
  /// In vi, this message translates to:
  /// **'Lưu khung hình này thành ảnh'**
  String get exportStill;

  /// No description provided for @stillSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu ảnh vào thư viện ảnh'**
  String get stillSaved;

  /// No description provided for @exportBackgroundHint.
  ///
  /// In vi, this message translates to:
  /// **'Có thể thoát app: thông báo sẽ cho biết khi xuất xong.'**
  String get exportBackgroundHint;

  /// No description provided for @templateSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu làm mẫu'**
  String get templateSave;

  /// No description provided for @templateApply.
  ///
  /// In vi, this message translates to:
  /// **'Dùng mẫu'**
  String get templateApply;

  /// No description provided for @templateName.
  ///
  /// In vi, this message translates to:
  /// **'Tên mẫu'**
  String get templateName;

  /// No description provided for @templateNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có mẫu nào.'**
  String get templateNone;

  /// No description provided for @templateApplied.
  ///
  /// In vi, this message translates to:
  /// **'Đã áp dụng mẫu'**
  String get templateApplied;

  /// No description provided for @templateSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu mẫu'**
  String get templateSaved;

  /// No description provided for @templateDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá mẫu'**
  String get templateDelete;

  /// No description provided for @menuTemplates.
  ///
  /// In vi, this message translates to:
  /// **'Mẫu dự án'**
  String get menuTemplates;

  /// No description provided for @exportNotifTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang xuất video'**
  String get exportNotifTitle;

  /// No description provided for @exportNotifDone.
  ///
  /// In vi, this message translates to:
  /// **'Xuất xong. Chạm để mở.'**
  String get exportNotifDone;

  /// No description provided for @exportNotifFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xuất không thành công.'**
  String get exportNotifFailed;

  /// No description provided for @stepLabelPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Bước '**
  String get stepLabelPrefix;

  /// No description provided for @speedMuteFast.
  ///
  /// In vi, this message translates to:
  /// **'Tắt tiếng khi nhanh hơn 2×'**
  String get speedMuteFast;

  /// No description provided for @iosNoRecording.
  ///
  /// In vi, this message translates to:
  /// **'Trên iPhone, ứng dụng quay màn hình của chính nó cùng giọng nói của bạn. Quay ứng dụng khác và dấu nổi trên chúng hiện chỉ có trên Android.'**
  String get iosNoRecording;

  /// No description provided for @touchSourceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phát hiện lần chạm'**
  String get touchSourceTitle;

  /// No description provided for @touchSourceOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt'**
  String get touchSourceOff;

  /// No description provided for @touchSourceDots.
  ///
  /// In vi, this message translates to:
  /// **'Chấm trắng'**
  String get touchSourceDots;

  /// No description provided for @touchSourceManual.
  ///
  /// In vi, this message translates to:
  /// **'Thủ công'**
  String get touchSourceManual;

  /// No description provided for @touchSourceHint.
  ///
  /// In vi, this message translates to:
  /// **'Chấm trắng: khi chỉnh sửa, app tìm các chấm trắng của “Hiển thị lần chạm” trong video để biết bạn bấm lúc nào, ở đâu. Thủ công: lắc máy hoặc dùng nút trên thông báo. Tắt: không phát hiện. Dù không bật gì, “Dựng từ lần chạm” vẫn tìm được lúc màn hình đổi nhưng không biết bạn bấm ở đâu.'**
  String get touchSourceHint;

  /// No description provided for @touchGuideTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bật hiển thị lần chạm'**
  String get touchGuideTitle;

  /// No description provided for @touchGuideStep1.
  ///
  /// In vi, this message translates to:
  /// **'1. Bật chế độ nhà phát triển: vào Thông tin điện thoại, bấm 7 lần vào Số hiệu bản dựng.'**
  String get touchGuideStep1;

  /// No description provided for @touchGuideAbout.
  ///
  /// In vi, this message translates to:
  /// **'Mở Thông tin điện thoại'**
  String get touchGuideAbout;

  /// No description provided for @touchGuideStep2.
  ///
  /// In vi, this message translates to:
  /// **'2. Trong Tùy chọn nhà phát triển, bật Hiển thị lần chạm (không cần Vị trí con trỏ).'**
  String get touchGuideStep2;

  /// No description provided for @touchGuideDev.
  ///
  /// In vi, this message translates to:
  /// **'Mở Tùy chọn nhà phát triển'**
  String get touchGuideDev;

  /// No description provided for @touchGuideStep3.
  ///
  /// In vi, this message translates to:
  /// **'3. Quay như thường. Chấm trắng hiện trong video; khi chỉnh sửa app tự tìm và có thể che bằng dấu đẹp hơn.'**
  String get touchGuideStep3;

  /// No description provided for @touchGuideDevOn.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ nhà phát triển: đã bật'**
  String get touchGuideDevOn;

  /// No description provided for @touchGuideDevOff.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ nhà phát triển: chưa bật'**
  String get touchGuideDevOff;

  /// No description provided for @touchGuideTapsOn.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị lần chạm: đã bật'**
  String get touchGuideTapsOn;

  /// No description provided for @touchGuideTapsOff.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị lần chạm: chưa bật'**
  String get touchGuideTapsOff;

  /// No description provided for @touchGuideRecheck.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra lại'**
  String get touchGuideRecheck;

  /// No description provided for @inputModeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xử lý nhập liệu'**
  String get inputModeTitle;

  /// No description provided for @inputModeMerge.
  ///
  /// In vi, this message translates to:
  /// **'Gộp thành một bước “Nhập liệu”'**
  String get inputModeMerge;

  /// No description provided for @inputModePerKey.
  ///
  /// In vi, this message translates to:
  /// **'Hiện dấu từng phím (chỉ khi ít phím)'**
  String get inputModePerKey;

  /// No description provided for @inputModeSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua phần nhập liệu'**
  String get inputModeSkip;

  /// No description provided for @pauseTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dừng hình tại mỗi lần chạm'**
  String get pauseTitle;

  /// No description provided for @pauseZoomTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phóng to nhẹ tại chỗ chạm'**
  String get pauseZoomTitle;

  /// No description provided for @pauseHint.
  ///
  /// In vi, this message translates to:
  /// **'Video dừng đúng lúc chạm trong khoảng thời gian này (0 = không dừng). Các lần chạm cách nhau dưới 1,5 giây dùng chung một lần dừng. Đoạn dừng không bị tua nhanh. Phóng to chỉ áp dụng khi biết vị trí chạm.'**
  String get pauseHint;

  /// No description provided for @autoFromTouches.
  ///
  /// In vi, this message translates to:
  /// **'Dựng từ lần chạm'**
  String get autoFromTouches;

  /// No description provided for @autoFromTouchesRunning.
  ///
  /// In vi, this message translates to:
  /// **'Đang tìm lần chạm…'**
  String get autoFromTouchesRunning;

  /// No description provided for @autoTouchesNone.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy lần chạm nào trong video.'**
  String get autoTouchesNone;

  /// No description provided for @autoTouchesDone.
  ///
  /// In vi, this message translates to:
  /// **'{taps} lần chạm, {typing} bước nhập liệu.'**
  String autoTouchesDone(int taps, int typing);

  /// No description provided for @autoTouchesNoPlace.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ tìm được thời điểm, không biết vị trí: có chú thích bước và dừng hình, không phóng to.'**
  String get autoTouchesNoPlace;

  /// No description provided for @autoPreviewPause.
  ///
  /// In vi, this message translates to:
  /// **'Xem thử chỗ dừng đầu tiên'**
  String get autoPreviewPause;

  /// No description provided for @typingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đang nhập…'**
  String get typingLabel;

  /// No description provided for @typedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhập'**
  String get typedLabel;

  /// No description provided for @presetGlow.
  ///
  /// In vi, this message translates to:
  /// **'Phát sáng'**
  String get presetGlow;

  /// No description provided for @presetGradient.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển màu'**
  String get presetGradient;

  /// No description provided for @presetExtrude.
  ///
  /// In vi, this message translates to:
  /// **'Chữ nổi 3D'**
  String get presetExtrude;

  /// No description provided for @presetHollow.
  ///
  /// In vi, this message translates to:
  /// **'Chữ rỗng'**
  String get presetHollow;

  /// No description provided for @presetGlitch.
  ///
  /// In vi, this message translates to:
  /// **'Glitch'**
  String get presetGlitch;

  /// No description provided for @presetSticker.
  ///
  /// In vi, this message translates to:
  /// **'Sticker'**
  String get presetSticker;

  /// No description provided for @captionPanelAdd.
  ///
  /// In vi, this message translates to:
  /// **'+ Thêm câu'**
  String get captionPanelAdd;

  /// No description provided for @captionPanelOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt phụ đề'**
  String get captionPanelOff;

  /// No description provided for @captionPanelEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có câu phụ đề nào.'**
  String get captionPanelEmpty;

  /// No description provided for @captionPanelStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu (ms)'**
  String get captionPanelStart;

  /// No description provided for @captionPanelEnd.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc (ms)'**
  String get captionPanelEnd;

  /// No description provided for @captionTabLines.
  ///
  /// In vi, this message translates to:
  /// **'Câu'**
  String get captionTabLines;

  /// No description provided for @captionTabStyle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểu'**
  String get captionTabStyle;

  /// No description provided for @captionReveal.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu ứng hiện chữ'**
  String get captionReveal;

  /// No description provided for @captionRevealNone.
  ///
  /// In vi, this message translates to:
  /// **'Hiện hết'**
  String get captionRevealNone;

  /// No description provided for @captionRevealWord.
  ///
  /// In vi, this message translates to:
  /// **'Từng từ'**
  String get captionRevealWord;

  /// No description provided for @captionRevealChar.
  ///
  /// In vi, this message translates to:
  /// **'Từng ký tự'**
  String get captionRevealChar;

  /// No description provided for @captionRevealKaraoke.
  ///
  /// In vi, this message translates to:
  /// **'Karaoke'**
  String get captionRevealKaraoke;

  /// No description provided for @captionOutlineWidth.
  ///
  /// In vi, this message translates to:
  /// **'Dày viền'**
  String get captionOutlineWidth;

  /// No description provided for @captionOutlineColor.
  ///
  /// In vi, this message translates to:
  /// **'Màu viền'**
  String get captionOutlineColor;

  /// No description provided for @captionShadowBlur.
  ///
  /// In vi, this message translates to:
  /// **'Nhoè bóng'**
  String get captionShadowBlur;

  /// No description provided for @captionBoxColor.
  ///
  /// In vi, this message translates to:
  /// **'Màu nền'**
  String get captionBoxColor;

  /// No description provided for @captionBoxRadius.
  ///
  /// In vi, this message translates to:
  /// **'Bo góc'**
  String get captionBoxRadius;

  /// No description provided for @captionPosY.
  ///
  /// In vi, this message translates to:
  /// **'Dọc'**
  String get captionPosY;

  /// No description provided for @captionPosX.
  ///
  /// In vi, this message translates to:
  /// **'Ngang'**
  String get captionPosX;

  /// No description provided for @captionReset.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại kiểu'**
  String get captionReset;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'vi':
      return AppL10nVi();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
