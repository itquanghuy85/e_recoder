# Thông số quay chuẩn cho từng chế độ

Cập nhật: 01/11/2026. Máy nghiệm thu: **Galaxy S25 Ultra (SM-S938B)**, màn hình 1440×3120, tiếng Việt.
Bản app: debug 1.2.0 (Flutter 3.47.4).

Quy ước:

- **Nét** = `Quality.high`, **Cân bằng** = `Quality.balanced`, **Nhẹ** = `Quality.low`.
- Thời gian ghi bằng mili giây (ms), trừ khi có chữ "s".
- `CODE_OBSERVED`: số lấy trực tiếp từ mã nguồn. `TEST_VERIFIED`: đã quay và kiểm trên S25, có ảnh/clip.
- "Quay xong dùng được ngay" nghĩa là bấm **Xuất ngay** ở màn kết quả, không mở trình sửa.

## 1. Bảng thông số đầy đủ

### 1.1. Cài đặt quay (`rec.*`)

| Mục trên màn Quay | Khoá | Mặc định | Lựa chọn / khoảng | Ý nghĩa | Mã |
|---|---|---|---|---|---|
| Độ phân giải | `rec.resolution` | 1080p | 720p / 1080p / Gốc | Cạnh ngắn của khung; Gốc giữ 1440×3120 | `lib/features/record/rec_settings.dart:49-53` |
| Tốc độ khung hình | `rec.fps` | 30 | 30 / 60 | Khung hình mỗi giây yêu cầu | `rec_settings.dart:90` |
| Chất lượng | `rec.quality` | Cân bằng | Nhẹ 0,04 / Cân bằng 0,07 / Nét 0,11 bit/pixel/khung | Chọn bitrate | `rec_settings.dart:56-60` |
| Âm thanh | `rec.audio` | Micro | Không có / Micro / Âm thanh máy / Cả hai | Nguồn tiếng | `rec_settings.dart:17` |
| Đếm ngược | `rec.countdown` | 3 giây | Tắt / 3 giây / 5 giây | Chờ trước khi ghi | `rec_settings.dart:93` |
| Dấu đánh dấu khi quay | `rec.floatingBar` | Bật | Bật / Tắt | Bật thanh nổi **và** bộ nghe chạm của chế độ sạch | `rec_settings.dart:94`, `RecorderService.kt:121-123` |

Bitrate được tính tự động, không có ô nhập tay:

```
bitrate = width × height × fps × bitsPerPixel
```

rồi kẹp trong **1,5–25 Mbps** (`rec_settings.dart:75-78`). Với S25 1440×3120:

| Khung | fps | Chất lượng | Bitrate |
|---|---|---|---|
| 1080p (1080×2340) | 30 | Cân bằng | ≈ 5,31 Mbps |
| 1080p | 30 | Nét | ≈ 8,34 Mbps |
| Gốc (1440×3120) | 30 | Nét | ≈ 14,83 Mbps |
| Gốc | 60 | Cân bằng | ≈ 18,8 Mbps |
| Gốc | 60 | Nét | ≈ 29,6 → kẹp còn **25 Mbps** |

### 1.2. Dấu và tự dựng (`marker.*`)

