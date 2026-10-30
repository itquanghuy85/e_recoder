# CAPTION_PLAN.md — Auto Caption cho e_recoder

## PHẦN 0 — BỐI CẢNH
Repo e_recoder. Tính năng Auto Caption: nghe giọng → CaptionCue → render dần theo nhịp thoại → template → export. Kiến trúc: preview dùng NATIVE BITMAP qua channel renderText → Image.memory. Export dùng Media3 Transformer + OverlayRenderers. Preview và Export PHẢI cùng native. cues=null → hành vi cũ e5a9c4c KHÔNG đổi.

## PHẦN 1 — MỤC TIÊU
4 RevealMode: none, wordByWord, charByChar, karaokeHighlight. 12 template. Style editor.

## PHẦN 2 — QUYẾT ĐỊNH KỸ THUẬT (KHÔNG đổi)
QĐ-1: Native render chung. Channel quantize currentMs 50ms, cache LRU 8-12.
QĐ-2: CaptionCue (không đổi typedef SubtitleCue trong srt.dart:2).
QĐ-3: copyWith sentinel _unset cho cues/captionStyle.
QĐ-4: WordTiming.startMs/endMs là source ms tuyệt đối.
QĐ-5: CaptionStyle.align là String.
QĐ-6: Schema JSON template trong doc CaptionStyle.fromJson.
QĐ-7: Font nhúng Barlow + Phase 4 thêm BeVietnam/Inter/Montserrat.
QĐ-8: iOS preview/export chưa hỗ trợ đợt này.

## PHẦN 3 — DỮ LIỆU ĐÃ XÁC NHẬN
TextItem — lib/features/editor/edit_project.dart:203. Trường: id, text, color, sizeU, x, y, startMs, endMs, bold, font, outline, box, shadow, align, rotation, opacity, motion, fx, cues, captionStyle.
OverlayRenderers.renderText + renderCue — android/.../export/OverlayRenderers.kt.
CaptionModels.kt — android/.../export/CaptionModels.kt.
textImage — editor_controller.dart:1129. _textWidget — editor_stage.dart:1021.
Exporter.kt:357-378 captionOverlays. Overlays.kt:60-115 MarkerOverlay.
Test deps đã duyệt: Robolectric 4.16.1 (test-only, `testImplementation`; dùng `@RunWith(RobolectricTestRunner::class)` + `@GraphicsMode(NATIVE)`).

## PHẦN 4 — ĐÃ HOÀN THÀNH
Phase 1 (44e78fc), H1 (58cb2d0), H2 (c16c5c4), H3 (b401fef), 2a (8842aaf), 2b+2b-fix (99c6248). 280 test PASS.

## PHẦN 5 — CÁC PHASE CÒN LẠI
Phase 2 (2c-2g): XONG, xem Phần 9.
Phase 3 (Phần 10), 4 (Phần 11), 5 + 7 + dọn dữ liệu + SRT (Phần 12): XONG. Còn lại, không làm đợt này: Whisper, timeline riêng cho phụ đề.

## PHẦN 6 — CHECKLIST CUỐI
cues=null preview/export không đổi, 6 effect e5a9c4c nguyên, 4 RevealMode, preview=export, 12 template, style editor đủ, Whisper OK, SRT OK, timeline OK, test PASS, không dep lạ, không đổi tên cũ.

## PHẦN 7 — TRẠNG THÁI
Phase 1, H1-3, 2a, 2b+fix: ✅. Phase 2 (2c-2g): ✅ (xem Phần 9). Phase 3 (chữ hiện dần): ✅ preview, xuất video chưa (xem Phần 10). Phase 4 (style editor): ✅ (Phần 11). Phase 5 (12 mẫu), Phase 7 (xuất video có phụ đề), dọn dữ liệu thử, nhập SRT vào phụ đề: ✅ (Phần 12). Whisper và timeline riêng cho phụ đề: KHÔNG làm đợt này (Phần 12, mục "Không làm").

## PHẦN 8 — KHÔNG LÀM
Không CustomPainter Flutter, không đổi typedef SubtitleCue, không tự thêm dep, không iOS export đợt này, không đổi tên cũ, không gộp phase, không tải Whisper không rõ nguồn, không sửa production để test pass.

## PHẦN 9 — PHASE 2 (đã nghiệm thu trên Galaxy S25 Ultra, serial R5CY6323KMX)

