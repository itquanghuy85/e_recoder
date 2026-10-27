# Báo cáo hoàn tất — E Screen Recorder (G0 → G7)

Ngày: 2026-10-27 · Repo: `d:\JOB\e_recorder` (chưa commit) · Gói: `com.huluca.escreenrecorder` · Android 10+

## Kết quả theo giai đoạn
| GĐ | Nội dung | Trạng thái |
|---|---|---|
| G0–G5 | Nền móng, quay ổn định, dấu báo trước, trình chỉnh sửa + xuất MP4/GIF, hoàn thiện, tiếng Anh | Xong (xem `CHANGELOG.md`) |
| G6 | Hai cách đánh dấu khi quay: **chấm nhỏ ở góc** (chọn dấu trước; khay chọn dấu tự tạm dừng quay nên không lọt vào video) và **quay sạch, dựng sau** (vùng ẩn/lắc/thông báo, không vẽ gì lên màn hình) | Xong |
| G6 | **Dựng tự động** trong editor: phóng to vào dấu, đánh số lại bước, tua nhanh đoạn đứng yên; tự áp sau khi quay sạch | Xong |
| G6b | **Dấu hiệu ứng nước**: gradient theo màu chọn, sóng lan, dải sáng chảy, mũi tên gật; một bộ vẽ cho quay trực tiếp, xem trước, xuất video | Xong |
| G7 | **Icon mới**, **màn khởi động** (native + intro Flutter), **trang web** quyền riêng tư / bảo mật / hỗ trợ (vi + en), **bộ hồ sơ cửa hàng** + playbook cho Agent + video | Xong |

## Kiểm thử (bản release R8, Oppo CPH2325 Android 13)
- `flutter analyze` sạch · `flutter test` **87/87** · JUnit Kotlin xanh (thêm `IdleAnalyzerTest`).
- Maestro **14/14 flow PASS** trên bản release cuối. Lần chạy trọn bộ được 12/14; `g0_smoke` và `g3_join` hỏng ở vài bước đầu do máy Oppo đưa về màn hình chính trước khi flow chạy (lỗi môi trường, không phải lỗi app), rồi PASS khi chạy lại riêng (`g3_join` với khởi động lạnh).
- Bằng chứng nội dung: video quay sạch không có gì chen vào; video xuất có dấu hiệu ứng nước + vòng báo trước, phóng to vào dấu, đoạn đứng yên được tua (75 s → 31 s); ảnh chụp xem thử các pha chuyển động của dấu; splash chụp liên tục (native → intro Flutter → app).

## Lỗi thật tìm ra và đã sửa trong đợt này
Phân tích đoạn đứng yên chạy quá chậm (giải mã mọi khung → chỉ giải mã khung khoá) · kết quả "Dựng tự động" nằm dưới vùng cuộn nên không thấy (chuyển lên đầu, hiện tổng số trong dự án) · bước reset của Maestro không đặt lại chế độ đánh dấu nên lệch sang flow sau · khớp pha vòng nước giữa xem trước và xuất (14 pha × 100 ms) · gradient sweep quay quanh gốc toạ độ thay vì tâm (icon xám tím) · snackbar "Đã lưu" không tự tắt khi bật trợ năng (Maestro) làm che ảnh chụp.

## Cần người làm trước khi phát hành (không làm thay được)
1. Điền `developer.supportEmail` trong `store/store_config.json` rồi `scripts\store\build_site.ps1`; đưa `site_dist/` lên GitHub Pages hoặc Firebase Hosting; ghi URL vào `site.baseUrl`. **URL chính sách quyền riêng tư:** `<baseUrl>/vi/privacy.html`.
2. Tạo khoá tải lên + `android/key.properties`; bật Play App Signing (`docs/PLAY_STORE.md`).
3. Đăng `store/video/promo.mp4` và `permission_demo.mp4` lên YouTube (video chứng minh quyền để *Không công khai*), dán link vào form.
4. Giao `docs/store/AGENT_PLAYBOOK.md` cho Agent (hoặc điền tay theo bảng trong đó). `scripts\store\check_assets.ps1` hiện chỉ còn 3 mục FAIL, đúng là 3 việc người ở trên (email, URL, khoá).
5. Tài khoản cá nhân mới: closed test ≥12 tester × 14 ngày trước khi lên Production.
6. Thử Samsung/Pixel/Xiaomi và Android 14/15; đo pin/nhiệt 10+ phút ở 60 fps; người bản ngữ đọc lại tiếng Anh.

## Giới hạn đã biết
- Chế độ **chấm nhỏ**: chấm và dấu lúc quay nằm trong video (cửa sổ `FLAG_SECURE` chỉ hiện ô đen, không ẩn được). Muốn sạch hoàn toàn dùng **quay sạch**.
- Quay sạch: lắc máy và rung phản hồi cần kiểm tay (Maestro không giả lập cảm biến); không chụm hai ngón khi đặt dấu (chỉnh trong editor).
- "Auto-Guide" (lấy tên nút làm chữ bước) cần dịch vụ trợ năng — chưa làm vì rủi ro duyệt Play.
- **App Store (Apple): chưa có bản iOS** (MediaProjection/lớp phủ/Media3 là API Android). Đã chuẩn bị icon 1024, văn bản và kế hoạch: `docs/store/APPSTORE_STATUS.md`.
- Khối che là khối đặc; xuất chạy trong màn editor; mới thử trên 2 máy Oppo Android 13.
- Harness Maestro trên ColorOS hay đưa máy về màn hình chính sau một lần chạy hỏng: force-stop app, mở lại, đợi ~10 s rồi chạy lại (`docs/TESTING.md`).

## Bản đồ tài liệu
`README.md` · `PRODUCT.md` · `DESIGN.md` · `docs/CHANGELOG.md` · `docs/TESTING.md` · `docs/HANDOVER.md` · `docs/PLAY_STORE.md` · `docs/PRIVACY.md` · **`docs/store/README.md`** (mục lục đăng cửa hàng) · `docs/store/AGENT_PLAYBOOK.md` · `docs/store/APPSTORE_STATUS.md` · `store/store_config.json` · `store/play/answers.json` · `fastlane/` · `site/`.