| Mục trên màn Quay | Khoá | Mặc định | Lựa chọn / khoảng | Ghi chú | Mã |
|---|---|---|---|---|---|
| Dấu bấm (Hướng dẫn) | `marker.mode` + `marker.touchSourceV2` | Tự động sau khi quay | Tự động sau khi quay / Bấm tay khi quay / Không dấu | "Tự động" = quay sạch + nghe chạm; "Bấm tay" = chấm nổi | `quick_options.dart:19-35` |
| Đánh số các bước | `marker.autoNumber` | Bật | Bật / Tắt | Đánh số 1..N, không giới hạn, không reset | `marker_settings.dart:154` |
| Phóng to vào dấu | `marker.autoZoom` | Bật | Bật / Tắt | Chỉ có ở chế độ Hướng dẫn | `marker_settings.dart:153` |
| Thời gian hiện dấu | `marker.hold` | 2500 | 500–10000, bước 100 | Thanh trượt "Thời gian hiện dấu" | `marker_settings.dart:142-144`, `marker_timing.dart:9-10` |
| Mức phóng | `marker.zoomScale` | 170% | 120–400% (UI 120–300%, bước 10) | Tâm là điểm chạm | `marker_settings.dart:155`, `quick_options.dart:138-141` |
| Phóng vào | `marker.zoomRamp` | 350 | 100–2000, bước 100 | Dùng chung cho cả vào và ra | `marker_settings.dart:156`, `quick_options.dart:270-272` |
| Giữ thêm | `marker.zoomHold` | 0 | 0–5000, bước 100 | Giữ zoom sau khi dấu mờ | `marker_settings.dart:157`, `quick_options.dart:281-283` |
| Dừng hình tại mỗi lần chạm | `marker.pause` | 800 | 0–1500, bước 100 | Ảnh đứng tại lúc bấm | `marker_settings.dart:160`, `quick_options.dart:259-261` |
| Dấu tự động gắn vào mỗi lần bấm | `marker.autoType` | Số | Số / Vòng / Tròn / Vuông / Mũi tên / Bút | Chỉ hiện khi "Tự động sau khi quay" | `quick_options.dart:241-252` |
| Kiểu dấu (Game) | `marker.tool` | Ngón tay | Ngón tay / Vòng / Tròn / Vuông / Mũi tên / Bút | Chấm nổi khi quay | `quick_options.dart:160-169` |
| Màu dấu | `marker.color` | Đỏ `#FF3B30` | 7 màu trong bảng | **Không còn chỗ chỉnh trên màn Quay** | `marker_settings.dart:84-86`, `app_tokens.dart:82-90` |
| Độ dày | `marker.thickness` | 5 | 3 / 5 / 8 | **Không còn chỗ chỉnh trên màn Quay** | `marker_settings.dart:82` |
| Góc chấm | `marker.corner` | Dưới trái | 0–3 | **Không còn UI**, giữ mặc định | `marker_settings.dart:151` |
| Lắc để đánh dấu | `marker.armShake` | Tắt | Bật / Tắt | **Không còn UI** | `marker_settings.dart:152` |
| Tự thoát sau khi đặt dấu | `marker.autoExit` | Bật | Bật / Tắt | **Không còn UI** | `marker_settings.dart:145` |
| Chờ sau khi đặt dấu | `marker.exitDelay` | 900 | 0–5000 | **Không còn UI** | `marker_settings.dart:146` |
| Khi gõ phím | `marker.inputMode` | Gộp | Gộp / Từng phím / Bỏ qua | **Không còn chỗ chỉnh trên màn Quay** | `marker_settings.dart:162` |
| Phóng nhẹ khi dừng hình | `marker.pauseZoom` | 100% | 100–150% | **Không còn chỗ chỉnh trên màn Quay** | `marker_settings.dart:161` |

### 1.3. Thời gian dấu (native, không đổi được)

| Thông số | Giá trị | Ý nghĩa | Mã |
|---|---|---|---|
| Cue | 500 ms | Vòng gợn chạy trước khi dấu hiện đủ | `marker_timing.dart:6` |
| Pop | 140 ms | Dấu bật ra | `marker_timing.dart:11` |
| Press | 260 ms | Nhịp "nhấn" | `marker_timing.dart:12` |
| Fade | 300 ms | Mờ dần | `marker_timing.dart:13` |
| Bóng mờ | 22% | Độ đậm của dấu kế đang chờ | `marker_timing.dart:14` |
| Vòng nước | 1400 ms, bước 100 ms | Chu kỳ gợn | `marker_timing.dart:19-21` |

`MarkerAnim.kt` phải khớp từng số với file Dart này (có test chung).

### 1.4. Tự dựng sau khi quay

