# Phương án: cài đặt theo chế độ quay và thời gian hiện dấu (đã chốt 31/10/2026)

Người dùng đã duyệt ("ok triển khai"). Làm theo thứ tự: Phần A (lỗi dấu) trước, Phần B (gom cài đặt) sau. Mỗi phần một commit, nghiệm thu trên S25.

## Phần A: dấu trong bản dựng tự động (chế độ quay sạch)
**Lỗi:** mỗi dấu luôn hiện cố định `holdMs` (2,5 giây) kể từ lúc bấm.
- Bấm làm đổi màn hình: dấu còn lan sang màn mới.
- Bấm nhanh: nhiều dấu cùng lúc.

**Đặc tả:** dấu bắt đầu mờ ở mốc sớm nhất trong ba mốc sau:
1. Mờ xong trước khi màn hình đổi hẳn (đổi từ 20% hình trở lên). Mốc này dò từ khung hình, trong khoảng tới lần bấm kế, tối đa 3 giây.
2. Mờ xong trước khi bóng mờ của dấu kế bắt đầu hiện.
3. Hết thời gian giữ dấu đã cài.

Quy tắc kèm theo:
- Hai lần chạm cách nhau dưới 0,3 giây chỉ giữ một dấu, bất kể vị trí (vị trí lần chạm thứ hai hay bị dò sai).
- Dừng hình tại lần bấm vẫn giữ dấu hiện đủ: dấu chạy theo thời gian của video gốc, mà thời gian này đứng yên trong lúc dừng hình.

**Tiêu chí nghiệm thu:**
- Không bao giờ có hai dấu đậm cùng lúc: dấu trước mờ xong trước lúc dấu sau hiện đủ.
- Không còn dấu trên khung hình đầu tiên của màn mới trong video xuất.
- Bấm đúp ra đúng 1 dấu.
- Test tự động bao phủ cả ba mốc.

## Phần B: cài đặt gắn vào từng chế độ quay
**Màn Quay**, từ trên xuống:
1. Thanh chọn chế độ `[Hướng dẫn | Game | Quay thường]`. Thay cho nút "Đổi mục đích"; đổi chế độ một chạm, không sang màn khác.
2. Lựa chọn chính của chế độ đang chọn (3–5 mục).
3. Nút lớn "Bắt đầu quay".
4. "Thêm tuỳ chọn" (đóng sẵn): các mục ít dùng của chế độ đó. Thay cho "Nâng cao"; bỏ thẻ cài đặt chung.

| Chế độ | Lựa chọn chính | Thêm tuỳ chọn |
|---|---|---|
| Hướng dẫn | Âm thanh (micro / âm máy), độ nét, dấu bấm (tự động sau khi quay / bấm tay khi quay / không dấu), đánh số bước, tự phóng to | Kiểu dấu, thời gian hiện dấu, dừng hình khi bấm, khung hình/giây, chất lượng, đếm ngược |
| Game | Âm thanh, độ nét, mượt (60 hình/giây), bút vẽ nổi | Nút nổi, chất lượng, đếm ngược |
| Quay thường | Âm thanh, độ nét | Đếm ngược, nút nổi, khung hình/giây, chất lượng |

- **Mỗi chế độ nhớ cài đặt riêng.** Lần đầu sau khi cập nhật, cả ba chế độ lấy giá trị đang dùng làm điểm khởi đầu. Khoá cũ giữ nguyên tên, không xoá.
- **Bỏ màn chọn mục đích lúc mới cài.** Mặc định chọn "Hướng dẫn".
- **Bỏ trang "Dấu" trong Cài đặt.** Cài đặt chỉ còn: giao diện, ngôn ngữ, quyền, giới thiệu, "Đưa các chế độ về mặc định".

