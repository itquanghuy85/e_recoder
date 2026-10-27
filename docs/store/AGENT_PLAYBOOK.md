# Playbook cho AI Agent: đăng E Screen Recorder lên Google Play (và chuẩn bị App Store)

Tài liệu này dành cho một AI Agent có trình duyệt (computer-use / Playwright / Claude in Chrome) hoặc dòng lệnh. Làm theo thứ tự. **Nguồn dữ liệu duy nhất:** `store/store_config.json`, `store/play/answers.json`, `fastlane/metadata/**`, `store/` (ảnh, video). Không tự bịa giá trị; thiếu thì dừng và hỏi chủ ứng dụng.

> Agent KHÔNG được: nhập thông tin thanh toán / thẻ, chấp nhận điều khoản pháp lý thay chủ tài khoản, vượt xác thực 2 bước, tạo tài khoản nhà phát triển, hoặc bấm **Send for review / Publish to production** khi chủ chưa nói rõ "đăng". Dừng và báo khi gặp CAPTCHA, 2FA, yêu cầu xác minh danh tính, hoặc cảnh báo chính sách.

## 0. Điều kiện cần (chủ ứng dụng làm một lần)
| # | Việc | Kiểm tra |
|---|---|---|
| 1 | Tài khoản Google Play Console (đã xác minh) | Đăng nhập được https://play.google.com/console |
| 2 | `store/store_config.json`: điền `developer.supportEmail`, `site.baseUrl` | Không còn chuỗi rỗng |
| 3 | Khoá tải lên + `android/key.properties` (xem `docs/PLAY_STORE.md` mục 1) | `flutter build appbundle --release` ra file ký bằng khoá riêng |
| 4 | Trang chính sách đã online | `curl -I <baseUrl>/vi/privacy.html` trả 200 (xem mục 1) |
| 5 | Ảnh/video đã tạo | `scripts/store/check_assets.ps1` báo `OK` (mục 2) |

## 1. Đưa trang quyền riêng tư & bảo mật lên mạng
Nguồn: `site/` (vi + en, không gọi tài nguyên bên ngoài). Chọn MỘT cách:
- **GitHub Pages** (khuyên dùng, miễn phí): đẩy repo lên GitHub, Settings → Pages → Source = *GitHub Actions*; workflow `.github/workflows/pages.yml` tự chạy `scripts/store/build_site.ps1` và triển khai. URL: `https://<user>.github.io/<repo>/`.
- **Firebase Hosting**: `powershell scripts/store/build_site.ps1` rồi `firebase deploy --only hosting` (cấu hình `firebase.json`, thư mục `site_dist`).
- **Tên miền riêng** (ví dụ huluca.com): trỏ về một trong hai nơi trên.

Sau khi online: ghi URL gốc vào `site.baseUrl` rồi dùng:
- Chính sách quyền riêng tư (dán vào Play Console): `<baseUrl>/vi/privacy.html` (bản tiếng Anh: `/en/privacy.html`)
- Bảo mật: `<baseUrl>/vi/security.html` · Hỗ trợ: `<baseUrl>/vi/support.html`

Kiểm tra: mở 4 trang, không còn `{{...}}`, link email mở được, chạy được trên điện thoại.

## 2. Chuẩn bị tài sản cửa hàng
```
powershell scripts/store/make_store_assets.ps1      # khung ảnh chụp, feature graphic, ảnh tablet
powershell scripts/store/check_assets.ps1           # kiểm kích thước/định dạng theo yêu cầu Google
```
Kết quả nằm trong `fastlane/metadata/android/<locale>/images/` và `store/`:
| Tài sản | Yêu cầu Google Play | File |
|---|---|---|
| Biểu tượng | PNG 512×512, ≤1 MB | `store/icon_512.png` → `images/icon.png` |
| Feature graphic | PNG/JPG 1024×500 | `images/featureGraphic.png` |
| Ảnh điện thoại | 2–8 ảnh, cạnh 320–3840 px, tỉ lệ ≤2:1 | `images/phoneScreenshots/*.png` (1080×1920; vi 8 ảnh gồm trình dựng nâng cao, en 5 ảnh) |
| Ảnh tablet 7"/10" | tuỳ chọn, nên có | `images/sevenInchScreenshots`, `tenInchScreenshots` |
| Video giới thiệu | link YouTube (không tải file lên Play) | `store/video/promo.mp4` → tự đăng YouTube, dán link vào `video.txt` |
| Video chứng minh quyền | cho khai báo FGS/mediaProjection | `store/video/permission_demo.mp4` (đăng YouTube chế độ *Không công khai*, dán link vào form) |