### Commit
- 2c `d0f6d03` — ExportJob parse cues + captionStyle, 6 test ExportJobParseTest.
- 2d `b7e8ef4` — kênh native `renderCue` (MainActivity) + `NativeRecorder.renderCue`, `EditorController.cueImage` (cache LRU 8), `_textWidget` dùng cue đang hiện. cues=null vẫn đi đường cũ `textImage`.
- 2e `5dec789` — `caption_panel.dart` (bottom sheet: sửa chữ, start/end ms, xoá, "+ Thêm câu", "Tắt phụ đề") + nút "Phụ đề" ở tab Chữ.
- 2f `dc90301` — Maestro smoke + sửa panel (SafeArea, lưu khi đóng sheet, chọn hết khi chạm ô số).
- 2g — rollback verify + tài liệu này (hash ở git log, message bắt đầu bằng "2g:").

### Kết quả test
- `flutter analyze` sạch; `flutter test` 282/282; `./gradlew :app:testDebugUnitTest` 71/71; `:app:assembleDebug` OK.
- Maestro `maestro/caption_phase2_smoke.yaml`: PASS. Thêm 2 câu: "Hello" hiện ở ~1.0s, "Goodbye" hiện ở ~2.4s, "Tắt phụ đề" thì hết chữ.
- Maestro `maestro/caption_rollback_effects.yaml`: PASS. 6 kiểu chữ (glow, gradient, extrude, hollow, glitch, sticker) với cues=null giống e5a9c4c (trước Phase 1). Lần chạy đầu glow mờ hơn do chụp lúc fade-in; chạy lại thì giống hệt.
- Ảnh (gitignored): `test-results/phase2/phase2_*.png`, `test-results/phase2/rollback_old/` (e5a9c4c), `test-results/phase2/rollback_new/`.

### Cách chạy Maestro trên máy này
Lệnh `maestro` trong PATH (npm) không chạy được. Dùng bản trong `D:\JOB\_tools\maestro\x\maestro\bin` kèm `JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8` (xem scripts/run_flow.ps1), qua PowerShell. Cần có sẵn 1 video `ESR_*` trong Thư viện. Thêm `--test-output-dir test-results/<tên>` để lấy ảnh. Bấm giữa máy bằng `point: 50%, 22%` để bỏ chọn item.

### Lưu ý / chưa làm
- Chỉ preview được nghiệm thu bằng Maestro. Xuất video có cues (Exporter.captionOverlays) CHƯA chạy thật, mới có test parse; để Phase 7/10.
- Chưa hiện dần theo từ (RevealMode chưa dùng): hiện cả câu cùng lúc. Phase 3.
- Chưa có style editor / template (Phase 4-5). captionStyle null thì dùng mặc định CaptionStyle().
- Item phụ đề có fade-in mặc định của chữ: ở t=0 chữ chưa hiện. Nhớ khi test bằng ảnh.
- Khi item chữ đang được chọn, nút "Phụ đề" nằm dưới hàng preset (cuộn xuống). Bỏ chọn thì nó nằm ngay dưới "Thêm chữ".
- Chuỗi mới: 5 key `captionPanel*` (vi + en).
- Phụ đề tạo ở panel là 1 TextItem chứa danh sách cues; lưu vào project như text thường.

## PHẦN 10 — PHASE 3 (chữ hiện dần theo nhịp thoại, preview)

### Đã làm
- `OverlayRenderers.renderCue(cue, style, frameW, timeMs?)`: thêm tham số `timeMs` (ms nguồn tuyệt đối). Có `timeMs` thì `revealMode` quyết định vẽ gì: `wordByWord` (từ hiện khi tới giờ), `charByChar` (các ký tự chia đều trong thời lượng từ), `karaokeHighlight` (cả câu mờ, tô sáng trái→phải theo từng từ). `none` hoặc `timeMs` null: vẽ cả câu như Phase 2.
- Kích thước bitmap luôn bằng cả câu, nên chữ không nhảy khi từ hiện ra.
- Thời gian từng từ: lấy `cue.words` nếu số từ khớp với text; không khớp (gõ tay) thì chia đều trong [startMs, endMs).
- Kênh `renderCue` nhận thêm `timeMs`. `EditorController.cueImage` lượng tử hoá 50ms (`cueRevealStepMs`), cache LRU 12; `revealMode == none` thì thời gian không nằm trong key.
- `captionStyle == null` dùng mặc định `CaptionStyle()` nên `revealMode = wordByWord`: mọi phụ đề hiện từng từ.

