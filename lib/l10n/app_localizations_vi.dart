// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppL10nVi extends AppL10n {
  AppL10nVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'E Screen Recorder';

  @override
  String get navRecord => 'Quay';

  @override
  String get navLibrary => 'Thư viện';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String get cancel => 'Huỷ';

  @override
  String get save => 'Lưu';

  @override
  String get close => 'Đóng';

  @override
  String get recordStart => 'Bắt đầu quay';

  @override
  String get recordStop => 'Dừng quay';

  @override
  String get recordPause => 'Tạm dừng';

  @override
  String get recordResume => 'Tiếp tục';

  @override
  String get recentTitle => 'Gần đây';

  @override
  String get seeAll => 'Xem tất cả';

  @override
  String get libraryEmptyTitle => 'Chưa có video nào';

  @override
  String get libraryEmptyBody =>
      'Quay màn hình đầu tiên của bạn, video sẽ nằm ở đây.';

  @override
  String get profileTitle => 'Cấu hình quay';

  @override
  String get resetDefaults => 'Khôi phục mặc định';

  @override
  String get optResolution => 'Độ phân giải';

  @override
  String get optFps => 'Tốc độ khung hình';

  @override
  String get optQuality => 'Chất lượng';

  @override
  String get optAudio => 'Âm thanh';

  @override
  String get optCountdown => 'Đếm ngược';

  @override
  String get optFloatingBar => 'Dấu đánh dấu khi quay';

  @override
  String get floatingBarHint =>
      'Bật để đánh dấu khi quay (chấm nhỏ ở góc hoặc quay sạch, chọn trong Cài đặt). Tắt để chỉ điều khiển bằng thông báo.';

  @override
  String get resolution720 => '720p';

  @override
  String get resolution1080 => '1080p';

  @override
  String get resolutionNative => 'Gốc';

  @override
  String fpsValue(int fps) {
    return '$fps fps';
  }

  @override
  String get qualityLow => 'Nhẹ';

  @override
  String get qualityBalanced => 'Cân bằng';

  @override
  String get qualityHigh => 'Nét';

  @override
  String get audioNone => 'Không có';

  @override
  String get audioMic => 'Micro';

  @override
  String get audioSystem => 'Âm thanh máy';

  @override
  String get audioBoth => 'Cả hai';

  @override
  String get countdownOff => 'Tắt';

  @override
  String countdownSeconds(int n) {
    return '$n giây';
  }

  @override
  String profileSummary(String resolution, int fps, String quality) {
    return '$resolution · $fps fps · $quality';
  }

  @override
  String get profileEdit => 'Chỉnh cấu hình quay';

  @override
  String get statusRecording => 'Đang quay';

  @override
  String get statusPaused => 'Đã tạm dừng';

  @override
  String get statusCountdown => 'Sắp quay…';

  @override
  String get statusSaving => 'Đang lưu video…';

  @override
  String get recordingHint =>
      'Mở ứng dụng bạn muốn quay. Bấm chấm nhỏ ở góc để đánh dấu chỗ sắp bấm; nhấn giữ chấm để mở thanh điều khiển.';

  @override
  String get recordingHintNoBar =>
      'Mở ứng dụng bạn muốn quay. Điều khiển bằng thông báo.';

  @override
  String get recordingHintClean =>
      'Mở ứng dụng bạn muốn quay. Chạm vùng ẩn ở góc, chạm chỗ sắp bấm (máy rung nhẹ), rồi bấm thật. Dừng bằng thông báo.';

  @override
  String savedSnack(String name) {
    return 'Đã lưu $name';
  }

  @override
  String get actionView => 'Xem';

  @override
  String get errLowStorage =>
      'Bộ nhớ sắp đầy. Hãy giải phóng dung lượng rồi quay lại.';

  @override
  String get errMic =>
      'Cần quyền micro để quay có tiếng. Chọn âm thanh \"Không có\" hoặc cấp quyền trong Cài đặt của máy.';

  @override
  String get errOverlay =>
      'Cần quyền hiển thị trên ứng dụng khác để dùng đếm ngược và thanh nổi. Bật quyền rồi quay lại ứng dụng.';

  @override
  String get errStart => 'Không bắt đầu quay được. Hãy thử lại.';

  @override
  String get errCapture => 'Quá trình quay bị gián đoạn.';

  @override
  String get errEmpty => 'Video không có dữ liệu. Hãy quay lại.';

  @override
  String get errSave => 'Không lưu được video vào bộ nhớ máy.';

  @override
  String get pickVideoFromDevice => 'Chọn video từ máy';

  @override
  String get pickVideoFailed => 'Không mở được video này.';

  @override
  String get libraryTitle => 'Thư viện';

  @override
  String get menuShare => 'Chia sẻ';

  @override
  String get menuRename => 'Đổi tên';

  @override
  String get menuDelete => 'Xoá';

  @override
  String get menuEdit => 'Chỉnh sửa';

  @override
  String get menuMore => 'Thao tác khác';

  @override
  String get renameTitle => 'Đổi tên video';

  @override
  String get renameField => 'Tên video';

  @override
  String get deleteTitle => 'Xoá video này?';

  @override
  String deleteBody(String name) {
    return '$name sẽ bị xoá khỏi máy và không khôi phục được.';
  }

  @override
  String get deleteDone => 'Đã xoá video';

  @override
  String get needsPermission =>
      'Video này do bản cài trước tạo nên hệ thống không cho sửa. Hãy xoá bằng ứng dụng Thư viện của máy.';

  @override
  String get genericError => 'Không thực hiện được. Hãy thử lại.';

  @override
  String videoMeta(String date, String size) {
    return '$date · $size';
  }

  @override
  String get playerError => 'Không phát được video này.';

  @override
  String get playVideo => 'Phát';

  @override
  String get pauseVideo => 'Dừng phát';

  @override
  String get settingsMarkers => 'Dấu đánh dấu';

  @override
  String get settingsMarkersSub =>
      'Dấu báo trước chỗ sắp bấm, cách đánh dấu khi quay và tự động dựng sau khi quay';

  @override
  String get settingsMarkersHint =>
      'Dấu hiện lên và được ghi vào video trước khi bạn bấm, để người xem biết sẽ bấm vào đâu.';

  @override
  String get markerPreviewTitle => 'Xem thử';

  @override
  String get previewLight => 'Nền sáng';

  @override
  String get previewDark => 'Nền tối';

  @override
  String get previewMockSave => 'Lưu';

  @override
  String get markerDefaultTool => 'Dấu mặc định';

  @override
  String get markerFinger => 'Ngón tay';

  @override
  String get markerRipple => 'Chạm';

  @override
  String get markerArrow => 'Mũi tên';

  @override
  String get markerCircle => 'Vòng tròn';

  @override
  String get markerRect => 'Khung';

  @override
  String get markerPen => 'Bút';

  @override
  String get markerNumber => 'Số bước';

  @override
  String get markerColor => 'Màu';

  @override
  String get colorRed => 'Đỏ';

  @override
  String get colorAmber => 'Vàng';

  @override
  String get colorGreen => 'Xanh lá';

  @override
  String get colorCyan => 'Xanh lơ';

  @override
  String get colorMagenta => 'Hồng';

  @override
  String get colorWhite => 'Trắng';

  @override
  String get colorBlack => 'Đen';

  @override
  String get markerThickness => 'Độ dày nét';

  @override
  String get thicknessThin => 'Mảnh';

  @override
  String get thicknessMedium => 'Vừa';

  @override
  String get thicknessThick => 'Dày';

  @override
  String get adjustScale => 'Cỡ';

  @override
  String get adjustRotate => 'Xoay';

  @override
  String get adjustOpacity => 'Độ trong';

  @override
  String get markerAdjustNote =>
      'Cỡ, xoay và độ trong chỉ để xem thử. Khi quay, hãy chụm hai ngón để đổi cỡ và xoay dấu.';

  @override
  String get markerHold => 'Giữ dấu sau khi đặt xong';

  @override
  String get markerHoldShort => 'Ngắn';

  @override
  String get markerHoldLong => 'Dài';

  @override
  String get markerHoldHint =>
      'Tính từ lúc đặt xong. Hết thời gian dấu mờ dần rồi biến mất, kể cả khi bạn vẫn ở chế độ đánh dấu hoặc đã chuyển sang trang khác.';

  @override
  String get previewToggleBackdrop => 'Đổi nền xem thử sáng/tối';

  @override
  String holdSeconds(String s) {
    return '$s giây';
  }

  @override
  String get markerAutoExit => 'Tự thoát chế độ chỉ điểm sau khi đặt';

  @override
  String get markerAutoExitHint =>
      'Đặt dấu xong, thanh nổi trở về bình thường để bạn bấm thật vào đích.';

  @override
  String markerExitDelay(String s) {
    return 'Chờ $s giây rồi mới cho bấm';
  }

  @override
  String get markerExitDelayHint =>
      'Thời gian từ lúc đặt dấu đến lúc bạn bấm thật được. Càng ngắn càng nhanh, nhưng dấu cần đủ lâu để người xem kịp nhìn.';

  @override
  String get captionsAutoTitle => 'Tạo phụ đề tự động';

  @override
  String get captionsPrivacy =>
      'Nhận dạng giọng nói ngay trên điện thoại bằng bộ nhận dạng của Android. Âm thanh không rời khỏi máy.';

  @override
  String get captionsUnavailable =>
      'Điện thoại này chưa hỗ trợ nhận dạng giọng nói trên máy (cần Android 13 trở lên).';

  @override
  String get captionsLanguage => 'Ngôn ngữ trong video';

  @override
  String get langVietnamese => 'Tiếng Việt';

  @override
  String get langEnglish => 'English';

  @override
  String get captionsLangReady => 'Đã có trên máy, dùng được ngay.';

  @override
  String get captionsLangDownload =>
      'Cần tải gói ngôn ngữ. Android tự tải một lần, có thể dùng mạng; sau đó chạy hoàn toàn trên máy.';

  @override
  String get captionsLangUnsupported => 'Điện thoại chưa hỗ trợ ngôn ngữ này.';

  @override
  String get captionsDownload => 'Tải gói ngôn ngữ';

  @override
  String get captionsDownloading => 'Đang tải…';

  @override
  String get captionsStart => 'Bắt đầu tạo phụ đề';

  @override
  String get captionsPreparing => 'Đang tách âm thanh…';

  @override
  String captionsProgress(int done, int total) {
    return 'Đang nghe đoạn $done/$total';
  }

  @override
  String captionsCreated(int n) {
    return 'Đã tạo $n dòng phụ đề. Sửa hoặc xoá từng dòng trong tab Chữ.';
  }

  @override
  String get captionsCancelled => 'Đã dừng, chưa thêm phụ đề nào.';

  @override
  String get captionsNoAudio =>
      'Video này không có âm thanh. Khi quay hãy bật micro hoặc âm thanh hệ thống.';

  @override
  String get captionsNoSpeech => 'Không nghe thấy lời nói nào trong video.';

  @override
  String get captionsFailed =>
      'Không tạo được phụ đề. Thử lại hoặc chọn ngôn ngữ khác.';

  @override
  String get captionsReplaceNote =>
      'Tạo lại sẽ thay các phụ đề tự động trước đó; phụ đề bạn tự thêm hoặc nhập từ SRT được giữ nguyên.';

  @override
  String get voiceFxTitle => 'Hiệu ứng giọng';

  @override
  String get fxNone => 'Gốc';

  @override
  String get fxDeep => 'Trầm';

  @override
  String get fxHigh => 'Cao';

  @override
  String get fxChipmunk => 'Sóc chuột';

  @override
  String get fxRobot => 'Robot';

  @override
  String get fxEcho => 'Echo';

  @override
  String get fxReverb => 'Vang';

  @override
  String get denoiseTitle => 'Giảm ồn';

  @override
  String get denoiseOff => 'Tắt';

  @override
  String get denoiseLight => 'Nhẹ';

  @override
  String get denoiseStrong => 'Mạnh';

  @override
  String get voiceFxBusy => 'Đang xử lý giọng…';

  @override
  String get voiceFxError => 'Không xử lý được file giọng này.';

  @override
  String get voiceFxHint =>
      'Áp dụng một lần lên file giọng nên xem trước và video xuất nghe giống nhau. Chọn Gốc + Tắt để quay về bản gốc. Không đụng tới nhạc nền.';

  @override
  String get markerBarNote => 'Thanh nổi và dấu sẽ hiện trong video.';

  @override
  String get splashTagline => 'Cho người xem biết trước chỗ bạn sắp bấm';

  @override
  String get markModeTitle => 'Cách đánh dấu khi quay';

  @override
  String get markModeDot => 'Chấm nhỏ ở góc';

  @override
  String get markModeDotHint =>
      'Chọn dấu trước. Khi quay chỉ còn một chấm nhỏ: bấm chấm, chạm vào chỗ sắp bấm, rồi mới bấm thật. Chấm và dấu hiện trong video.';

  @override
  String get markModeClean => 'Quay sạch, dựng sau';

  @override
  String get markModeCleanHint =>
      'Màn hình không có gì chen vào. Chạm vùng ẩn ở góc, chạm chỗ sắp bấm (máy rung nhẹ), rồi bấm thật. Dấu được vẽ đẹp trong trình chỉnh sửa.';

  @override
  String get markCornerTitle => 'Vị trí chấm và vùng ẩn';

  @override
  String get cornerTL => 'Trên trái';

  @override
  String get cornerTR => 'Trên phải';

  @override
  String get cornerBL => 'Dưới trái';

  @override
  String get cornerBR => 'Dưới phải';

  @override
  String get markShake => 'Lắc máy để đánh dấu';

  @override
  String get markShakeHint =>
      'Lắc hai lần để bắt đầu đánh dấu. Cú lắc có thể làm rung video.';

  @override
  String get markDotNote =>
      'Nhấn giữ chấm để mở thanh điều khiển và đổi dấu (video tạm dừng khi chọn dấu, nên bảng chọn không lọt vào video).';

  @override
  String get markCleanNote =>
      'Chế độ sạch cũng có nút “Đánh dấu” trong thông báo. Vùng ẩn ở góc không nhìn thấy trong video.';

  @override
  String get toolAuto => 'Tự động';

  @override
  String get autoTitle => 'Dựng tự động';

  @override
  String get autoHint =>
      'Tự phóng to vào chỗ đánh dấu, đánh số lại các bước và tua nhanh đoạn màn hình đứng yên. Mọi thứ vẫn sửa và hoàn tác được.';

  @override
  String get autoZoomOpt => 'Phóng to vào dấu';

  @override
  String get autoNumberOpt => 'Đánh số lại các bước';

  @override
  String get autoIdleOpt => 'Tua nhanh đoạn đứng yên';

  @override
  String get autoRun => 'Dựng tự động';

  @override
  String get autoRunning => 'Đang phân tích video…';

  @override
  String autoDone(int zooms, int steps, int idle) {
    return 'Xong: $zooms phóng to, $steps bước đánh số, $idle đoạn tua nhanh.';
  }

  @override
  String get autoNothing =>
      'Không có gì để dựng thêm. Hãy thêm dấu hoặc quay đoạn dài hơn.';

  @override
  String get autoAfterRec => 'Sau khi quay sạch';

  @override
  String get onbSkip => 'Bỏ qua';

  @override
  String get onbNext => 'Tiếp';

  @override
  String get onbStart => 'Bắt đầu dùng';

  @override
  String get onbTitle1 => 'Người xem luôn biết bạn sắp bấm vào đâu';

  @override
  String get onbBody1 =>
      'Dấu hiện lên trước, màn hình đổi sau. Video hướng dẫn của bạn dễ theo dõi hơn nhiều.';

  @override
  String get onbTitle2 => 'Ba bước để chỉ điểm';

  @override
  String get onbStep1 =>
      'Khi đang quay, bật chế độ chỉ điểm trên thanh nổi, chọn dấu rồi đặt lên đích.';

  @override
  String get onbStep2 =>
      'Chế độ tự tắt sau khi đặt. Dấu vòng vàng thu vào đích, rồi giữ lại vài giây.';

  @override
  String get onbStep3 =>
      'Bấm thật vào đích. Người xem đã biết cần nhìn vào đâu.';

  @override
  String get onbTitle3 => 'Cho phép vài quyền';

  @override
  String get onbBody3 =>
      'Chỉ xin những quyền thật sự cần. Video luôn nằm trên máy của bạn.';

  @override
  String get permOverlayTitle => 'Hiện trên ứng dụng khác';

  @override
  String get permOverlayBody =>
      'Để hiện thanh nổi, đếm ngược và dấu đánh dấu trên màn hình lúc quay.';

  @override
  String get permMicTitle => 'Micro';

  @override
  String get permMicBody => 'Chỉ dùng khi bạn chọn quay có tiếng.';

  @override
  String get permNotifTitle => 'Thông báo';

  @override
  String get permNotifBody => 'Hiện nút Tạm dừng và Dừng khi đang quay.';

  @override
  String get permBatteryTitle => 'Quay lâu không bị ngắt';

  @override
  String get permBatteryBody =>
      'Một số máy (Xiaomi, Oppo, Vivo, Samsung) tự tắt ứng dụng chạy nền. Vào cài đặt ứng dụng và đặt Pin thành không hạn chế.';

  @override
  String get permGranted => 'Đã cấp';

  @override
  String get permGrant => 'Cấp quyền';

  @override
  String get permOpenSettings => 'Mở cài đặt ứng dụng';

  @override
  String get settingsPermissions => 'Quyền và pin';

  @override
  String get settingsPermissionsSub =>
      'Kiểm tra app đã đủ quyền để quay và chạy nền chưa';

  @override
  String get settingsGuide => 'Hướng dẫn';

  @override
  String get settingsGuideSub => 'Xem lại các bước dùng app lần đầu';

  @override
  String get settingsPrivacy => 'Quyền riêng tư';

  @override
  String get settingsPrivacySub => 'Video ở lại trên máy của bạn';

  @override
  String get settingsAbout => 'Giới thiệu';

  @override
  String get settingsAboutSub => 'Phiên bản và thông tin ứng dụng';

  @override
  String aboutVersion(String v) {
    return 'Phiên bản $v';
  }

  @override
  String get aboutBody =>
      'E Screen Recorder là ứng dụng quay màn hình miễn phí, không quảng cáo, không cần tài khoản.';

  @override
  String get aboutLicenses =>
      'Phông chữ Barlow theo giấy phép SIL OFL. Biểu tượng bàn tay dựa trên Material Icons (Apache-2.0).';

  @override
  String get privacyH1 => 'Video ở lại trên máy';

  @override
  String get privacyP1 =>
      'Mọi video, dự án chỉnh sửa và ảnh chụp đều được lưu trên chính thiết bị của bạn. Ứng dụng không tải video, âm thanh hay màn hình lên máy chủ nào.';

  @override
  String get privacyH2 => 'Không tài khoản, không theo dõi';

  @override
  String get privacyP2 =>
      'Ứng dụng không yêu cầu đăng nhập, không có quảng cáo và không thu thập số liệu sử dụng hay định danh thiết bị.';

  @override
  String get privacyH3 => 'Quyền dùng để làm gì';

  @override
  String get privacyP3 =>
      'Quay màn hình: để ghi lại nội dung hiển thị khi bạn đồng ý trong hộp thoại của hệ thống. Micro: chỉ khi bạn chọn quay có tiếng. Hiện trên ứng dụng khác: để hiện thanh điều khiển và dấu đánh dấu. Thông báo: để hiện nút Tạm dừng và Dừng.';

  @override
  String get privacyH4 => 'Nội dung nhạy cảm';

  @override
  String get privacyP4 =>
      'Video quay màn hình có thể chứa mật khẩu, tin nhắn hay số điện thoại. Hãy dùng khối che trong trình chỉnh sửa trước khi chia sẻ. Ứng dụng chỉ chia sẻ khi bạn chọn Chia sẻ.';

  @override
  String get privacyH5 => 'Xoá dữ liệu';

  @override
  String get privacyP5 =>
      'Xoá video trong Thư viện hoặc gỡ cài đặt ứng dụng để xoá dự án chỉnh sửa. Video đã xuất nằm trong thư mục Movies/E Screen Recorder và Pictures/E Screen Recorder.';

  @override
  String get toolCut => 'Cắt';

  @override
  String get toolMarker => 'Dấu';

  @override
  String get toolText => 'Chữ';

  @override
  String get toolCover => 'Che';

  @override
  String get toolZoom => 'Phóng';

  @override
  String get splitHere => 'Cắt tại đây';

  @override
  String get deleteSegment => 'Xoá đoạn';

  @override
  String get moveLeft => 'Dịch đoạn sang trái';

  @override
  String get moveRight => 'Dịch đoạn sang phải';

  @override
  String get segmentSpeed => 'Tốc độ đoạn này';

  @override
  String get trimHint => 'Chạm đoạn trên timeline rồi kéo hai đầu để cắt bớt.';

  @override
  String get markerAddHint =>
      'Đưa đầu phát tới đúng lúc bạn bấm. Dấu sẽ hiện báo trước 0,5 giây, rồi mới tới lúc bấm.';

  @override
  String get clipHold => 'Giữ dấu';

  @override
  String get clipLength => 'Thời lượng';

  @override
  String get textAdd => 'Thêm chữ';

  @override
  String get textHint =>
      'Chữ nằm trên video và không bị phóng to theo hiệu ứng phóng.';

  @override
  String get textField => 'Nội dung';

  @override
  String get textSize => 'Cỡ chữ';

  @override
  String get coverAdd => 'Thêm vùng';

  @override
  String get coverStyleSolid => 'Khối đặc';

  @override
  String get coverStyleBlur => 'Làm mờ';

  @override
  String get coverStyleMosaic => 'Mosaic';

  @override
  String get coverStyleSpotlight => 'Tiêu điểm';

  @override
  String get coverStrength => 'Cường độ';

  @override
  String get coverMove => 'Di chuyển';

  @override
  String get coverMoveHint =>
      'Vùng trượt mượt từ điểm đầu tới điểm cuối trong suốt thời gian của nó. Chọn điểm rồi kéo trên video.';

  @override
  String get coverPointStart => 'Điểm đầu';

  @override
  String get coverPointEnd => 'Điểm cuối';

  @override
  String get coverHint =>
      'Che số điện thoại, mật khẩu… bằng khối đặc, làm mờ hoặc mosaic; hoặc làm tối phần còn lại để nhấn mạnh một vùng (tiêu điểm). Kéo trên video để đặt vị trí.';

  @override
  String get coverWidth => 'Rộng';

  @override
  String get coverHeight => 'Cao';

  @override
  String get zoomAdd => 'Thêm phóng to';

  @override
  String get zoomHint => 'Phóng to vào một vùng rồi thu lại êm ái.';

  @override
  String get zoomScale => 'Mức phóng';

  @override
  String get zoomIn => 'Phóng vào';

  @override
  String get zoomOut => 'Thu lại';

  @override
  String get zoomHold => 'Giữ thêm';

  @override
  String get zoomTimingHint =>
      'Phóng vào/Thu lại là thời gian để phóng tới mức đầy đủ và để trở về; càng ngắn càng nhanh. Giữ thêm là thời gian vẫn phóng sau khi dấu đã mờ.';

  @override
  String get zoomAutoTuning => 'Tinh chỉnh phóng tự động';

  @override
  String get zoomDragHint => 'Kéo trên video để chọn vùng sẽ phóng vào.';

  @override
  String get undo => 'Hoàn tác';

  @override
  String get redo => 'Làm lại';

  @override
  String get exportAction => 'Xuất';

  @override
  String get exportTitle => 'Xuất video';

  @override
  String exportSummary(String duration) {
    return 'Thời lượng $duration';
  }

  @override
  String get exportFormat => 'Định dạng';

  @override
  String get formatMp4 => 'MP4';

  @override
  String get formatGif => 'GIF';

  @override
  String get exportQuality => 'Chất lượng';

  @override
  String get qualityOriginal => 'Gốc';

  @override
  String get resolution480 => '480p';

  @override
  String get gifHint =>
      'GIF nhẹ, không có tiếng. Đẹp nhất với đoạn ngắn dưới 15 giây.';

  @override
  String get exportStart => 'Bắt đầu xuất';

  @override
  String exportRunning(int pct) {
    return 'Đang xuất $pct%';
  }

  @override
  String get exportDone => 'Đã xuất xong';

  @override
  String get exportError => 'Xuất không thành công. Hãy thử lại.';

  @override
  String timelineSummary(
    int segments,
    int markers,
    int texts,
    int covers,
    int zooms,
  ) {
    return 'Dòng thời gian: $segments đoạn, $markers dấu, $texts chữ, $covers khối che, $zooms phóng to';
  }

  @override
  String get selectMode => 'Chọn';

  @override
  String selectedCount(int n) {
    return 'Đã chọn $n';
  }

  @override
  String get joinAction => 'Ghép';

  @override
  String get joinTitle => 'Ghép video';

  @override
  String joinSummary(int n) {
    return 'Ghép $n video theo thứ tự đã chọn.';
  }

  @override
  String get joinDone => 'Đã ghép xong';

  @override
  String get resetProject => 'Làm lại từ đầu';

  @override
  String get resetTitle => 'Bỏ mọi chỉnh sửa?';

  @override
  String get resetBody =>
      'Video gốc không bị ảnh hưởng. Bạn vẫn có thể bấm Hoàn tác ngay sau đó.';

  @override
  String get seekBack => 'Lùi 1 giây';

  @override
  String get seekForward => 'Tiến 1 giây';

  @override
  String get timelineZoomOut => 'Thu nhỏ timeline';

  @override
  String get timelineZoomIn => 'Phóng to timeline';

  @override
  String get editorLoadError => 'Không mở được video để chỉnh sửa.';

  @override
  String get settingsTheme => 'Giao diện';

  @override
  String get themeSystem => 'Theo hệ thống';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get toolSpeed => 'Tốc độ';

  @override
  String get toolTransition => 'Chuyển cảnh';

  @override
  String get toolAudio => 'Âm thanh';

  @override
  String get editFreeze => 'Đóng băng khung';

  @override
  String get editDuplicate => 'Nhân đôi';

  @override
  String get editBlank => 'Để trống';

  @override
  String get editMultiSelect => 'Chọn nhiều';

  @override
  String get editMultiHint =>
      'Chạm các đoạn để chọn; thao tác áp cho tất cả đoạn đã chọn.';

  @override
  String get frameBack => 'Lùi 1 khung hình';

  @override
  String get frameForward => 'Tiến 1 khung hình';

  @override
  String get enterFullscreen => 'Xem toàn màn hình';

  @override
  String get exitFullscreen => 'Thoát toàn màn hình';

  @override
  String get toolsHide => 'Ẩn công cụ';

  @override
  String get toolsShow => 'Hiện công cụ';

  @override
  String get presetClassic => 'Cổ điển';

  @override
  String get presetSubtitle => 'Phụ đề';

  @override
  String get presetYellow => 'Vàng';

  @override
  String get presetNeon => 'Neon';

  @override
  String get presetClean => 'Gọn';

  @override
  String get presetLabel => 'Nhãn';

  @override
  String get subtitlesImport => 'Nhập phụ đề (.srt)';

  @override
  String subtitlesImported(int n) {
    return 'Đã thêm $n dòng phụ đề.';
  }

  @override
  String get subtitlesNone => 'Không đọc được dòng phụ đề nào trong tệp này.';

  @override
  String get timelineFit => 'Vừa khung';

  @override
  String get reorderHint => 'Giữ một đoạn rồi trượt ngang để đổi thứ tự.';

  @override
  String get speedFree => 'Tốc độ tự do';

  @override
  String get speedRamp => 'Đổi tốc độ dần';

  @override
  String get speedRampFrom => 'Đầu đoạn';

  @override
  String get speedRampTo => 'Cuối đoạn';

  @override
  String get speedReverse => 'Chạy ngược';

  @override
  String get speedReverseHint =>
      'Chạy ngược không có tiếng và tối đa 30 giây cho mỗi đoạn.';

  @override
  String get speedStillHint =>
      'Đây là khung đóng băng: chỉ chỉnh được thời lượng.';

  @override
  String get freezeLength => 'Thời lượng đóng băng';

  @override
  String get transNone => 'Không';

  @override
  String get transDipBlack => 'Mờ qua đen';

  @override
  String get transDipWhite => 'Mờ qua trắng';

  @override
  String get transSlideLeft => 'Trượt trái';

  @override
  String get transSlideRight => 'Trượt phải';

  @override
  String get transSlideUp => 'Trượt lên';

  @override
  String get transSlideDown => 'Trượt xuống';

  @override
  String get transZoom => 'Phóng mờ';

  @override
  String get transLength => 'Thời lượng';

  @override
  String get transApplyAll => 'Áp dụng mọi điểm cắt';

  @override
  String get transFirstHint =>
      'Đoạn đầu không có chuyển cảnh. Chọn đoạn từ thứ 2 trở đi.';

  @override
  String get transHint =>
      'Chuyển cảnh nằm ở chỗ nối vào đoạn đang chọn; tổng thời lượng video không đổi.';

  @override
  String get audioVolume => 'Âm lượng';

  @override
  String get audioMute => 'Tắt tiếng đoạn này';

  @override
  String get audioFadeIn => 'Mờ vào';

  @override
  String get audioFadeOut => 'Mờ ra';

  @override
  String get audioStillHint => 'Khung đóng băng và đoạn trống không có tiếng.';

  @override
  String get toolPicture => 'Hình';

  @override
  String get toolOverlay => 'Lớp phủ';

  @override
  String get picRotate => 'Xoay 90°';

  @override
  String get picTilt => 'Xoay tự do';

  @override
  String get picTiltReset => 'Làm thẳng';

  @override
  String get picCrop => 'Cắt khung';

  @override
  String get picCropReset => 'Bỏ cắt khung';

  @override
  String get picAspect => 'Tỉ lệ khung xuất';

  @override
  String get aspectAuto => 'Gốc';

  @override
  String get aspect916 => '9:16';

  @override
  String get aspect11 => '1:1';

  @override
  String get aspect45 => '4:5';

  @override
  String get aspect169 => '16:9';

  @override
  String get picFit => 'Viền đen';

  @override
  String get picFill => 'Lấp đầy';

  @override
  String get picFitHint =>
      'Khung khác tỉ lệ: thêm viền đen hoặc lấp đầy và cắt phần thừa.';

  @override
  String get picFilters => 'Màu sắc';

  @override
  String get presetNone => 'Gốc';

  @override
  String get presetVivid => 'Rực rỡ';

  @override
  String get presetWarm => 'Ấm';

  @override
  String get presetCool => 'Lạnh';

  @override
  String get presetBw => 'Đen trắng';

  @override
  String get presetVintage => 'Hoài cổ';

  @override
  String get presetFade => 'Nhạt';

  @override
  String get colorBrightness => 'Độ sáng';

  @override
  String get colorContrast => 'Tương phản';

  @override
  String get colorSaturation => 'Bão hoà';

  @override
  String get colorWarmth => 'Nhiệt độ';

  @override
  String get picRotateNote =>
      'Xoay và cắt khung nên làm trước khi thêm dấu; dấu đã đặt có thể lệch.';

  @override
  String get cropTitle => 'Cắt khung hình';

  @override
  String get cropDone => 'Xong';

  @override
  String get ovAddImage => 'Thêm ảnh';

  @override
  String get ovAddPip => 'Hình trong hình';

  @override
  String get ovPipHint =>
      'Chọn ảnh hoặc video ngắn (tối đa 30 giây) đặt ở góc màn hình.';

  @override
  String get shapeRect => 'Khung chữ nhật';

  @override
  String get shapeEllipse => 'Hình tròn';

  @override
  String get shapeLine => 'Đường thẳng';

  @override
  String get shapeArrow => 'Mũi tên';

  @override
  String get shapeBubble => 'Chú thích';

  @override
  String get ovWidth => 'Độ rộng';

  @override
  String get ovOpacity => 'Độ mờ';

  @override
  String get ovRotation => 'Xoay';

  @override
  String get ovStroke => 'Độ dày nét';

  @override
  String get ovFilled => 'Tô đầy';

  @override
  String get ovBubbleText => 'Chữ trong chú thích';

  @override
  String get ovPipVolume => 'Âm thanh';

  @override
  String get ovPipStart => 'Bắt đầu tại';

  @override
  String get ovPipLength => 'Thời lượng';

  @override
  String get ovHint =>
      'Thêm ảnh, hình vẽ, chú thích hoặc hình trong hình; kéo trên màn hình để đặt vị trí, chụm hai ngón để đổi cỡ và xoay.';

  @override
  String get motionTitle => 'Chuyển động';

  @override
  String get motionEnter => 'Xuất hiện';

  @override
  String get motionExit => 'Biến mất';

  @override
  String get motionNone => 'Không';

  @override
  String get motionFade => 'Mờ dần';

  @override
  String get motionPop => 'Nảy lên';

  @override
  String get motionSlideUp => 'Trượt lên';

  @override
  String get motionSlideDown => 'Trượt xuống';

  @override
  String get motionSlideLeft => 'Trượt trái';

  @override
  String get motionSlideRight => 'Trượt phải';

  @override
  String get motionKeyframe => 'Di chuyển đến vị trí cuối';

  @override
  String get motionSetEnd => 'Đặt vị trí hiện tại làm điểm cuối';

  @override
  String get motionClear => 'Bỏ chuyển động';

  @override
  String get motionEase => 'Nhịp chuyển động';

  @override
  String get easeLinear => 'Đều';

  @override
  String get easeIn => 'Chậm rồi nhanh';

  @override
  String get easeOut => 'Nhanh rồi chậm';

  @override
  String get easeInOut => 'Mượt';

  @override
  String get textFont => 'Phông chữ';

  @override
  String get fontBarlow => 'Barlow';

  @override
  String get fontSans => 'Hiện đại';

  @override
  String get fontCondensed => 'Hẹp';

  @override
  String get fontSerif => 'Có chân';

  @override
  String get fontMono => 'Đơn cách';

  @override
  String get fontCursive => 'Viết tay';

  @override
  String get textOutline => 'Viền chữ';

  @override
  String get textBox => 'Nền chữ';

  @override
  String get textShadow => 'Đổ bóng';

  @override
  String get textBold => 'In đậm';

  @override
  String get textAlignLabel => 'Căn lề';

  @override
  String get alignLeft => 'Trái';

  @override
  String get alignCenter => 'Giữa';

  @override
  String get alignRight => 'Phải';

  @override
  String get autoStepLabels => 'Thêm chữ Bước N cho dấu số';

  @override
  String get audioTracks => 'Nhạc và giọng nói';

  @override
  String get audioAddMusic => 'Thêm nhạc từ máy';

  @override
  String get audioRecordVoice => 'Thu giọng nói';

  @override
  String get audioStopVoice => 'Dừng thu';

  @override
  String get audioVoiceHint =>
      'Nên dùng tai nghe để giọng nói không lẫn tiếng từ loa.';

  @override
  String get audioStartAt => 'Bắt đầu tại';

  @override
  String get audioLoop => 'Lặp lại đến hết video';

  @override
  String get audioDuck => 'Hạ nhạc khi có giọng nói';

  @override
  String get audioNormalize => 'Chuẩn hoá âm lượng';

  @override
  String get audioNormalized => 'Đã chuẩn hoá âm lượng';

  @override
  String get audioNoSound => 'Đoạn này không có tiếng để đo.';

  @override
  String get audioMicDenied => 'Cần quyền micro để thu giọng nói.';

  @override
  String get audioMusicName => 'Nhạc';

  @override
  String get audioVoiceName => 'Giọng nói';

  @override
  String get audioTracksNone => 'Chưa có nhạc hay giọng nói.';

  @override
  String get exportPreset => 'Mẫu xuất';

  @override
  String get presetCustom => 'Tuỳ chọn';

  @override
  String get presetYoutube => 'YouTube 1080p';

  @override
  String get presetVertical => 'TikTok / Reels 9:16';

  @override
  String get presetShare => 'Gửi nhanh (≤ 24 MB)';

  @override
  String get presetGif => 'Ảnh GIF';

  @override
  String get presetVerticalNote => 'Khung xuất sẽ đổi sang 9:16.';

  @override
  String exportEstimate(String size) {
    return 'Dung lượng ước tính $size';
  }

  @override
  String get exportCapMissed =>
      'Video quá dài để vừa 24 MB: chất lượng sẽ thấp. Hãy cắt ngắn bớt.';

  @override
  String get exportStill => 'Lưu khung hình này thành ảnh';

  @override
  String get stillSaved => 'Đã lưu ảnh vào thư viện ảnh';

  @override
  String get exportBackgroundHint =>
      'Có thể thoát app: thông báo sẽ cho biết khi xuất xong.';

  @override
  String get templateSave => 'Lưu làm mẫu';

  @override
  String get templateApply => 'Dùng mẫu';

  @override
  String get templateName => 'Tên mẫu';

  @override
  String get templateNone => 'Chưa có mẫu nào.';

  @override
  String get templateApplied => 'Đã áp dụng mẫu';

  @override
  String get templateSaved => 'Đã lưu mẫu';

  @override
  String get templateDelete => 'Xoá mẫu';

  @override
  String get menuTemplates => 'Mẫu dự án';

  @override
  String get exportNotifTitle => 'Đang xuất video';

  @override
  String get exportNotifDone => 'Xuất xong. Chạm để mở.';

  @override
  String get exportNotifFailed => 'Xuất không thành công.';

  @override
  String get stepLabelPrefix => 'Bước ';

  @override
  String get speedMuteFast => 'Tắt tiếng khi nhanh hơn 2×';

  @override
  String get iosNoRecording =>
      'Trên iPhone, ứng dụng quay màn hình của chính nó cùng giọng nói của bạn. Quay ứng dụng khác và dấu nổi trên chúng hiện chỉ có trên Android.';

  @override
  String get touchSourceTitle => 'Phát hiện lần chạm';

  @override
  String get touchSourceOff => 'Tắt';

  @override
  String get touchSourceDots => 'Chấm trắng';

  @override
  String get touchSourceManual => 'Thủ công';

  @override
  String get touchSourceHint =>
      'Chấm trắng: khi chỉnh sửa, app tìm các chấm trắng của “Hiển thị lần chạm” trong video để biết bạn bấm lúc nào, ở đâu. Thủ công: lắc máy hoặc dùng nút trên thông báo. Tắt: không phát hiện. Dù không bật gì, “Dựng từ lần chạm” vẫn tìm được lúc màn hình đổi nhưng không biết bạn bấm ở đâu.';

  @override
  String get touchGuideTitle => 'Bật hiển thị lần chạm';

  @override
  String get touchGuideStep1 =>
      '1. Bật chế độ nhà phát triển: vào Thông tin điện thoại, bấm 7 lần vào Số hiệu bản dựng.';

  @override
  String get touchGuideAbout => 'Mở Thông tin điện thoại';

  @override
  String get touchGuideStep2 =>
      '2. Trong Tùy chọn nhà phát triển, bật Hiển thị lần chạm (không cần Vị trí con trỏ).';

  @override
  String get touchGuideDev => 'Mở Tùy chọn nhà phát triển';

  @override
  String get touchGuideStep3 =>
      '3. Quay như thường. Chấm trắng hiện trong video; khi chỉnh sửa app tự tìm và có thể che bằng dấu đẹp hơn.';

  @override
  String get touchGuideDevOn => 'Chế độ nhà phát triển: đã bật';

  @override
  String get touchGuideDevOff => 'Chế độ nhà phát triển: chưa bật';

  @override
  String get touchGuideTapsOn => 'Hiển thị lần chạm: đã bật';

  @override
  String get touchGuideTapsOff => 'Hiển thị lần chạm: chưa bật';

  @override
  String get touchGuideRecheck => 'Kiểm tra lại';

  @override
  String get inputModeTitle => 'Xử lý nhập liệu';

  @override
  String get inputModeMerge => 'Gộp thành một bước “Nhập liệu”';

  @override
  String get inputModePerKey => 'Hiện dấu từng phím (chỉ khi ít phím)';

  @override
  String get inputModeSkip => 'Bỏ qua phần nhập liệu';

  @override
  String get pauseTitle => 'Dừng hình tại mỗi lần chạm';

  @override
  String get pauseZoomTitle => 'Phóng to nhẹ tại chỗ chạm';

  @override
  String get pauseHint =>
      'Video dừng đúng lúc chạm trong khoảng thời gian này (0 = không dừng). Các lần chạm cách nhau dưới 1,5 giây dùng chung một lần dừng. Đoạn dừng không bị tua nhanh. Phóng to chỉ áp dụng khi biết vị trí chạm.';

  @override
  String get autoFromTouches => 'Dựng từ lần chạm';

  @override
  String get autoFromTouchesRunning => 'Đang tìm lần chạm…';

  @override
  String get autoTouchesNone => 'Không tìm thấy lần chạm nào trong video.';

  @override
  String autoTouchesDone(int taps, int typing) {
    return '$taps lần chạm, $typing bước nhập liệu.';
  }

  @override
  String get autoTouchesNoPlace =>
      'Chỉ tìm được thời điểm, không biết vị trí: có chú thích bước và dừng hình, không phóng to.';

  @override
  String get autoPreviewPause => 'Xem thử chỗ dừng đầu tiên';

  @override
  String get typingLabel => 'Đang nhập…';

  @override
  String get typedLabel => 'Đã nhập';

  @override
  String get presetGlow => 'Phát sáng';

  @override
  String get presetGradient => 'Chuyển màu';

  @override
  String get presetExtrude => 'Chữ nổi 3D';

  @override
  String get presetHollow => 'Chữ rỗng';

  @override
  String get presetGlitch => 'Glitch';

  @override
  String get presetSticker => 'Sticker';

  @override
  String get captionPanelAdd => '+ Thêm câu';

  @override
  String get captionPanelOff => 'Tắt phụ đề';

  @override
  String get captionPanelEmpty => 'Chưa có câu phụ đề nào.';

  @override
  String get captionPanelStart => 'Bắt đầu (ms)';

  @override
  String get captionPanelEnd => 'Kết thúc (ms)';

  @override
  String get captionTabLines => 'Câu';

  @override
  String get captionTabStyle => 'Kiểu';

  @override
  String get captionReveal => 'Hiệu ứng hiện chữ';

  @override
  String get captionRevealNone => 'Hiện hết';

  @override
  String get captionRevealWord => 'Từng từ';

  @override
  String get captionRevealChar => 'Từng ký tự';

  @override
  String get captionRevealKaraoke => 'Karaoke';

  @override
  String get captionOutlineWidth => 'Dày viền';

  @override
  String get captionOutlineColor => 'Màu viền';

  @override
  String get captionShadowBlur => 'Nhoè bóng';

  @override
  String get captionBoxColor => 'Màu nền';

  @override
  String get captionBoxRadius => 'Bo góc';

  @override
  String get captionPosY => 'Dọc';

  @override
  String get captionPosX => 'Ngang';

  @override
  String get captionReset => 'Đặt lại kiểu';

  @override
  String get captionTabTemplates => 'Mẫu';

  @override
  String get captionTemplateSample => 'Xin chào các bạn';

  @override
  String captionsCreatedCues(int n) {
    return 'Đã tạo $n dòng phụ đề. Chọn mẫu hoặc sửa từng dòng trong mục Phụ đề.';
  }

  @override
  String get captionsApplyTemplate => 'Dùng mẫu TikTok có sẵn';

  @override
  String get settingsGroupApp => 'Ứng dụng';

  @override
  String get settingsGroupRecord => 'Quay màn hình';

  @override
  String get settingsGroupHelp => 'Trợ giúp và thông tin';

  @override
  String get markerSecLook => 'Kiểu dấu';

  @override
  String get markerSecLookSub =>
      'Chọn dấu và chỉnh màu, độ dày, cỡ. Khung xem thử ở trên cho thấy ngay kết quả.';

  @override
  String get markerSecTime => 'Dấu hiện bao lâu';

  @override
  String get markerSecTimeSub =>
      'Dấu ở lại bao lâu sau khi bạn đặt, và có tự thoát chế độ chỉ điểm hay không.';

  @override
  String get markerSecHow => 'Cách đánh dấu khi quay';

  @override
  String get markerSecHowSub =>
      'Chọn cách đặt dấu lúc đang quay: chấm nhỏ ở góc màn hình, hoặc quay sạch rồi dựng sau.';

  @override
  String get markerSecAuto => 'Tự động dựng sau khi quay';

  @override
  String get markerSecAutoSub =>
      'App tự phóng to vào chỗ bạn đã đánh dấu và đánh số bước ngay khi quay xong. Bạn vẫn sửa được trong trình chỉnh sửa.';

  @override
  String get markerAutoNeedsClean =>
      'Tự động dựng chỉ có khi quay sạch, vì lúc đó video chưa có dấu nào chen vào để app dựng lại cho đẹp.';

  @override
  String get markerAutoSwitch => 'Bật Quay sạch, dựng sau';

  @override
  String get settingsGroupRecordSub =>
      'Cách đánh dấu khi quay, tự động dựng và các quyền cần để quay';

  @override
  String get settingsGroupHelpSub =>
      'Xem lại hướng dẫn, quyền riêng tư và thông tin ứng dụng';

  @override
  String get markCleanLimit =>
      'Lưu ý: vài màn hình của hệ thống (như Cài đặt hay màn hình xin quyền) chặn vùng ẩn, nên không đánh dấu được ở đó. Ứng dụng thường thì dùng bình thường.';

  @override
  String get touchSourceAuto => 'Tự động';

  @override
  String get touchSourceAutoHint =>
      'Khuyên dùng. Khi quay sạch, app tự nghe mọi lần bạn bấm vào màn hình, không cần lắc máy hay chạm vùng ẩn. Quay xong, app tự tìm chỗ bạn bấm, phóng to và đánh số các bước.';
}
