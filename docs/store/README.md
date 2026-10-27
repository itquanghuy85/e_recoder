# Đăng cửa hàng — mục lục

| Cần làm | Xem |
|---|---|
| Agent tự đăng lên Google Play | [AGENT_PLAYBOOK.md](AGENT_PLAYBOOK.md) |
| Mọi câu trả lời khai báo (Data safety, xếp hạng, quyền, FGS) | [`store/play/answers.json`](../../store/play/answers.json) |
| Thông tin cố định (email, URL, tên nhà phát triển) | [`store/store_config.json`](../../store/store_config.json) |
| Văn bản cửa hàng (vi, en) | [`fastlane/metadata/android/`](../../fastlane/metadata/android) — sửa ở `tool/gen_store_meta.py` rồi `python tool/gen_store_meta.py` |
| Trang quyền riêng tư / bảo mật / hỗ trợ | [`site/`](../../site) → `scripts/store/build_site.ps1` → GitHub Pages hoặc Firebase Hosting |
| Biểu tượng, ảnh chụp, feature graphic, video | `scripts/store/make_store_assets.ps1`, `scripts/store/make_videos.ps1`, kiểm bằng `scripts/store/check_assets.ps1` |
| Upload tự động bằng fastlane | [`fastlane/Fastfile`](../../fastlane/Fastfile) |
| App Store (Apple) | [APPSTORE_STATUS.md](APPSTORE_STATUS.md) — chưa có bản iOS |
| Nhật ký đăng | [PUBLISH_LOG.md](PUBLISH_LOG.md) |

## Quy trình ngắn (chủ ứng dụng)
1. Điền `developer.supportEmail` và (sau khi có) `site.baseUrl` trong `store/store_config.json`.
2. `powershell scripts\store\build_site.ps1` → đưa `site_dist/` lên GitHub Pages / Firebase Hosting.
3. Tạo khoá tải lên + `android/key.properties`; `flutter build appbundle --release`.
4. `powershell scripts\store\check_assets.ps1` phải in `OK`.
5. Giao `AGENT_PLAYBOOK.md` cho Agent (hoặc làm tay theo đúng bảng trong đó).

## Tái tạo tài sản khi giao diện đổi
```
powershell scripts\run_flow.ps1 store_vi -Cold            # chụp ảnh thô trên máy thật
powershell scripts\store\make_store_assets.ps1 -Collect   # khung ảnh + feature graphic
powershell scripts\store\make_videos.ps1                  # video giới thiệu + video chứng minh quyền
```