## 3. Tạo ứng dụng (một lần)
Play Console → **Create app**.
- App name: `E Screen Recorder` · Default language: `Vietnamese – vi-VN`
- App or game: **App** · Free or paid: **Free**
- Tick: Developer Program Policies, US export laws (chủ ứng dụng đã đồng ý trước; nếu chưa → dừng và hỏi).
- Package name được cố định bởi bản AAB đầu tiên: `com.huluca.escreenrecorder` (**không đổi được**).

## 4. Điền "Set up your app" (Dashboard → các việc cần làm)
Giá trị lấy từ `store/play/answers.json`. Trình tự và đáp án:

| Mục (menu: Policy and programs → App content) | Điền |
|---|---|
| **Privacy policy** | URL `…/vi/privacy.html` |
| **App access** | *All functionality is available without special access* |
| **Ads** | *No, my app does not contain ads* |
| **Content rating** | Bắt đầu bảng câu hỏi IARC; email = `supportEmail`; Category = *Utility, Productivity, Communication, or Other*; trả lời **No** mọi câu (bạo lực, tình dục, ngôn ngữ, ma tuý, cờ bạc, nội dung người dùng tạo/chia sẻ, vị trí, mua kỹ thuật số). Kết quả kỳ vọng: Everyone / 3+ |
| **Target audience and content** | Nhóm tuổi: 13–15, 16–17, 18+. **Không** chọn nhóm dưới 13. "Appeals to children": **No** |
| **Data safety** | "Does your app collect or share any of the required user data types?" → **No**. Xem lại tóm tắt: *No data collected, No data shared*. Policy URL như trên |
| **Government apps** | No · **Financial features** | None · **Health** | None (nếu có mục) |
| **News apps / COVID-19** | Not a news app / No |
| **Foreground service permissions** | Khai báo 3 loại: `mediaProjection`, `microphone` và `dataSync` (xuất video, có thông báo + nút Huỷ; video chứng minh đã có đoạn thông báo xuất). Dùng văn bản trong `answers.json → permissionsDeclarations`. Đính kèm link YouTube của `permission_demo.mp4`. Quan trọng: nói rõ có thông báo hiển thị suốt lúc quay và người dùng bấm bắt đầu |
| **Advertising ID** | App does not use it |

Mục **Store settings** (menu Grow users → Store presence → Store settings):
- App category: **Tools** · Tags: Screen recorder, Video editor (chọn tối đa theo gợi ý của Google)
- Contact details: email = `supportEmail`, website = `site.baseUrl`, phone tuỳ chọn.

## 5. Store listing (Grow users → Store presence → Main store listing)
Ngôn ngữ mặc định `vi-VN`, sau đó **Manage translations → Add** `en-US`.
- **App name**: `fastlane/metadata/android/<loc>/title.txt`
- **Short description**: `short_description.txt` (≤80 ký tự)
- **Full description**: `full_description.txt` (≤4000 ký tự), giữ xuống dòng
- **App icon**: `images/icon.png` · **Feature graphic**: `images/featureGraphic.png`
- **Phone screenshots**: tải đủ ảnh theo thứ tự tên file `1_…png` → `8_…png`
- **Promo video**: link YouTube từ `video.txt` (bỏ qua nếu chưa có)

