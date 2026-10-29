# Changelog

## [2026-10-29] Dựng từ lần chạm: phân loại chạm/bàn phím, dừng hình tại chỗ chạm, chấm trắng "Hiển thị lần chạm"
- **Quyết định về Trợ năng: vẫn KHÔNG dùng** (Google Play chỉ chấp nhận cho app hỗ trợ người khuyết tật, và dịch vụ này đọc được cả ô mật khẩu). Vì vậy mục "Cơ bản" bị bỏ; còn **Tắt / Chấm trắng / Thủ công** (Cài đặt → Dấu → chế độ sạch → "Phát hiện lần chạm"). Hệ quả: app **không đọc nội dung gõ** và không có công tắc "đọc nội dung ô nhập" (không có nguồn dữ liệu để đọc); video chỉ hiện "Đang nhập…" / "Đã nhập".
- **Dữ liệu mỗi lần chạm** (`RecMark`): thêm `kind` (tap/input/swipe/noise), `group`, `app`, `sensitive`, `pauseMs`, `zoom`, tùy chọn; dữ liệu cũ đọc thành `tap`. Dấu đặt tay ghi `kind=tap`.
- **Phân loại** (`touch_log.dart`, thuần Dart, có test): vuốt (đi xa ≥ 5% bề rộng) → `swipe`; chạm lặp < 250 ms cùng chỗ → `noise`; từ 3 chạm liền nhau (cách nhau ≤ 2 s) ở 45% dưới màn hình → một cụm `input` (bàn phím). Chạm không biết vị trí thì không bao giờ là bàn phím. Hạn chế: "bàn phím" nhận theo vùng màn hình, chưa nhận theo tên app bàn phím (cần Trợ năng).
- **Quét lần chạm** (`TouchScan.kt`): "chấm trắng" so các khung cạnh nhau (8 khung/giây, ảnh 108×240) để tìm một đốm tròn nhỏ xuất hiện/di chuyển rồi nối thành lần chạm (có x, y, thời gian, quãng đi); "đổi khung" chỉ tìm lúc màn hình đang yên bỗng đổi nhiều (không có vị trí). Nếu chấm trắng không tìm thấy gì thì tự dùng đổi khung. **Chưa chỉnh thông số trên máy thật** (không có điện thoại kết nối lúc làm); JUnit chỉ kiểm logic trên ảnh tổng hợp.
- **Hướng dẫn bật Hiển thị lần chạm**: hộp thoại 3 bước, nút mở thẳng "Thông tin điện thoại" / "Tùy chọn nhà phát triển", tự kiểm đã bật chưa (`touchSetup`).
- **Editor → Tự động → "Dựng từ lần chạm"**: một bước hoàn tác gồm dấu số/ripple tại mỗi lần chạm, **một bước "Nhập liệu"** thay cho từng phím ("Đang nhập…" trước và trong lúc gõ, "Đã nhập" sau đó, dừng 0,5 s trước/sau, phóng nhẹ vào ô nhập nếu biết vị trí), và **dừng hình** tại chỗ chạm (0–1,5 s, mặc định 0,8 s; chạm cách nhau < 1,5 s dùng chung một lần dừng; đoạn dừng không bị tua nhanh). Không biết vị trí → chỉ chú thích "Bước N" + dừng hình, không phóng to. Nút "Xem thử chỗ dừng đầu tiên"; cài đặt xử lý nhập liệu: gộp (mặc định) / từng phím (≤ 4 phím) / bỏ qua.
- Chưa làm: che chấm trắng bằng dấu đẹp, kéo khung vùng bỏ qua, thời gian dừng riêng từng lần trên giao diện (dữ liệu đã có `pauseMs`).

