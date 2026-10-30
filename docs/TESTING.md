# Kiểm thử

## Unit / widget
```
flutter analyze
flutter test
```

## Maestro (máy thật)
Maestro CLI cài tại `D:\JOB\_tools\maestro\x\maestro\bin` (bản 2.11.0, tải từ GitHub chính thức). Lệnh `maestro` trong npm là gói khác, hỏng — không dùng.

```
$env:JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"   # bắt buộc, nếu không chữ có dấu không khớp
$env:Path="D:\JOB\_tools\maestro\x\maestro\bin;$env:Path"
flutter build apk --debug
adb -s <serial> install -r build\app\outputs\flutter-apk\app-debug.apk
maestro.bat --device <serial> test maestro\<flow>.yaml
```

Lưu ý máy Oppo/ColorOS:
- `pm clear`, `pm grant`, `appops set` qua adb bị chặn → không dùng `clearState`; cấp quyền (overlay, thông báo) bằng tay một lần, hoặc để flow bấm hộp thoại.
- Máy phải mở khoá màn hình; `adb shell svc power stayon true` giữ sáng khi cắm USB.
- Nhãn thanh điều hướng của Flutter có dạng `<nhãn>\nTab n of 3` → dùng regex `text: "Thư viện.*"`.
- Ảnh chụp của Maestro nằm ở `C:\Users\<user>\.maestro\tests\<ngày>\...`.

## Máy thử
| Serial | Máy | Android |
|---|---|---|
| T4E6S8IFU4AQBM8L | Oppo CPH2325 | 13 |
| NJR8W86LKRVW7DHQ | Oppo CPH2203 | 13 (hay khoá màn hình) |