**Tiêu chí nghiệm thu:**
- Đổi một cài đặt ở chế độ A không làm đổi chế độ B; mở lại app vẫn đúng.
- Lần quay dùng đúng cài đặt của chế độ đang chọn.
- Người dùng cũ không mất cài đặt.
- Cài đặt không còn trang Dấu.
- Có Maestro trên S25 cho cả ba chế độ.

## Kết quả
### Phần A: RUNTIME_VERIFIED trên S25
Lệnh chạy: `bash scripts/qa/ux_mark_timing.sh`. Flow `maestro/ux_mark_timing.yaml` quay máy tính Samsung ở chế độ sạch theo trình tự:
1. Bấm 7, 5, 3.
2. Bấm phím 8 nhanh 3 lần, cách nhau 0,45 giây.
3. Bấm đúp phím 2, cách nhau 0,1 giây.
4. Bấm phím 1.
5. Bấm "Chuyển đổi đơn vị" (mở màn mới).

Script đọc dự án vừa lưu (`marks_timing.py`) và cắt khung hình từ video xuất.

| Lượt | Kết quả | Ghi chú |
|---|---|---|
| 1 (lệch trước 0,15 s) | Chưa đạt | Dấu nút chuyển đổi còn mờ dần trên màn mới khoảng 0,3 giây. Sửa: dấu phải mờ xong trước mốc đổi (lệch trước 0,45 s) |
| 2 | FAIL | Bấm đúp phím 2 ra 2 dấu cách nhau 0,12 giây, vì lần chạm thứ hai bị dò vị trí ở góc trên phải. Phát hiện thêm: chữ "Typing…" / "Typed" ra tiếng Anh trong bản dựng sau khi quay. Sửa: chạm dưới 0,3 giây luôn gộp; truyền chữ tiếng Việt |
| 3 | **PASS** | 6 dấu (7, 5, 3, 2, 1, chuyển đổi), "never two full marks: PASS". Dấu nút chuyển đổi: giữ 0 ms, hiện suốt lúc dừng hình, mờ xong trước khi màn chuyển đổi trượt vào (ảnh `test-results/ux_mark_timing/last_mark_frames.png`, từ ô 8 không còn dấu). Bấm đúp ra 1 dấu. Phím 8 bấm nhanh thành bước "Đang nhập…" / "Đã nhập" (tiếng Việt) |

Giới hạn còn lại:
- Phím nằm ở nửa dưới màn hình bấm từ 3 lần trong 2 giây được coi là "gõ phím" và gộp thành một bước "Đang nhập…". Đây là quy tắc có sẵn (cài đặt "Khi gõ phím"), không đổi trong phần này.
- Hai lần bấm cách nhau 0,3–0,8 giây: bóng mờ (22%) của dấu sau có thể chồng lên dấu trước đang mờ dần, tối đa 0,3 giây. Không bao giờ có hai dấu đậm cùng lúc.
- Mốc "màn hình đổi" chỉ có ở bản dựng ngay sau khi quay sạch. Nút "Dựng tự động" trong trình sửa dò lần bấm theo cách khác, nên chỉ được quy tắc "một dấu mỗi lúc".

### Phần B: RUNTIME_VERIFIED trên S25
**Cách làm** (không đổi tên khoá cũ):
- Các khoá `rec.*` và `marker.*` vẫn là bộ cài đặt đang dùng mà cả app đọc.
- Mỗi chế độ có một bản lưu riêng `purpose.profile.<tên chế độ>` (JSON).
- Đổi chế độ: chụp bộ đang dùng vào bản lưu của chế độ cũ, rồi nạp bản lưu của chế độ mới. Chế độ dùng lần đầu lấy bộ đang dùng, cộng thiết lập sẵn của chế độ.
- Máy chưa từng chọn mục đích: tự chọn "Hướng dẫn", giữ nguyên các cài đặt cũ.
- "Đưa các chế độ quay về mặc định": xoá các bản lưu và bộ đang dùng, rồi áp thiết lập sẵn của chế độ hiện tại.
- Mã: `lib/features/purpose/purpose.dart` (`PurposeNotifier.choose/resetAll`, `profileKeys`), `quick_options.dart` (`QuickOptions`, `MoreOptions`, `MarkWhen`), `record_screen.dart`, `settings_screen.dart`, `SettingsStore.getRaw/setRaw`.

