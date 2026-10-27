# Kế hoạch nâng trình chỉnh sửa lên mức chuyên nghiệp

Ngày: 2026-10-27 · Dựa trên đọc mã `lib/features/editor/*` (3.8k dòng) và `android/.../export/*` (850 dòng, Media3 1.8.0).

## 1. Audit hiện trạng

**Đang có:** cắt (chia, xoá đoạn, kéo mép), tốc độ theo đoạn (0.5/1/1.5/2/3×), dấu hiệu ứng nước, chữ, khối che, phóng to (zoom) theo thời gian, dựng tự động (zoom + đánh số + tua nhanh đoạn đứng yên), hoàn tác 60 bước, tự lưu, xuất MP4/GIF theo chiều cao + bitrate, ghép nhiều video (`join_sheet`, `seg.uri`).

**Cấu trúc tốt để mở rộng:** dữ liệu là `EditProject` bất biến (JSON, có hoàn tác), xuất là một `Composition` Media3 dựng từ `ExportJob`; mỗi lớp (cover, marker, zoom, caption, speed) là một `Effect` riêng theo đoạn. Thêm tính năng = thêm trường dữ liệu + một Effect, không phải viết lại.

**Khoảng trống so với một trình dựng chuyên nghiệp:**
| Nhóm | Thiếu |
|---|---|
| Dòng thời gian | Một track duy nhất; không kéo đổi thứ tự đoạn; không nhân đôi đoạn; không "ghim" điểm cắt chính xác theo khung; không zoom dòng thời gian |
| Tốc độ | Chỉ 5 mức cố định; không nhập tự do (0.1–8×); không chuyển tốc mượt (speed ramp); không đóng băng khung; không chạy ngược |
| Chuyển cảnh | Không có (cắt cứng giữa các đoạn) |
| Âm thanh | Không chỉnh âm lượng, không tắt tiếng từng đoạn, không fade, không nhạc nền, không thu lồng tiếng sau |
| Hình | Không cắt khung/xoay/đổi tỉ lệ (9:16, 1:1, 16:9, nền mờ), không lọc màu, không chỉnh sáng/tương phản |
| Lớp phủ | Chỉ marker/chữ/khối che; không ảnh, hình khung, mũi tên tự do, hộp phóng to (callout), không hoạt cảnh vào/ra cho chữ; chữ không có font/viền/nền |
| Phụ đề | Không có (không nhận dạng giọng nói trên máy) |
| Xuất | Không có preset (TikTok/YouTube/Zalo), không ước lượng dung lượng, không xuất khung hình tĩnh, không chạy nền khi tắt màn hình |
| Hiệu năng | Mọi thứ xuất trong màn editor (đã ghi ở giới hạn); chưa có bản xem trước chất lượng thấp cho hiệu ứng nặng |

**Rủi ro đã thấy trong mã:** `SpeedChangeEffect` + `SonicAudioProcessor` theo từng đoạn nên tốc độ đổi đột ngột ở ranh giới; zoom dùng một hệ số cố định (`zoomScale=1.7`), chưa có cong chuyển động (easing) cấu hình; hoàn tác lưu cả project mỗi bước (ổn với project nhỏ, tốn bộ nhớ nếu thêm nhiều lớp ảnh).

## 2. Phương án theo giai đoạn

Mỗi giai đoạn: làm → test đơn vị → flow Maestro → chạy trên Oppo cũ **và** Samsung S25 → cập nhật tài liệu. Thứ tự theo giá trị/rủi ro.

### E1 — Dòng thời gian chuyên nghiệp (nền cho mọi thứ sau)
- Kéo thả đổi thứ tự đoạn; nhân đôi đoạn; chia theo khung; zoom dòng thời gian (chụm/thanh trượt); bám (snap) vào dấu, đầu/cuối đoạn, con trỏ phát.
- Chọn nhiều đoạn, xoá gợn (ripple) hoặc để trống.
- Chấp nhận: đổi thứ tự rồi xuất → thứ tự đúng; hoàn tác 1 bước.

### E2 — Tốc độ và thời gian
- Nhập tốc độ tự do 0.1–8×; thanh trượt + nhập số.
- **Speed ramp**: đường cong tốc độ trong một đoạn (vào/ra mượt) bằng `SpeedProvider` của Media3 thay cho một số cố định.
- Đóng băng khung (N giây); chạy ngược (giải mã sang tệp tạm — chỉ cho đoạn ngắn, cảnh báo dung lượng).
- Giữ cao độ khi đổi tốc (Sonic đã có), có tuỳ chọn tắt tiếng khi >2×.
- Chấp nhận: 4× → 1× mượt, không giật âm thanh; độ dài xuất khớp tính toán ±1 khung.