| Thông số | Giá trị | Ý nghĩa | Mã |
|---|---|---|---|
| Zoom trước dấu | 200 ms | Bắt đầu zoom trước cue | `auto_director.dart:122` |
| Gộp zoom cùng chỗ | 700 ms, sai số 6% | Hai lần chạm gần nhau dùng chung zoom | `auto_director.dart:123,126` |
| Zoom ngắn nhất | 800 ms | Ngắn hơn thì bỏ | `auto_director.dart:127` |
| Tua nhanh đoạn đứng yên | 4×, từ 1800 ms, chừa 350 ms mỗi đầu | **Không áp dụng ở bản dựng ngay sau quay** (`idle: false`) | `auto_director.dart:128-130`, `recorder_controller.dart:120,168` |
| Dấu mờ trước khi đổi màn | 450 ms | Cue + fade + 150 ms dò | `auto_director.dart:467,487` |
| Gộp dấu khi dừng hình | 1500 ms | Hai dấu sát nhau dùng chung một ảnh đứng | `auto_director.dart:167-184` |
| Nhãn "Bước N" | y = 10%, cỡ 20U | Cố định, không chỉnh | `auto_director.dart:522-537` |
| Chữ khi gõ | "Đang nhập…" trước 400 ms, "Đã nhập" sau 1500 ms | Theo ngôn ngữ máy | `auto_director.dart:372-380` |

### 1.5. Xuất video

| Thông số | Giá trị | Mã |
|---|---|---|
| fps khi xuất | **30 cố định** | `Exporter.kt:250` |
| Bitrate mặc định | `w × h × 30 × 0,07`, kẹp 1,5–25 Mbps | `export_presets.dart:91-92` |
| Audio | 128 kbps | `export_presets.dart:70` |
| Mẫu YouTube | 1080p | `export_presets.dart:33` |
| Mẫu dọc | 1080p, 9:16 | `export_presets.dart:34-37` |
| Mẫu chia sẻ | 720p, tối đa 24 MB | `export_presets.dart:38-41` |
| GIF | 480p, **10 fps** | `export_presets.dart:42-45`, `ExportJob.kt:209` |
| Nơi lưu | `Movies/E Screen Recorder`, ảnh `Pictures/E Screen Recorder` | `app_vi.arb` (privacyP5) |

### 1.6. Phụ đề

| Thông số | Giá trị | Mã |
|---|---|---|
| Mẫu "Chuẩn" | 24U, viền 2, đậm, y 85%, hiện từng từ | `assets/caption_templates.json` |
| Mẫu "TikTok" | 32U, viền 4, y 62%, hiện từng từ | `assets/caption_templates.json` |
| Mẫu "Karaoke vàng" | 28U, viền 3, y 82%, tô theo nhịp | `assets/caption_templates.json` |
| Cỡ chữ | 12–48U | `caption_style_editor.dart:200-203` |
| Viền | 0,5–6, bước 0,5 | `caption_style_editor.dart:208-212` |
| Bóng | 1–10 | `caption_style_editor.dart:226-230` |
| Bo nền | 0–20 | `caption_style_editor.dart:246-250` |
| Vị trí dọc | 5–95% | `caption_style_editor.dart:257-259` |
| Vị trí ngang | 10–90% | `caption_style_editor.dart:266-268` |
| Bước hiện chữ | 50 ms | `CueFrames.kt:10` |
| Phụ đề tự động | Luôn dùng mẫu **TikTok** | `auto_caption_sheet.dart:94-97` |
| Phụ đề đặt tay | Dùng mẫu **Chuẩn** | `editor_controller.dart:946` |

## 2. Vì sao chọn những số này

### 2.1. Hướng dẫn