## [2026-10-29] Chọn video từ máy, khung chỉnh overlay, xoay tự do, timeline và nút phát ổn định hơn
- **Chọn video từ máy** (Thư viện → "Chọn video từ máy"): bộ chọn của hệ thống (`ACTION_OPEN_DOCUMENT`), mở thẳng editor; **không sao chép** vào thư viện app, **không quét** cả thư viện ảnh. Giữ quyền đọc lâu dài của tệp đã chọn; kích thước lấy theo chiều hiển thị (có tính cờ xoay 90/270 của video quay dọc).
- **Kích thước xem trước**: bảng công cụ thấp hơn (1/5 màn hình, cuộn được) và đệm gọn → khung xem trước lớn hơn rõ rệt. Zoom/pan hai ngón, nút "n,n×" và chạm đúp để về vừa khung vẫn như đợt trước (chỉ để xem, không xung đột với kéo/chọn lớp).
- **PiP**: kích thước video PiP luôn là kích thước **đang hiển thị** (kể cả khi có cờ xoay). Trước đây bộ xuất dùng kích thước thô của khung (ngang) cho video dọc nên xuất hiện viền đen quanh video; nay bản sao trung gian dùng đúng kích thước đã hiển thị (cả với dự án cũ). Chiều rộng PiP = `widthFrac` × bề rộng khung hình ra ở cả xem trước lẫn xuất.
- **Khung chỉnh overlay**: chọn marker/chữ/ảnh/hình/PiP/vùng che có khung với **tay nắm** ở bốn góc (đổi cỡ; vùng che và hình tròn/chữ nhật kéo từng góc) và **núm xoay** phía trên (chữ, ảnh, hình, marker; bắt vào 0/45/90…); **vạch hút** giữa/mép khung khi kéo. Tay nắm giữ cỡ cố định khi zoom xem trước; khung nhỏ chừa phần thân để kéo. Một bước hoàn tác cho mỗi lần kéo.
- **Xoay tự do** (Hình ảnh → "Xoay tự do", −45°…45°, cộng với nút xoay 90°): tự phóng đủ để **không có góc trống** (hệ số `cos θ + k·sin θ`, cùng công thức ở Dart và Kotlin). Xuất dùng `ScaleAndRotateTransformation`.
- **Timeline**: vùng nắm cắt rộng hơn (24 dp, tay nắm 8×26), giữ chạm kéo clip có **vạch chèn** to hơn kèm chấm hai đầu, **tự cuộn** khi kéo sát mép, rung nhẹ mỗi lần đổi vị trí chèn; thứ tự tính theo điểm giữa nên không cần chính xác.
- **Nút phát**: phát/tạm dừng chạy tuần tự (trước đây hai lần bấm sát nhau có thể để player chạy dưới màn hình "tạm dừng"), có vòng xoay khi đang xử lý, lỗi từ player không còn làm nút kẹt ở trạng thái "đang phát". Test: bấm 10 lần liên tiếp.

## [2026-10-28] Zoom hai ngón, hiệu ứng giọng + giảm ồn, phụ đề tự động, giao diện gọn hơn
- **Zoom khung xem trước** (chỉ để xem, không đổi dự án, ảnh lưu khung hình hay video xuất): chụm hai ngón/kéo khi **không chọn lớp** → zoom 1×–5× quanh điểm chạm; **đang chọn lớp** → chụm vẫn đổi cỡ/xoay lớp như cũ. Chạm/kéo/đặt lớp đúng vị trí khi đang zoom (quy đổi qua `ViewZoom`); nhãn "n,n×" hoặc chạm đúp để về vừa khung; màn hình toàn màn hình giữ zoom riêng. Test: 10 widget test + `integration_test/editor_zoom_test.dart` trên Oppo CPH2203 (3,0× → kéo → 5,0× → đặt lại → chạm đúp → toàn màn hình), bắt được một lỗi thật (cây widget đổi khi nhãn hiện làm đứt cử chỉ đang chụm).
- **Hiệu ứng giọng + giảm ồn** cho giọng lồng tiếng (không đụng nhạc nền): trầm, cao, sóc chuột (đổi cao độ Sonic), robot, echo, vang; giảm ồn Tắt/Nhẹ/Mạnh (trừ phổ nhiễu từ các khung yên nhất, làm mượt), giới hạn đỉnh để không méo/clip. Xử lý **một lần** ra file m4a, xem trước và xuất cùng dùng file đó (`AudioTrack.playPath`); bản gốc giữ nguyên, "Gốc + Tắt" khôi phục, mỗi thay đổi một bước hoàn tác. Đo trên Oppo CPH2203: cao độ 440 Hz × 0,78/1,25/1,6 → 342/550/704 Hz; tiếng ồn ở quãng nghỉ giảm 6,3 dB (nhẹ) / 11,9 dB (mạnh), giọng đổi ≤ 0,5 dB; đỉnh ≤ −0,5 dBFS; qua giao diện editor + xuất: giọng 1000 Hz ra 780 Hz. JUnit `DspTest` (10), Dart `voice_fx_test` (9).
- **Phụ đề tự động** (Chữ → "Tạo phụ đề tự động"): dùng bộ nhận dạng giọng nói **có sẵn của Android, chỉ chạy trên máy** (API 33+) — không thêm thư viện, không mô hình đóng kèm, không quyền INTERNET, APK không phình. Tách âm thanh, cắt theo khoảng lặng (`Chunker`), nhận dạng từng cụm, xếp chữ ≤2 dòng × 32 ký tự (cụm dài tách theo độ dài), không chồng nhau; một bước hoàn tác; làm lại thay các phụ đề tự động trước đó, giữ phụ đề tay/SRT. Việt/Anh; gói ngôn ngữ chưa có do **Android** tải (nút "Tải gói ngôn ngữ"). Trên máy này bộ nhận dạng trả chữ qua kết quả từng phần khi nạp tệp: dùng kết quả từng phần mới nhất. Đã kiểm với lời nói tiếng Việt thật (giọng đọc của máy → video): đúng cả 3 câu, đúng thời điểm, hoàn tác/làm lại, xuất có phụ đề. Tiếng Anh: hệ thống chưa tải xong gói trong 4 phút nên chưa kiểm. PRIVACY + trang web cập nhật. JUnit `ChunkerTest` (6), Dart `auto_captions_test` (9).
- **Giao diện gọn**: biểu tượng 22 dp (trước 24), nút ≥ 44 dp (trước 48 và 40 ở thanh phát), thanh dưới 64 dp, tab công cụ editor 44 dp với viên 40×24, khay dấu đệm 6 dp, đồng hồ thanh phát co lại thay vì tràn. Ảnh trước/sau: `docs/qa/icons_before_after.png`; kiểm tràn bằng `integration_test/ui_audit_test.dart` (bắt được biểu tượng đen và tràn 18 px trong lúc làm).
- APK release 60,78 MB (+0,65 MB), quyền không đổi (không INTERNET).