### Test
- `flutter analyze` sạch; `flutter test` 284/284; `gradlew testDebugUnitTest` 79/79 (8 test mới `OverlayRenderersRevealTest`: lượng ink theo thời gian ở 3 chế độ, kích thước không đổi, chia đều, ký tự); `assembleDebug` OK.
- Maestro S25 Ultra `maestro/caption_phase3_reveal.yaml`: PASS. Câu "Mot hai ba bon" (6s): ở 0.87s "Mot", 2.33s "Mot hai", 3.8s "Mot hai ba", 5.27s "Mot hai ba bon". Ảnh: `test-results/phase3/phase3_t*.png`.
- Chạy lại `caption_phase2_smoke.yaml` (PASS) và `caption_rollback_effects.yaml` (6 kiểu chữ giống e5a9c4c, PASS).

### Chưa nghiệm thu / việc còn lại
- `charByChar` và `karaokeHighlight` mới được kiểm bằng unit test (đếm ink), chưa xem bằng Maestro vì chưa có giao diện đổi `revealMode` (Phase 4 style editor).
- Xuất video: `Exporter.captionOverlays` vẫn chỉ vẽ `renderText`, CHƯA vẽ cues. Bản xuất chưa có phụ đề từ panel. Phase 7.
- Ô số start/end trong panel chưa kiểm tra tự động cho trường hợp start >= end (tự sửa end = start+1).

## PHẦN 11 — PHASE 4 (trình chỉnh kiểu phụ đề)

### Đã làm
- `caption_style_editor.dart` (MỚI): tab "Kiểu" trong panel Phụ đề. Chỉnh: hiệu ứng hiện chữ (4 kiểu), phông (6 phông có sẵn), in đậm, viền (dày + màu), đổ bóng (độ nhoè), nền (màu + bo góc), căn lề, màu chữ, cỡ chữ, vị trí dọc/ngang, "Đặt lại kiểu". Mọi thay đổi đi qua `EditorController.setCaptionStyle` và hiện ngay trên stage qua renderer native dùng chung. Kéo slider là 1 bước undo.
- `caption_panel.dart`: thêm 2 tab "Câu | Kiểu" (tab Kiểu chỉ có khi phụ đề đang bật).
- Kiểu mặc định cho phụ đề mới: `CaptionStyle.standard` (chữ trắng đậm 24U, viền đen 2U, bóng nhẹ) để đọc được trên mọi nền.
- Vị trí: **x/y của TextItem là nguồn thật** (stage và xuất video đặt chữ theo đó, nên kéo trên stage hoạt động). `setCaptionStyle` đồng bộ x/y của item theo style; editor luôn đọc x/y từ item. `CaptionStyle.x/y` chỉ là bản sao để lưu mẫu (Phase 5).
- `EditorController.turnOffCaptions`: tắt phụ đề xoá item nếu item chỉ dùng cho phụ đề (text rỗng), không để lại item rỗng trong dự án (trước đây mỗi lần tắt để lại 1 item rỗng). Item có chữ riêng thì chỉ bỏ cues.
- Tab Chữ: item phụ đề chỉ hiện tiêu đề + nút "Phụ đề" (các điều khiển chữ thường không áp dụng cho phụ đề).
- 15 key l10n mới `caption*` (vi + en).

### Test
- `flutter analyze` sạch; `flutter test` 295/295 (11 test mới `caption_style_editor_test.dart`: chip hiệu ứng/phông/viền/bóng/nền/căn lề, đặt lại, đồng bộ vị trí, undo, tắt phụ đề); `gradlew testDebugUnitTest` 79/79; `assembleDebug` OK.
- Maestro S25 Ultra `maestro/caption_phase4_style.yaml`: PASS. A: karaoke + nền (ở 1.5s "Mot" sáng, các từ sau mờ). B: từng ký tự + phông có chân + căn trái (ở 3.0s đã hiện "Mot hai"). C: hiện hết + kéo slider dọc về giữa khung. Ảnh: `test-results/phase4/`.
- Chạy lại và PASS: `caption_phase2_smoke`, `caption_phase3_reveal`, `caption_rollback_effects` (6 kiểu chữ với cues=null không đổi).

