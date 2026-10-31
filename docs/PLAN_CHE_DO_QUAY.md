# Phương án: cài đặt theo chế độ quay và thời gian hiện dấu (đã chốt 31/10/2026)

Người dùng đã duyệt ("ok triển khai"). Làm theo thứ tự: Phần A (lỗi dấu) trước, Phần B (gom cài đặt) sau. Mỗi phần một commit, nghiệm thu trên S25.

## Phần A: dấu trong bản dựng tự động (chế độ quay sạch)
**Lỗi:** mỗi dấu luôn hiện cố định `holdMs` (2,5 giây) kể từ lúc bấm.
- Bấm làm đổi màn hình: dấu còn lan sang màn mới.
- Bấm nhanh: nhiều dấu cùng lúc.

**Đặc tả:** dấu bắt đầu mờ ở mốc sớm nhất trong ba mốc sau:
1. Mờ xong trước khi màn hình đổi hẳn (đổi từ 20% hình trở lên). Mốc này dò từ khung hình, trong khoảng tới lần bấm kế, tối đa 3 giây.
2. Mờ xong trước khi bóng mờ của dấu kế bắt đầu hiện.
3. Hết thời gian giữ dấu đã cài.

Quy tắc kèm theo:
- Hai lần chạm cách nhau dưới 0,3 giây chỉ giữ một dấu, bất kể vị trí (vị trí lần chạm thứ hai hay bị dò sai).
- Dừng hình tại lần bấm vẫn giữ dấu hiện đủ: dấu chạy theo thời gian của video gốc, mà thời gian này đứng yên trong lúc dừng hình.

**Tiêu chí nghiệm thu:**
- Không bao giờ có hai dấu đậm cùng lúc: dấu trước mờ xong trước lúc dấu sau hiện đủ.
- Không còn dấu trên khung hình đầu tiên của màn mới trong video xuất.
- Bấm đúp ra đúng 1 dấu.
- Test tự động bao phủ cả ba mốc.

## Phần B: cài đặt gắn vào từng chế độ quay
**Màn Quay**, từ trên xuống:
1. Thanh chọn chế độ `[Hướng dẫn | Game | Quay thường]`. Thay cho nút "Đổi mục đích"; đổi chế độ một chạm, không sang màn khác.
2. Lựa chọn chính của chế độ đang chọn (3–5 mục).
3. Nút lớn "Bắt đầu quay".
4. "Thêm tuỳ chọn" (đóng sẵn): các mục ít dùng của chế độ đó. Thay cho "Nâng cao"; bỏ thẻ cài đặt chung.

| Chế độ | Lựa chọn chính | Thêm tuỳ chọn |
|---|---|---|
| Hướng dẫn | Âm thanh (micro / âm máy), độ nét, dấu bấm (tự động sau khi quay / bấm tay khi quay / không dấu), đánh số bước, tự phóng to | Kiểu dấu, thời gian hiện dấu, dừng hình khi bấm, khung hình/giây, chất lượng, đếm ngược |
| Game | Âm thanh, độ nét, mượt (60 hình/giây), bút vẽ nổi | Nút nổi, chất lượng, đếm ngược |
| Quay thường | Âm thanh, độ nét | Đếm ngược, nút nổi, khung hình/giây, chất lượng |

- **Mỗi chế độ nhớ cài đặt riêng.** Lần đầu sau khi cập nhật, cả ba chế độ lấy giá trị đang dùng làm điểm khởi đầu. Khoá cũ giữ nguyên tên, không xoá.
- **Bỏ màn chọn mục đích lúc mới cài.** Mặc định chọn "Hướng dẫn".
- **Bỏ trang "Dấu" trong Cài đặt.** Cài đặt chỉ còn: giao diện, ngôn ngữ, quyền, giới thiệu, "Đưa các chế độ về mặc định".

**Tiêu chí nghiệm thu:**
- Đổi một cài đặt ở chế độ A không làm đổi chế độ B; mở lại app vẫn đúng.
- Lần quay dùng đúng cài đặt của chế độ đang chọn.
- Người dùng cũ không mất cài đặt.
- Cài đặt không còn trang Dấu.
- Có Maestro trên S25 cho cả ba chế độ.

## Kết quả
### Phần A: RUNTIME_VERIFIED trên S25
Lệnh chạy: `bash scripts/qa/ux_mark_timing.sh`. Flow `maestro/ux_mark_timing.yaml` quay máy tính Samsung ở chế độ sạch theo trình tự:
1. Bấm 7, 5, 3.
2. Bấm phím 8 nhanh 3 lần, cách nhau 0,45 giây.
3. Bấm đúp phím 2, cách nhau 0,1 giây.
4. Bấm phím 1.
5. Bấm "Chuyển đổi đơn vị" (mở màn mới).

Script đọc dự án vừa lưu (`marks_timing.py`) và cắt khung hình từ video xuất.

| Lượt | Kết quả | Ghi chú |
|---|---|---|
| 1 (lệch trước 0,15 s) | Chưa đạt | Dấu nút chuyển đổi còn mờ dần trên màn mới khoảng 0,3 giây. Sửa: dấu phải mờ xong trước mốc đổi (lệch trước 0,45 s) |
| 2 | FAIL | Bấm đúp phím 2 ra 2 dấu cách nhau 0,12 giây, vì lần chạm thứ hai bị dò vị trí ở góc trên phải. Phát hiện thêm: chữ "Typing…" / "Typed" ra tiếng Anh trong bản dựng sau khi quay. Sửa: chạm dưới 0,3 giây luôn gộp; truyền chữ tiếng Việt |
| 3 | **PASS** | 6 dấu (7, 5, 3, 2, 1, chuyển đổi), "never two full marks: PASS". Dấu nút chuyển đổi: giữ 0 ms, hiện suốt lúc dừng hình, mờ xong trước khi màn chuyển đổi trượt vào (ảnh `test-results/ux_mark_timing/last_mark_frames.png`, từ ô 8 không còn dấu). Bấm đúp ra 1 dấu. Phím 8 bấm nhanh thành bước "Đang nhập…" / "Đã nhập" (tiếng Việt) |

Giới hạn còn lại:
- Phím nằm ở nửa dưới màn hình bấm từ 3 lần trong 2 giây được coi là "gõ phím" và gộp thành một bước "Đang nhập…". Đây là quy tắc có sẵn (cài đặt "Khi gõ phím"), không đổi trong phần này.
- Hai lần bấm cách nhau 0,3–0,8 giây: bóng mờ (22%) của dấu sau có thể chồng lên dấu trước đang mờ dần, tối đa 0,3 giây. Không bao giờ có hai dấu đậm cùng lúc.
- Mốc "màn hình đổi" chỉ có ở bản dựng ngay sau khi quay sạch. Nút "Dựng tự động" trong trình sửa dò lần bấm theo cách khác, nên chỉ được quy tắc "một dấu mỗi lúc".

### Phần B
Chưa làm.