## [2026-10-28] Cài đặt dấu: xem thử dính đầu trang, thời gian hiệu ứng 0,5–10 s; đợt 3 trình dựng (một phần)
- **Cài đặt → Dấu đánh dấu**: khung "Xem thử" nhỏ gọn hơn (≈250 dp thay vì tới 380) và **dính ở đầu trang**: cuộn xuống chỉnh thì thu thành dải ≈108 dp quanh dấu, cuộn lên trở lại như cũ; nút đổi sáng/tối luôn ở góc khung (và vẫn có nút "Nền sáng/Nền tối" ở đầu trang). Khung được dựng một lần ở kích thước cố định, chỉ cửa sổ nhìn thay đổi nên không giật.
- **Thời gian hiệu ứng dấu** là thanh trượt **0,5–10 s** (bước 0,5 s, hiện số giây, mốc "Ngắn · 0,5 s"/"Dài · 10 s"), lưu lại (`marker.hold`, giá trị cũ ngoài dải được kéo về dải). Tính **từ lúc nhả tay đặt xong** (trước đây tính từ lúc thoát chế độ đánh dấu nên dấu có thể dính vô hạn khi tắt "tự thoát"); hết giờ thì mờ dần rồi biến mất, kể cả khi vẫn ở chế độ đánh dấu hay đã chuyển trang/app; có lần vẽ lại cuối để lớp phủ không giữ khung cũ. Xem thử, quay trực tiếp, chỉnh sửa và xuất dùng chung `markerHoldMs` (kẹp 0,5–10 s ở cả Dart và Kotlin).
- Đo trên Oppo CPH2203 từ video quay (`scripts/qa/marker_lifetime.py`): hold 0,5 s → ngón tay ≈0,8 s, mũi tên ≈1,0 s; hold 10 s → dấu ngón tay ≈10,5 s, đi theo sang màn hình chính rồi tự hết; tắt "tự thoát" (vẫn ở chế độ đánh dấu) hold 0,5 s → ≈1,0 s.
- Maestro mới: `g2d_marker_preview_sticky`, `g2e_hold_short`, `g2e_hold_long`, `g2e_hold_stay`; helper `set_marker_hold_min/max`. Test Dart 199.
- **Đợt 3 (một phần)**: vùng che **di chuyển** (điểm đầu/điểm cuối, trượt mượt trong suốt clip, mọi kiểu vùng; khối đặc nay cũng đi qua shader GL) — `e11_region_motion` PASS, khối đo được trượt từ 45 % xuống 70 % chiều cao trong 3 s. **Sóng âm trên timeline** (`EditorMedia.waveform`, thanh đối xứng mờ trong thanh đoạn video, theo âm lượng và đảo chiều khi chạy ngược) — `e12_waveform` PASS, đã xem ảnh timeline trên Oppo CPH2203. Chưa làm: hiệu ứng giọng, giảm ồn, phụ đề tự động từ giọng nói.

## [2026-10-28] Đợt 2 trình dựng kiểu CapCut: làm mờ, mosaic, tiêu điểm
- Tab **Che** nay có 4 kiểu vùng: **khối đặc**, **làm mờ**, **mosaic**, **tiêu điểm** (làm tối phần còn lại để nhấn mạnh một vùng) + thanh cường độ. Đổi kiểu của vùng đã đặt được, một bước hoàn tác. Dự án cũ mở như khối đặc.
- Bản xuất: một lượt GL riêng (`RegionFx.kt`, `RegionEffect`) chạy trên chính video, đặt TRƯỚC mọi lớp phủ nên dấu chỉ điểm vẫn đọc được; góc bo, mép mềm 1 px, mờ vào/ra 120 ms. Mosaic ô 2–8% bề rộng khung, làm mờ bán kính 1,5–4,5%, tiêu điểm tối 35–85%.
- Xem trước: làm mờ bằng BackdropFilter, mosaic bằng shader thật (`shaders/mosaic.frag`, cần Impeller; nơi không hỗ trợ thì làm mờ mạnh + lưới mờ để vẫn che được), tiêu điểm vẽ lớp tối có lỗ. Công thức tham số dùng chung Dart/Kotlin (`RegionMath`, cùng vector test). Khác biệt biết trước: xem trước không làm mờ dần vào/ra cho làm mờ/mosaic.
- Test: Dart 194, JUnit `RegionMathTest`; Maestro `e10_regions` PASS trên Oppo CPH2203. Đã xem khung hình video xuất: chữ bị làm mờ / chia ô / vùng tiêu điểm sáng giữa nền tối đúng vị trí; xem trước trên máy khớp.
- QA: trạng thái "ẩn công cụ" được nhớ nên flow mới dùng `helpers/ensure_tools_open`.