**Bỏ đi:**
- Màn chọn mục đích lúc mới cài (`purpose_screen.dart`).
- Trang Dấu (`marker_settings_screen.dart`, `touch_source_section.dart`).
- Bảng cài đặt quay (`showRecSettingsSheet`).
- Thẻ cài đặt, "Nâng cao", "Đổi mục đích" trên màn Quay.
- Thông báo "Đã lưu… Xem": sau khi quay luôn mở màn kết quả.

Các mục từng chỉ có trên trang Dấu giờ không còn chỗ chỉnh và giữ giá trị đã lưu: góc chấm, lắc để đánh dấu, tự thoát và thời gian chờ sau khi đặt dấu, độ phóng và tốc độ phóng to, cách xử lý khi gõ phím. Đúng phạm vi phương án đã chốt.

**Test tự động:** `test/purpose_test.dart` viết lại cho hành vi mới:
- mỗi chế độ nhớ riêng;
- người dùng cũ giữ cài đặt;
- "Thêm tuỳ chọn" khác nhau theo chế độ;
- đưa về mặc định;
- ba kiểu dấu bấm.

Các test khác cập nhật: `onboarding_test`, `l10n_test`, `settings_layout_test`, `widget_test`. Flutter test 394/394, analyze sạch.

**Maestro:** `bash scripts/qa/ux_modes_record.sh` + `maestro/ux_modes_record.yaml`, PASS (exit 0) ở lượt 4. Ba lượt trước hỏng đều do kịch bản:
- Maestro không đọc được trạng thái "đang chọn" của chip theo id;
- mục "Thêm tuỳ chọn" phải tìm theo id `record_more`;
- sau khi bắt đầu quay, app tự lùi xuống nền, phải mở lại app để bấm Dừng.

Kết quả đo:
- Bản lưu riêng:
  - Hướng dẫn: `resolution=0` (720p), `fps=30`, `marker.mode=1`, `touchSource=3` (quay sạch, dấu tự động).
  - Game: `resolution=2` (gốc), `fps=60`, `marker.mode=0` (dấu bấm tay).
- Mở lại app (dừng hẳn rồi mở) vẫn đúng chế độ và cài đặt. Ảnh: `test-results/ux_modes_record/maestro/.../modes_3c_after_restart.png`.
- Hai video quay thật (ffprobe):
  - Game: **1440×3120** (độ nét gốc).
  - Hướng dẫn: **720×1560** (720p).
- Cài đặt không còn trang Dấu, có "Đưa các chế độ quay về mặc định".
- Cài đặt của app được trả lại y hệt bản sao lưu (`cmp` giống hệt).

**Chưa chứng minh được bằng video:** số khung hình/giây. Bản quay màn hình chỉ sinh khung khi màn hình đổi (đo được khoảng 26 khung/giây ở cả hai bản). Mức 60/30 chỉ xác nhận qua cài đặt đã lưu.

**Ghi nhận theo thiết kế:** chế độ dùng lần đầu lấy cài đặt đang dùng. Ví dụ ở lượt test, "Quay thường" mở lần đầu ngay sau Game nên nhận luôn 60 hình/giây và độ nét gốc của Game.

