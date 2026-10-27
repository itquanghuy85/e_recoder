# Prompt giao cho Agent: đăng E Screen Recorder lên Google Play

Cách dùng: mở Claude (Claude in Chrome / computer-use), **tự đăng nhập Play Console trước**, dán nguyên khối dưới đây.
Trước khi dán, điền 2 giá trị `<...>` (hoặc để Agent hỏi lại).

---

```
Bạn là Agent đăng ứng dụng lên Google Play. Tôi ĐÃ đăng nhập sẵn Google Play Console trên trình duyệt này.
Hãy tự làm toàn bộ, không hỏi lại những gì đã có trong tài liệu.

ĐẦU VÀO CỦA CHỦ ỨNG DỤNG
- Email hỗ trợ công khai: <EMAIL>
- URL gốc trang chính sách (đã online): <https://...>  (dùng <URL>/vi/privacy.html cho chính sách quyền riêng tư)

TÀI NGUYÊN (repo d:\JOB\e_recorder, đã đẩy lên https://github.com/itquanghuy85/e_recoder.git)
- Đọc TRƯỚC: docs/store/AGENT_PLAYBOOK.md (từng bước + màn hình), store/play/answers.json (mọi đáp án khai báo), store/store_config.json.
- Điền email/URL ở trên vào store/store_config.json rồi chạy powershell scripts/store/check_assets.ps1 -> phải báo OK.
- Gói ứng dụng: D:\JOB\e_recorder_release\ESR-1.0.0+1.aab  (com.huluca.escreenrecorder, versionCode 1, ký bằng khoá tải lên; bật Play App Signing).
- Văn bản cửa hàng: fastlane/metadata/android/vi-VN và en-US (title, short_description, full_description, changelogs/1.txt).
- Ảnh: icon fastlane/metadata/android/<loc>/images/icon.png, featureGraphic.png, phoneScreenshots/ (vi 8 ảnh, en 5 ảnh, tải theo thứ tự 1_ -> 8_).
- Video chứng minh quyền: store/video/permission_demo.mp4 (có hộp thoại quay, thanh thông báo, dùng app khác, thông báo xuất video).
  Video giới thiệu: store/video/promo.mp4. Play chỉ nhận link YouTube: nếu tôi chưa đăng, hãy dừng ở bước cần link và báo tôi (đừng bịa link).

VIỆC CẦN LÀM, THEO THỨ TỰ
1. Create app: tên "E Screen Recorder", mặc định vi-VN, App, Free. Cờ chính sách/luật xuất khẩu: tôi đồng ý.
2. App content (theo bảng trong AGENT_PLAYBOOK mục 4): Privacy policy, App access, Ads=No, Content rating (IARC, mọi câu No), Target audience 13+ (KHÔNG chọn dưới 13), Data safety = không thu thập/chia sẻ, News/COVID/Government/Financial/Health = không, Advertising ID = không dùng.
3. Foreground service permissions: khai báo mediaProjection, microphone, dataSync bằng văn bản trong answers.json -> permissionsDeclarations, đính video chứng minh.
4. Store settings: danh mục Tools, email/website liên hệ.
5. Main store listing vi-VN, rồi thêm en-US (Manage translations): tiêu đề, mô tả ngắn/đầy đủ, icon, feature graphic, ảnh điện thoại.
6. Internal testing: tạo bản phát hành, tải AAB, release notes từ changelogs/1.txt, thêm tester <các email tester của tôi>, Start rollout. Gửi tôi link tham gia thử nghiệm.
7. Ghi từng bước vào docs/store/PUBLISH_LOG.md, chụp bằng chứng vào artifacts/store/ (không commit).

RÀO CHẮN (tuyệt đối)
- KHÔNG nhập thông tin thanh toán/thẻ, KHÔNG xác minh danh tính, KHÔNG vượt 2FA/CAPTCHA: gặp thì dừng và báo tôi.
- KHÔNG bấm Send for review / Publish to production / Apply for production khi tôi chưa nói rõ "đăng". Dừng ở Internal testing.
- Tài khoản cá nhân mới: Production cần Closed test >= 12 tester trong 14 ngày liên tục -> chỉ nhắc tôi, đừng tự tạo tester giả.
- Không tự bịa giá trị; thiếu thì hỏi. Không sửa mã nguồn ứng dụng.
- Cuối cùng báo: mục đã xong, mục còn thiếu, cảnh báo của Console (nếu có).
```

---

## Việc chủ ứng dụng phải làm một lần (Agent không làm được)
1. **Email hỗ trợ** và **URL trang chính sách quyền riêng tư**. Repo GitHub đang riêng tư nên GitHub Pages miễn phí không chạy: chọn một trong (a) chuyển repo thành công khai rồi bật Pages (workflow `.github/workflows/pages.yml`), (b) `firebase deploy --only hosting` từ `site_dist/` (`scripts/store/build_site.ps1`), (c) tên miền riêng.
2. **Sao lưu khoá tải lên** (mất khoá = rất khó cập nhật app): `D:\JOB\_keys\esr\upload-keystore.jks` + `key.properties.backup` cùng thư mục. Chép ra 2 nơi ngoài máy. SHA-256 chứng chỉ: `02:A9:AD:B5:9E:01:73:6E:90:89:D8:01:CA:7B:36:C5:5B:5F:90:BF:A5:07:6C:F0:15:5C:6B:AD:8D:76:BE:87`.
3. Đăng 2 video lên YouTube (không công khai cho video quyền) nếu muốn dùng link.
4. Danh sách >= 12 email tester cho Closed test (yêu cầu của Google với tài khoản cá nhân mới).