## [2026-10-28] Đợt 1 trình dựng kiểu CapCut: phụ đề SRT và kiểu chữ dựng sẵn
- **Nhập phụ đề .srt** (tab Chữ): mỗi dòng thành một chữ có hộp nền ở đáy khung, một bước hoàn tác. `lib/features/editor/srt.dart` đọc được BOM, CRLF, dấu chấm thay dấu phẩy, thiếu số thứ tự, thẻ `<i>` và `{n8}`; dòng ngoài độ dài video bị cắt/bỏ. Giờ phụ đề tính theo thời gian video gốc.
- **6 kiểu chữ dựng sẵn** (Cổ điển, Phụ đề, Vàng, Neon, Gọn, Nhãn) ngay dưới ô nhập chữ, một hàng cuộn ngang; chỉ đổi giao diện.
- Test: Dart 186 (`subtitles_test`), Maestro `e9_subtitles` PASS trên Oppo CPH2203 (Android 13): nhập SRT qua bộ chọn hệ thống, áp kiểu, xuất 480p; khung hình xuất có phụ đề "Xin chao" đúng vị trí.
- Ghi chú QA: `scripts/qa/push_test_media.ps1` đẩy thêm `esr_subs.srt`; bộ chọn Oppo không liệt kê file này ở "Gần đây" nên flow mở thư mục "Tải xuống"; `reset_rec_settings` cuộn tới nút "Đóng" trên màn hình ngắn; trên Oppo chạy flow không dùng `-Cold`.

## [2026-10-28] Chỉnh phóng to, chờ sau khi đánh dấu, ẩn công cụ, xem toàn màn hình
- **Chờ sau khi đánh dấu**: trước đây cố định 900 ms rồi mới bấm được. Nay có thanh trượt 0–3 s trong Cài đặt dấu (`marker.exitDelay`, mặc định 0,9 s; chỉ hiện khi bật "Tự thoát chế độ chỉ điểm"). Đi qua `RecConfig.markerExitDelayMs` tới `MarkerLayer`.
- **Phóng to**: mỗi clip phóng có thêm tốc độ phóng vào / thu lại (`ZoomItem.inMs/outMs`, 0–2 s, dự án cũ dùng 350 ms). Phóng tự động có mức phóng (1,2–4×), tốc độ và thời gian giữ thêm sau khi dấu mờ; chỉnh được ở bảng "Tự động" và trong Cài đặt dấu (chế độ sạch). Công thức Dart và Kotlin (`ZoomMath`) khớp nhau, có test.
- **Ẩn thanh công cụ** trong trình sửa (nhớ lựa chọn) và **xem toàn màn hình** có xoay ngang, chụm để phóng, thanh tua. Nút "Tự động chạy" đưa lên đầu bảng vì trên màn hình cao nó bị che.
- Test: Dart 180, JUnit `ZoomMathTest` thêm ramp; Maestro mới `e8_tools_zoom`, `g2c_exit_delay`. S25 Ultra: `e8_tools_zoom`, `g2c_exit_delay`, `g7_auto_direct`, `g3_editor`, `e1_edit_core`, `g5_dot_mode` PASS.
- Chưa kiểm tay: cảm giác thực tế của thời gian chờ ngắn (0–0,3 s) khi quay thật, và chụm phóng trong chế độ toàn màn hình (Maestro không giả lập đa chạm).

## [2026-10-27] E1–E7 — Trình dựng video chuyên nghiệp
- **E1** dòng thời gian: chọn nhiều, tách/xoá/nhân đôi, kéo đổi thứ tự, nam châm, đóng băng khung, đoạn trống. **E2** tốc độ hằng/ramp 24 bậc/chạy ngược (≤30 s)/tắt tiếng >2×. **E3** chuyển cảnh (mờ đen/trắng, trượt 4 hướng, phóng). **E4** âm lượng + fade từng đoạn, nhạc từ file, thu giọng, hạ nhạc khi có giọng, chuẩn hoá âm lượng. **E5** xoay/cắt/tỉ lệ/màu. **E6** ảnh, hình vẽ, chữ nâng cao, chuyển động vào/ra, hình-trong-hình. **E7** mẫu xuất, ước lượng dung lượng, GIF, lưu khung hình, xuất nền (ExportService foreground + thông báo + Huỷ), mẫu dự án.
- Xem trước và xuất dùng cùng công thức (golden test Dart↔Kotlin). Dự án JSON v2, tương thích dự án cũ. Quyền mới: FOREGROUND_SERVICE_DATA_SYNC, FOREGROUND_SERVICE_MEDIA_PROCESSING (không INTERNET).
- Chi tiết: `docs/EDITOR_PRO_PLAN.md` (mục 6–7), `docs/EDITOR_PRO_HANDOVER.md`. Flow máy thật: `e1_edit_core`, `e2_overlays`, `e2b_crop_rotate`, `e2_pick_probe`, `e3_motion`, `e4_audio`, `e7_background`.