- **1080p, 30 fps, Nét**: chữ trong app (Settings, Chrome, Zalo) sắc nét khi phóng to 180%; 30 fps đủ cho thao tác chậm, file nhỏ hơn 60 fps.
- **Thời gian hiện dấu 1,5 s**: đủ để người xem thấy chỗ bấm, không che bước kế. Dấu tự dựng còn bị cắt ngắn nếu màn hình đổi hoặc dấu kế xuất hiện (`auto_director.dart:503-520`), nên 1,5 s là mức trần an toàn.
- **Mức phóng 180%**: đủ đọc chữ mà không làm mất ngữ cảnh. 300% chỉ nên dùng khi quay màn hình nhỏ hoặc bấm vào chi tiết rất nhỏ.
- **Phóng vào 300 ms**: nhanh, không gây say; 350 ms mặc định hơi chậm với clip 30–45 s.
- **Giữ thêm 0 ms**: dấu đã giữ 1,5 s, giữ zoom thêm sẽ làm clip dài.
- **Dừng hình 300 ms**: đủ để mắt bắt kịp, không làm clip giật. Đặt 0 nếu muốn clip liền mạch.
- **Đánh số bật, kiểu dấu Số**: người xem theo dõi được thứ tự bước. Nếu không muốn số, chọn "Vòng" và tắt "Đánh số các bước" để tránh chữ "Bước N".
- **Dấu đánh dấu khi quay phải bật**: đây là điều kiện để app nghe được lần chạm và tự dựng dấu. Tắt nút này thì chế độ sạch không có dấu nào (`RecorderService.kt:121-123,177-179`).
- **Micro bật**: clip hướng dẫn thường có giọng nói. Nếu quay trong môi trường ồn, chọn "Không có" và lồng tiếng sau.

### 2.2. Game

- **Gốc 1440×3120, 60 fps**: giữ chi tiết HUD và chuyển động. Chất lượng Nét cho bitrate ≈25 Mbps (bị kẹp), đủ cho cảnh động.
- **Âm thanh máy**: nghe tiếng game. Chọn "Cả hai" nếu muốn bình luận.
- **Dấu bấm tay, thời gian hiện dấu 1,5 s**: chấm nổi chỉ để đánh dấu khoảnh khắc, không phóng to.
- **Không bật phóng to / đánh số**: chế độ chấm nổi không sinh dấu tự dựng, nên các nút này vô tác dụng.
- **60 fps không được bảo đảm trên màn hình tĩnh**: bộ ghi chỉ phát lại khung cuối mỗi 500 ms khi không có gì đổi (`RecordingSession.kt`), nên clip cảnh đứng yên có thể thấp hơn 60 fps. Đây là giới hạn của Android, không phải cài đặt sai.

### 2.3. Quay thường

- **1080p, 30 fps, Cân bằng**: file nhỏ, dùng ngay để gửi hoặc đăng.
- **Dấu đánh dấu khi quay TẮT**: video sạch, không có chấm góc. Đổi lại, app không nghe chạm và không tự dựng dấu.
- **Không dấu, không phóng to, không đánh số**: đúng mục đích quay thường.
- **Micro hoặc Không có**: tuỳ nhu cầu; quay màn hình im lặng nên chọn "Không có".

## 3. Hai bộ thông số cho mỗi chế độ

Cách chỉnh: mở app → chọn chế độ ở thanh trên → chỉnh các mục chính → mở **Thêm tuỳ chọn** cho các mục còn lại. Mỗi chế độ nhớ riêng.

### 3.1. Hướng dẫn – Chuẩn (1080p)

Dùng cho: dạy thao tác app, video 1–3 phút, đăng YouTube/Facebook.

| Mục | Giá trị | Chỗ chỉnh |
|---|---|---|
| Chế độ | Hướng dẫn | Thanh chế độ |
| Micro | Bật | Ô "Micro" |
| Độ phân giải | 1080p | Ô "Độ phân giải" |
| Dấu bấm | Tự động sau khi quay | Ô "Dấu bấm" |
| Đánh số các bước | Bật | Ô "Đánh số các bước" |
| Phóng to vào dấu | Bật | Ô "Phóng to vào dấu" |
| Thời gian hiện dấu | 1,5 s | Thanh "Thời gian hiện dấu" |
| Mức phóng | 180% | Thanh "Mức phóng" |
| Phóng vào | 0,3 s | Thêm tuỳ chọn → "Phóng vào" |
| Giữ thêm | 0 s | Thêm tuỳ chọn → "Giữ thêm" |
| Dừng hình tại mỗi lần chạm | 0,3 s | Thêm tuỳ chọn → "Dừng hình tại mỗi lần chạm" |
| Dấu tự động gắn vào mỗi lần bấm | Số | Thêm tuỳ chọn → "Dấu tự động gắn vào mỗi lần bấm" |
| Tốc độ khung hình | 30 fps | Thêm tuỳ chọn → "Tốc độ khung hình" |
| Chất lượng | Nét | Thêm tuỳ chọn → "Chất lượng" |
| Đếm ngược | 3 giây | Thêm tuỳ chọn → "Đếm ngược" |
| Dấu đánh dấu khi quay | Bật | Thêm tuỳ chọn → "Dấu đánh dấu khi quay" |

