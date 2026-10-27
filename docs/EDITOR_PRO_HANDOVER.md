# Trình dựng video — bàn giao E1–E7

Trạng thái chi tiết từng mục nằm ở `docs/EDITOR_PRO_PLAN.md` (mục 6). Tài liệu này dành cho người tiếp quản: kiến trúc, file, cách build/test, bài học và cách tái hiện lỗi.

## 1. Kiến trúc trong một trang

```
EditProject (bất biến, JSON v2)            lib/features/editor/edit_project.dart, segment.dart, ...
   │  segments[]  markers/texts/covers/zooms (thời gian NGUỒN)
   │  images/shapes (thời gian NGUỒN), pips/audioTracks (thời gian ĐẦU RA)
   │  look: xoay · cắt · tỉ lệ · màu           picture_look.dart
   ▼
EditorController (undo 60 bước, tự lưu)     editor_controller.dart
   ├─ PlaybackDriver  (phát bản xem trước)   editor_playback.dart   — player giữ file GỐC, driver nhảy/chỉnh tốc độ
   ├─ ExtraPlayers    (nhạc, giọng, PiP)     editor_extra_players.dart
   ├─ EditorStage     (vẽ xem trước)         editor_stage.dart      — StageGeometry = 2 hệ toạ độ
   └─ toExportMap ──► ExportService ──► Exporter (Media3)      android/.../export/
```

**Hai hệ toạ độ** (giống nhau ở xem trước và xuất):
- *Không gian ẢNH* = khung nguồn đã xoay. Dấu, khối che, zoom sống ở đây → bị cắt cùng ảnh.
- *Không gian ĐẦU RA* = sau cắt + tỉ lệ. Chữ, ảnh, hình vẽ, hình-trong-hình sống ở đây.

**Chuỗi hiệu ứng mỗi clip** (`Exporter.itemsFor/pictureEffects`): xoay → dấu+che → zoom → cắt → tỉ lệ → ảnh/hình/chữ → (tốc độ) → PiP → màu + chuyển cảnh. Xem trước dựng theo đúng thứ tự (`EditorStage._frame`).

**Một nguồn toán học, hai bản dịch** — mỗi phép tính phải khớp giữa Dart (xem trước) và Kotlin (xuất), khoá bằng test *golden dùng chung*:
| Toán | Dart | Kotlin | Test |
|---|---|---|---|
| Đoạn ramp / độ dài / gain | `segment.dart` | `SegmentPlan.kt` | `segment_model_test.dart` ↔ `SegmentPlanTest.kt` |
| Chuyển cảnh | `TransitionLook` | `TransitionLook` | cùng hai file trên |
| Chuyển động lớp phủ | `overlay_motion.dart` | `OverlayMotion.kt` | `pro_model_test.dart` ↔ `OverlayMotionTest.kt` |
| Hạ nhạc khi có giọng | `AudioTrack.duckFactor` | `AudioDuck` | cùng hai file trên |
| Ma trận màu | `ColorLook.matrix4/flutterMatrix` | `LookColor` | `pro_model_test.dart` |

Sửa một bên mà không sửa bên kia → test golden đỏ. Đừng "sửa số golden cho qua".

## 2. Quyết định kỹ thuật (và lý do)

| Chủ đề | Quyết định | Lý do |
|---|---|---|
| Tốc độ ramp | 24 bậc đều theo độ dài NGUỒN; xuất thành 24 clip hằng tốc | `SpeedProvider` không chắc chắn về gốc thời gian trong Composition; clip hằng tốc là đường đã chạy ổn |
| Chuyển cảnh | Chỉ dùng ảnh của 2 clip, không chồng 2 decoder: nửa cuối clip trước "đi ra", nửa đầu clip sau "đi vào". Gồm mờ qua đen/trắng, trượt 4 hướng, phóng mờ | Media3 không có chuyển cảnh sẵn; chồng 2 decoder nặng với máy yếu; cách này cho xem trước và xuất cùng công thức, tổng thời lượng không đổi |
| Chạy ngược | Tối đa 30 giây/đoạn; tạo bản sao ngược bằng 2 bước (Media3 → file toàn khung khoá 24 fps ≤720p; đọc ngược từng khung và mã hoá lại), không tiếng | Bản ghi màn hình thường có rất ít khung khoá; đọc từng khung trên file gốc sẽ giải mã hàng giây mỗi khung. Bộ nhớ chỉ 1 khung |
| Đóng băng/đoạn trống | Ảnh PNG + `setImageDurationMs` | Đường chuẩn của Media3, ghép được với mọi hiệu ứng khác |
| Hình trong hình (video) | Lấy mẫu ≤30 s thành ảnh JPEG 15 khung/s (từ bản sao toàn khung khoá), vẽ bằng overlay theo thời gian đầu ra | Không cần decoder thứ hai chạy đồng thời; nằm trong chuỗi một sequence đã chạy tốt |
| Âm thanh PiP | Xem như một track âm thanh | Cùng đường trộn âm với nhạc/giọng |
| Nhạc nền | Chỉ file người dùng chọn (copy vào bộ nhớ app) | Không đóng gói nhạc: tránh bản quyền, giữ APK nhẹ |
| Hạ nhạc khi có giọng | 0,3× trong khoảng giọng, dốc 250 ms hai đầu | Đơn giản, nghe tự nhiên, cùng công thức hai phía |
| Chuẩn hoá âm lượng | Đo RMS (≤30 s) → đưa về −16 dBFS, tối đa 200% | Không cần thư viện |
| Làm nét | **Không làm** | Không có hiệu ứng sẵn; shader tự viết thì xem trước không khớp (Flutter không có tích chập trên video) |
| Chuyển cảnh "nước" | **Không làm** | Cần shader hai khung; xem trước không dựng được cùng công thức |
| Tắt tiếng >2× | Mặc định bật, có công tắc | Tiếng nói tăng tốc chỉ là nhiễu |
| Xuất nền | Foreground service (`dataSync`; `mediaProcessing` từ Android 15) + thông báo có nút Huỷ | Không mất khi thoát app/tắt màn hình |
| Media3 | Ghim `1.9.2` | Gradle vẫn nâng 1.8.0 lên 1.9.2 vì phụ thuộc của `video_player`; ghi rõ cho khỏi nhầm API |
| Nền khung khác tỉ lệ | Viền đen hoặc lấp đầy (cắt phần thừa) | Màu nền khác cần hiệu ứng nền mà xem trước dựng được cùng công thức — để dành |