## [2026-10-27] G7 — Thương hiệu, màn khởi động, trang web, bộ hồ sơ cửa hàng
- **Icon mới** (`lib/theme/brand_mark.dart`, một nguồn cho mọi thứ): giọt "ghi hình" đỏ bóng loáng giữa 3 vòng sóng ánh cầu vồng (cyan/vàng/san hô/tím) trên nền nước sâu; adaptive + monochrome (themed icon) + legacy; `store/icon_512.png`, `store/ios_icon_1024.png`.
- **Màn khởi động**: native theo sáng/tối (`splash_bg`, Android 12+ dùng icon launcher, <12 dùng `splash_logo`) nối liền với intro Flutter (`features/splash/splash_overlay.dart`): cùng huy hiệu cùng vị trí, sóng lan ra, tên + câu giới thiệu hiện dần, tan vào app (1,5 s, chạm để bỏ qua, giảm chuyển động thì tĩnh). Chỉ một lần mỗi lần mở lạnh.
- **Trang web** `site/` (vi + en, không gọi tài nguyên ngoài, sáng/tối): trang chủ, **Chính sách quyền riêng tư**, **Bảo mật**, **Hỗ trợ**. Nội dung dựa trên kiểm quyền thật của bản release (không có INTERNET). `scripts/store/build_site.ps1` điền email/tên từ `store/store_config.json` (từ chối build khi chưa có email); đăng bằng GitHub Pages (`.github/workflows/pages.yml`) hoặc Firebase Hosting (`firebase.json`).
- **Bộ hồ sơ cửa hàng**: `store/store_config.json`, `store/play/answers.json` (Data safety, xếp hạng nội dung, đối tượng, khai báo FGS mediaProjection/microphone, SYSTEM_ALERT_WINDOW, ghi chú cho người duyệt), `fastlane/` (văn bản vi/en, `Fastfile` validate/listing/internal/closed/production), ảnh chụp có khung + feature graphic (`tool/make_store_assets_test.dart`, `scripts/store/make_store_assets.ps1`), video giới thiệu + video chứng minh quyền (`scripts/store/make_videos.ps1`), `scripts/store/check_assets.ps1`.
- **`docs/store/AGENT_PLAYBOOK.md`**: hướng dẫn từng bước cho AI Agent đăng Google Play (điều kiện, ràng buộc an toàn, từng mục Play Console và giá trị, bản phát hành, cảnh báo thường gặp); `APPSTORE_STATUS.md` (chưa có iOS, kế hoạch, tài sản đã sẵn).
- Test: Dart 87 (thêm `splash_test`), Maestro `store_vi`, `store_video_a/b` (chụp/quay tài sản).

## [2026-10-26] G6b — Dấu hiệu ứng nước (gradient + chuyển động)
- Mọi dấu hết màu đơn: `marker/Water.kt` sinh gradient từ màu người dùng chọn (sáng → thân → tối, lệch sắc như ánh sáng qua nước: đỏ → đỏ thẫm, xanh lá → lục lam, xanh lơ → lam…; đen → xanh biển sâu, trắng → xanh nông), bóng loáng và điểm sáng.
- Chuyển động theo vòng 1,4 s (`phaseMs`, hàm thuần của thời gian nên quay trực tiếp, xem trước và xuất video giống nhau): **Chạm** = giọt nước (vũng mềm, 3 vòng sóng lan, giọt bóng ở giữa); **Ngón tay** = vũng + sóng dưới đầu ngón, tay gradient bóng; **Số bước** = bong bóng bóng loáng, thở nhẹ, sóng toả; **Mũi tên** = dải sáng chảy dọc thân, gật nhẹ về phía đích; **Khung/Vòng tròn** = nền nước nhạt trôi, viền có ánh sáng xoay; **Bút** = mực có dải sáng chảy. Vòng báo trước vàng là gradient quay.
- Trình chỉnh sửa/xem thử: native vẽ sẵn 14 pha (`renderMarker(phaseMs)`), `MarkerSprite` đổi pha mỗi 100 ms không nháy; xuất video vẽ liên tục ~30 khung/s. Tôn trọng "giảm chuyển động" (pha 0). 
- Màn Dấu đánh dấu: xem thử + công cụ ở trên, "Cách đánh dấu khi quay" ngay dưới.
- Test: `marker_timing_test` (pha vòng nước); Maestro `g2_marker_gallery`, `g7_auto_direct` + ảnh chụp xem thử các pha.