## Flow
| Flow | Giai đoạn | Nội dung |
|---|---|---|
| g0_smoke | G0 | Khung app, điều hướng, đổi giao diện |
| g1_record | G1 | Quay (chấm nhỏ → nhấn giữ mở thanh): đếm ngược, tạm dừng, tiếp tục, dừng, lưu vào thư viện |
| g1_library | G1 | Phát, đổi tên, xoá (xác nhận) |
| g1_no_bar | G1 | Không thanh nổi/đếm ngược, âm thanh cả hai, dừng từ app, khôi phục cấu hình |
| g2_marker_gallery | G2 | Xem thử 7 công cụ dấu, nền sáng/tối |
| g2_live_markers | G2 | Quay thật bằng chấm nhỏ: chọn dấu trước, đổi công cụ qua khay (tự tạm dừng), mũi tên, chạm, số bước, hoàn tác |
| g5_dot_mode | G6 | Chỉ còn 1 chấm khi quay; bấm chấm → chạm chỗ → tự thoát; nhấn giữ mở thanh; khay tạm dừng quay |
| g6_clean_mode | G6 | Quay sạch: vùng ẩn → cú chạm bị nuốt → bấm thật; editor có sẵn 3 dấu |
| g7_auto_direct | G6 | Quay sạch → editor → tab Tự động (phóng to, đánh số, tua đoạn đứng yên) → hoàn tác một lần → xuất |
| g3_editor | G3 | Quay clip mẫu → mở editor → cắt, tốc độ, dấu, chữ, che, phóng → xuất 480p |
| e1_edit_core / e2_overlays / e2b_crop_rotate / e2_pick_probe / e3_motion / e4_audio / e7_background | E1–E7 | Trình dựng chuyên nghiệp: cắt/ghép, lớp phủ, cắt-xoay, chuyển động, âm thanh (nhạc từ trình chọn), xuất nền. Chạy gộp: `scripts/qa/run_editor_batch.ps1` (xác minh file xuất bằng `verify_export.ps1`). Cần `scripts/qa/push_test_media.ps1` trước |
| g3_gif | G3 | Cắt còn 4 s → xuất GIF |
| g3_join | G3 | Quay 2 clip → chọn → Ghép |
| g3_project | G3 | Thêm chữ → thoát → mở lại còn nguyên → Làm lại từ đầu → Hoàn tác |
| store_vi / store_en | G7 | Chụp ảnh thô cho cửa hàng (vi, en) — không phải test nghiệm thu |
| store_video_a / store_video_b | G7 | Quay video giới thiệu bằng chính app (`scripts/store/make_videos.ps1`) |
| g2c_exit_delay | G2 | Cài đặt dấu: thanh trượt chờ giữa lúc đặt dấu và lúc bấm được |
| g2d_marker_preview_sticky | G2 | Cài đặt dấu: xem thử dính đầu trang khi cuộn, thanh trượt 0,5–10 s, nền sáng/tối vẫn đổi |
| g2e_hold_short / g2e_hold_long / g2e_hold_stay | G2 | Quay thật với thời gian hiệu ứng ngắn nhất / dài nhất (sang màn hình chính) / tắt tự thoát; đo bằng `scripts/qa/marker_lifetime.py` |
| e8_tools_zoom | E | Ẩn/hiện công cụ, xem toàn màn hình, phóng to (mức, tốc độ vào/ra) và tinh chỉnh phóng tự động |
| e9_subtitles | E | Nhập .srt, kiểu chữ dựng sẵn, xuất (cần `esr_subs.srt` trong Download; bộ chọn Oppo hay không thấy file: không phải lỗi mới) |
| e10_regions / e11_region_motion | E | Làm mờ / mosaic / tiêu điểm theo ba khoảng thời gian; khối di chuyển giữa hai điểm; xuất |
| e12_waveform | E | Timeline vẽ sóng âm của clip |
| e13_pick_video | E | Thư viện → "Chọn video từ máy" (bộ chọn hệ thống) → editor: video 1280×720 có cờ xoay 90° hiện dọc, phát/dừng 10 lần (cần `esr_rot.mp4` trong Download: `ffmpeg -display_rotation 90 -i ngang.mp4 -c copy esr_rot.mp4`) |
| e14_pip_portrait | E | PiP là video dọc theo cờ xoay: xem trước và xuất giữ đúng hình dạng, không viền đen |
| s1_icon_audit | UI | Ảnh chụp các màn hình chính (chạy trước/sau khi đổi giao diện) |
| helpers/set_mark_mode | — | Chọn chế độ đánh dấu (env MODE, CORNER) trong Cài đặt |
| helpers/record_clip | — | Quay ~12 s màn hình Cài đặt, để lại clip mới nhất |
| helpers/grant_overlay | — | Cấp quyền overlay một lần (ColorOS) |
| helpers/reset_rec_settings | — | Đưa cấu hình quay về mặc định, dừng bản quay còn sót |

