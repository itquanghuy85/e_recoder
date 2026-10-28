# Chính sách quyền riêng tư — E Screen Recorder

> Bản đăng công khai nằm ở `site/vi/privacy.html` (và `site/en/privacy.html`), sinh bởi `tool/gen_site.py`. Sửa nội dung ở đó; file này chỉ là bản tóm tắt trong repo.

Cập nhật: 2026-10-28

**Tóm tắt:** video của bạn ở lại trên máy của bạn. Ứng dụng không có tài khoản, không quảng cáo và không thu thập dữ liệu.

## Dữ liệu ứng dụng xử lý
- Nội dung màn hình và âm thanh bạn chọn quay (sau khi bạn đồng ý trong hộp thoại của hệ thống). Dữ liệu này được ghi thành tệp video trên thiết bị, trong thư mục `Movies/E Screen Recorder` (GIF: `Pictures/E Screen Recorder`).
- Dự án chỉnh sửa (vị trí cắt, dấu, chữ…) lưu trong cơ sở dữ liệu cục bộ của ứng dụng.
- Cài đặt (độ phân giải, giao diện…) lưu cục bộ.
- **Phụ đề tự động** (khi bạn bấm nút): lời nói trong video được nhận dạng **ngay trên điện thoại** bằng bộ nhận dạng giọng nói của Android, ở chế độ chỉ chạy trên máy (`createOnDeviceSpeechRecognizer`): âm thanh không được gửi đi và ứng dụng **không có quyền INTERNET**. Chỉ phần chữ kết quả được lưu vào dự án. Lần đầu dùng một ngôn ngữ chưa có sẵn, Android có thể tự tải gói ngôn ngữ (việc của hệ thống Android, không phải của ứng dụng; ứng dụng chỉ hiển thị nút "Tải gói ngôn ngữ" và nói rõ điều đó). Ứng dụng không cài mô hình nào riêng và không tăng dung lượng cài đặt vì tính năng này.
- **Hiệu ứng giọng và giảm ồn** cho giọng lồng tiếng: xử lý trên máy; bản đã xử lý nằm trong thư mục riêng của ứng dụng, bản gốc được giữ để khôi phục.

## Ứng dụng không làm gì
- Không tải video, âm thanh, ảnh màn hình hay dự án lên máy chủ nào.
- Không dùng tài khoản, định danh quảng cáo, phân tích sử dụng hay báo lỗi tự động.
- Không chia sẻ dữ liệu với bên thứ ba. Chỉ khi bạn bấm **Chia sẻ**, tệp được gửi tới ứng dụng bạn chọn qua hộp thoại chia sẻ của Android.

## Quyền và mục đích
- **Quay màn hình** (hộp thoại hệ thống mỗi lần quay): ghi lại nội dung hiển thị.
- **Micro**: chỉ khi bạn chọn quay có tiếng.
- **Hiện trên ứng dụng khác**: hiện thanh điều khiển, đếm ngược và dấu đánh dấu lên màn hình đang quay.
- **Thông báo**: hiện nút Tạm dừng/Dừng khi đang quay.

## Nội dung nhạy cảm
Màn hình có thể chứa mật khẩu, tin nhắn, số điện thoại. Hãy dùng khối che trong trình chỉnh sửa trước khi chia sẻ video. Thanh điều khiển nổi và dấu vẽ lúc quay được ghi vào video.

## Xoá dữ liệu
Xoá video trong **Thư viện** hoặc bằng ứng dụng Ảnh/Tệp. Gỡ cài đặt ứng dụng sẽ xoá dự án chỉnh sửa và cài đặt.

## Liên hệ
Qua trang của ứng dụng trên Google Play.