## [2026-10-26] G6 — Hai cách đánh dấu khi quay (chấm nhỏ · quay sạch dựng sau)
Lý do: khay chọn dấu hiện trong video mỗi lần đánh dấu nên video xuất rất xấu. Cài đặt → Dấu đánh dấu → **Cách đánh dấu khi quay**.
- **Chấm nhỏ ở góc** (mặc định; `overlay/MarkDot.kt`): chọn dấu/màu/độ dày TRƯỚC khi quay; khi quay chỉ còn một chấm 34 dp ở góc (4 góc, kéo được). Bấm chấm → chạm chỗ sắp bấm → dấu báo trước → bấm thật. Nhấn giữ chấm mở thanh điều khiển; nút "Chọn dấu" mở khay và **tự tạm dừng quay** khi khay mở, đóng khay thì tiếp tục — khay không bao giờ lọt vào video. Chạm thân thanh để đóng.
- **Quay sạch, dựng sau** (`HotCorner.kt`, `MarkerLayer(drawLive=false)`): không vẽ gì lên màn hình. Chạm vùng ẩn 56 dp ở góc (hoặc lắc máy hai lần, hoặc nút "Đánh dấu" trong thông báo) → máy rung → chạm chỗ sắp bấm (cú chạm bị nuốt) → bấm thật. Dịch vụ ghi `{tMs, holdMs, spec}` và gửi kèm sự kiện "đã lưu"; Flutter dựng sẵn dự án chỉnh sửa (`AutoDirector.draft`) với các dấu đúng thời điểm, có báo trước 0,5 s.
- **Dựng tự động** (`editor/auto_director.dart`, thuần Dart, có test): phóng to mượt vào từng dấu (gộp dấu gần nhau, không chồng), đánh số lại bước theo thời gian, tua nhanh 4× đoạn màn hình đứng yên (`IdleAnalyzer.kt`: so khung hình khoá ~1 khung/giây bằng luma; không tua phần có dấu/chữ). Tự áp phóng to + đánh số sau khi quay sạch (tắt được); tab **Tự động** trong editor chạy cả ba, hoàn tác một lần.
- Native: `RecConfig.markMode/markCorner/armShake`, quyền `VIBRATE`, `ShakeDetector`, `Haptics`; chuỗi vi/en.
- Test: Dart 82 (thêm `auto_director_test`, `clean_mode_test`), JUnit `IdleAnalyzerTest`; Maestro mới `g5_dot_mode`, `g6_clean_mode`, `g7_auto_direct`; `g1_record`, `g2_live_markers`, `helpers/record_clip` đổi sang điều khiển bằng chấm. Bằng chứng ffmpeg: video quay sạch không có gì chen vào; video xuất có dấu + vòng cue, phóng to vào dấu, đoạn đứng yên được tua (75 s → 31 s).
- Còn lại / đã biết: lắc máy và cú chạm bị nuốt cần kiểm tay (Maestro không giả lập cảm biến); ở chế độ sạch không chụm hai ngón (chỉnh dấu trong editor); trợ năng "Auto-Guide" (lấy tên nút làm chữ bước) chưa làm vì rủi ro duyệt Play.

## [2026-10-26] G5 — Tiếng Anh
- `lib/l10n/app_en.arb` (đủ 100% khoá của bản tiếng Việt, test `l10n_test` kiểm khoá và placeholder) + `android/.../values-en/strings.xml` cho thanh nổi, khay dấu, thông báo.
- Ngôn ngữ theo hệ thống: vi hoặc en; ngôn ngữ khác → tiếng Việt (`localeListResolutionCallback`). Không có công tắc ngôn ngữ trong app (native và Flutter luôn cùng ngôn ngữ).
- `docs/PLAY_STORE.md` có thêm bản mô tả tiếng Anh. Còn lại: ảnh cửa hàng tiếng Anh, người bản ngữ đọc lại bản dịch.
- Test Dart: 61.

