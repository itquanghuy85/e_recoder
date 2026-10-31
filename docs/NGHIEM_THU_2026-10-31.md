# Báo cáo nghiệm thu E Recorder — 31/10/2026 (Galaxy S25 Ultra, R5CY6323KMX)

Nhãn: **PASS** đã chạy thật trên máy và đạt · **FAIL** chạy và không đạt (ghi nguyên nhân) · **BLOCKED** không chạy được do môi trường.

## 1. Dấu tự động trên ứng dụng bên thứ ba (Google Calculator)
- Cài `com.google.android.calculator` từ Google Play chính thức (installer = `com.android.vending`, nhà phát hành Google LLC).
- `scripts/qa/ux_third_party.ps1` + `maestro/ux_third_party.yaml`: quay hướng dẫn, bấm 7, 5, 3, 9, dừng, chờ dựng, xem trước, xuất.
- **PASS** (có giới hạn): 4 lần bấm ra 4 dấu. Lần chạy đầu, dấu của phím 7 lệch lên góc phải vì ô gợi ý quyền riêng tư của Calculator biến mất đúng lúc bấm (vị trí tìm từ hình: thay đổi lớn ở chỗ khác làm lệch); dấu 5, 3, 9 đúng phím. Lần chạy sau (không còn ô gợi ý) cả 4 dấu đúng phím 7, 5, 3, 9. Video xuất có dấu và zoom.
- Không thao tác trên app cá nhân. (Lần thử Chrome trước đó đã bỏ: Chrome hiện trang chủ cá nhân.)

## 2. 18 flow Maestro (sau khi thêm bước tự bật Nâng cao)
Chạy bằng `scripts/qa/run_flows18.ps1`: mỗi flow từ app nguội; dọn trình chọn tệp, Cài đặt, máy tính giữa các flow; `OTHER_APP=com.sec.android.app.popupcalculator` vì Samsung ẩn cửa sổ nổi trên Cài đặt (cách chạy đã ghi trong `scripts/run_flow.ps1`). Máy ở "đường cũ" (bỏ khoá `purpose`) vì các flow này viết cho màn Quay cũ.

| Flow | Kết quả | Ghi chú |
|---|---|---|
| e1_edit_core | PASS | lượt 2 (OTHER_APP) |
| e2_overlays | FAIL | Kịch bản trên S25: ô chữ của khung chú thích nằm sâu dưới mép bảng công cụ, 3 cách cuộn chưa ổn định. Phần đầu (tỉ lệ khung, màu) qua sau khi thêm bước vuốt. Không thấy lỗi sản phẩm; phần sau của flow chưa kiểm |
| e2_pick_probe | PASS | Kịch bản: chọn tệp theo tên thay toạ độ cố định (trình chọn Samsung nhớ thư mục) |
| e2_pip_s25 | PASS | Như trên |
| e2b_crop_rotate | PASS | Dùng Hình ảnh (Nâng cao), tự bật đúng |
| e3_motion | PASS | Dùng Chuyển cảnh (Nâng cao) |
| e8_tools_zoom | PASS | Thêm bước vuốt bảng (S25 cao) |
| e10_regions | PASS | |
| e11_region_motion | PASS | |
| e14_pip_portrait | PASS | Tạo `esr_rot.mp4` (ffmpeg, cờ xoay 90°) theo mô tả flow |
| e16_build_from_touches | FAIL | Kịch bản lỗi thời: mong dự án trống "1 đoạn", nhưng tính năng quay sạch tự nhận lần bấm (đã nghiệm thu trước) đã dựng sẵn (3 đoạn, 1 chữ). Không sửa số kỳ vọng |
| g3_editor | PASS | |
| g7_auto_direct | FAIL | Cùng nguyên nhân e16 (thấy 7 đoạn, 3 dấu, 3 chữ thay vì 1 đoạn, 2 dấu) |
| s1_icon_audit | FAIL | Sau khi lùi từ editor, app về màn phát video; flow mong về màn chính. Cần xem lại kịch bản |
| store_pro | PASS | Thêm bước vuốt bảng Tốc độ |
| store_vi | BLOCKED | Cố định quay app Cài đặt; Samsung ẩn cửa sổ nổi trên Cài đặt |
| store_en | BLOCKED | Cần đổi ngôn ngữ app sang tiếng Anh và clip của store_vi |
| store_video_b | BLOCKED | Cần store_video_a; store_video_a chờ chữ "Bắt đầu ngay", trên S25 hộp xin quyền ghi "Chia sẻ màn hình" |