## Kiểm thử trên máy không cần Maestro (`integration_test/`)
Maestro không tạo được cử chỉ hai ngón và `sendevent` bị SELinux chặn trên Oppo, nên các kiểm tra sau chạy bằng `flutter test integration_test/... -d <serial>` (app thật trên máy, cử chỉ Flutter đưa vào app):
| Script | Kiểm gì |
|---|---|
| `scripts/qa/run_integration.sh <serial> integration_test/editor_zoom_test.dart` | Zoom hai ngón khung xem trước: chụm ra/vào, kéo, 1×–5×, nút đặt lại, chạm đúp, toàn màn hình vẫn chạy (kèm ảnh chụp từng bước) |
| `scripts/qa/run_integration.sh <serial> integration_test/ui_audit_test.dart <thư mục>` | Ảnh chụp các màn hình để so trước/sau khi đổi giao diện; tràn bố cục làm test hỏng |
| `scripts/qa/editor_pro_check.sh <serial>` | Phát/dừng ×10, cắt 3 clip rồi giữ-kéo đổi thứ tự, xoay tự do 30°, khung overlay, xuất; đo bốn góc ảnh xuất |
| `scripts/qa/voice_fx_check.sh <serial>` | Mọi hiệu ứng giọng + giảm ồn trên file thật; đo cao độ, mức ồn, đỉnh, độ dài |
| `scripts/qa/voice_fx_editor_check.sh <serial>` | Hiệu ứng giọng qua giao diện editor rồi xuất; đo tần số trong video xuất |
| `scripts/qa/auto_captions_check.sh <serial> vi|en` | Phụ đề tự động với lời nói thật (giọng đọc của chính máy, `DebugTts` chỉ có ở bản debug): tạo, hoàn tác/làm lại, xuất; in phụ đề so với câu đã đọc |
Lưu ý: bản **debug** cài mới bằng `adb install` có thể đứng ở màn splash trên Oppo (CPH2203, CPH2325; không phải lỗi của app, bản release chạy bình thường): chạy Maestro bằng bản release (`flutter build apk --release`) hoặc cài qua `flutter run`. `flutter test` gỡ rồi cài lại app nên mất quyền (overlay, micro) và video cũ không còn trong thư viện (thư viện chỉ liệt kê video do chính lần cài đó quay). Các script giữ máy sáng (`svc power stayon usb`); màn hình tắt làm test đứng. Sau khi chạy xong cần cài lại bản debug thường và cấp lại quyền "Hiển thị trên ứng dụng khác" trước khi chạy Maestro. `scripts/qa/run_flow_retry.sh <serial> <flow>` chạy flow và tự khởi động lại app nếu hỏng ở vài bước đầu.