**Kịch bản Maestro cập nhật theo giao diện mới:**
- Flow phụ `after_stop.yaml` (mới) thay cho chờ "Đã lưu ESR_…" ở 17 chỗ. Cập nhật thêm các flow phụ `record_clip`, `reset_rec_settings` (dùng "Đưa các chế độ quay về mặc định"), `set_mark_mode` (Hướng dẫn + Tự động/Bấm tay; `CORNER` bỏ qua), `set_marker_hold_max/min`.
- Bấm tab Quay bằng mẫu `'Quay\sTab.*'`, vì "Quay.*" khớp nhầm nút "Quay thường".
- Sửa `g1_no_bar`, `s1_icon_audit`, `store_vi`, `store_en`, `ios_smoke` và các flow `ux_*` (nút "Bắt đầu quay").
- Bỏ các flow chỉ kiểm giao diện đã bỏ: `clean_auto_touches`, `e15_touch_settings`, `g2c_exit_delay`, `g2d_marker_preview_sticky`, `g2e_hold_stay`, `settings_layout`, `ux_simple_flow`, cùng script `ux_flow.ps1`.

### Hồi quy sau Phần B (S25, 01/11/2026)
- 19 flow (`run_flows18.ps1`, `test-results/flows18_modes`): **19/19 PASS**.
  - Gồm 18 flow chính và `store_video_a`.
  - Có cả 4 flow trước đây còn FAIL: e2_overlays, e3_motion, store_pro, store_video_b.
- Lượt đầu bị dừng giữa chừng vì lỗi kịch bản do mình sửa: chờ chữ "Quay" / bấm "Cài đặt" khớp chính xác, trong khi nhãn tab thật có hậu tố "Tab 1 trong tổng số 3". Đã sửa, rồi chạy lại toàn bộ.
- Phần A chạy lại trên giao diện mới (`ux_mark_timing.sh`, flow chọn "Tự động sau khi quay" bằng giao diện): PASS, 6 dấu, "never two full marks: PASS".
- Cài đặt của app trên S25 đã trả về đúng bản sao lưu trước khi chạy (`test-results/prefs_backup_flows18_modes.xml`, so `cmp` giống hệt). Video thử để lại trên máy, không xoá.

## Đợt 2 (01/11/2026): dấu còn lan sang màn sau, zoom, số bước

Người dùng báo sau đợt 1: dấu vẫn lan sang màn hình sau; muốn thanh thời gian hiện dấu và cài đặt zoom nằm ngay trong các chế độ, zoom tới 300% và lấy điểm chạm làm tâm; video quay sạch không bật đánh số vẫn hiện "Bước 18, 19, 20" gần cuối.

**Nguyên nhân và cách sửa** (`CODE_OBSERVED` + `TEST_VERIFIED`; chưa chạy thật trên S25, xem "Chưa nghiệm thu"):
- **Dò màn hình đổi quá chặt.** Trước đây tính theo phần trăm điểm ảnh đổi (từ 20%). Trang trắng sang trang trắng khác chữ chỉ đổi rất ít điểm ảnh nên không dò ra, dấu giữ đủ 2,5 s trên màn mới. Nay chia khung thành 12×24 ô và đếm ô đổi (từ 15%): một dòng sáng lên hoặc dãy số đổi (khoảng 7–12% số ô) vẫn không bị tính là màn mới; trang chữ khác thì đổi trên 70% số ô. `TouchScan.changedBlocks`, 3 test Kotlin (nút bấm, trang chữ, dòng sáng).
- **Chạm do chính thao tác Dừng quay.** `TouchWatcher` nghe cả chạm lên app mình, nên lúc kéo thông báo, mở lại app và bấm "Dừng quay" cũng ghi thành lần bấm. Nay `RecorderService` bỏ chạm khi app đang ở phía trước, và khi app về phía trước thì xoá các chạm trong 1,5 s gần nhất (chạm dẫn về app). `MainActivity.onResume/onPause`.
- **"Bước N" dù tắt đánh số.** Kiểu dấu mặc định là "Số" nên luôn vẽ số, và lần chạm không rõ vị trí luôn ra chữ "Bước N". Nay tắt "Đánh số các bước" thì dấu kiểu Số được vẽ thành vòng gợn nước, không còn chữ "Bước N" (kiểu dấu do người dùng chọn vẫn giữ). Nhãn đổi từ "Đánh số lại các bước" thành "Đánh số các bước" (đúng nghĩa hơn). `AutoDirector._tapKind`.
- **Zoom lệch tâm.** Trước đây các lần chạm gần nhau được gộp, tâm zoom là trung điểm và mức phóng bị giảm. Nay mỗi lần chạm có zoom riêng, tâm đúng điểm chạm, mức phóng đúng mức đã đặt: chạm cùng một chỗ thì dùng chung một zoom; chạm chỗ khác trước khi zoom xong thì zoom cũ thu lại sớm; chuỗi chạm quá nhanh chỉ zoom ở lần chạm cuối. Tâm chỉ bị dịch khi điểm chạm sát mép (khung zoom không thể ra ngoài video: ở 300% là ngoài dải 17–83% mỗi chiều). `AutoDirector.autoZoom`.

