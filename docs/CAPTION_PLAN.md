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
2c: ExportJob.kt parse cues + captionStyle.
2d: _textWidget dùng cue active, cueImage, cache LRU.
2e: caption_panel.dart MỚI — ListView cue + nút thêm/xoá/tắt.
2f: Maestro S25 Ultra.
2g: Rollback verify + commit Phase 2.
Phase 3-10: progressive reveal, style editor, 12 template, SRT, Whisper, timeline, export, E2E.

## PHẦN 6 — CHECKLIST CUỐI
cues=null preview/export không đổi, 6 effect e5a9c4c nguyên, 4 RevealMode, preview=export, 12 template, style editor đủ, Whisper OK, SRT OK, timeline OK, test PASS, không dep lạ, không đổi tên cũ.

## PHẦN 7 — TRẠNG THÁI
Phase 1, H1-3, 2a, 2b+fix: ✅. 2c: ⚠️ dở (ExportJob.kt modified). 2d-2g: ⬜. Phase 3-10: ⬜.

## PHẦN 8 — KHÔNG LÀM
Không CustomPainter Flutter, không đổi typedef SubtitleCue, không tự thêm dep, không iOS export đợt này, không đổi tên cũ, không gộp phase, không tải Whisper không rõ nguồn, không sửa production để test pass.