Kết quả mong đợi: mỗi lần bấm có một dấu số đỏ, zoom 180% vào đúng chỗ, dấu tự mờ trước khi màn hình đổi, không có chấm góc trong video.

### 3.2. Hướng dẫn – Nhanh (720p)

Dùng cho: clip ngắn, gửi chat, mạng yếu.

| Mục | Giá trị |
|---|---|
| Chế độ | Hướng dẫn |
| Micro | Bật |
| Độ phân giải | 720p |
| Dấu bấm | Tự động sau khi quay |
| Đánh số các bước | Bật |
| Phóng to vào dấu | Bật |
| Thời gian hiện dấu | 1,0 s |
| Mức phóng | 150% |
| Phóng vào | 0,2 s |
| Giữ thêm | 0 s |
| Dừng hình tại mỗi lần chạm | 0 s |
| Dấu tự động | Số |
| Tốc độ khung hình | 30 fps |
| Chất lượng | Cân bằng |
| Đếm ngược | 3 giây |
| Dấu đánh dấu khi quay | Bật |

### 3.3. Game – Chuẩn (Gốc 60 fps)

Dùng cho: game hành động, clip ngắn có chuyển động nhanh.

| Mục | Giá trị | Chỗ chỉnh |
|---|---|---|
| Chế độ | Game | Thanh chế độ |
| Âm thanh máy | Bật | Ô "Âm thanh máy" (bật thêm Micro nếu bình luận) |
| Độ phân giải | Gốc | Ô "Độ phân giải" |
| Mượt (60 hình/giây) | Bật | Ô "Mượt" |
| Dấu khi bạn chạm | Ngón tay | Ô "Dấu khi bạn chạm" |
| Thời gian hiện dấu | 1,5 s | Thanh "Thời gian hiện dấu" |
| Chất lượng | Nét | Thêm tuỳ chọn → "Chất lượng" |
| Đếm ngược | 3 giây | Thêm tuỳ chọn → "Đếm ngược" |
| Dấu đánh dấu khi quay | Bật | Thêm tuỳ chọn → "Dấu đánh dấu khi quay" |

Lưu ý: bitrate bị kẹp 25 Mbps; máy nóng có thể tự giảm fps. Không bật phóng to/đánh số vì chấm nổi không sinh dấu tự dựng.

### 3.4. Game – Nhẹ (1080p 60 fps)

Dùng cho: máy nóng, clip dài, cần file nhỏ.

| Mục | Giá trị |
|---|---|
| Chế độ | Game |
| Âm thanh máy | Bật |
| Độ phân giải | 1080p |
| Mượt (60 hình/giây) | Bật |
| Dấu khi bạn chạm | Ngón tay |
| Thời gian hiện dấu | 1,0 s |
| Chất lượng | Cân bằng |
| Đếm ngược | 3 giây |
| Dấu đánh dấu khi quay | Bật |

### 3.5. Quay thường – Chuẩn (1080p)

Dùng cho: quay màn hình để gửi, lưu bằng chứng, clip không cần dấu.

| Mục | Giá trị | Chỗ chỉnh |
|---|---|---|
| Chế độ | Quay thường | Thanh chế độ |
| Âm thanh | Micro hoặc Không có | Ô "Micro" / "Âm thanh máy" |
| Độ phân giải | 1080p | Ô "Độ phân giải" |
| Đếm ngược | 3 giây | Thêm tuỳ chọn → "Đếm ngược" |
| Dấu đánh dấu khi quay | **Tắt** | Thêm tuỳ chọn → "Dấu đánh dấu khi quay" |
| Tốc độ khung hình | 30 fps | Thêm tuỳ chọn → "Tốc độ khung hình" |
| Chất lượng | Cân bằng hoặc Nét | Thêm tuỳ chọn → "Chất lượng" |

