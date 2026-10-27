# E Screen Recorder

Ứng dụng quay màn hình cho Android. Điểm khác biệt: **dấu báo trước** — người xem thấy dấu (ngón tay, mũi tên, vòng tròn…) hiện lên *trước* khi màn hình đổi, nên luôn biết bạn sắp bấm vào đâu. Có trình chỉnh sửa trên máy, xuất MP4/GIF. Miễn phí, không quảng cáo, video không rời máy.

- **Nền tảng:** Android có bản chạy được; iOS chưa phát hành. Bảng tính năng Android/iOS: [docs/PLATFORMS.md](docs/PLATFORMS.md).
- Gói `com.huluca.escreenrecorder` · Android 10+ (minSdk 29) · Flutter (UI) + Kotlin (quay, lớp phủ, xuất).
- Ngôn ngữ: tiếng Việt (ARB `lib/l10n/app_vi.arb`) và tiếng Anh (`app_en.arb`), theo ngôn ngữ hệ thống.
- Thiết kế: `PRODUCT.md`, `DESIGN.md`, `.impeccable/` (hướng "Cue before cut").

## Chạy
```
flutter pub get
flutter run                      # máy thật, Android 10+
flutter build apk --debug
flutter build appbundle --release   # xem docs/PLAY_STORE.md để ký
```

## Kiểm thử
```
flutter analyze
flutter test                                   # Dart: model, controller, UI, thời gian dấu
cd android; .\gradlew.bat :app:testDebugUnitTest --offline   # Kotlin: MarkerAnim, ZoomMath, ItemClock
powershell -File scripts\run_suite.ps1         # toàn bộ Maestro trên máy thật
```
Chi tiết, mẹo máy Oppo/ColorOS và cách chạy từng flow: `docs/TESTING.md`.

## Kiến trúc (một dòng mỗi phần)
| Phần | Vị trí | Vai trò |
|---|---|---|
| Quay | `android/.../capture/` | MediaCodec + MediaMuxer: video H.264 từ VirtualDisplay, AAC (micro/hệ thống), tạm dừng cắt cả hai track |
| Dịch vụ + lớp phủ | `RecorderService.kt`, `overlay/` | Foreground service, chấm đánh dấu, vùng ẩn, thanh điều khiển, đếm ngược, thông báo |
| Dấu | `marker/` | **Một** bộ vẽ (`MarkerRenderer` + hiệu ứng nước `Water`) dùng cho lúc quay, xem trước và xuất; `MarkerAnim` (cue → take) |
| Xuất | `export/` | Media3 Transformer: cắt/ghép/tốc độ, lớp phủ, phóng to; GIF tự mã hoá |
| Cầu nối | `MainActivity.kt`, `lib/core/native_recorder.dart` | MethodChannel + EventChannel duy nhất |
| UI | `lib/features/{record,library,marker,editor,settings,onboarding}` | Riverpod, Material 3 |
| Token thiết kế | `lib/theme/` | màu, chữ, bo góc, chuyển động; `brand_mark.dart` = logo vẽ bằng code |
| Dựng tự động | `lib/features/editor/auto_director.dart` | Phóng to vào dấu, đánh số bước, tua đoạn đứng yên (thuần Dart, có test) |
| Cửa hàng + trang web | `store/`, `fastlane/`, `site/`, `docs/store/` | Văn bản, ảnh, khai báo, playbook cho Agent, trang quyền riêng tư |

## Quyết định cần nhớ
- Dấu vẽ lúc quay ở chế độ "chấm nhỏ" **in thẳng vào video** (cửa sổ `FLAG_SECURE` hiện ô đen, không ẩn được). Chế độ "quay sạch" không vẽ gì: chỉ ghi vị trí + thời điểm, editor vẽ sau; dấu thêm trong editor sửa tự do.
- Thời gian lớp phủ lưu theo **thời gian gốc**; timeline hiển thị thời gian đã cắt.
- Trong Composition, effect nhận thời gian của cả chuỗi → luôn đo từ khung đầu của từng đoạn (`ItemClock`).
- Media3 vẽ overlay theo kích thước điểm ảnh gốc của bitmap (không nhân thêm tỉ lệ khung).
- Không dùng Accessibility ở bản đầu (rủi ro duyệt Play).
- Icon/splash/ảnh cửa hàng đều sinh từ `lib/theme/brand_mark.dart` (`flutter test tool/make_icons_test.dart`).
- Tài liệu: `docs/store/README.md` (đăng cửa hàng), `docs/CHANGELOG.md`, `docs/HANDOVER.md`, `docs/PLAY_STORE.md`, `docs/PRIVACY.md`, `docs/PLAN.md`.
