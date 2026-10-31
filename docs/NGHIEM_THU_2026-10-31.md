# Báo cáo nghiệm thu E Recorder — 31/10/2026 (Galaxy S25 Ultra, R5CY6323KMX)

Nhãn: **PASS** đã chạy thật trên máy và đạt · **FAIL** chạy và không đạt (ghi nguyên nhân) · **BLOCKED** không chạy được do môi trường.

## 1. Dấu tự động trên ứng dụng bên thứ ba (Google Calculator)
- Cài `com.google.android.calculator` từ Google Play chính thức (installer = `com.android.vending`, nhà phát hành Google LLC).
- `scripts/qa/ux_third_party.ps1` + `maestro/ux_third_party.yaml`: quay hướng dẫn, bấm 7, 5, 3, 9, dừng, chờ dựng, xem trước, xuất.
- **PASS** (có giới hạn): 4 lần bấm ra 4 dấu. Lần chạy đầu, dấu của phím 7 lệch lên góc phải vì ô gợi ý quyền riêng tư của Calculator biến mất đúng lúc bấm (vị trí tìm từ hình: thay đổi lớn ở chỗ khác làm lệch); dấu 5, 3, 9 đúng phím. Lần chạy sau (không còn ô gợi ý) cả 4 dấu đúng phím 7, 5, 3, 9. Video xuất có dấu và zoom.
- Không thao tác trên app cá nhân. (Lần thử Chrome trước đó đã bỏ: Chrome hiện trang chủ cá nhân.)

## 2. 18 flow Maestro (sau khi thêm bước tự bật Nâng cao)
Chạy bằng `scripts/qa/run_flows18.ps1`: mỗi flow từ app nguội; dọn trình chọn tệp, Cài đặt, máy tính giữa các flow; `OTHER_APP=com.sec.android.app.popupcalculator` vì Samsung ẩn cửa sổ nổi trên Cài đặt (cách chạy đã ghi trong `scripts/run_flow.ps1`). Máy ở "đường cũ" (bỏ khoá `purpose`) vì các flow này viết cho màn Quay cũ.

| Flow | Kết quả | Ghi chú |
|---|---|---|
| e1_edit_core | PASS | lượt 2 (OTHER_APP) |
| e2_overlays | FAIL | Kịch bản trên S25: ô chữ của khung chú thích nằm sâu dưới mép bảng công cụ, 3 cách cuộn chưa ổn định. Phần đầu (tỉ lệ khung, màu) qua sau khi thêm bước vuốt. Không thấy lỗi sản phẩm; phần sau của flow chưa kiểm |
| e2_pick_probe | PASS | Kịch bản: chọn tệp theo tên thay toạ độ cố định (trình chọn Samsung nhớ thư mục) |
| e2_pip_s25 | PASS | Như trên |
| e2b_crop_rotate | PASS | Dùng Hình ảnh (Nâng cao), tự bật đúng |
| e3_motion | PASS | Dùng Chuyển cảnh (Nâng cao) |
| e8_tools_zoom | PASS | Thêm bước vuốt bảng (S25 cao) |
| e10_regions | PASS | |
| e11_region_motion | PASS | |
| e14_pip_portrait | PASS | Tạo `esr_rot.mp4` (ffmpeg, cờ xoay 90°) theo mô tả flow |
| e16_build_from_touches | FAIL | Kịch bản lỗi thời: mong dự án trống "1 đoạn", nhưng tính năng quay sạch tự nhận lần bấm (đã nghiệm thu trước) đã dựng sẵn (3 đoạn, 1 chữ). Không sửa số kỳ vọng |
| g3_editor | PASS | |
| g7_auto_direct | FAIL | Cùng nguyên nhân e16 (thấy 7 đoạn, 3 dấu, 3 chữ thay vì 1 đoạn, 2 dấu) |
| s1_icon_audit | FAIL | Sau khi lùi từ editor, app về màn phát video; flow mong về màn chính. Cần xem lại kịch bản |
| store_pro | PASS | Thêm bước vuốt bảng Tốc độ |
| store_vi | BLOCKED | Cố định quay app Cài đặt; Samsung ẩn cửa sổ nổi trên Cài đặt |
| store_en | BLOCKED | Cần đổi ngôn ngữ app sang tiếng Anh và clip của store_vi |
| store_video_b | BLOCKED | Cần store_video_a; store_video_a chờ chữ "Bắt đầu ngay", trên S25 hộp xin quyền ghi "Chia sẻ màn hình" |

