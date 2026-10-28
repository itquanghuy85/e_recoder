# Tính năng theo nền tảng / Features by platform

Cập nhật 27/10/2026. **Android: có bản chạy được. iOS: chưa phát hành** (xem mục 3).
Cột "Kiểm chứng" nói rõ đã thử trên máy thật hay chưa; không có chữ "đã thử" nghĩa là chưa.

*Updated 27 Oct 2026. **Android: available. iOS: not released** (see section 3). "Verified" says whether a feature was tested on a real device.*

Ký hiệu: ✅ có · ⚠️ có giới hạn · ❌ không có · 🕓 dự kiến (chưa làm)

## 1. Quay màn hình

| Tính năng | Android 10+ | iOS | Ghi chú |
|---|---|---|---|
| Quay màn hình (MP4) | ✅ | 🕓 | iOS cần ReplayKit + Broadcast Extension viết riêng |
| Quay tiếp khi thoát app | ✅ | 🕓 | iOS: phải qua Broadcast Extension (bấm giữ nút quay của hệ thống) |
| Tiếng micro | ✅ | 🕓 | |
| Âm thanh hệ thống (tiếng trong app khác) | ⚠️ tuỳ app/Android | ❌ | iOS không cho app thứ ba thu tiếng nội bộ |
| Đếm ngược 3-2-1 nổi trên app khác | ✅ | ❌ | iOS không có lớp phủ trên app khác |
| **Dấu báo trước** nổi trên app đang quay | ✅ | ❌ | Tính năng đặc trưng; iOS không cho vẽ lên app khác. Phương án iOS: đặt dấu lúc dựng video (không phải lúc quay) |
| Điều khiển từ thanh thông báo (Tạm dừng/Dừng) | ✅ | ⚠️ | iOS: Dynamic Island/đồng hồ đỏ của hệ thống |

## 2. Trình dựng video (E1–E7)

Giao diện dựng là Flutter dùng chung; **bộ xuất** (Media3 trên Android) phải viết lại trên iOS (AVFoundation).

| Tính năng | Android | iOS | Kiểm chứng (Android) |
|---|---|---|---|
| Cắt, tách, xoá, nhân đôi, kéo đổi thứ tự, nam châm | ✅ | 🕓 | Đã thử Oppo + S25 (`e1_edit_core`) |
| Đóng băng khung, đoạn trống | ✅ | 🕓 | Đã thử |
| Tốc độ hằng, ramp tốc độ, chạy ngược (≤30 s) | ✅ | 🕓 | Đã thử Oppo + S25 (`e3_motion`) |
| Chuyển cảnh (mờ đen/trắng, trượt, phóng) | ✅ | 🕓 | Đã thử Oppo + S25 |
| Âm lượng/fade từng đoạn, tắt tiếng khi nhanh | ✅ | 🕓 | Đã thử Oppo |
| Nhạc nền từ file, thu giọng, hạ nhạc khi có giọng | ✅ | 🕓 | Đã thử Oppo + S25 (`e4_audio`, `e4_audio_s25`) |
| Xoay, cắt, đổi tỉ lệ, màu | ✅ | 🕓 | Đã thử Oppo + S25 (`e2b_crop_rotate`) |
| Chữ nâng cao, hình vẽ, ảnh chèn, chuyển động vào/ra | ✅ | 🕓 | Đã thử Oppo + S25 (`e2_overlays`) |
| Hình-trong-hình (ảnh) | ✅ | 🕓 | Đã thử |
| Hình-trong-hình (video) | ✅ | 🕓 | Đã thử S25 (`e2_pip_s25`) |
| Xuất MP4 theo mẫu, ước lượng dung lượng, GIF, lưu khung hình | ✅ | 🕓 | Đã thử Oppo + S25 |
| Xuất chạy nền (có thông báo + Huỷ) | ✅ | ⚠️ | iOS giới hạn xử lý nền khi tắt màn hình |
| Mẫu dự án | ✅ | 🕓 | |
| Vùng che: khối đặc, làm mờ, mosaic, tiêu điểm; vùng di chuyển giữa hai điểm | ✅ | 🕓 | Oppo CPH2203 (`e10_regions`, `e11_region_motion`); bộ xuất dùng shader GL riêng nên iOS phải viết lại |
| Nhập phụ đề SRT, kiểu chữ dựng sẵn | ✅ | 🕓 | Oppo CPH2203 (`e9_subtitles`) |
| Phóng to khi dùng tự động: mức, tốc độ vào/ra, giữ thêm; thanh công cụ ẩn được; xem toàn màn hình | ✅ | 🕓 | S25 + Oppo (`e8_tools_zoom`) |
| Zoom hai ngón khung xem trước (chỉ để xem), sóng âm trên timeline | ✅ | 🕓 | Oppo CPH2203 (`integration_test/editor_zoom_test.dart`; `e12_waveform`) |
| Hiệu ứng giọng (trầm, cao, sóc chuột, robot, echo, vang) và giảm ồn cho giọng lồng tiếng | ✅ | 🕓 | Oppo CPH2203 đo bằng `scripts/qa/voice_fx_check.sh` + `voice_fx_editor_check.sh` |
| Phụ đề tự động từ lời nói, chạy trên máy | ⚠️ Android 13+ | 🕓 | Oppo CPH2203, tiếng Việt thật (`scripts/qa/auto_captions_check.sh`). Dùng bộ nhận dạng của Android (chế độ chỉ chạy trên máy); Android dưới 13 báo "chưa hỗ trợ"; tiếng Anh cần hệ thống tải gói ngôn ngữ một lần. iOS dùng `SFSpeechRecognizer` với `requiresOnDeviceRecognition` |
| Chọn video từ máy (không sao chép), mở thẳng editor | ✅ | 🕓 | Oppo CPH2203; iOS dùng `PHPickerViewController` |
| Khung chỉnh overlay (tay nắm, núm xoay, vạch hút), xoay tự do −45°…45° | ✅ | 🕓 | Oppo CPH2203; bộ xuất dùng `ScaleAndRotateTransformation` |

## 3. Tình trạng iOS và vì sao

- Đã có khung `ios/` (chạy được phần thư viện/trình chỉnh sửa theo giao diện Flutter, chưa có quay màn hình, chưa build thử); chưa có bản iOS nào để cài. Build iOS cần macOS + Xcode (và tài khoản Apple Developer để phát hành).
- Kiểm tra tự động: `.github/workflows/ios.yml` dựng iOS trên máy macOS của GitHub (xem file). Chỉ khi workflow đó chạy xanh và có thử trên iPhone thật thì cột iOS ở trên mới được đổi từ 🕓 sang ✅.
- Không thể đưa lên iOS: dấu nổi trên app khác, đếm ngược nổi, thu tiếng nội bộ của app khác. Đây là giới hạn của hệ điều hành, không phải thiếu sót của app.

## 4. Chung cho mọi nền tảng

Miễn phí, không quảng cáo, video và dữ liệu không rời máy (Android không khai báo quyền INTERNET). Tiếng Việt và tiếng Anh.