**Giao diện** (`quick_options.dart`):
- Hướng dẫn (dấu tự động): thanh "Thời gian hiện dấu" (0,5–10 s, id `quick_hold`) và thanh "Mức phóng" (120–300%, id `quick_zoom_scale`, chỉ hiện khi bật "Phóng to vào dấu"). "Thêm tuỳ chọn" có thêm tốc độ phóng vào/ra (`more_zoom_ramp`) và giữ thêm (`more_zoom_hold`).
- Game: thanh "Thời gian hiện dấu" cho dấu bấm tay.
- Nút "Bắt đầu quay" được ghim cố định dưới đáy, phần lựa chọn cuộn phía trên: lựa chọn dài ra không đẩy nút khỏi tầm tay.

**Test tự động:** Flutter 397/397, analyze sạch, Kotlin unit test đạt. Thêm test: tâm zoom đúng điểm chạm ở 300%, chạm cùng chỗ, chạm chỗ khác, chuỗi chạm nhanh, tắt đánh số (không số, không "Bước N"), hai thanh trượt (kể cả 120%…300%).

**Chưa nghiệm thu (BLOCKED):** S25 không kết nối trong lượt này (ADB chỉ thấy hai máy Oppo, không dùng). Chưa chạy lại trên S25: `scripts/qa/ux_mark_timing.sh`, `scripts/qa/ux_modes_record.sh`, hồi quy 19 flow, kiểm tra thật zoom 300% và việc bỏ chạm khi dừng quay. Flow `ux_modes_record.yaml` và `set_marker_hold_max/min` đã sửa theo id mới nhưng chưa chạy. Cần chạy khi S25 kết nối lại.

## Đợt 3 (01/11/2026): dấu hết trước khi đổi màn, vuốt mở rộng vùng làm việc, hướng dẫn thiết lập, báo "chỉ có trên Android"

Người dùng yêu cầu thêm: (1) Android tải về dùng được ngay không, cái nào cần bật quyền hay chế độ nhà phát triển thì phải hướng dẫn, nói rõ kết quả và có ảnh; (2) màn sửa: vuốt xuống ở khung xem trước / timeline để mở rộng vùng làm việc, vuốt lần nữa thì toàn màn hình, vuốt lên để thu lại; (3) iOS làm được gì thì phải báo rõ tính năng chỉ có trên Android.

### Dấu hết hẳn trước khi màn hình đổi (RUNTIME_VERIFIED trên S25)
- Cài đặt đang có trên S25 (bản sao lưu `test-results/prefs_backup_r3.xml`, có thể do các flow thử để lại): thời gian hiện dấu **0,5 s** (thấp nhất), dừng hình tại lần bấm 0,2 s. Dấu chỉ còn chừng 0,8 s nên chỗ dấu "lan sang màn mới" xảy ra khi màn đổi chỉ khoảng 0,25 s sau lần chạm: dấu mờ dần (0,3 s) đè lên màn mới. Đây là suy luận từ số liệu, chưa tái hiện trên video của người dùng.
- Sửa: lần bấm làm đổi màn gần như ngay thì dấu được lấy **sớm hơn lần chạm tối đa 0,45 s**, và ảnh dừng hình cũng ở đúng chỗ đó, để người xem thấy dấu bấm xong, mờ hết, rồi mới đổi màn. `AutoDirector.markTimes`, 3 test.
- Ảnh kiểm trên S25 (máy tính Samsung, bấm "Chuyển đổi đơn vị"): `test-results/ux_mark_timing/last_mark_frames.png` ô 4–5 dấu mờ dần trên màn cũ, ô 6 màn "Chuyển đổi đơn vị" **không còn vòng dấu**. `ux_mark_timing.sh`: 6 dấu, "never two full marks: PASS".