### E3 — Chuyển cảnh
- Mờ chéo (crossfade), trượt (4 hướng), đẩy, phóng-mờ, "nước" (gợn, hợp bộ dấu hiệu ứng nước), cắt-khung-đen.
- Cách làm: Media3 không có sẵn chuyển cảnh. Hai hướng, thử ở E3.0 để chọn: (a) hai chuỗi chồng nhau + `AlphaScale`/`MatrixTransformation` theo thời gian (đúng tinh thần Composition đa chuỗi); (b) một `GlEffect` tự viết lấy hai khung. Chọn (a) nếu đạt trên máy yếu.
- Thời lượng 0.2–1.5 s; mỗi ranh giới đoạn có một chuyển cảnh; xem trước ngay trong editor bằng cùng bộ vẽ.
- Chấp nhận: ảnh chụp giữa chuyển cảnh khớp giữa xem trước và video xuất (cùng phép thử như dấu hiệu ứng nước).

### E4 — Âm thanh
- Âm lượng và tắt tiếng theo đoạn; fade vào/ra; chuẩn hoá âm lượng; hạ nhạc nền khi có giọng (ducking) ở mức đơn giản.
- Nhạc nền: **người dùng tự chọn tệp từ máy** (không đóng gói nhạc — tránh bản quyền và phình APK); lồng tiếng: thu micro ngay trên dòng thời gian.
- Chấp nhận: xuất có 2 track trộn đúng mức; tệp không âm thanh vẫn xuất được.

### E5 — Hình ảnh và bố cục
- Cắt khung (crop) tự do + khoá tỉ lệ; xoay 90°; đổi tỉ lệ khung xuất (9:16, 1:1, 4:5, 16:9) với nền mờ/màu; lọc màu (sáng, tương phản, bão hoà, nhiệt độ, vài preset); làm nét nhẹ.
- Hình trong hình: một video/ảnh nhỏ góc màn (Composition đa chuỗi + `VideoCompositorSettings`).
- Chấp nhận: xuất đúng tỉ lệ; thao tác crop không làm lệch marker/zoom (toạ độ marker chuẩn hoá theo khung gốc, cần test riêng).

### E6 — Lớp phủ nâng cao
- Chữ: font (Barlow + 2 font đóng gói), viền, nền, bóng, hoạt cảnh vào/ra, căn lề; bước đánh số kiểu "Bước 1/2/3" tự đặt chữ.
- Ảnh/nhãn dán/hình (mũi tên, khung, vòng tròn); hộp phóng to (callout) nổi lên chỗ bấm.
- Keyframe vị trí/tỉ lệ/độ mờ cho mọi lớp phủ (hai điểm + easing).
- Chấp nhận: lớp phủ vẽ cùng một bộ vẽ ở xem trước và xuất.

### E7 — Xuất và quy trình
- Preset: YouTube 1080p, TikTok/Reels 9:16, Zalo/Facebook nhỏ (≤25 MB tự chọn bitrate), GIF, ảnh tĩnh từ khung; ước lượng dung lượng trước khi xuất.
- Xuất chạy nền bằng dịch vụ nền có thông báo (không mất khi tắt màn hình); chia sẻ thẳng sang ứng dụng khác.
- Mẫu (template) dự án: lưu bộ chữ + marker + chuyển cảnh để dùng lại.
- Phụ đề tự động: **không làm** trong bản này (ML Kit chưa có nhận dạng giọng nói offline tiếng Việt đủ tốt; hoãn, đánh giá lại sau).

## 3. Ràng buộc giữ nguyên
- Không INTERNET, mọi xử lý trên máy; không thêm SDK theo dõi → Data safety vẫn "không thu thập".
- Một bộ vẽ cho xem trước và xuất (bài học của dấu hiệu ứng nước); mọi tính năng mới có test khớp pha/khung.
- Mỗi Effect mới chạy được trên máy yếu (Oppo CPH2325 720×1600) và máy lớn (S25 1440×3120); xuất 5 phút 1080p không quá ~2× thời lượng.
- Không đóng gói nhạc/ảnh có bản quyền. APK release hiện 56 MB: mỗi giai đoạn ghi lại mức tăng; ngưỡng 80 MB.