## 3. File chính

Dart (`lib/features/editor/`): `segment.dart` (đoạn, ramp, chuyển cảnh), `edit_project.dart` (dự án, ánh xạ thời gian, thao tác, `toExportMap`), `picture_look.dart`, `overlay_items.dart`, `overlay_motion.dart`, `audio_track.dart`, `editor_controller.dart`, `editor_playback.dart`, `editor_extra_players.dart`, `editor_stage.dart`, `editor_timeline.dart`, `editor_tools.dart` (+ `editor_pro_tools.dart`), `export_sheet.dart`, `export_presets.dart`, `project_template.dart`, `auto_director.dart`.

Kotlin (`android/app/src/main/kotlin/com/huluca/escreenrecorder/`): `export/Exporter.kt` (dựng Composition), `ExportJob.kt`, `SegmentPlan.kt`, `PartEffects.kt` (Gain, chuyển cảnh, màu), `Overlays.kt`, `OverlayRenderers.kt` (chữ, hình vẽ, ảnh), `OverlayMotion.kt`, `StillFrames.kt`, `IntraCopy.kt`, `ReverseRenderer.kt`, `PipFrames.kt`, `IdleAnalyzer.kt`; `ExportService.kt`, `EditorMedia.kt` (chọn tệp, thu giọng, đo âm lượng, lưu ảnh), `MainActivity.kt`.

## 4. Build và kiểm thử

```
flutter analyze
flutter test                                   # 170+ test Dart
cd android && ./gradlew.bat :app:testDebugUnitTest   # JUnit (SegmentPlan, OverlayMotion, ItemClock, ...)
flutter build apk --release
powershell scripts/qa/push_test_media.ps1      # ảnh/nhạc/video nhỏ vào Download của máy test
powershell scripts/run_flow.ps1 e1_edit_core -Serial <serial>   # xem docs/TESTING.md
```

Cạm bẫy khi test trên máy thật: xem `docs/TESTING.md` (Maestro không thấy lớp phủ trên Cài đặt của Samsung — dùng `-OtherApp`; sau khi chạy hỏng nên `force-stop` app và driver `dev.mobile.maestro` rồi chạy lại).

## 5. Việc chưa làm / giới hạn đã biết

Xem mục 6 và 7 của `docs/EDITOR_PRO_PLAN.md` (được cập nhật cùng báo cáo cuối).

## 6. Kết quả kiểm tra cuối (27/10/2026)

- `flutter analyze`: không lỗi. `flutter test`: 177 test đều qua. `gradlew :app:testDebugUnitTest`: qua.
- `flutter build apk --release`: `build/app/outputs/flutter-apk/app-release.apk`, 57,3 MB (< 80 MB). Manifest hợp nhất không có `INTERNET`; quyền mới chỉ là `FOREGROUND_SERVICE_DATA_SYNC` và `FOREGROUND_SERVICE_MEDIA_PROCESSING`.
- Máy thật Oppo CPH2325: `e1_edit_core`, `e2_overlays`, `e2b_crop_rotate`, `e2_pick_probe`, `e3_motion`, `e4_audio`, `e7_background` đều PASS; file xuất kiểm bằng `scripts/qa/verify_export.ps1`.
- Samsung S25 Ultra (R5CY6323KMX, Android 17): `e1_edit_core`, `e2_overlays` (cuộn bảng thêm một lần vì màn cao), `e2b_crop_rotate`, `e3_motion`, `e7_background` PASS, xuất 480p đúng độ dài. `e4_audio_s25` PASS (trình chọn Samsung có ngăn kéo khác Oppo nên dùng kịch bản riêng; nhạc ♪ + giọng thu + xuất, file có AAC, mean −21,3 dB), `e2_pip_s25` PASS (video hình-trong-hình: số đếm đổi theo thời gian ở góc ảnh xuất).
- Chưa kiểm: hộp xin quyền micro lần đầu trên máy cài mới, hiệu năng chạy ngược trên máy yếu hơn Oppo CPH2325.
- Lưu ý chạy flow chọn tệp: trình chọn nhớ thư mục lần trước, toạ độ chạm có thể lệch → dùng ngăn kéo "Tải xuống" như `e4_audio`.