### Vuốt để mở rộng vùng làm việc (RUNTIME_VERIFIED trên S25)
- Vuốt nhanh xuống trên khung xem trước, thanh phát hoặc timeline: **lần 1** gập công cụ (như nút "Ẩn công cụ"), **lần 2** toàn màn hình (màn xem toàn màn hình có sẵn). Vuốt **lên**: thu lại từng bước (từ toàn màn hình về gập công cụ, rồi về như cũ).
- Cách làm an toàn (`SwipeZone`): chỉ nghe chạm thô, **không tham gia cuộc đua cử chỉ**, nên kéo timeline, kéo dấu, chụm phóng không bị ảnh hưởng. Chỉ tính là vuốt khi một ngón, dài từ 72 điểm, dốc hơn 2:1, xong trong 0,65 s. Trên khung xem trước, không nhận khi đang chọn một dấu / chữ / hình (lúc đó kéo là di chuyển nó). Trong màn toàn màn hình, không nhận khi ảnh đang được phóng.
- Gợi ý: 3 lần mở editor đầu có dòng nhắc mờ "Vuốt xuống để mở rộng vùng làm việc…" ở khung xem trước (không nhận chạm, tự ẩn sau 5 s).
- **Lỗi do mình gây ra rồi đã sửa trong lúc làm:** dòng nhắc, khi ẩn, trả về một ô rỗng không định vị làm khung xem trước co về kích thước 0 (xem trước bị trắng, vuốt không tới). Đã sửa (luôn là phần tử định vị), tách `SwipeHint`, thêm test `swipe_hint_test` (khung xem trước giữ nguyên kích thước sau khi nhắc ẩn).
- Flow `maestro/ux_swipe_guide.yaml` PASS: kiểm vuốt ngang không đổi gì, xuống 2 lần, lên 2 lần, ảnh `sw_0..sw_3`.

### Hướng dẫn thiết lập (RUNTIME_VERIFIED trên S25 cho Android)
- **Android dùng được ngay sau khi cài**: quay màn hình chạy được với hộp thoại của hệ thống. Các bước dưới đây mở thêm tính năng:
  1. **Hiện trên ứng dụng khác** (nên bật): thanh nổi, đếm ngược 3-2-1; khi quay sạch app nghe được từng lần bấm để tự đặt dấu sau khi quay xong.
  2. **Micro** (nên bật): thu giọng nói khi chọn Micro.
  3. **Thông báo** (nên bật): nút Tạm dừng / Dừng trên thanh thông báo.
  4. **Hiển thị lần chạm (chế độ nhà phát triển)** (tuỳ chọn): quay như bình thường, quay xong app tự đánh dấu đúng chỗ đã bấm, kể cả chỗ màn hình không phản hồi. Có nút mở "Thông tin điện thoại" (bấm 7 lần Số hiệu bản dựng) và "Tùy chọn nhà phát triển", hiện trạng thái hiện tại.
  5. **Quay lâu không bị ngắt** (tuỳ chọn): đặt Pin của app thành không hạn chế.
