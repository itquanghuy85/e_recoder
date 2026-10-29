# Phát hành lên Google Play

> Quy trình đầy đủ cho Agent và tài sản đã tạo sẵn: `docs/store/README.md`, `docs/store/AGENT_PLAYBOOK.md`.

Gói: `com.huluca.escreenrecorder` — **không đổi được sau lần phát hành đầu**. minSdk 29, targetSdk theo Flutter. Miễn phí, không quảng cáo, không mua trong app.

## 1. Ký bản phát hành
1. Tạo khoá tải lên (giữ kín, sao lưu 2 nơi):
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Sao chép `android/key.properties.example` → `android/key.properties`, điền mật khẩu và đường dẫn `storeFile`. Tệp này và `*.jks` đã nằm trong `.gitignore`.
3. Bật **Play App Signing** khi tạo ứng dụng trên Play Console (Google giữ khoá ký, bạn giữ khoá tải lên).
4. Build: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
   Trước khi tăng bản: sửa `version: 1.x.y+N` trong `pubspec.yaml` (N = versionCode, luôn tăng).
5. Chưa có `key.properties` thì bản release tự ký bằng khoá debug (chỉ để thử, **không** tải lên Play).

## 2. Thông tin cửa hàng (tiếng Việt)
- **Tên:** E Screen Recorder
- **Mô tả ngắn (≤ 80):** Quay màn hình có dấu báo trước chỗ sắp bấm, chỉnh sửa ngay trên máy.
- **Mô tả đầy đủ:**
  Quay video hướng dẫn mà người xem luôn biết bạn sắp bấm vào đâu.

  • Dấu báo trước: ngón tay, mũi tên, vòng tròn, khung, bút, số bước và hiệu ứng chạm. Vòng vàng thu vào đích rồi mới đến lúc bấm.
  • Chấm nhỏ ở góc: bấm chấm, chạm chỗ sắp bấm, rồi bấm thật — màn hình đổi sau khi người xem đã biết nhìn đâu.
  • Quay sạch, dựng sau: không có gì chen vào video; dấu được vẽ đẹp và tự phóng to trong trình chỉnh sửa.
  • Chỉnh sửa trên máy: cắt, tách, ghép, đổi tốc độ, thêm chữ, che thông tin nhạy cảm, phóng to vùng quan trọng.
  • Xuất MP4 hoặc GIF, chọn chất lượng, chia sẻ ngay.
  • Quay có tiếng micro hoặc âm thanh trong máy (Android 10 trở lên), tạm dừng/tiếp tục, đếm ngược.
  • Giao diện sáng/tối, tiếng Việt.
  • Miễn phí, không quảng cáo, không cần tài khoản. Video ở lại trên máy của bạn.
- **Danh mục:** Công cụ (Tools). **Liên hệ:** điền email hỗ trợ của chủ ứng dụng trong Play Console.
- **Ảnh:** biểu tượng `store/icon_512.png`; ảnh bìa `store/feature_1024x500.png`; ảnh chụp màn hình: dùng ảnh `takeScreenshot` của các flow Maestro (Quay, Khay dấu, Editor, Xuất) trên máy thật 1080×2400 hoặc 720×1600.

## 3. Khai báo quyền (App content → Sensitive permissions)
| Quyền | Vì sao cần | Cách khai báo |
|---|---|---|
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Quay màn hình liên tục khi app ở nền | Loại `mediaProjection`; video demo: bật quay, mở app khác, dừng |
| `FOREGROUND_SERVICE_MICROPHONE`, `RECORD_AUDIO` | Quay có tiếng khi người dùng chọn | Chỉ khi chọn Âm thanh ≠ Không có |
| `SYSTEM_ALERT_WINDOW` | Thanh điều khiển nổi, đếm ngược, dấu đánh dấu vẽ lên màn hình đang quay | Tính năng cốt lõi; có thể từ chối (khi đó dùng thông báo) |
| `POST_NOTIFICATIONS` | Nút Tạm dừng/Dừng trong thông báo bắt buộc của dịch vụ nền | Tuỳ chọn |
Không dùng: Accessibility, vị trí, danh bạ, SMS, bộ nhớ ngoài rộng (`MediaStore` cho Movies/Pictures của chính app), `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (app chỉ hướng dẫn mở cài đặt).

## 4. Data safety
- Thu thập dữ liệu: **Không**. Chia sẻ dữ liệu: **Không**. Mã hoá khi truyền: không áp dụng (không truyền).
- Người dùng có thể xoá dữ liệu: có (xoá video trong Thư viện; gỡ app xoá dự án chỉnh sửa).
- Không quảng cáo, không SDK phân tích.
- Chính sách quyền riêng tư: trang sẵn trong `site/` (`scripts/store/build_site.ps1` rồi GitHub Pages / Firebase Hosting); dán `<baseUrl>/vi/privacy.html` vào Play Console.

## 5. Phân loại & đối tượng
- Đối tượng: 13+; không nhắm trẻ em. Phân loại nội dung: Mọi lứa tuổi (không có nội dung do app tạo ra).
- Nêu rõ trong mô tả: không quay nội dung có bản quyền/DRM (hệ thống sẽ trả về màn đen).

## 6. Danh sách kiểm trước khi gửi duyệt
- [ ] Ký bằng khoá tải lên, `flutter analyze` sạch, `flutter test` xanh, `gradlew :app:testDebugUnitTest` xanh.
- [ ] Chạy `scripts/run_suite.ps1` trên **bản release** (R8 bật) ít nhất một máy.
- [ ] Thử thêm: máy Samsung/Pixel, Android 14 và 15 (hộp thoại quay mỗi lần; chia sẻ một phần màn hình bị tắt bằng `createConfigForDefaultDisplay`).
- [ ] Kiểm tra pin/nhiệt khi quay 10 phút 60 fps; hướng dẫn tắt tối ưu pin trên Xiaomi/Oppo/Vivo.
- [ ] Điền email hỗ trợ, URL chính sách, ảnh chụp màn hình, video demo quyền.
- [ ] Phát hành nội bộ → kín → mở theo từng bước.

## 7. English listing (G5)
- **Title:** E Screen Recorder
- **Short description (≤ 80):** Screen recorder that shows where you are about to tap. Edit on device.
- **Full description:**
  Record tutorial videos where viewers always know where you are about to tap.

  • Point-ahead markers: finger, arrow, circle, box, pen, step numbers and a tap ripple. An amber ring closes in on the target, then the tap happens.
  • Small corner dot: tap it, touch where you are about to press, then press for real — the screen changes after the viewer already knows where to look.
  • Record clean, edit later: nothing on screen while recording; markers are drawn and auto-zoomed in the editor.
  • On-device editor: cut, split, join, change speed, add text, cover sensitive info, zoom into what matters.
  • Export MP4 or GIF, pick the quality, share instantly.
  • Record with the microphone or device audio (Android 10+), pause/resume, countdown.
  • Light and dark themes. Vietnamese and English.
  • Free, no ads, no account. Your videos stay on your device.
- The app follows the system language (Vietnamese or English; Vietnamese for any other language). The floating bar and notification follow the system language too.