### Chưa làm / lưu ý
- Phông BeVietnam/Inter/Montserrat (QĐ-7) CHƯA thêm: cần file font bên thứ ba (giấy phép OFL, tăng dung lượng app), nên chờ bạn duyệt như một thêm tài nguyên mới. Hiện dùng 6 phông có sẵn (Barlow hỗ trợ tiếng Việt).
- Xuất video vẫn chưa vẽ phụ đề (Phase 7). Khi làm, phải đặt chữ theo `TextItem.x/y` (không dùng `captionStyle.x/y`).
- Flow rollback: sau mỗi vòng playhead trôi nhẹ nên nền video khác nhau giữa các lần chạy; so sánh bằng mắt vùng chữ.
- Dữ liệu thử trên máy S25: đã dọn các item rỗng/ "Văn bản" do các lần chạy thử cũ để lại trong dự án video `media/235`.

## PHẦN 12 — PHASE 5 (12 mẫu), PHASE 7 (xuất video), dọn dữ liệu thử, SRT, chấm kéo nhỏ

Phần này thay các ghi chú "xuất video chưa" của Phần 10 và 11.

### Phase 7 — xuất video có phụ đề
- `Overlays.kt`: `CueOverlay` (MỚI). Mỗi khung hình tính thời gian nguồn qua `ItemClock`, tìm cue đang hiện, vẽ bằng ĐÚNG `OverlayRenderers.renderCue` của preview (cùng phông, màu, viền, nền, kiểu hiện chữ), bitmap lấy từ cache LRU 24 (một cue đứng yên dùng lại bitmap, không tải lại texture). Vị trí, xoay, độ mờ, chuyển động vào/ra lấy từ item như `MotionBitmapOverlay`.
- `CueFrames.kt` (MỚI, thuần toán): cue nào hiện ở thời điểm t (đầu bao gồm, cuối loại trừ), bước hiện chữ 50ms (`REVEAL_STEP_MS`, bằng `cueRevealStepMs` bên Dart), "có cue nào nằm trong cửa sổ xuất".
- `Exporter.captionOverlays`: item có `cues` dùng `CueOverlay`, item chữ thường (cues null) đi đường cũ không đổi.
- Hiện chữ theo thời gian GỐC của video, nên đổi tốc độ / cắt đoạn vẫn đúng.

### Phase 5 — 12 mẫu phụ đề
- `assets/caption_templates.json` (12 mẫu, tên/mô tả vi + en): Chuẩn, TikTok, Karaoke vàng, Điện ảnh, Neon, Tối giản, Nhãn vàng, Máy chữ, Viết tay, Impact đỏ, Bản tin, Pastel. Dùng đủ 4 kiểu hiện chữ và cả 6 phông có sẵn; mỗi mẫu có viền, bóng hoặc nền để luôn đọc được.
- `caption_templates.dart` (đọc và kiểm tra mẫu, bỏ qua mục hỏng), `caption_template_picker.dart` (lưới 2 cột, mỗi thẻ vẽ bằng renderer native thật, chạm 1 lần để áp dụng, dấu tick ở mẫu đang dùng). Tab "Mẫu" nằm giữa "Câu" và "Kiểu" của panel Phụ đề. Chỉnh tay ở tab Kiểu thì mẫu không còn được đánh dấu.
- Áp mẫu đưa item tới vị trí của mẫu (vd Impact đỏ ở giữa khung).
- Phông BeVietnam/Inter/Montserrat: ĐÃ ĐÁNH GIÁ, KHÔNG THÊM. Cả 6 phông có sẵn hiển thị đúng dấu tiếng Việt ("Xin chào các bạn") trên S25 Ultra (xem `test-results/phase5/`), 12 mẫu đủ khác biệt, nên thêm file font bên thứ ba chỉ tăng dung lượng và rủi ro giấy phép mà không tăng chất lượng.

### Nhập SRT vào phụ đề
- Nút "Nhập phụ đề (.srt)" trong tab "Câu": thêm các dòng SRT thành cue của phụ đề (bỏ dòng ngắn hơn 100ms, cắt theo độ dài video). Nút cũ ở tab Chữ vẫn tạo chữ rời như trước (không đổi). SRT không có thời gian từng từ, nên các từ chia đều trong dòng.
- Chỉ kiểm bằng test (controller + widget có tệp thật). CHƯA kiểm trên máy thật qua hộp chọn tệp.

### Chấm kéo ở 4 góc
- Chấm khung chọn nhỏ lại: 14dp -> 8dp (núm xoay 10dp), viền mảnh hơn. Vùng chạm không đổi (vẫn bắt từ ~24dp quanh góc), nên kéo vẫn dễ.
- Khung chọn của phụ đề giờ ôm đúng dòng đang hiện (trước đây là 1 thanh mỏng), kéo góc / chụm 2 ngón đổi cỡ chữ của KIỂU phụ đề (trước đây đổi cỡ của item, không có tác dụng).