Tổng: **11 PASS · 4 FAIL · 3 BLOCKED**. 4 FAIL đều do kịch bản (lỗi thời hoặc màn S25 cao), không phải hồi quy của thay đổi hôm nay. Kết quả thô: `test-results/flows18*/results.csv`.

## 3. Phục hồi khi dựng / xuất video dài
Dự án thử riêng: `QA_long_5min.mp4` (hình thử 5 phút, tạo bằng ffmpeg) mở bằng "Chọn video" từ Tải xuống; không đụng dự án thật.
- **PASS** Xuất rồi đưa app xuống nền 15 giây, mở lại: xuất vẫn chạy và xong (`ux_long.ps1`).
- **PASS** Đóng giao diện (Maestro `stopApp`) giữa lúc xuất: dịch vụ xuất nền vẫn làm xong (có tệp).
- **PASS** Giết hẳn tiến trình (`am force-stop`) giữa lúc xuất (`ux_long_kill.ps1`): không có tệp hỏng trong thư viện; dự án còn nguyên chữ đã thêm; xuất lại được (`ESR_edit_20261031_185033`, 300 s, 480×1040).
- **Đã sửa:** tệp tạm của lần xuất bị giết nằm lại trong bộ nhớ đệm (thấy 5,6 MB, và một tệp `rev_` 4,5 MB sót từ trước). `Exporter.start` giờ dọn `cache/export*` khi bắt đầu xuất; đã thấy thư mục trống sau lần xuất kế tiếp.
- **Đã sửa:** giết app giữa lúc dựng bản tự động thì mất hết dấu (lần bấm chỉ nằm trong bộ nhớ). Việc dựng giờ được ghi lại (`draft.pending`) trước khi dựng; mở app lần sau thì dựng tiếp, tối đa 2 lần để tránh vòng lặp. Trên S25 (`ux_draft_kill.ps1`): ngay sau khi giết, dự án 0 dấu; mở lại 30 giây sau có đủ 4 dấu đúng phím 7, 5, 3, 9; việc chờ được xoá.

## 4. Hồi quy
- Flutter test 387/387, `flutter analyze` sạch.
- Maestro: `ux_editor_modes` (Cơ bản/Nâng cao hai chiều, chữ, dấu, zoom, xuất, nhớ chế độ) PASS; `ux_third_party`, `ux_long`, `ux_long_kill`, `ux_draft_kill` như trên.

## Giới hạn còn lại
- Vị trí dấu tìm từ hình: thay đổi lớn ở chỗ khác lúc bấm (ô gợi ý biến mất, chuyển trang) làm dấu lệch.
- Nếu app bị giết trước khi bản ghi kịp lưu (sự kiện "đã lưu" chưa tới) thì lần bấm của bản đó không được giữ. Chưa kiểm.
- 4 flow FAIL và 3 BLOCKED ở bảng trên.

## Trạng thái máy sau nghiệm thu
- Đã cài Google Calculator (Play). Tệp thử: `Download/esr_rot.mp4`, `Download/QA_long_5min.mp4`, `Movies/E Screen Recorder/QA_long_5min.mp4` (lần đẩy thử đầu). Video thử giữ nguyên, không xoá.
- Cài đặt app: mục đích Hướng dẫn, chế độ quay sạch, editor Cơ bản. Sao lưu cài đặt trước lượt flow: `test-results/prefs_backup_flows18.xml`.
