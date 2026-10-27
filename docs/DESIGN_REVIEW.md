# Rà soát thiết kế (Impeccable finish review)

Đối chiếu với hợp đồng hướng "Cue before cut" (`.impeccable/surfaces/lib-theme-app-theme-dart.md`) và `DESIGN.md`. Rà trong luồng (không có subagent), bằng ảnh chụp máy thật (Oppo CPH2325, 720×1600) và test widget.

## Kết quả theo hợp đồng
| Mục hợp đồng | Kết quả |
|---|---|
| THESIS — báo trước rồi mới bấm | Đạt: vòng cue vàng thu vào đích 500 ms → dấu đặc; thấy trong video quay, xem trước và file xuất (ffmpeg xác nhận) |
| OWN-WORLD — ink + tally đỏ + cue vàng + key cyan, Barlow | Đạt; token ở `lib/theme/`, bản gốc native `overlay/Ui.kt` khớp |
| STORY — nhìn là biết đang quay | Đạt: viền tally nhấp nháy khi mở app lúc đang quay, thanh nổi, thông báo |
| FIRST VIEWPORT — danh sách gần đây, thẻ cấu hình, nút quay đỏ to ở vùng ngón cái, 3 tab | Đạt |
| Cue → Take (nét ký) | Đạt: `MarkerAnim` (Kotlin) = `MarkerTiming` (Dart), chung bộ vector test |
| Raise "độ dài = thời lượng" (labanotation) | Đạt: chip dấu trên timeline có đoạn cue gạch vàng rồi đoạn giữ theo đúng thời lượng |
| Raise "huỷ cô lập" (dark console) | Đạt: nút Xoá luôn dạng viền, tách khỏi nút khác; xác nhận bằng hộp thoại |
| Raise "giờ căn phải, tabular" (j-card) | Đạt: `timecodeStyle` ở danh sách, transport, ruler |

## Lỗi tìm thấy và đã sửa
1. Đỏ rò sang lựa chọn (chỉ báo thanh tab, nút chữ, công tắc, chip chọn, nút viền, Phát/Xuất) → chuyển sang cyan; đỏ chỉ còn cho quay.
2. Nút Xoá trong bảng chỉnh bị khuất → đưa lên hàng tiêu đề của bảng.
3. Thanh "Đã lưu…" che nút Bắt đầu quay / tab công cụ → margin cao hơn nút, tự ẩn khi bắt đầu quay hoặc mở màn mới.
4. Xem trước dấu: nút giả lệch vị trí đích; dấu hơi nhỏ/mảnh → đã chỉnh cỡ ngón tay (66 u) và đầu mũi tên.
5. Chữ quá lớn (150–200%) tràn: màn Quay cuộn được; trang onboarding đầu cuộn; thời lượng trong danh sách tự thu nhỏ; nút Tiếp xuống dòng thay vì tràn.
6. Nút Xuất/Phát là đỏ → cyan (hành động chính ngoài quay không dùng màu "live").

## Kiểm tra
- Tương phản: chữ chính ≥ 12:1; chữ phụ `#48526A` trên `#F6F8FB` ≈ 7:1; cyan sáng `#00687A` trên daylight ≈ 6:1; nút đỏ `#C4161C` + trắng ≈ 6,1:1.
- Mục tiêu chạm ≥ 48 dp (44 dp trong khay nổi, có nhãn trợ năng tiếng Việt).
- Chữ 100/150/200% (`test/accessibility_test.dart`), sáng/tối, giảm chuyển động (bỏ pulse và vòng cue).
- Chưa kiểm: máy tablet/gập, Dynamic Color (cố ý tắt ở v1), màn hình rất nhỏ (< 320 dp).

## Còn lại (không chặn phát hành)
- Thanh trạng thái hệ thống đang xám trên Android 13 (chưa edge-to-edge); Android 15 tự edge-to-edge nhờ `SafeArea`.
- Ảnh cửa hàng nên chụp từ máy thật với dữ liệu mẫu đẹp (hiện là ảnh Maestro).