## 4. Thứ tự đề xuất và công sức (ước lượng)
| GĐ | Nội dung | Giá trị | Rủi ro | Công sức |
|---|---|---|---|---|
| E1 | Dòng thời gian | Rất cao | Thấp | 3–4 ngày |
| E2 | Tốc độ/ramp/đóng băng | Cao | Trung bình (âm thanh khi ramp) | 3 ngày |
| E3 | Chuyển cảnh | Cao | Cao (GL, máy yếu) | 4–5 ngày |
| E4 | Âm thanh | Cao | Trung bình | 3–4 ngày |
| E5 | Crop/tỉ lệ/lọc/PiP | Cao | Trung bình-cao | 5 ngày |
| E6 | Lớp phủ nâng cao | Trung bình | Thấp | 4 ngày |
| E7 | Preset, xuất nền, mẫu | Trung bình | Thấp | 3 ngày |

Khuyến nghị: làm **E1 → E2 → E3** trước (đúng thứ bạn nêu: cắt ghép, tua nhanh/chậm, chuyển cảnh), phát hành bản thử, rồi E4–E7 theo phản hồi.

## 5. Cần chốt trước khi bắt đầu
1. Phạm vi nhạc nền: chỉ tệp người dùng chọn (khuyên dùng) hay có thư viện miễn phí đi kèm (cần giấy phép rõ ràng).
2. Có muốn bản xuất chạy nền (dịch vụ nền) ngay từ E2 không, hay để E7.
3. Mức hỗ trợ máy yếu: giữ Android 10+, hay đặt tính năng nặng (PiP, lọc) chỉ cho máy RAM ≥ 4 GB.

## 6. Trạng thái triển khai (27/10/2026)

Mọi mục đều là mã thật chạy trong xem trước VÀ xuất; không có bản giả lập. "Máy thật" = Oppo CPH2325 (Android 11). Samsung S25 Ultra không kết nối được trong đợt này nên CHƯA thử trình dựng mới trên S25.

| Mục | Trạng thái | Kiểm chứng |
|---|---|---|
| E1 Dòng thời gian | Xong: chọn nhiều, tách/xoá/nhân đôi, kéo đổi thứ tự, nam châm, đóng băng, đoạn trống | `e1_edit_core` PASS, xuất đúng độ dài/hình/tiếng (ffprobe + ảnh) |
| E2 Tốc độ | Xong: tốc độ hằng, ramp 24 bậc, chạy ngược ≤30 s, tắt tiếng >2× | Test mô hình + JUnit; `e3_motion` PASS, xuất 8,65 s |
| E3 Chuyển cảnh | Xong: mờ đen/trắng, trượt 4 hướng, phóng | `e3_motion` PASS; công thức golden Dart↔Kotlin |
| E4 Âm thanh | Xong: âm lượng/fade từng đoạn, nhạc từ file, thu giọng, hạ nhạc khi có giọng, chuẩn hoá | `e4_audio` PASS (nhạc từ trình chọn + giọng + xuất) |
| E5 Hình ảnh | Xong: xoay, cắt, tỉ lệ (viền đen/lấp đầy), màu có sẵn + chỉnh | `e2b_crop_rotate` PASS, xuất 480×480 |
| E6 Lớp phủ | Xong: ảnh, hình vẽ (mũi tên, chú thích…), chữ nâng cao, chuyển động vào/ra, PiP ảnh/video | `e2_overlays` PASS (hình, chữ nền/viền/serif, chuyển động); chọn ảnh bằng trình chọn: `e2_pick_probe` PASS |
| E7 Xuất | Xong: mẫu cài sẵn, ước lượng dung lượng/cảnh báo, xuất GIF, lưu khung hình, xuất nền (dịch vụ + thông báo + Huỷ), lưu/áp mẫu dự án | `e7_background` PASS: thoát về màn hình chính, thông báo `esr_export` hiện, file mới ghi xong |

Không làm (có lý do trong HANDOVER): làm nét, chuyển cảnh "nước", tự tạo phụ đề (ngoài phạm vi), nền màu khác viền đen.

## 7. Giới hạn đã biết

- Xem trước chạy ngược là từng bước (nhảy khung), xuất mới là chạy ngược thật.
- Chạy ngược và video PiP giới hạn 30 s/đoạn; PiP video dùng ảnh mẫu 15 khung/s, không có tiếng riêng ngoài track âm thanh.
- `e2_overlays` không còn bước chọn ảnh/PiP từ trình chọn (trình chọn Oppo nhớ thư mục, toạ độ thay đổi); ảnh được chọn xác nhận ở `e2_pick_probe`, PiP video CHƯA có kịch bản máy thật tự động (xuất ảnh PiP đã thấy trong ảnh mẫu lần chạy trước, video PiP chưa kiểm).
- Hướng xoay (cùng/ngược chiều kim đồng hồ) đã khớp trong ảnh xuất của `e2b_crop_rotate`; chưa thử mọi góc trên thiết bị khác.
- Chưa thử trên Samsung S25 Ultra sau khi làm trình dựng mới.