Tổng: **11 PASS · 4 FAIL · 3 BLOCKED**. 4 FAIL đều do kịch bản (lỗi thời hoặc màn S25 cao), không phải hồi quy của thay đổi hôm nay. Kết quả thô: `test-results/flows18*/results.csv`.

## 3. Phục hồi khi dựng / xuất video dài
Dự án thử riêng: `QA_long_5min.mp4` (hình thử 5 phút, tạo bằng ffmpeg) mở bằng "Chọn video" từ Tải xuống; không đụng dự án thật.
- **PASS** Xuất rồi đưa app xuống nền 15 giây, mở lại: xuất vẫn chạy và xong (`ux_long.ps1`).
- **PASS** Đóng giao diện (Maestro `stopApp`) giữa lúc xuất: dịch vụ xuất nền vẫn làm xong (có tệp).
- **PASS** Giết hẳn tiến trình (`am force-stop`) giữa lúc xuất (`ux_long_kill.ps1`): không có tệp hỏng trong thư viện; dự án còn nguyên chữ đã thêm; xuất lại được (`ESR_edit_20261031_185033`, 300 s, 480×1040).
- **Đã sửa:** tệp tạm của lần xuất bị giết nằm lại trong bộ nhớ đệm (thấy 5,6 MB, và một tệp `rev_` 4,5 MB sót từ trước). `Exporter.start` giờ dọn `cache/export*` khi bắt đầu xuất; đã thấy thư mục trống sau lần xuất kế tiếp.
- **Đã sửa:** giết app giữa lúc dựng bản tự động thì mất hết dấu (lần bấm chỉ nằm trong bộ nhớ). Việc dựng giờ được ghi lại (`draft.pending`) trước khi dựng; mở app lần sau thì dựng tiếp, tối đa 2 lần để tránh vòng lặp. Trên S25 (`ux_draft_kill.ps1`): ngay sau khi giết, dự án 0 dấu; mở lại 30 giây sau có đủ 4 dấu đúng phím 7, 5, 3, 9; việc chờ được xoá.

## 4. Hồi quy
- Flutter test 387/387, `flutter analyze` sạch.
- Maestro: `ux_editor_modes` (Cơ bản/Nâng cao hai chiều, chữ, dấu, zoom, xuất, nhớ chế độ) PASS; `ux_third_party`, `ux_long`, `ux_long_kill`, `ux_draft_kill` như trên.

## Giới hạn còn lại
- Vị trí dấu tìm từ hình: thay đổi lớn ở chỗ khác lúc bấm (ô gợi ý biến mất, chuyển trang) làm dấu lệch.
- Nếu app bị giết trước khi bản ghi kịp lưu (sự kiện "đã lưu" chưa tới) thì lần bấm của bản đó không được giữ. Chưa kiểm.
- 4 flow FAIL và 3 BLOCKED ở bảng trên.

## Trạng thái máy sau nghiệm thu
- Đã cài Google Calculator (Play). Tệp thử: `Download/esr_rot.mp4`, `Download/QA_long_5min.mp4`, `Movies/E Screen Recorder/QA_long_5min.mp4` (lần đẩy thử đầu). Video thử giữ nguyên, không xoá.
- Cài đặt app: mục đích Hướng dẫn, chế độ quay sạch, editor Cơ bản. Sao lưu cài đặt trước lượt flow: `test-results/prefs_backup_flows18.xml`.


## Lượt QA cuối (sau commit 4ff8a29)

### Sửa sản phẩm (đã xác nhận lỗi)
- **Bảng công cụ giữ vị trí cuộn của công cụ trước** (`editor_tools.dart`): đổi công cụ hay đổi mục chọn thì bảng mới mở ở giữa, các điều khiển đầu bảng (ví dụ ô chữ khung chú thích, vốn đã ở đầu) bị khuất. Nay bảng cuộn về đầu mỗi khi đổi công cụ hoặc mục chọn. Đây là nguyên nhân thật của e2_overlays (không phải ô chữ nằm sâu).
- **Tệp tạm của bản ghi bị giết nằm lại** (`RecorderService.kt`): giết app trong lúc quay để lại `cache/rec/rec_*.mp4` không phát được ("moov atom not found"); đã tích 3 tệp, khoảng 13 MB. Nay bắt đầu quay là dọn. Xác nhận trên S25: sau một lần quay mới `cache/rec` trống, quay vẫn ra 4 dấu đúng phím và xuất được.

