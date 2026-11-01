# Báo cáo build và kiểm thử iOS (31/10/2026)

PC Windows điều khiển Mac qua SSH. Mac chỉ build, chạy kiểm thử và trả log; mã nguồn gốc vẫn ở PC.

## Tóm tắt
- **iOS build được:** Simulator (Debug) và máy thật (`--no-codesign`, chỉ kiểm biên dịch) đều thành công.
- **Kiểm thử chung trên Mac:** Flutter test 387/387, analyze sạch.
- **App mở được trên iPhone 17 Simulator,** không crash. Phần bấm qua các màn hình bị chặn vì Mac thiếu Java (Maestro cần).
- **Chưa kiểm trên iPhone thật:** chưa có thiết bị và chưa ký ứng dụng.
- Build thành công **không** có nghĩa là mọi tính năng chạy trên iOS (xem mục 5). Kết quả iOS **không** thay cho các flow Android.

## 1. Kết nối và môi trường
| Mục | Giá trị |
|---|---|
| SSH | `ssh mac-ios` (192.168.68.129, user `huy`, khoá `~/.ssh/id_ed25519_mac`). Đăng nhập bằng khoá, chạy lệnh không tương tác (`BatchMode=yes`) được |
| macOS | 26.6.2 (25G83), arm64 |
| Xcode | 27.1 (27A9275), runtime iOS 26.5 và 27.0 |
| Flutter | Mac 3.47.8 / PC 3.47.4 (cùng stable, lệch bản vá) |
| CocoaPods | 1.15.2 (cảnh báo cần `LANG=en_US.UTF-8`; script tự đặt) |
| Ổ đĩa | còn trống khoảng 23 GB (đã dùng 89%) |
| Java | **Không có**, nên Maestro trên Mac không chạy được |

Không cài hay đổi gì trong môi trường hệ thống của Mac. Bộ công cụ có sẵn `~/ios-build` không bị động tới.

## 2. Đồng bộ mã nguồn
- PC: nhánh `feature/caption-p1`, HEAD `bf5f759254d6370c1fc27208b890b79d1ba99401`, working tree sạch.
- Chuyển bằng `git bundle create … feature/caption-p1`, sao qua `scp`, rồi `git clone` từ bundle vào thư mục riêng `~/e_recorder_ios_qa/src`. Bundle đã được xoá khỏi `/tmp` của Mac sau khi clone.
- HEAD trên Mac: `bf5f759254d6370c1fc27208b890b79d1ba99401`. **Trùng tuyệt đối** với PC, working tree sạch trước khi build.
- Không push, không lấy mã từ remote.

## 3. Nền tảng iOS hiện có
- Có sẵn `ios/`: `Podfile` (iOS 15.5), `Runner.xcworkspace`, `RunnerTests` và mã native Swift khoảng 1450 dòng: `ScreenRecorder`, `RecorderChannel`, `IOSExporter`, `MediaProbe`, `OverlayRenderer`.
- Plugin trong `pubspec.yaml` đều hỗ trợ iOS: shared_preferences, sqflite, path_provider, permission_handler, video_player, package_info_plus. Ngoài pod Flutter, các plugin được nạp qua Swift Package Manager.
- Kênh native `escreenrecorder/recorder` (+ `/events`) có ở cả hai nền tảng. Các lệnh chưa làm trên iOS đều trả lời "chưa hỗ trợ" (`unsupported`), không bị lỗi thiếu lệnh.

