# Maestro — Bộ nghiệm thu tự động (e_recorder)

Mọi test trong thư mục này chạy trên **máy thật** qua [Maestro CLI](https://maestro.mobile.dev) (bản 2.11.0+, tải từ GitHub chính thức — KHÔNG dùng gói npm có tên `maestro`).

Thiết bị nghiệm thu mặc định: **Oppo CPH2325** (serial `T4E6S8IFU4AQBM8L`, Android 13). Máy phụ Galaxy S25 Ultra (`R5CY6323KMX`) có trong `docs/TESTING.md`.

## Cách chạy

### Yêu cầu môi trường (PowerShell, Windows)

```powershell
$env:JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
$env:Path="D:\JOB\_tools\maestro\x\maestro\bin;$env:Path"
```

### Chạy một test đơn lẻ

```powershell
flutter build apk --debug
adb -s <serial> install -r build\app\outputs\flutter-apk\app-debug.apk
maestro --device <serial> test maestro\<ten-file>.yaml
```

Ví dụ:

```powershell
maestro --device T4E6S8IFU4AQBM8L test maestro\g1_record.yaml
maestro --device T4E6S8IFU4AQBM8L test maestro\caption_auto_flow.yaml
maestro --device T4E6S8IFU4AQBM8L test maestro\ux_modes_record.yaml -e OTHER_APP=com.sec.android.app.popupcalculator
```

### Chạy TOÀN BỘ nghiệm thu

```powershell
.\scripts\qa\run_all_acceptance.ps1
```

Tuỳ chọn:

| Tham số | Ý nghĩa | Mặc định |
|---------|---------|----------|
| `-Serial` | Serial thiết bị adb | `T4E6S8IFU4AQBM8L` |
| `-SkipBuild` | Bỏ qua bước `flutter build apk` | false |
| `-SkipInstall` | Bỏ qua bước cài APK | false |
| `-TimeoutMin` | Giới hạn thời gian mỗi test (phút) | 15 |

Kết quả ghi vào `test-results\all_acceptance\results.csv` (cột: `group,flow,exit,first_failure,screenshot_dir`). Ảnh chụp của Maestro lưu tại `C:\Users\<user>\.maestro\tests\<ngày>\...`.

## Danh sách test theo nhóm

### P0 — Smoke / Làm cốt lõi (chạy đầu tiên)

| File | Nội dung |
|------|----------|
| `g0_smoke.yaml` | Khung app, điều hướng tab, đổi giao diện sáng/tối |
| `g1_record.yaml` | Quay: đếm ngược → tạm dừng → tiếp tục → dừng → lưu thư viện |
| `g1_library.yaml` | Phát video, đổi tên, xoá (xác nhận) |
| `g1_no_bar.yaml` | Không thanh nổi / đếm ngược, âm thanh cả hai, dừng từ app |

### P1 — Quay và đánh dấu

| File | Nội dung | Cần `OTHER_APP` |
|------|----------|:---:|
| `g2_marker_gallery.yaml` | 7 công cụ dấu, nền sáng/tối | |
| `g2_live_markers.yaml` | Quay thật bằng chấm nhỏ, đổi công cụ qua khay | |
| `g5_dot_mode.yaml` | Chỉ còn 1 chấm khi quay; nhấn giữ mở thanh điều khiển | ✅ |
| `g6_clean_mode.yaml` | Quay sạch (không gì trên màn hình), dấu vào editor | ✅ |
| `g7_auto_direct.yaml` | Quay sạch → editor → tự động (phóng to, đánh số, tua đoạn đứng yên) → xuất | ✅ |
| `ux_modes_record.yaml` | Ba chế độ quay (Hướng dẫn / Game / Quay thường) giữ cài đặt riêng | ✅ |
| `ux_mark_timing.yaml` | Dấu không bao giờ đậm cùng lúc; dấu mất trước màn mới | ✅ |

### P1 — Trình chỉnh sửa (Editor)

| File | Nội dung |
|------|----------|
| `g3_editor.yaml` | Cắt, tốc độ, dấu, chữ, che, phóng → xuất 480p |
| `g3_gif.yaml` | Cắt còn 4 s → xuất GIF |
| `g3_join.yaml` | 2 clip → ghép |
| `g3_project.yaml` | Thêm chữ → thoát → mở lại → làm lại → hoàn tác |
| `g4_onboarding.yaml` | Màn dẫn đầu tiên |
| `e1_edit_core.yaml` | Cắt/ghép chuyên nghiệp |
| `e2_overlays.yaml` | Lớp phủ |
| `e2b_crop_rotate.yaml` | Cắt-xoay |
| `e2_pick_probe.yaml` | Chọn ảnh từ trình chọn tệp |
| `e2_pip_s25.yaml` | PiP video trên S25 |
| `e3_motion.yaml` | Chuyển động |
| `e4_audio.yaml` | Âm thanh (nhạc từ trình chọn) |
| `e4_audio_s25.yaml` | Âm thanh trên S25 |
| `e4_voice_permission.yaml` | Quyền giọng nói |
| `e7_background.yaml` | Xuất chạy nền |
| `e8_tools_zoom.yaml` | Phóng to / tinh chỉnh |
| `e9_subtitles.yaml` | Nhập `.srt`, kiểu chữ dựng sẵn, xuất |
| `e10_regions.yaml` | Làm mờ / mosaic |
| `e11_region_motion.yaml` | Vùng chuyển động |
| `e12_waveform.yaml` | Hình dạng âm thanh |
| `e13_pick_video.yaml` | Chọn video |
| `e14_pip_portrait.yaml` | PiP dọc |
| `e16_build_from_touches.yaml` | Dựng từ các lần chạm |
| `e17_auto_captions.yaml` | Phụ đề tự động |
| `e18_text_fx.yaml` | Hiệu ứng chữ |

### P1 — Phụ đề / Caption

| File | Nội dung |
|------|----------|
| `caption_phase2_smoke.yaml` | Thêm 2 câu, hiện trên khung xem trước, tắt phụ đề |
| `caption_auto_flow.yaml` | STT tự động → mẫu TikTok → phát (chữ hiện dần theo lời) → xuất 720p |
| `caption_phase3_reveal.yaml` | 4 chế độ hiện chữ (none, wordByWord, charByChar, karaokeHighlight) |
| `caption_phase4_style.yaml` | Trình chỉnh sửa kiểu chữ (màu, cỡ, căn lề, kiểu) |
| `caption_phase5_templates.yaml` | 12 mẫu phụ đề |
| `caption_phase7_export.yaml` | Xuất video có phụ đề |
| `caption_phase7_full.yaml` | Xuất đầy đủ |
| `caption_phase7_speed.yaml` | Xuất đổi tốc |
| `caption_rollback_effects.yaml` | `cues=null`: 6 kiểu chữ giống bản cũ (rollback) |
| `caption_rollback_export.yaml` | `cues=null`: xuất giống bản cũ (rollback) |
| `caption_srt_import.yaml` | Nhập tệp `.srt` thật (UTF-8 / UTF-16) |

### P1 — UX / Người dùng thực

| File | Nội dung |
|------|----------|
| `ux_real_user.yaml` | Người dùng thực: quay máy tính, xem kết quả, sửa, xuất |
| `ux_swipe_guide.yaml` | Vuốt xuống/lên ở màn sửa, mở Cài đặt → Hướng dẫn thiết lập |
| `ux_editor_modes.yaml` | Chế độ Cơ bản / Nâng cao, chuyển hai chiều |
| `ux_kill_recording.yaml` | Giết app giữa lúc quay |
| `ux_long_export.yaml` | Xuất video dài |
| `ux_long_kill_a.yaml` | Giết giữa lúc xuất (lần 1) |
| `ux_long_kill_b.yaml` | Giết giữa lúc xuất (lần 2) |
| `ux_mic_denied.yaml` | Microphone bị từ chối |
| `ux_ready_a.yaml` | Trạng thái sẵn sàng quay |
| `ux_ready_b.yaml` | Trạng thái sẵn sàng quay (lần 2) |
| `ux_third_party.yaml` | Ứng dụng bên thứ ba (Google Calculator) |

### Presets (cài đặt sẵn)

| File | Nội dung |
|------|----------|
| `preset_tutorial.yaml` | Hướng dẫn 1080p, quay cài đặt Android, xuất không chỉnh |
| `preset_game.yaml` | Game native 60fps, quay menu game, xuất không chỉnh |
| `preset_game_landscape.yaml` | Game ngang |
| `preset_plain.yaml` | Quay thường 1080p, không dấu, xuất không chỉnh |

### Cửa hàng (Store)

| File | Nội dung |
|------|----------|
| `store_en.yaml` | Chụp ảnh cửa hàng (tiếng Anh) |
| `store_vi.yaml` | Chụp ảnh cửa hàng (tiếng Việt) |
| `store_pro.yaml` | Chụp ảnh Pro |
| `store_video_a.yaml` | Video giới thiệu A |
| `store_video_b.yaml` | Video giới thiệu B |
| `store_export_demo.yaml` | Xuất video demo |

### Khác

| File | Nội dung |
|------|----------|
| `s1_icon_audit.yaml` | Kiểm tra biểu tượng |
| `test_zoom_s25.yaml` | Kiểm tra zoom trên S25 |
| `export_current.yaml` | Xuất kết quả hiện tại |
| `back_to_record.yaml` | Quay lại màn quay |

## Helpers (dùng chung)

Ở `maestro/helpers/`:

| File | Ý nghĩa |
|------|---------|
| `start_recording.yaml` | Bấm "Bắt đầu quay", chấp nhận đồng ý hệ thống |
| `after_stop.yaml` | Sau khi dừng, chờ lưu rồi về màn quay |
| `reset_rec_settings.yaml` | Đặt lại cấu hình quay về mặc định |
| `open_edit.yaml` | Mở video chỉnh sửa mới nhất trong thư viện |
| `ensure_tools_open.yaml` | Đảm bảo khay công cụ editor đang hiện |
| `caption_cleanup.yaml` | Tắt phụ đề trong editor đang mở |
| `set_mark_mode.yaml` | Chọn cách làm dấu (`mode_dot` / `mode_clean`) |
| `editor_advanced.yaml` | Mở chế độ Nâng cao trong editor |

## Lưu ý quan trọng

1. **Không dùng `clearState`** — ColorOS chặn `pm clear` qua adb. Các flow dọn dẹp sau mình thay vì xóa toàn bộ dữ liệu app.
2. **Màn hình phải mở khóa và giữ sáng**: `adb shell svc power stayon true`.
3. **Chữ có dấu**: phải set `JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"`否则 Maestro sẽ không khớp được chữ tiếng Việt.
4. **Test ghi hình "khác ứng dụng"** (g5, g6, g7, ux_real_user, ux_mark_timing, ux_modes_record) cần tham số `-e OTHER_APP=<pkg>` (mặc định `com.sec.android.app.popupcalculator`).
5. **Một số test cần dữ liệu thử trước**: `caption_auto_flow` cần `stt_sample.mp4` trong Download; `e9_subtitles` cần `esr_subs.srt`; xem `docs/CAPTION_PLAN.md` và `docs/TESTING.md` chi tiết.
6. **Test store** (`store_vi`, `store_en`, …) không phải test nghiệm thu — dùng để chụp ảnh/video cho cửa hàng ứng dụng.

## Cấu trúc thư mục

```
maestro/
├── README.md                 # (tập tin này)
├── *.yaml                    # Tất cả file test nghiệm thu
├── helpers/                  # Flow dùng chung giữa các test
├── artifacts/                # Ảnh chụp màn hình (gitignored)
└── maestro-mobile.zip        # Bản cài Maestro (không dùng trực tiếp)
```

## Liên quan

- `docs/TESTING.md` — hướng dẫn kiểm thử chi tiết (unit, widget, Maestro)
- `docs/CAPTION_PLAN.md` — kế hoạch và nghiệm thu tính năng phụ đề
- `docs/PLAN_CHE_DO_QUAY.md` — kế hoạch và nghiệm thu chế độ quay
- `docs/EDITOR_PRO_PLAN.md` — kế hoạch nâng trình chỉnh sửa
- `CLAUDE.md` — lệnh chạy, thiết bị test, quy tắc làm việc
### Sửa lỗi lưu video / đánh dấu tự động (14/11/2026)

| File | Nội dung |
|------|----------|
| `clean_auto_marks.yaml` | Hướng dẫn → Tự động sau khi quay → 4 lần chạm ở app khác → Dừng → trình sửa có dấu, panel "Dấu tự động" đếm đúng (B1) |
| `rec_save_notification.yaml` | Dừng từ thông báo khi app ở nền → mở lại app thấy màn kết quả và video trong Thư viện (A2/A3) |
| `clean_auto_no_overlay.yaml` | Thu hồi quyền hiển thị trên app khác (adb) → bấm Quay không bắt đầu quay (B2) |

Lưu ý: Maestro báo "device not connected" nếu có **bất kỳ** máy nào đang ở trạng thái `unauthorized` trong `adb devices`.