### 3.6. Quay thường – Nhẹ (720p)

Dùng cho: clip rất ngắn, gửi qua ứng dụng giới hạn dung lượng.

| Mục | Giá trị |
|---|---|
| Chế độ | Quay thường |
| Âm thanh | Không có |
| Độ phân giải | 720p |
| Đếm ngược | 3 giây |
| Dấu đánh dấu khi quay | Tắt |
| Tốc độ khung hình | 30 fps |
| Chất lượng | Nhẹ |

## 4. Kết quả test trên S25

Chưa chạy trong lượt này. Phần này sẽ ghi: tên clip, thời lượng, kích thước, fps thực, 5–6 ảnh khung hình, và kết luận ĐẠT / CHƯA ĐẠT cho từng chế độ.

## 5. Những gì CHƯA hoạt động

Đây là các giới hạn lấy từ mã nguồn, không phải lỗi cài đặt:

1. **Phụ đề không tự sinh lúc quay.** Bản dựng ngay sau quay chỉ có dấu, zoom, đánh số, dừng hình; muốn có phụ đề phải mở trình sửa và chạy "Phụ đề tự động". Vì vậy "quay xong dùng ngay" chưa đúng cho video cần phụ đề.
2. **Không có mẫu phụ đề theo chế độ.** Phụ đề tự động luôn dùng mẫu TikTok; phụ đề đặt tay dùng mẫu Chuẩn. Không có chỗ chọn mẫu riêng cho Hướng dẫn/Game/Quay thường.
3. **Không chỉnh được thời gian hiện từng từ.** Chữ hiện theo bước 50 ms; không có fade từng từ. Thời gian lấy từ nhận dạng giọng nói hoặc chia đều.
4. **Không chỉnh được độ mờ của chấm/thanh nổi.** Chấm ở 72% và thanh nổi nhấp nháy 100%→35% là cố định.
5. **Không có giới hạn số bước.** Đánh số chạy 1..N, không reset, không đặt tối đa.
6. **"Phóng to vào dấu" và "Đánh số các bước" vô tác dụng ở Game.** Chấm nổi không lưu dấu tự dựng, nên không có gì để zoom/đánh số.
7. **Các mục đã bị bỏ UI:** góc chấm, lắc để đánh dấu, tự thoát, chờ sau khi đặt dấu, màu dấu, độ dày, khi gõ phím, phóng nhẹ khi dừng hình. Chúng vẫn được lưu và truyền xuống native nhưng người dùng không chỉnh được.
8. **Không có nguồn chạm "dots"/"manual" trên UI.** Chỉ còn Tự động / Bấm tay / Không dấu.
9. **Zoom vào và ra dùng chung một thời gian** (`zoomRamp`), không chỉnh riêng thời gian thu lại.
10. **Tua nhanh đoạn đứng yên không áp dụng ở bản dựng sau quay** (`idle: false`); chỉ có trong trình sửa.
11. **60 fps không được bảo đảm khi màn hình tĩnh.** Bộ ghi phát lại khung cuối mỗi 500 ms.
12. **Xuất cố định 30 fps**, không chọn fps/bitrate tay; GIF 10 fps.
13. **Quay thường bật "Dấu đánh dấu khi quay" sẽ ghi chấm góc vào video.** Muốn video sạch phải tắt, nhưng tắt thì mất khả năng nghe chạm.
14. **Nhãn "Bước N" cố định** ở y 10%, cỡ 20U; không chỉnh được vị trí/cỡ.
15. **"Dấu đánh dấu khi quay" là điều kiện bắt buộc của dấu tự động.** Tắt nút này ở chế độ Hướng dẫn thì không có dấu nào, dù vẫn chọn "Tự động sau khi quay".