Cách nhanh hơn cho phần này: `fastlane android listing` (cần `SUPPLY_JSON_KEY`, xem `fastlane/Appfile`). Chỉ dùng khi chủ đã tạo service account (Play Console → Setup → API access).

## 6. Bản phát hành
1. Build: `flutter build appbundle --release` (nhớ tăng `version:` trong `pubspec.yaml`, versionCode luôn tăng).
2. **Internal testing** (Testing → Internal testing → Create new release): tải `app-release.aab`, bật **Play App Signing** (lần đầu), release notes lấy từ `changelogs/1.txt` cho từng ngôn ngữ (định dạng `<vi-VN>…</vi-VN>` nếu console đòi). Thêm danh sách tester (email) → Save → Review release → Start rollout.
3. Console có thể báo cảnh báo; đọc và xử lý theo bảng mục 8. Chỉ sang bước sau khi Internal testing hết lỗi.
4. **Closed testing** (bắt buộc với tài khoản cá nhân mới: ≥12 tester tham gia liên tục 14 ngày) rồi mới *Apply for production*. Ghi lại ngày bắt đầu.
5. **Production**: Create release → dùng lại AAB đã test → *Staged rollout* 20% → xem Android vitals vài ngày → 100%.
6. **Send for review**: chỉ khi chủ đã nói "đăng". Thời gian duyệt từ vài giờ đến vài ngày.

Ghi chú gửi Google (App content → hoặc ô "Notes for review" nếu có): lấy `answers.json → reviewNotesToGoogle`.

## 7. Kiểm tra sau khi đăng
- Tìm app theo package trên Play Store; mở trang: icon, ảnh, mô tả đúng ngôn ngữ.
- Cài từ Play trên một máy sạch: onboarding → cấp quyền → quay thử → xuất.
- Play Console → Quality → Android vitals: crash/ANR = 0 trong 24 giờ đầu; nếu không, dừng rollout.

## 8. Cảnh báo thường gặp và cách xử lý
| Cảnh báo | Xử lý |
|---|---|
| "Your app uses foreground service type mediaProjection – declare" | Làm mục 4, đính kèm video đúng yêu cầu: bấm quay → hộp thoại hệ thống → thông báo → dùng app khác → dừng |
| "Privacy policy URL can't be loaded / not an active page" | Kiểm tra trang online, không chuyển hướng lạ, không PDF, có tên app và email |
| "Data safety form doesn't match" (do quét phát hiện thư viện) | Chạy `aapt2 dump permissions`; ứng dụng không có INTERNET. Nếu thêm SDK → cập nhật `answers.json` và form |
| "Target API level" | `targetSdk` hiện 36; luôn theo yêu cầu mới nhất của Google khi build |
| "64-bit / 16 KB page size" | Dùng Flutter/AGP mới nhất khi build AAB; kiểm tra bằng Play Console pre-launch report |
| Từ chối vì "Intent: screen recording must be user-initiated and visible" | Nhấn mạnh trong ghi chú: người dùng tự bấm bắt đầu, thông báo hiện suốt phiên quay, dừng được từ thông báo |

## 9. App Store (Apple) — hiện CHƯA có bản iOS
E Screen Recorder là ứng dụng Android gốc (MediaProjection, lớp phủ, Media3). iOS cần viết lại phần quay bằng ReplayKit (quay toàn hệ thống qua Broadcast Upload Extension, không có lớp phủ, không dấu "báo trước" lúc quay) — xem `docs/store/APPSTORE_STATUS.md`. Metadata và biểu tượng 1024 đã chuẩn bị sẵn (`fastlane/metadata/ios/**`, `store/ios_icon_1024.png`) để dùng ngay khi có bản iOS. Agent KHÔNG đăng gì lên App Store trong giai đoạn này.

## 10. Nhật ký
Sau mỗi bước, ghi ngày giờ + ảnh chụp màn hình bằng chứng vào `artifacts/store/` (không commit) và cập nhật `docs/store/PUBLISH_LOG.md`.