## 4. Build và kiểm thử (log: `test-results/ios_build/`)
| Bước | Kết quả | Thời gian | Bằng chứng |
|---|---|---|---|
| `plutil -lint ios/Runner/Info.plist` | PASS | 0 s | `01_plutil.log` (xem lỗi I-1) |
| `flutter pub get` | PASS | 2 s | `02_pub_get.log` |
| `pod install` | PASS | dưới 1 s | `03_pod_install.log`: 1 pod; có cảnh báo base configuration (xem I-2) |
| `flutter test` | PASS 387/387 | 24 s | `04_test.log` |
| `flutter analyze` | PASS (No issues found) | 8 s | `05_analyze.log` |
| `flutter build ios --simulator --debug` | PASS | 70 s | `06_build_sim.log`: `Built build/ios/iphonesimulator/Runner.app` |
| `flutter build ios --no-codesign` (release, máy thật) | PASS | 55 s | `07_build_device.log`: `Built build/ios/iphoneos/Runner.app (22.0MB)` |
| Mở app trên iPhone 17 Simulator (`simctl launch`) | PASS | 15 s | `09_launch.log`: PID 83332, sau 15 s vẫn chạy, 0 crash report, 0 dòng fatal/exception trong log hệ thống; ảnh `09_launch.png` hiện màn giới thiệu tiếng Việt |
| Smoke test Maestro `maestro/ios_smoke.yaml` (giới thiệu → màn Quay với thông báo iOS → Thư viện → Cài đặt) | BLOCKED | | `08_smoke.log`: "Unable to locate a Java Runtime" |
| Quay màn hình, chỉnh sửa, xuất trên iPhone thật | BLOCKED | | Không có iPhone kết nối và chưa có chứng chỉ ký |

Phiên bản trong bản build: 1.2.0 (build 3), lấy từ `pubspec.yaml`, không đổi.

## 5. Tính năng trên iOS: dùng chung, giới hạn theo thiết kế, chưa làm
Phần này rút ra từ đọc mã nguồn, **chưa kiểm thực tế trên iOS**.

**Dùng chung (Flutter, chạy cả hai nền tảng):** giao diện, giới thiệu, Thư viện, Cài đặt, trình chỉnh sửa (timeline, công cụ, hoàn tác), lưu dự án (sqflite), cài đặt (shared_preferences), xem trước video (video_player).

**Giới hạn theo thiết kế hiện tại (không phải lỗi build):**
- Chỉ quay được màn hình **của chính app**, vì dùng ReplayKit `RPScreenRecorder.startCapture`. Không quay được app khác vì dự án không có Broadcast Upload Extension. App tự hiện thông báo `ios_notice`.
- Không có nút nổi, dấu nổi trên app khác hay quyền vẽ đè (`canOverlay` / `requestOverlay`): iOS không cho phép.
- Không có dấu tự động theo lần bấm trên app khác (`locateTouches` chỉ có trên Android).

**Chưa làm trên iOS** (mã iOS trả `unsupported`, hoặc bỏ qua khi xuất nhưng video vẫn ra):
- Phụ đề tự động (nhận giọng nói): `sttSupport` trả `available: false`.
- Thu giọng thuyết minh và hiệu ứng giọng (`startVoice`, `stopVoice`, `processVoice`).
- Khi xuất video: tăng tốc dần, đảo chiều, chuyển cảnh, phóng to, làm mờ / khảm / tô sáng vùng, video lồng video, màu sắc (look), xuất GIF.
- Phụ đề không được vẽ vào video xuất: bộ xuất iOS không có phần nào xử lý phụ đề.

## 6. Lỗi và cảnh báo phát hiện (chưa sửa)
| Mã | Mức | Tệp | Nguyên nhân | Hướng xử lý |
|---|---|---|---|---|
| I-1 | Thấp | `ios/Runner/Info.plist` | Khai báo **trùng** 3 khoá `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` (bản tiếng Anh, rồi bản song ngữ). `plutil` vẫn chấp nhận và bản sau được dùng | Xoá bộ khoá tiếng Anh phía trên, giữ bản song ngữ |
| I-2 | Thấp | `ios/Flutter/Debug.xcconfig`, `Release.xcconfig`, `Runner.xcodeproj/project.pbxproj`, `Runner.xcworkspace` | Repo chưa ghi phần tích hợp CocoaPods, nên mỗi bản clone mới thì `pod install` và build lại tự sửa 4 tệp này (thêm `#include? Pods…`, thêm Pods vào workspace) và tạo `Podfile.lock`. Build vẫn chạy | Commit 4 thay đổi và `Podfile.lock` sinh ra trên Mac. Bản diff đầy đủ: `test-results/ios_build/git_diff_after_build.patch` |
| I-3 | Thông tin | Môi trường Mac | Thiếu Java nên Maestro trên Mac không chạy | Bạn cài Java trên Mac (mục 7) |