## [2026-10-26] G4 — Hoàn thiện & phát hành
- **Biểu tượng**: vẽ bằng code từ token (chấm tally đỏ + vòng cue vàng trên nền ink), adaptive + monochrome + legacy; ảnh cửa hàng `store/icon_512.png`, `store/feature_1024x500.png` (`flutter test tool/make_icons_test.dart`).
- **Onboarding** 3 trang (ý tưởng có demo dấu thật, 3 bước chỉ điểm, quyền) + xem lại ở Cài đặt → Hướng dẫn. **Quyền và pin** (overlay/micro/thông báo/tối ưu pin) tự cập nhật khi quay lại app. **Quyền riêng tư**, **Giới thiệu** trong app. Quyền runtime đi qua `PermissionsGateway` (giả được trong test).
- **Release**: R8 + shrink resources, `proguard-rules.pro`, cấu hình ký qua `android/key.properties` (không commit), `flutter build apk --release` chạy được (55 MB; AAB tách ABI nhỏ hơn).
- **Tài liệu**: `DESIGN.md` + `.impeccable/design.json` (Impeccable), `PRODUCT.md`, `docs/PLAY_STORE.md` (listing, khai báo quyền, Data safety, checklist), `docs/PRIVACY.md`, `docs/HANDOVER.md`, `README.md`.
- Theme: nút viền dùng chữ on-surface (đỏ chỉ cho quay).
- Test: Dart 53, JUnit 3 lớp, Maestro 11 flow + `scripts/run_suite.ps1` (chạy trên bản release).

## [2026-10-26] G3 — Trình chỉnh sửa
- **Mô hình dự án** thuần Dart (`edit_project.dart`, có test): đoạn (cắt/tách/xoá/đổi chỗ/tốc độ 0,5–3×), dấu, chữ, khối che, phóng to. Thời gian lớp phủ lưu theo **thời gian gốc**; timeline hiển thị theo **thời gian video đã cắt** (`sourceToOut`/`outToSource`).
- **Dấu có "báo trước" tự động**: thêm dấu tại đầu phát = thời điểm bấm; vòng cue bắt đầu sớm 0,5 s (đoạn gạch vàng trên timeline). Kéo/chụm trên khung xem trước để di chuyển, đổi cỡ, xoay.
- **Xem trước = đúng thứ được xuất**: dấu/chữ/khối che vẽ bằng cùng bitmap native (`renderMarker/renderText/renderCover`), thời gian dùng cùng `MarkerAnim`/`ZoomMath`.
- **Timeline** (`editor_timeline.dart`): đầu phát giữ giữa, kéo để tua, chụm để thu phóng, chọn clip rồi kéo thân/hai đầu để dời/cắt bớt; nhãn trợ năng tóm tắt số đoạn/dấu/chữ/che/phóng.
- **Xuất** (Media3 Transformer 1.9, `export/`): thứ tự hiệu ứng = (khối che + dấu) → phóng to (dấu bị phóng theo nền) → chữ (không bị phóng) → tốc độ. H.264 + AAC, mã hoá dọc (không cờ xoay), chất lượng Gốc/1080p/720p/480p, tiến độ + huỷ. **GIF** (bộ mã hoá tự viết, bảng màu median-cut, ≤300 khung, 10 fps, rộng 480). **Ghép video** từ Thư viện (chọn nhiều, theo thứ tự chọn).
- **Lưu dự án** (sqflite, tự lưu sau 0,5 s): thoát giữa chừng không mất; "Làm lại từ đầu" (hoàn tác được).
- Lỗi thật đã sửa nhờ test máy thật: (1) thời gian effect trong Composition là của cả chuỗi → dùng `ItemClock` mốc khung đầu của từng đoạn; (2) Media3 vẽ overlay theo kích thước điểm ảnh gốc, không nhân thêm tỉ lệ khung; (3) thanh "Đã lưu…" che nút Bắt đầu quay / thanh công cụ; (4) sự kiện "đã lưu" gửi trước khi dịch vụ về trạng thái rảnh.
- Test: Dart 49 (model, controller, zoom math, thời gian dấu, UI); JUnit `MarkerAnimTest`, `ZoomMathTest`, `ItemClockTest`; Maestro `g3_editor`, `g3_gif`, `g3_join`, `g3_project`. Bằng chứng ffmpeg: khung xuất có khối che, chữ có viền, dấu + vòng cue, phóng to; GIF 41 khung 480×1066; ghép = tổng thời lượng.
- Còn lại / đã biết: khối che là khối đặc (Media3 không có làm mờ theo vùng); xuất chạy trong Activity (chưa là dịch vụ nền).

