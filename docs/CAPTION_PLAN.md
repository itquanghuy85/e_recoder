# CAPTION PLAN

## Phần 3 — Dữ liệu Phase 0

### Test deps

- `org.robolectric:robolectric:4.16.1` — **ĐÃ DUYỆT** cho unit test Bitmap/Canvas của
  `OverlayRenderers.renderCue`. Chỉ khai báo ở `testImplementation` (test-only, không vào APK).
  Dùng `@RunWith(RobolectricTestRunner::class)` + `@GraphicsMode(NATIVE)` để `Paint.measureText`
  và `Bitmap` chạy thật trên JVM.