## 7. Việc bạn cần làm trên Mac
1. **Cài Java để chạy Maestro** (một lần): mở Terminal trên Mac, gõ `brew install openjdk@17`, rồi làm theo dòng hướng dẫn "sudo ln -sfn …" mà brew in ra. Sau đó mình sẽ chạy `maestro/ios_smoke.yaml`.
2. **Kiểm trên iPhone thật** (khi cần):
   - cắm iPhone vào Mac, bật Developer Mode;
   - trong Xcode chọn Team (tài khoản Apple) cho target Runner.
   Đây là thay đổi cấu hình ký, nên mình chưa làm.

## 8. Tái chạy
- Script trên Mac: `~/e_recorder_ios_qa/ios_qa.sh`. Script chạy lần lượt plutil, pub get, pod install, test, analyze, build simulator, build máy thật; mỗi bước một log trong `~/e_recorder_ios_qa/logs`, tổng hợp trong `summary.csv`.
- Mỗi lần có commit mới trên PC: tạo lại bundle, clone vào thư mục mới hoặc `git fetch` từ bundle, chạy lại script, rồi chép `logs/` về `test-results/ios_build/`.
- Bản sao script trong repo: `scripts/qa/ios_qa.sh`.
- Thư mục `~/e_recorder_ios_qa` (khoảng 1,1 GB) được giữ lại để chạy lần sau.
- Simulator iPhone 17 đã tắt sau khi kiểm. iPhone 18 Pro đang chạy sẵn trên Mac không bị động tới.

## 9. Cài lên iPhone thật (01/11/2026)
Làm theo yêu cầu "cài lên máy iPhone": đây là lần đầu có ký ứng dụng, đã được người dùng cho phép.

| Mục | Giá trị |
|---|---|
| Mã | main, commit `43d835f` (Mac trùng PC, qua Git Bundle) |
| Máy | "Huy 18PRM (2)", iPhone 15 Pro Max, UDID `00008130-000241480E04001C`, trạng thái connected |
| Ký | team "Huy Bui" `F7B6X2BZ6A` (Individual, trả phí); chứng chỉ Apple Development; `codesign` báo `TeamIdentifier=F7B6X2BZ6A` |
| Bản build | `flutter build ios --release`, 22,0 MB, phiên bản 1.2.0 (3), không đổi version |
| Kết quả | **PASS**: build (`12_build_gui.log`), cài (`13_install.log`, `install_rc=0`), mở app (`14_launch.log`, `launch_rc=0`). iPhone liệt kê "E Screen Recorder 1.2.0 (3)" và có tiến trình đang chạy |

**Cách đã làm và vì sao:**
- Cấu hình ký chỉ đặt trong bản sao trên Mac (`DEVELOPMENT_TEAM = F7B6X2BZ6A` trong `ios/Runner.xcodeproj/project.pbxproj` của thư mục `~/e_recorder_ios_qa/src`). **Repo không bị đổi.**
- Chạy qua SSH trực tiếp bị lỗi `errSecInternalComponent` (xem `11_build_device_signed.log`): khoá đăng nhập trên Mac bị khoá với phiên SSH nên không dùng được khoá ký.
- Cách xử lý: SSH chỉ chép script `~/e_recorder_ios_qa/install_iphone.command` rồi mở bằng Terminal trên Mac, để lệnh chạy trong phiên giao diện của tài khoản `huy` (đã đăng nhập sẵn trên Mac). Không dùng hay đoán mật khẩu nào. Một cửa sổ Terminal đã mở trên Mac trong lúc build.
- Lệnh cài và mở: `xcrun devicectl device install app` rồi `devicectl device process launch`.

**Chưa kiểm:**
- Giao diện trên iPhone: chưa chụp được màn hình iPhone từ xa, nên mới biết app đã chạy chứ chưa xem từng màn. Cần bạn mở app và xem.
- Nếu iPhone báo "Nhà phát triển chưa được tin cậy": Cài đặt → Cài đặt chung → VPN và quản lý thiết bị → tin cậy chứng chỉ của tài khoản.
- Các hạn chế iOS ở mục 5 vẫn đúng (chỉ quay được chính app, chưa có phụ đề, nhiều hiệu ứng xuất chưa làm). Các sửa dấu / zoom của Android chưa liên quan tới iPhone.
- Bản này ký bằng chứng chỉ phát triển nên hết hạn theo hồ sơ cấp phép (thường 7 ngày với team miễn phí, 1 năm với team trả phí). Không đưa lên App Store hay TestFlight.

