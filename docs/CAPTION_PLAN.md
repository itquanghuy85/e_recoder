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
Phase 3-10: progressive reveal, style editor, 12 template, SRT, Whisper, timeline, export, E2E.

## PHẦN 6 — CHECKLIST CUỐI
cues=null preview/export không đổi, 6 effect e5a9c4c nguyên, 4 RevealMode, preview=export, 12 template, style editor đủ, Whisper OK, SRT OK, timeline OK, test PASS, không dep lạ, không đổi tên cũ.

## PHẦN 7 — TRẠNG THÁI
Phase 1, H1-3, 2a, 2b+fix: ✅. Phase 2 (2c-2g): ✅ (xem Phần 9). Phase 3-10: ⬜.

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
