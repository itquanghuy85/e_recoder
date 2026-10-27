# E Screen Recorder — Kế hoạch

**Tên hiển thị:** E Screen Recorder · **Package:** `com.huluca.escreenrecorder` (khoá sau lần phát hành đầu)
**Nền tảng:** Android (minSdk 29) · **Phát hành:** CH Play · **Mô hình:** miễn phí hoàn toàn, không quảng cáo
**Ngôn ngữ:** Tiếng Việt trước (ARB), tiếng Anh sau khi ổn định · **Giao diện:** sáng/tối · **Thiết kế:** Impeccable

## 1. Quyết định đã chốt
- Dấu vẽ lúc quay = cửa sổ nổi, **ghi thẳng vào video** (spike: `FLAG_SECURE` hiện ô đen, không ẩn được). Không sửa được sau.
- Trình chỉnh sửa thêm dấu mới trên timeline, tự bắt đầu sớm ~0,5 s trước điểm chạm → người xem biết trước chỗ sắp bấm.
- Không dùng Accessibility ở bản đầu (rủi ro duyệt CH Play). Chặn-rồi-chạm-lại để sau.
- Kiến trúc: Flutter (UI) + Kotlin (quay, cửa sổ nổi, xuất video).

## 2. Công nghệ
| Lớp | Lựa chọn |
|---|---|
| UI | Flutter, Material 3 làm nền, token thiết kế riêng theo Impeccable |
| Quay | Kotlin: MediaProjection + MediaRecorder/MediaCodec, foreground service `mediaProjection` |
| Cửa sổ nổi | Kotlin: `TYPE_APPLICATION_OVERLAY`, vẽ vector bằng Canvas |
| Dấu trong editor | Flutter (xem trước) + dựng lại khi xuất bằng cùng mô hình dữ liệu |
| Xuất video | **Media3 Transformer** (cắt, ghép, tốc độ, lớp phủ). Không dùng FFmpeg-kit (đã ngừng bảo trì) |
| Lưu trữ | MediaStore (video), SQLite (thư viện, dự án chỉnh sửa) |
| i18n | `flutter gen-l10n`, ARB, chỉ `vi` lúc đầu |

## 3. Giai đoạn

### G0 — Nền móng (2–3 ngày)
Đổi tên package/app; cấu trúc thư mục; l10n `vi`; theme sáng/tối; CI `flutter analyze` + test; **Impeccable: chốt hướng thiết kế** (bảng màu, chữ, khoảng cách, chuyển động) trước khi làm màn hình.
*Xong khi:* app mở được, analyze sạch, có tài liệu thiết kế.

### G1 — Quay ổn định (1–1,5 tuần)
Quay toàn màn hình, độ phân giải/FPS/bitrate + cấu hình sẵn; micro và âm thanh hệ thống (Android 10+); đếm ngược; tạm dừng/tiếp tục; thanh nổi (kéo được, thu thành nút); thông báo điều khiển; lưu vào MediaStore; thư viện (xem, đổi tên, xoá, chia sẻ). Xử lý Android 14+ (xin quyền mỗi lần) và Android 15 (chia sẻ một phần).
*Xong khi:* quay 10 phút không rớt khung/mất tiếng trên ≥3 hãng máy.

### G2 — Dấu đánh dấu khi quay (2 tuần)
Công cụ: ngón tay, mũi tên, vòng tròn, khung, bút (làm mượt), số bước, gợn nước khi chạm. Chỉnh: phóng/thu, xoay, màu, độ dày, độ trong. Hoạt ảnh vào/giữ/mờ. **Chế độ chỉ điểm** (đặt dấu → nhấp nháy → tắt chế độ → bấm thật). Nút **Hoàn tác dấu**. Bộ cài sẵn màu/cỡ.
*Xong khi:* hình vẽ đạt chuẩn thiết kế, mượt 60 fps, không làm rớt khung video.

### G3 — Trình chỉnh sửa (3 tuần)
Timeline; cắt đầu cuối, bỏ đoạn giữa, ghép đoạn; thêm dấu (cùng bộ công cụ G2) với **tự bắt đầu sớm hơn điểm chạm**; chữ chú thích; làm mờ vùng nhạy cảm; zoom vào vùng; đổi tốc độ; xuất MP4/GIF, chọn chất lượng; chia sẻ.
**Spike G3 (trước khi làm):** Media3 Transformer vẽ lớp phủ vector thay đổi theo thời gian — kiểm tra chất lượng và tốc độ xuất trên máy thật.
*Xong khi:* video xuất ra khớp bản xem trước từng khung; mất điện/thoát giữa chừng không hỏng dự án.

### G4 — Hoàn thiện & phát hành (1,5 tuần)
Đo pin, nhiệt, dung lượng; cảnh báo hết bộ nhớ; hướng dẫn tắt tối ưu pin (Xiaomi/Oppo/Vivo); onboarding; chính sách quyền riêng tư; Data Safety ("không tải video lên máy chủ"); giải thích `SYSTEM_ALERT_WINDOW` + `mediaProjection` khi nộp; ảnh/chữ cho cửa hàng; kiểm thử nội bộ → kín → mở.
*Xong khi:* qua duyệt CH Play, không crash trong bản thử.

### G5 — Tiếng Anh (sau khi ổn định)
Dịch ARB `en`, kiểm tra tràn chữ, ảnh cửa hàng tiếng Anh.

## 4. Rủi ro
| Rủi ro | Cách giảm |
|---|---|
| Dịch vụ nền bị hãng máy giết | Hướng dẫn tắt tối ưu pin, thử Xiaomi/Oppo/Vivo/Samsung ngay G1 |
| Android 14/15 đổi cách xin quyền | Thử máy thật đời mới ngay G1 (hiện chỉ có 2 máy Oppo Android 13) |
| Xuất overlay bằng Media3 chậm/lệch | Spike G3; phương án dự phòng: dựng từng khung bằng Canvas rồi mã hoá |
| Duyệt CH Play từ chối | Không dùng Accessibility; mô tả mục đích rõ; chính sách quyền riêng tư |
| Màn hình DRM/`FLAG_SECURE` ra đen | Cảnh báo người dùng, không tránh được |
| Nóng máy khi quay 60 fps | Mặc định 30 fps, cảnh báo khi chọn cấu hình nặng |

## 5. Việc cần làm ngay
1. G0: đổi package, dựng khung, chạy Impeccable chốt hướng thiết kế.
2. Tìm thêm ít nhất 1 máy Samsung/Pixel và 1 máy Android 14+ để thử.
