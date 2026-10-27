# Bàn giao — E Screen Recorder

Cập nhật: 2026-10-27 · Trạng thái: **G0–G7 hoàn tất về code, test, tài liệu và bộ hồ sơ cửa hàng; chưa phát hành** (cần khoá ký, email hỗ trợ + nơi đặt trang web, thử thêm máy).

## Đã có
- Quay: toàn màn hình, 720p/1080p/gốc, 30/60 fps, micro + âm thanh hệ thống, tạm dừng/tiếp tục, đếm ngược, thanh nổi hoặc chỉ thông báo, lưu `Movies/E Screen Recorder`.
- Dấu: 7 loại, cue → take. Hai cách đánh dấu khi quay (Cài đặt → Dấu đánh dấu): **chấm nhỏ ở góc** (chọn dấu trước; nhấn giữ chấm mở thanh, khay chọn dấu tự tạm dừng quay) hoặc **quay sạch, dựng sau** (vùng ẩn ở góc/lắc/thông báo; dấu vẽ trong editor).
- Editor có tab **Tự động**: phóng to vào dấu, đánh số bước, tua nhanh đoạn đứng yên.
- Editor: cắt/tách/xoá/đổi chỗ, tốc độ, dấu "báo trước" trên timeline, chữ, khối che, phóng to, hoàn tác/làm lại, lưu dự án; xuất MP4 (Gốc/1080/720/480), GIF; ghép nhiều video.
- App: onboarding, quyền & pin, quyền riêng tư, giới thiệu, giao diện sáng/tối, tiếng Việt.

## Việc còn lại trước khi phát hành (cần người)
Mọi thứ khác đã chuẩn bị: xem `docs/store/README.md` và `docs/store/AGENT_PLAYBOOK.md`.
1. Điền `developer.supportEmail` trong `store/store_config.json`, chạy `scripts/store/build_site.ps1`, đưa `site_dist/` lên GitHub Pages hoặc Firebase Hosting, rồi ghi URL vào `site.baseUrl`. URL chính sách quyền riêng tư = `<baseUrl>/vi/privacy.html`.
2. Tạo khoá tải lên + `android/key.properties` (`docs/PLAY_STORE.md` mục 1); bật Play App Signing.
3. Đăng `store/video/promo.mp4` và `permission_demo.mp4` lên YouTube (không công khai cho video chứng minh quyền), dán link vào form / `video.txt`.
4. Giao `docs/store/AGENT_PLAYBOOK.md` cho Agent, hoặc điền tay theo bảng trong đó. Tài khoản cá nhân mới: closed test ≥12 tester × 14 ngày trước khi lên Production.
5. Thử trên **Samsung, Pixel, Xiaomi** và **Android 14/15** (chỉ có 2 máy Oppo Android 13 trong quá trình phát triển).
6. Đo pin/nhiệt khi quay 10+ phút ở 60 fps; chỉnh mặc định nếu máy nóng.
7. Nhờ người bản ngữ đọc lại bản tiếng Anh (app, trang web, mô tả cửa hàng).

## Giới hạn đã biết
- Chế độ chấm nhỏ: chấm và dấu lúc quay bị ghi vào video (không ẩn được). Muốn video hoàn toàn sạch dùng chế độ "Quay sạch, dựng sau" hoặc tắt "Dấu đánh dấu khi quay".
- Khối che là khối đặc (không có làm mờ theo vùng).
- Quay không tự đổi cỡ khi xoay màn hình giữa chừng (khung giữ cỡ lúc bắt đầu).
- Xuất chạy trong màn hình editor (thoát app giữa chừng thì dừng); chưa là dịch vụ nền.
- Chưa tự động hoá được: lắc máy, rung phản hồi, chụm hai ngón khi đặt dấu (chế độ chấm), Android 14+/15 consent, nhiều hãng máy.
- Máy Oppo/ColorOS: `adb` không cấp được quyền/xoá dữ liệu; Maestro phải cấp quyền bằng tay một lần (`maestro/helpers/grant_overlay.yaml`).

## Bẫy kỹ thuật (đã trả giá)
- `FLAG_SECURE` trên lớp phủ = ô đen trong video, không phải "ẩn".
- `presentationTimeUs` của effect trong Composition là của cả chuỗi → `ItemClock`.
- Media3 overlay: không `setScale(bitmap/frame)`; kích thước điểm ảnh gốc là mặc định.
- `Transformer.setPortraitEncodingEnabled(true)` để video dọc không bị đóng gói ngang + cờ xoay.
- `EventChannel` chỉ cho một sink: mọi người nghe dùng chung `NativeRecorder.events`.
- Flutter `Semantics(identifier)` mới là id cho Maestro; `ValueKey` thì không.
- Thanh "Đã lưu…" từng che nút quay và thanh công cụ editor → margin cao hơn nút và `clearSnackBars()` khi mở màn mới.
- Log app trên ColorOS bị Maestro làm ngập `logcat`; ghi log ra file song song khi gỡ lỗi.

## Kiểm thử nhanh
`flutter analyze && flutter test`, rồi `scripts\run_suite.ps1` (11 flow Maestro). Kết quả lần gần nhất: xem cuối `docs/CHANGELOG.md`.
