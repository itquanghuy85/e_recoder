# Nhật ký đăng cửa hàng

| Ngày | Bước | Người/Agent | Kết quả | Bằng chứng |
|---|---|---|---|---|
| 2026-10-27 | Chuẩn bị tài sản, trang web, playbook | Claude | Xong, chưa đăng | docs/store/AGENT_PLAYBOOK.md |
| 2026-10-27 | Ảnh trình dựng E1–E7 (S25), mô tả cập nhật, video quyền thêm thông báo xuất, khoá tải lên + AAB ký 1.0.0+1 | Claude | Xong, chưa đăng; thiếu email hỗ trợ + URL chính sách | `D:\JOB\e_recorder_release\ESR-1.0.0+1.aab` |
| 2026-10-27 | Điền `store/store_config.json`: supportEmail = itquanghuy85@gmail.com | Claude | Xong; `site.baseUrl` còn trống | `store/store_config.json` |
| 2026-10-27 | Chạy `scripts/store/check_assets.ps1` | Claude | Chưa chạy được: lệnh PowerShell bị từ chối bởi bộ phân loại quyền | — |
| 2026-10-27 | Tạo app trên Play Console: "E Screen Recorder", com.huluca.escreenrecorder, vi-VN, App, Free, cam kết chính sách + xuất khẩu | Claude | Xong, trạng thái Draft | Play Console, danh sách ứng dụng |
| 2026-10-27 | Khai báo App content (Privacy policy, Ads, IARC, Target audience, Data safety, FGS) | Claude | Chưa làm: cần URL chính sách quyền riêng tư | — |
| 2026-10-27 | Upload icon, feature graphic, ảnh chụp, AAB, video | Claude | Chưa làm: trình duyệt tích hợp không tải tệp lên được | — |
| 2026-10-27 | Store settings: danh mục Tools, email liên hệ itquanghuy85@gmail.com (website để trống chờ site.baseUrl) | Claude | Xong (Change saved) | Play Console, Store settings; app ID 4974496625819143694 |
| 2026-10-27 | Thử kết nối Claude in Chrome để tải tệp | Claude | Không kết nối được (extension không phản hồi) | — |
| 2026-10-27 | Main store listing vi-VN: tên, mô tả ngắn, mô tả đầy đủ (lưu nháp) | Claude | Xong | Play Console, Default store listing |
| 2026-10-27 | Upload icon 512, feature graphic 1024×500, 8 ảnh điện thoại vi-VN (lưu nháp); thứ tự hiển thị cần kiểm tra lại | Claude | Xong | Play Console, Default store listing |
| 2026-10-27 | AAB lên Internal testing | Người dùng | Người dùng tự upload (AAB 58 MB vượt giới hạn 10 MB của công cụ Chrome) | — |
| 2026-10-27 | Privacy policy URL = https://sites.google.com/view/escreenrecorder (có nội dung đầy đủ; phần liên hệ chỉ dẫn qua trang Play, email khai trong Store settings) | Claude | Xong, đã lưu | Play Console, App content > Privacy Policy |
| 2026-10-27 | App content: Ads (No), Advertising ID (No), Government (No), Financial (không có), Health (không có), Content rating IARC (All Other App Types, 3+), Sign in details (No restricted), Target audience (13–15, 16–17, 18+), Data safety (không thu thập, không chia sẻ) | Claude | Xong | Play Console, App content |
| 2026-10-27 | Store listing en-US: tên, mô tả ngắn 70/80, mô tả đầy đủ 2101/4000 (lưu nháp) | Claude | Xong | Play Console, Default store listing |
| 2026-10-27 | Internal testing: bundle ESR 1.0.0 (versionCode 1) đã có trong thư viện, gắn vào bản nháp; release notes en-US; tên "1.0.0 (1)" | Claude | Xong, chưa publish | Play Console, Internal testing |
| — | Tester Internal testing, publish Internal testing | — | Chờ danh sách email tester (chỉ có email chủ ứng dụng) | — |
| — | Foreground service permissions, vi-VN release notes | — | Chưa thấy mục FGS trong App content; cần kiểm tra sau khi bản phát hành có bundle | — |