### Dọn dữ liệu thử
- Lỗi gốc đã sửa ở Phase 4: tắt phụ đề không để lại item rỗng.
- `scripts/qa/qa_data.ps1`: `-Action record|list|clean [-Apply]`. Chỉ xoá file có tên trong `test-results/qa_created_files.txt` (do test ghi, `verify_caption_export.ps1 -Record` hoặc `-Action record`); mặc định chạy thử, không xoá. Xoá file + dòng MediaStore; chỉ sửa cơ sở dữ liệu dự án khi `adb run-as` chạy được (bản debug, bản release không cho), trên BẢN SAO, sao lưu trước vào `test-results/projects_backup_*.db`, chỉ xoá dòng dự án của video bị xoá (`scripts/qa/projects_db.py`). Không động tới video/dự án thật.
- Đã chạy `clean -Apply` trên S25: xoá 5 bản xuất thử + 1 dòng dự án; DB toàn vẹn (`integrity_check` ok). Chạy lại sau lượt kiểm thử cuối (xem Kết quả).
- Dự án video `msf%3A232` có 2 chữ cũ ("EXPORT QA 2026", "Văn bản") không do đợt này tạo, nên để nguyên.

### Kết quả kiểm thử thực tế (S25 Ultra R5CY6323KMX)
- `flutter analyze` sạch; `flutter test` 317/317; `gradlew testDebugUnitTest` 85/85; build debug OK.
- Maestro PASS: `caption_phase2_smoke`, `caption_phase3_reveal`, `caption_phase4_style`, `caption_phase5_templates`, `caption_rollback_effects` (cues=null, 6 kiểu chữ giống e5a9c4c), `caption_phase7_full`, `caption_rollback_export`, `caption_phase7_speed`.
- Xuất video thật (kéo file về, cắt khung bằng ffmpeg, `scripts/qa/verify_caption_export.ps1`):
  - Luồng đầy đủ `caption_phase7_full`: tạo 2 dòng, áp mẫu "Nhãn vàng", kéo chữ lên, thoát và mở lại app (dự án giữ nguyên dòng, kiểu, vị trí), đổi sang karaoke, xuất 720p. Khung hình ở 0.6/2.2/3.7/5.2s thấy "Mot hai ba bon" tô dần từng từ, ở 6.5s không chữ, 7.6s "Goodbye" tô dần, 9.6s không chữ; timecode in sẵn trong video khớp thời điểm. Chữ ở đúng vị trí đã kéo, đúng nhãn vàng.
  - Đổi tốc độ 2x (`caption_phase7_speed`, nguồn thử tạo bằng `qa_make_test_source`): chữ bám thời gian gốc (timecode 0.6 -> "Mot", 2.2 -> "Mot hai", 3.8, 5.4, 6.4 không chữ, 7.6 "Goodbye"); video 6.0s.
  - Đồng bộ âm thanh: độ dài audio và video lệch <= 25ms ở cả hai bản xuất, âm lượng bình thường (-21 dB trung bình).
  - Chữ thường có hiệu ứng (glow) không phụ đề vẫn xuất như cũ (`caption_rollback_export`).
- Chạy lại các Phase trước (2, 3, 4) và kiểm tra rollback: không hồi quy.

### Không làm / lưu ý
- Whisper: không làm. Cần mô hình nhận dạng tải về (rủi ro nguồn và dung lượng) trong khi app đã có nhận dạng giọng nói trên máy của Android ("Tạo phụ đề tự động" ở tab Chữ). Phụ đề tự động đó vẫn tạo chữ rời kiểu cũ, chưa chuyển thành cue có kiểu/mẫu; việc nối hai bên là hướng phát triển tiếp theo.
- Timeline riêng cho phụ đề: không làm; phụ đề là 1 item chữ trên timeline hiện có, sửa dòng và thời gian trong panel.
- Nhập SRT qua hộp chọn tệp trên máy thật chưa kiểm (xem trên).
- Ảnh xem trước ở thẻ mẫu là ảnh tĩnh cả câu; hiệu ứng hiện chữ xem ở preview và video xuất.
- Chạy lại Maestro cần video `ESR_edit_20261030_121019` có sẵn trong thư viện; bài `caption_phase7_speed` cần nguồn thử: chạy `maestro/qa_make_test_source.yaml`, ghi tên file bằng `qa_data.ps1 -Action record`, đổi PATTERN trong flow, rồi `qa_data.ps1 -Action clean -Apply` khi xong.