### Độ bền: giết app sau khi tạo dấu, trước khi bản ghi được lưu
`scripts/qa/ux_kill_recording.ps1` + `maestro/ux_kill_recording.yaml` (máy tính Samsung, bấm 7 và 5 trong lúc quay, rồi `am force-stop`):
- Thư viện không có video mới; tệp tạm không phát được. **Mất toàn bộ bản ghi** (không chỉ thao tác cuối): video chỉ được hoàn tất khi bấm Dừng, còn dấu và lần bấm nằm trong bộ nhớ của dịch vụ quay.
- Khắc phục được trong phạm vi: dọn tệp tạm (đã làm). Giữ được bản ghi khi bị giết cần ghi theo kiểu MP4 phân mảnh hoặc chia đoạn: thay đổi lớn, chưa làm.
- Cửa sổ rủi ro nhỏ còn lại: giữa lúc video đã vào thư viện và lúc Flutter nhận sự kiện "đã lưu" (vài phần nghìn giây), nếu bị giết thì video còn nhưng lần bấm mất. Chưa tái hiện được, chưa kiểm.

### Kịch bản Maestro (theo hành vi đúng thiết kế)
- e16, g7: ghi nhãn timeline trước khi chạy rồi so sau khi hoàn tác (`copyTextFrom` + `${maestro.copiedText}`), thay giả định dự án trống; g7 kiểm "có dấu và phóng to từ bản quay".
- s1_icon_audit, store_video_b: editor mở từ màn phát nên lùi về màn phát trước (đúng thiết kế, có từ khi flow được viết); thêm lần lùi / lùi đến khi thấy tab Thư viện.
- store_vi, store_video_a: quay `OTHER_APP` (máy tính Samsung, không dữ liệu cá nhân) thay app Cài đặt; store_video_a nhận cả "Chia sẻ màn hình" của One UI.
- store_en: script đặt ngôn ngữ app `en-US` trước và khôi phục sau.
- Flow phụ mới `helpers/panel_find.yaml`: vuốt trong bảng công cụ đến khi thấy điều khiển; dùng ở e2_overlays, e3_motion, store_pro.
- `run_flows18.ps1`: đánh thức và mở khoá màn hình trước mỗi flow.

### Kết quả 18 flow (lượt chạy toàn bộ `test-results/flows18_final`)
| Flow | Kết quả | Ghi chú |
|---|---|---|
| e1_edit_core | PASS | |
| e2_overlays | FAIL | Sau khi bảng cuộn về đầu, nút thêm khung chú thích nằm dưới mép bảng. Đã thêm `panel_find`, **chưa chạy lại được** (S25 mất kết nối USB) |
| e2_pick_probe | PASS | |
| e2_pip_s25 | PASS | |
| e2b_crop_rotate | PASS | |
| e3_motion | FAIL | Như e2_overlays (nút `speed_ramp`); đã thêm `panel_find`, chưa chạy lại |
| e8_tools_zoom | PASS | |
| e10_regions | PASS | Theo log: 0 bước thất bại, bước cuối `export_view` hoàn tất (dòng CSV không được ghi) |
| e11_region_motion | PASS | |
| e14_pip_portrait | PASS | |
| e16_build_from_touches | PASS | |
| g3_editor | PASS | |
| g7_auto_direct | PASS | |
| s1_icon_audit | PASS | |
| store_vi | PASS | |
| store_en | PASS | |
| store_pro | FAIL | Như e2_overlays (nút thêm khung chú thích); đã thêm `panel_find`, chưa chạy lại |
| store_video_b | FAIL | Điều kiện "chưa thấy Quay thì lùi" bị chữ "Quay lại" đánh lừa; đã sửa, chưa chạy lại |