**Chạy flow:** `powershell -File scripts\run_flow.ps1 <tên_flow> [-Cold]` (UTF-8 JVM, loại 3uTools, `-Cold` = khởi động lạnh app; in `RESULT: PASS/FAIL`). Không dùng `launchApp: stopApp: true` (id ngữ nghĩa Flutter không xuất hiện kịp).
`run_flow.ps1` còn: chờ cây ngữ nghĩa Flutter sẵn sàng (id `profile_card`...), canh để 3uTools (PC) không kéo app khác lên trước trong lúc chạy, và chạy lại 1 lần nếu hỏng trong 4 bước đầu (lần chạy đầu sau khi cài hay mất foreground). Ảnh `takeScreenshot` nằm ở `C:\Users\<user>\.maestro\tests\<ngày>\<tên flow>\takeScreenshot\`. Log app trên ColorOS bị ngập bởi Maestro: ghi `adb logcat` ra file song song khi cần.
Kiểm chứng video xuất: `scripts\verify_latest.ps1` (xem rotation bằng `ffprobe -show_entries stream_side_data=rotation`).
Bộ đếm "tự thoát chế độ chỉ điểm" ~0,9 s: flow phải bật lại chế độ trước khi bấm công cụ tiếp theo.
Unit test Kotlin: `cd android; .\gradlew.bat :app:testDebugUnitTest --offline`.

Kiểm chứng file video: `powershell -File scripts\verify_latest.ps1 [-Sheet]` (kéo bản mới nhất, in luồng bằng ffprobe, tuỳ chọn tạo ảnh lưới khung hình).
Lưu ý: nhãn Flutter gộp nhiều Text (thẻ danh sách, thẻ cấu hình) → assert bằng regex `.*chuỗi.*`; id nút = `Semantics(identifier: ...)`.
Hay gặp: flow hỏng ngay ở `profile_card` vì máy Oppo bị đưa về màn hình chính (sau một lần chạy hỏng, sau khi cài bản mới, hoặc khởi động lạnh). Cách xử lý: `adb shell am force-stop com.huluca.escreenrecorder`, HOME, `am start -n com.huluca.escreenrecorder/.MainActivity`, đợi ~10 s rồi chạy lại (flow nào hỏng khi "warm" thì thử `-Cold` và ngược lại). Một bản quay còn chạy dở do flow hỏng cũng làm flow sau lệch: force-stop app. Trước đây ghi nhận: lần chạy đầu sau khi cài bản mới hay hỏng ở `profile_card` (app chưa kịp lên): mở app bằng tay, đợi ~10 s rồi chạy lại. Chế độ quay sạch: lắc máy / rung phản hồi cần kiểm tay.
Máy thử có thể bị 3uTools (PC) kéo ứng dụng khác lên trước: `adb shell am force-stop cn.tools3u.mobile`.

## Dựng từ lần chạm (S25 Ultra, SM-S938B, bản debug)
- `e15_touch_settings`: chọn "Chấm trắng", hộp hướng dẫn 3 bước, nút mở "Thông tin điện thoại" và quay lại app — PASS.
- `e16_build_from_touches`: quay sạch trên Cài đặt, mở editor, "Dựng từ lần chạm" (đổi khung, không có vị trí) → "3 lần chạm", chú thích "Bước 1" + đoạn dừng 0,8 s, hoàn tác về 1 đoạn — PASS.
- Chưa kiểm: chế độ chấm trắng thật. `screenrecord` của adb trên S25 không thấy chấm "Hiển thị lần chạm" khi tiêm chạm bằng `adb input`; cần thử với ghi hình của app và chạm thật.

## Phụ đề tự động (Auto Caption) — S25 Ultra, bản debug
Chi tiết và kết quả: `docs/CAPTION_PLAN.md` (Phần 9-12).
- Flow: `maestro/caption_phase2_smoke`, `caption_phase3_reveal`, `caption_phase4_style`, `caption_phase5_templates`, `caption_rollback_effects` (preview), `caption_phase7_full` (tạo, mẫu, kéo, lưu, mở lại, xuất), `caption_phase7_speed` (xuất khi tăng tốc 2x), `caption_rollback_export` (chữ thường vẫn xuất như cũ).
- Chạy Maestro trên máy này: lệnh `maestro` trong PATH (npm) không chạy; dùng `D:\JOB\_tools\maestro\x\maestro\bin` + `JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8` (xem `scripts/run_flow.ps1`), `--test-output-dir test-results/<tên>` để lấy ảnh. Toạ độ `point:` phải là số nguyên %.
- Kiểm tra video xuất: `scripts\qa\verify_caption_export.ps1 [-At "0.6,2.2"] [-Record]` kéo bản xuất mới nhất, in độ dài video/âm thanh (đồng bộ), tạo ảnh lưới khung hình (`sheet.png`). Video thử có timecode in sẵn nên mỗi khung cho thấy thời gian nguồn.
- Dọn dữ liệu thử: `scripts\qa\qa_data.ps1 -Action list|clean [-Apply]` (mặc định chạy thử). Chỉ xoá file có trong `test-results/qa_created_files.txt`; xem quy tắc an toàn ở đầu script.
- Thư viện chỉ liệt kê video do chính app tạo (quyền truy cập MediaStore), nên video thử phải là bản xuất của app (`maestro/qa_make_test_source.yaml`), không thể chép tay bằng adb.

### Phụ đề tự động và nhập SRT (S25 Ultra)
- `maestro/qa_stt_probe.yaml -e SAMPLE=<file>`: đo STT trên video mẫu trong Download (kết quả đọc từ dự án bằng `adb run-as`, chỉ bản debug). Mẫu và văn bản gốc: `test-results/stt/` (tạo lại bằng TTS, xem `docs/CAPTION_PLAN.md` Phần 12).
- `maestro/caption_auto_flow.yaml`: chọn video mẫu qua hộp chọn tệp, "Tạo phụ đề tự động", panel mở tab Mẫu, phát, xuất. Kiểm video: `scripts\qa\verify_caption_export.ps1 -At "0.8,2,..." -Record`.
- `maestro/caption_srt_import.yaml`: cần `test.srt` (3 dòng) trong Download; chọn qua hộp chọn tệp thật.
- Dọn video test chọn từ Download: `scripts\qa\qa_data.ps1 -Action clean -Apply -PickedProject "<đuôi uri dự án>"`.
- Không dùng `clearState` trong flow: nó xoá cả cơ sở dữ liệu dự án của app.