- Mỗi bước có: trạng thái Đã bật / Chưa bật, **Bạn được gì**, **Cách bật**, nút mở đúng chỗ, và **ảnh thật** (2 khung hình từ một bản quay thật trên máy tính Samsung: vòng dấu hiện trước chỗ sắp bấm, dấu đúng chỗ ngón tay). Tự kiểm lại trạng thái khi quay về app từ Cài đặt hệ thống.
- Vào từ: Cài đặt → "Hướng dẫn thiết lập"; và thẻ **"Còn N bước thiết lập"** trên màn Quay (chỉ hiện khi còn thiếu quyền cần thiết). Mã: `lib/features/setup/setup_guide_screen.dart`, ảnh `assets/guide/*.png` (thêm vào `pubspec.yaml`, không thêm thư viện).
- **Chưa có:** ảnh chụp chính trang Tùy chọn nhà phát triển của hệ thống (tên mục khác nhau theo hãng máy, đã ghi chú trong hướng dẫn) và video minh hoạ. Hình của bước nhà phát triển dùng ảnh kết quả, không phải ảnh trang hệ thống.

### Báo "chỉ có trên Android" ở iPhone (TEST_VERIFIED; kiểm trên Simulator xem bên dưới)
- Mọi tính năng iPhone chưa có đều hiện nhãn **Android** thay vì lặng lẽ không chạy: bấm vào nhãn thì hiện bảng nói tính năng đó là gì, bạn được gì trên Android, vì sao iPhone chưa có.
- Màn Quay (iPhone): khối "Dấu tự động theo lần bấm" (tutorial), "Dấu nổi khi quay" (game), "Thanh nổi và đếm ngược" mờ đi, có nhãn, bấm vào để đọc giải thích. Có nút "Xem chi tiết": **Làm được** / **Chỉ có trên Android** (liệt kê đủ).
- Màn sửa (iPhone): Chuyển cảnh, Phóng to, Dựng tự động: thay bảng bằng giải thích (có biểu tượng Android ở tab); Tốc độ (tăng dần, phát ngược), Hình ảnh (bộ lọc màu), Chèn hình (video lồng video), Che vùng (làm mờ, khảm, tô sáng): dùng được phần có sẵn kèm một dòng nói phần nào chỉ có trên Android. Cơ sở: `ios/Runner/IOSExporter.swift` ("Not done yet: speed ramps, reversed clips, transitions, zoom, blur / mosaic / spotlight, picture-in-picture videos, colour looks, GIF") và các lệnh `unsupported` trong `RecorderChannel.swift` (thu giọng, phụ đề, GIF).
- Mã: `lib/core/platform_support.dart` (`isIOS`, `AndroidOnly`, `AndroidOnlyPanel`, `AndroidOnlyNote`, `AndroidBadge`).

### Kiểm thử kỹ thuật
Flutter test 428+, analyze sạch, Kotlin unit test đạt. Test mới: `swipe_zone_test` (9), `swipe_hint_test` (3), `setup_guide_test` (8), `ios_editor_gate_test` (12), thêm 3 test ở `touch_log_test`.

### Hồi quy S25 sau Đợt 3 (01/11/2026): CHƯA ĐỦ
- **11/19 flow đạt (RUNTIME_VERIFIED):** e1_edit_core, e2_overlays, e2_pick_probe, e2_pip_s25, e2b_crop_rotate, e3_motion, e8_tools_zoom, e10_regions, e11_region_motion, e14_pip_portrait, e16_build_from_touches.
- **8 flow chưa chạy được:** g3_editor, g7_auto_direct, s1_icon_audit, store_vi, store_en, store_pro, store_video_a, store_video_b. Nguyên nhân: S25 (`R5CY6323KMX`) mất kết nối adb giữa lúc chạy ("device not found"), không phải lỗi sản phẩm. **Không ghi PASS** cho 8 flow này; cần cắm lại S25 và chạy lại.
- Cài đặt app trên S25 chưa khôi phục được từ `test-results/prefs_backup_r4.xml` (máy mất kết nối); cần khôi phục khi cắm lại.