## [2026-10-26] G2 — Dấu đánh dấu khi quay
- **Bộ vẽ duy nhất** `android/.../marker/MarkerRenderer.kt`: ngón tay, chạm (gợn nước), mũi tên, vòng tròn, khung, bút (làm mượt), số bước. Mọi hình có viền tương phản ngược sáng (halo) để đọc được trên nền sáng lẫn tối; đơn vị `u` = chiều rộng khung / 360 nên cùng một dấu ở mọi độ phân giải. Dùng chung cho: lớp phủ lúc quay, xem trước trong app (`renderMarker` → PNG) và xuất video (G3).
- **Cue → Take** (`MarkerAnim.kt` ↔ `marker_timing.dart`, chung bộ vector test Dart + JUnit): vòng vàng co dần vào đích 500 ms (dấu mờ), rồi dấu đặc + nhịp nhấn, giữ, mờ dần.
- **Chế độ chỉ điểm** (`MarkerLayer.kt`): cửa sổ phủ toàn màn hình, mặc định xuyên chạm; bật chế độ chỉ điểm thì bắt chạm để đặt dấu (chạm = đặt, kéo = mũi tên/khung/bút, chụm hai ngón = đổi cỡ/xoay). Thoát chế độ (tự động sau ~0,9 s, tuỳ chọn) thì bắt đầu đếm "giữ dấu" rồi mới mờ — người dùng bấm thật vào đích khi người xem đã biết nhìn đâu.
- **Khay công cụ** (`MarkerTray.kt`) dưới thanh nổi: 7 công cụ, 7 màu, 3 độ dày, Hoàn tác dấu, Xoá hết dấu; mục tiêu ≥ 44 dp, có nhãn trợ năng.
- Cài đặt → **Dấu đánh dấu** (`marker_settings_screen.dart`): xem thử bằng đúng bộ vẽ native trên nền sáng/tối, công cụ mặc định, màu, độ dày, cỡ/xoay/độ trong (xem thử), thời gian giữ dấu, tự thoát. `MarkerInspector` dùng lại ở trình chỉnh sửa.
- Sheet cấu hình quay: nút **Khôi phục mặc định**; id ngữ nghĩa cho chip (`res_*`, `fps_*`, …).
- Test: Dart 21 (gồm `marker_timing_test`), JUnit `MarkerAnimTest` (`gradlew :app:testDebugUnitTest`), Maestro `g2_marker_gallery`, `g2_live_markers` PASS. Bằng chứng: ffmpeg lưới khung hình cho thấy mũi tên hiện trước khi trang "Vị trí" mở.
- Chưa tự động hoá được: chụm hai ngón để đổi cỡ/xoay (Maestro không giả lập đa chạm) — kiểm tay.

## [2026-10-26] G1 — Quay ổn định
- Pipeline quay bằng MediaCodec + MediaMuxer (`android/.../capture/RecordingSession.kt`): H.264 từ VirtualDisplay, AAC 48 kHz (micro và/hoặc âm thanh hệ thống, trộn PCM), một file MP4. Tạm dừng = bỏ video tới key frame kế + ngừng đếm mẫu audio → hai track luôn khớp.
- `RecorderService` (foreground `mediaProjection|microphone`), thông báo có Tạm dừng/Tiếp tục/Dừng, kiểm tra dung lượng (dừng êm khi < 60 MB), lưu MediaStore `Movies/E Screen Recorder`.
- Overlay gốc: thanh điều khiển nổi (kéo, thu gọn, hiện thời gian tabular, nhãn trợ năng) và đếm ngược 3·2·1 (gỡ trước khung hình đầu). Tắt thanh nổi/đếm ngược → điều khiển bằng thông báo.
- Android 14+: `MediaProjectionConfig.createConfigForDefaultDisplay()` (không dùng chọn một app).
- Kích thước lấy từ `maximumWindowMetrics` (đủ cả thanh điều hướng), thu nhỏ đều hai cạnh theo giới hạn encoder → không méo tỉ lệ.
- Flutter: màn Quay (tally rim, thẻ cấu hình, danh sách gần đây), sheet cấu hình (độ phân giải, fps, chất lượng, âm thanh, đếm ngược, thanh nổi), Thư viện (xem, chia sẻ, đổi tên, xoá có xác nhận), trình phát.
- Theme: đỏ tally chỉ cho quay/hành động chính; chọn lựa/điều hướng dùng cyan "key".
- Test: 14 test Dart; Maestro `g1_record`, `g1_library`, `g1_no_bar` PASS trên Oppo CPH2325 (720x1600 → 720x1600 H.264 + AAC, ffprobe).
- Đã biết: thanh nổi và dấu vẽ lúc quay bị ghi vào video (không ẩn được); xoay màn hình giữa chừng không đổi cỡ video (v1).

## [2026-10-26] G0 — Nền móng
- Repo riêng `e_recorder`, app **E Screen Recorder**, package `com.huluca.escreenrecorder`, minSdk 29.
- Spike `FLAG_SECURE` (Oppo Android 13): cửa sổ nổi thường được ghi vào video; cửa sổ `FLAG_SECURE` hiện **ô đen**, không ẩn được → dấu lúc quay được in thẳng vào video.
- Hướng thiết kế Impeccable "Cue before cut" (tally red / cue amber / key cyan, Barlow); token ở `lib/theme/`, hợp đồng thiết kế ở `.impeccable/surfaces/`.
- Khung app: `AppShell` (Quay / Thư viện / Cài đặt), Riverpod, chọn giao diện Sáng/Tối/Hệ thống, l10n `vi` (ARB, `flutter gen-l10n`).
- Android: thêm plugin `org.jetbrains.kotlin.android`, `kotlin.incremental=false` (pub cache khác ổ đĩa).
- Test: `test/widget_test.dart` (2), Maestro `maestro/g0_smoke.yaml` PASS (Oppo CPH2325, Android 13).
