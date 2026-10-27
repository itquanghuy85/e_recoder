# Apple App Store — trạng thái và kế hoạch

**Hiện trạng:** chưa có bản iOS. Ứng dụng dùng `MediaProjection`, lớp phủ hệ thống (`SYSTEM_ALERT_WINDOW`), `MediaCodec` và Media3 — đều là API riêng của Android. Giao diện Flutter (màn Quay, Thư viện, Cài đặt, Trình chỉnh sửa, mô hình dự án, `AutoDirector`, trình xuất logic) dùng lại được; phần native phải viết lại.

## Việc phải làm cho iOS (nếu quyết định làm)
| Thành phần | Android hiện tại | iOS |
|---|---|---|
| Quay màn hình | MediaProjection + MediaCodec | `RPScreenRecorder` (trong app) hoặc Broadcast Upload Extension (toàn hệ thống). Không đếm ngược/lớp phủ trên app khác |
| Dấu báo trước lúc quay | Lớp phủ + vùng ẩn | Không làm được trên app khác → chỉ có chế độ **dựng sau**: đánh dấu bằng nút trong tiện ích broadcast hoặc thêm dấu trong trình chỉnh sửa |
| Xuất video (cắt, tốc độ, chữ, che, phóng, dấu) | Media3 Transformer | `AVMutableComposition` + `AVVideoCompositing` / Core Animation tool |
| GIF | Bộ mã hoá tự viết | ImageIO (`CGImageDestination`) |
| Lưu thư viện | MediaStore | Photos framework (`PHPhotoLibrary`) |
| Phân tích đứng yên (`IdleAnalyzer`) | MediaMetadataRetriever | `AVAssetImageGenerator` |
| Quyền | overlay, mic, thông báo | `NSMicrophoneUsageDescription`, `NSPhotoLibraryAddUsageDescription` |

Ước lượng: 3–5 tuần cho một người quen Swift/Flutter. Cần Mac + tài khoản Apple Developer (99 USD/năm).

## Tài sản đã sẵn sàng
- Biểu tượng: `store/ios_icon_1024.png` (vuông, Apple tự bo góc; **không** có kênh alpha — xuất lại bằng công cụ có `-pix_fmt rgb24` nếu App Store Connect từ chối).
- Văn bản: `fastlane/metadata/ios/{vi,en-US}/` (name, subtitle, keywords, promotional_text, description).
- Trang quyền riêng tư và hỗ trợ: dùng chung với Android (`site/`).

## Khai báo App Privacy ("nhãn dinh dưỡng") dự kiến
Data Not Collected (ứng dụng không gửi dữ liệu ra ngoài). Nếu thêm SDK phân tích sau này thì phải cập nhật.

## Kích thước ảnh chụp bắt buộc (khi làm)
iPhone 6.9" (1320×2868) hoặc 6.5" (1284×2778 / 1242×2688); iPad 13" (2064×2752) nếu hỗ trợ iPad. `scripts/store/make_store_assets.ps1` có thể tạo thêm theo khung này khi có ảnh chụp iOS thật.