Tổng: **14 PASS · 4 FAIL · 0 BLOCKED** (store_video_a, điều kiện của b: PASS). 4 FAIL đều đã có bản sửa kịch bản nhưng chưa chạy lại: lượt chạy lại bị dừng vì màn hình S25 tự tắt (đã thêm bước đánh thức), rồi máy mất kết nối USB và không kết nối lại trong 5 phút.

### Kiểm thử kỹ thuật
- Flutter test 387/387, `flutter analyze` sạch (sau các thay đổi Dart của lượt này).

### Trạng thái máy
- Ngôn ngữ app đã trả về mặc định sau store_en.

### Chạy lại 4 flow sau khi S25 kết nối lại (`test-results/flows18_final2`)
ADB thấy 3 máy; S25 là `R5CY6323KMX` (SM-S938B). `run_flows18.ps1` ghim cả adb và Maestro vào số máy này.

| Flow | Kết quả | Nguyên nhân (bằng chứng) |
|---|---|---|
| e2_overlays | FAIL (kịch bản) | Đã qua bước khung chú thích. Hỏng ở `font_serif`: bảng Chữ nay mở ở đầu, nhưng kịch bản còn 2 lần vuốt cố định viết cho kiểu cũ (giữ vị trí cuộn), nên vuốt quá, `font_serif` trôi lên trên (ảnh `step-046`). Đã thay 3 chỗ vuốt cố định (`font_serif`, `text_box`, `text_motion_enter_pop`) bằng `panel_find`. **Chưa chạy lại.** |
| e3_motion | BLOCKED (môi trường) | Đã qua `speed_ramp`, đảo chiều, chuyển cảnh, bấm Xuất. Chờ `export_view` 400 giây thì màn hình tắt và máy khoá (ảnh đen, `mWakefulness=Dozing`). Không có tệp xuất mới trong Movies, nhưng lúc đó pin S25 còn 4%→2% và không sạc, nên chưa kết luận được là lỗi sản phẩm. |
| store_pro | BLOCKED (môi trường) | Máy đang ở màn khoá (ảnh: màn đen, thẻ "Now brief"), `isKeyguardShowing=true`. |
| store_video_a | BLOCKED (môi trường) | Như store_pro, không tới được nút "Bắt đầu quay". |
| store_video_b | BLOCKED (môi trường) | Như trên. |

Nguyên nhân chung: `dumpsys battery` báo pin **2%**, `USB powered: false`, `AC powered: false` (cáp đang nối PC chỉ truyền dữ liệu, không sạc). Thời gian tắt màn hình 30 giây, "luôn sáng khi cắm sạc" không có tác dụng vì máy không nhận nguồn. Sắp hết pin nên không thể chạy tiếp.

**Kết quả cuối 18 flow hiện tại: 14 PASS · 1 FAIL (kịch bản, đã sửa, chưa chạy lại) · 3 BLOCKED (môi trường).** Nghiệm thu **chưa hoàn tất**: các flow e2_overlays, e3_motion, store_pro, store_video_b vẫn chưa chạy lại thành công (store_video_a bị chặn cùng lý do).

Để chạy lại: sạc S25 (cắm sạc nguồn hoặc cổng có cấp điện), mở khoá màn hình, rồi chạy
`powershell -File scripts\qa\run_flows18.ps1 -OutDir test-results\flows18_final3 -Flows e2_overlays,e3_motion,store_pro,store_video_a,store_video_b`
(trước đó bỏ khoá `purpose` như các lượt "đường cũ", sau đó khôi phục).

### Khôi phục khoá `purpose` (đã làm, đã kiểm)
- Giá trị lấy từ `test-results/prefs_backup_final.xml`: `<long name="flutter.purpose" value="0" />`.
- Cách làm: dừng app, sao tệp prefs hiện tại ra `cache/` của app, thêm đúng dòng này, ghi lại. So với bản sao: **chỉ khác đúng một dòng thêm vào**, 31 khoá còn lại giữ nguyên.
- Sự cố trong lúc làm: lần ghi đầu qua Git Bash bị đổi đường dẫn trên máy nên tệp prefs bị ghi rỗng. Đã ghi lại ngay từ bản đã chuẩn bị. App bị dừng suốt quá trình, không được mở khi tệp rỗng, nên không mất dữ liệu. Đã xoá bản sao tạm trong `cache/`. Không xoá video hay dữ liệu nào khác.
