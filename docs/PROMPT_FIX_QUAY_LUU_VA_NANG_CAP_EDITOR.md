# Prompt: sửa lỗi quay xong không lưu vào thư viện, không tự tạo đánh dấu ở chế độ quay sạch, và nâng cấp chỉnh sửa video

Tài liệu này là prompt hoàn chỉnh để giao cho một AI coding agent (hoặc người tiếp quản) trong repo `e_recorder`.
Dán toàn bộ mục **1 → 9** vào phiên làm việc. Không cần đọc thêm gì khác ngoài các file được chỉ định.

---

## 1. Vai trò và mục tiêu

Bạn là kỹ sư Flutter + Kotlin phụ trách app ghi màn hình **E Screen Recorder** (`D:\JOB\e_recorder`, package `e_screen_recorder`), chạy Android thật (máy nghiệm thu: **Galaxy S25 Ultra**), có nhánh iOS chỉ để xem trước.

Hãy thực hiện **3 việc, theo đúng thứ tự**:

1. **Sửa lỗi A**: quay xong video không xuất hiện trong thư viện của app (dù file đã có trong thư viện ảnh hệ thống), hoặc thư viện không tự cập nhật, hoặc màn kết quả không mở.
2. **Sửa lỗi B**: ở chế độ **quay sạch** (clean mode) có bật đánh dấu tự động, quay xong **không có đánh dấu nào** được tạo trong dự án chỉnh sửa.
3. **Nâng cấp chỉnh sửa video** theo backlog ưu tiên ở mục 7, giữ nguyên kiến trúc xem trước = xuất.

Không được “sửa cho hết lỗi test” bằng cách nới lỏng test. Mỗi lỗi phải có bằng chứng tái hiện trước khi sửa và bằng chứng sau khi sửa.

---

## 2. Bối cảnh kỹ thuật bắt buộc đọc

Đọc các file sau trước khi viết dòng code đầu tiên:

**Ghi âm / lưu file**
- `lib/features/record/recorder_controller.dart` — nhận sự kiện native, tạo draft tự động, kiểm tra quyền overlay.
- `lib/core/native_recorder.dart` — `RecSavedEvent`, `RecMark`, `RawTouch`, các lời gọi channel.
- `lib/features/record/record_screen.dart` — `_openSaved`, `SavedNotice`, điều hướng sang `ResultScreen`.
- `android/app/src/main/kotlin/com/huluca/escreenrecorder/RecorderService.kt` — `onStop`, `addTouch`, `addMark`, `dropTrailingTouches`.
- `android/app/src/main/kotlin/com/huluca/escreenrecorder/RecorderBus.kt` — `sink`, `emit`, `snapshot`.
- `android/app/src/main/kotlin/com/huluca/escreenrecorder/MainActivity.kt` — `EventChannel` (`onListen`, `onCancel`).
- `android/app/src/main/kotlin/com/huluca/escreenrecorder/MediaRepo.kt` — `save`, `list`, `IS_PENDING`, `RELATIVE_PATH`.
- `android/app/src/main/kotlin/com/huluca/escreenrecorder/overlay/TouchWatcher.kt` — cửa sổ 1×1 nghe chạm.

**Đánh dấu / tự dựng**
- `lib/features/marker/marker_settings.dart` — `MarkMode`, `TouchSource`, `MarkerSettings`.
- `lib/features/purpose/purpose.dart` — preset theo chế độ, `profileKeys`, `choose`, `_start`.
- `lib/features/purpose/quick_options.dart` — `MarkWhen`, `applyMarkWhen`.
- `lib/features/editor/auto_director.dart`, `lib/features/editor/touch_log.dart`.
- `test/clean_mode_test.dart`, `test/draft_resume_test.dart`, `test/purpose_test.dart`.

**Trình dựng**
- `docs/EDITOR_PRO_HANDOVER.md` và `docs/EDITOR_PRO_PLAN.md` mục 6–7 (những gì đã có, giới hạn).
- `lib/features/editor/editor_tools.dart`, `editor_pro_tools.dart`, `editor_controller.dart`, `edit_project.dart`, `project_store.dart`.
- `android/.../export/Exporter.kt` và các file `export/*.kt` liên quan.

**Quy tắc repo (bắt buộc)**
- Chạy tuần tự, **mỗi bước một commit**; không gộp 3 việc vào một commit.
- **Không thêm dependency mới**, không đổi tên khoá cài đặt cũ (`marker.*`, `rec.*`, `purpose.profile.*`).
- Giữ nguyên nguyên tắc: **một công thức toán, hai bản dịch Dart ↔ Kotlin**, khoá bằng golden test dùng chung.
- Mọi hiệu ứng phải có trong **xem trước và xuất**; không làm hiệu ứng chỉ đẹp ở xem trước.
- Có **test rollback**: bật/tắt tính năng mới không làm hỏng dự án cũ.
- Cập nhật `docs/CHANGELOG.md` và tài liệu liên quan sau mỗi mục.

**Lệnh kiểm tra**
```
flutter analyze
flutter test
cd android && ./gradlew.bat :app:testDebugUnitTest
flutter build apk --release
maestro --device <udid> test maestro/<flow>.yaml
powershell scripts/qa/verify_export.ps1
```

---

## 3. Lỗi A — quay xong không lưu vào thư viện

### 3.1. Hiện tượng cần tái hiện

Tái hiện tối thiểu 4 kịch bản, ghi lại kết quả thực tế:

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| A1 | Quay 10–20 s, bấm **Dừng trên app** | Video vào `Movies/E Screen Recorder`, mở màn kết quả, thư viện app có video ngay |
| A2 | Quay, kéo thông báo xuống, bấm **Dừng** khi app đang ở nền | Video vẫn lưu; mở lại app thấy video trong thư viện và có màn kết quả (hoặc thông báo “đã lưu”) |
| A3 | Quay, thoát app bằng Home, chờ 5 s, mở lại app | Thư viện tự làm mới, không cần kéo-refresh mới thấy video |
| A4 | Quay video dài (≥ 60 s), bấm Dừng | Màn kết quả mở sau khi MediaStore index xong; không im lặng quay về màn Quay |

Chạy lại A2/A3 ít nhất 3 lần mỗi kịch bản; ghi log `adb logcat` của `RecorderService`, `MediaRepo`, `RecorderBus`, `MainActivity`.

### 3.2. Giả thuyết gốc — phải kiểm chứng từng cái

1. **Sự kiện `saved` bị mất khi Flutter không gắn listener.**
   - `RecorderBus.emit` chỉ gọi `sink?.invoke(...)`; `sink` là `null` khi Activity/Flutter engine không ở foreground.
   - `MainActivity` khi `onListen` chỉ gửi `RecorderBus.snapshot()` (phase), **không phát lại sự kiện `saved` gần nhất**.
   - Vì vậy: file đã nằm trong MediaStore nhưng Dart không nhận `RecSavedEvent` → không `invalidate(mediaListProvider)`, không `SavedNotice`, không tạo draft tự động, không mở `ResultScreen`. Đây là nguyên nhân khớp nhất với A2/A3.

2. **Thư viện app là ảnh chụp cache, không tự làm mới theo vòng đời.**
   - `mediaListProvider` là `FutureProvider`; `library_screen.dart` chỉ refresh khi kéo hoặc khi có `invalidate` từ sự kiện.
   - Không có `WidgetsBindingObserver` / `AppLifecycleState.resumed` để refresh khi quay về app.

3. **MediaStore ghi xong nhưng dòng dữ liệu còn `IS_PENDING = 1`.**
   - `MediaRepo.save` gọi `resolver.update(..., IS_PENDING = 0)` nhưng **không kiểm tra kết quả trả về**.
   - `MediaRepo.list` lọc `IS_PENDING = 0`, nên dòng còn pending sẽ vô hình với app dù file tồn tại.
   - Nếu update ném lỗi, code xoá URI và trả `null` → người dùng chỉ thấy lỗi chung, không biết file đã mất.

4. **`_openSaved` chờ quá ngắn.**
   - Vòng lặp tối đa `8 × 400 ms = 3,2 s`; máy chậm / video 4K / thẻ nhớ chậm có thể index lâu hơn.
   - Hết vòng lặp mà không thấy entry thì **không có thông báo**, người dùng tưởng video không được lưu.

5. **Lọc thư viện quá chặt.**
   - `MediaRepo.list` lọc `RELATIVE_PATH LIKE 'Movies/E Screen Recorder%'`. Cần kiểm tra trên Samsung/Android 15–17 xem giá trị thực tế có đuôi `/`, có bị đổi thư mục, hay bị lưu vào `Movies/E Screen Recorder/` nhưng tên hiển thị bị đổi.

### 3.3. Yêu cầu sửa

**A-Fix-1 — Sự kiện lưu không được thất lạc**
- Thêm cơ chế **ghi nhớ kết quả lưu gần nhất** ở native (ví dụ `RecorderBus.lastSaved: Map<String, Any?>?` + thời điểm).
- Khi `EventChannel.onListen`, gửi snapshot **và** phát lại `lastSaved` nếu còn trong cửa sổ hợp lệ (ví dụ 24 giờ) và chưa được xác nhận.
- Thêm method channel `takeLastSaved` (hoặc cơ chế ack tương đương) để Dart lấy đúng một lần, tránh mở màn kết quả lặp lại mỗi lần resume.
- Dart: khi app resume hoặc khi `recorderProvider` khởi tạo, gọi `takeLastSaved`; nếu có thì xử lý **đúng cùng một đường** như `RecSavedEvent` (invalidate thư viện, tạo draft, hiện `SavedNotice`).

**A-Fix-2 — Thư viện tự làm mới**
- `LibraryScreen` (và màn Quay nếu đang hiển thị danh sách gần đây) lắng nghe vòng đời app; khi `resumed` thì `invalidate(mediaListProvider)`.
- Không refresh dồn dập: debounce tối thiểu 500 ms; không invalidate nếu đang ở foreground và vừa refresh < 2 s.

**A-Fix-3 — Xác minh dòng MediaStore**
- Sau khi copy, kiểm tra `update(...) > 0` và query lại URI: tồn tại, `IS_PENDING = 0`, `SIZE > 0`, `DURATION > 0` (nếu có).
- Nếu không đạt: thử `scanFile`/`MediaScannerConnection` một lần; vẫn không đạt thì trả lỗi có mã rõ ràng (`save_not_indexed`) và **giữ file** để người dùng không mất bản ghi.
- Không xoá URI khi chỉ có bước update pending thất bại; chỉ xoá khi copy thất bại hoặc file rỗng.

**A-Fix-4 — Chờ index có giới hạn và có phản hồi**
- Tăng cửa sổ chờ trong `_openSaved` theo backoff (ví dụ 0,3 → 0,6 → 1,2 → 2,4 s, tổng ~15 s), có thể dừng sớm khi thấy entry.
- Nếu hết thời gian: hiện snackbar/dialog “Đã lưu video, đang cập nhật thư viện” kèm nút **Mở thư viện** và **Thử lại**; tuyệt đối không im lặng.
- Không chặn người dùng quay tiếp.

**A-Fix-5 — Kiểm tra lọc thư viện**
- Viết test cho `MediaRepo.list` với các biến thể `RELATIVE_PATH` (có/không đuôi `/`, chữ hoa/thường) và xác nhận không bỏ sót video.
- Nếu cần, dùng thêm điều kiện `DISPLAY_NAME LIKE 'ESR_%'` **theo kiểu OR** với đường dẫn, nhưng không mở rộng đến video ngoài thư mục app.

### 3.4. Test bắt buộc cho lỗi A

**Dart**
- `RecSavedEvent` đến khi app resume → có `SavedNotice`, `mediaListProvider` bị invalidate, draft được tạo (nếu có mark/touch).
- Phát lại `lastSaved` hai lần không tạo hai màn kết quả / hai draft trùng.
- `_openSaved` hết thời gian chờ → có thông báo, không im lặng.
- Thư viện refresh đúng một lần khi resume.

**Kotlin**
- `RecorderBus` giữ `lastSaved`; `takeLastSaved` trả đúng một lần rồi xoá.
- `MediaRepo.save` trả `save_not_indexed` khi update pending thất bại; không xoá file.
- `MediaRepo.list` bao gồm bản ghi có `RELATIVE_PATH` với/không có `/`.

**Maestro trên S25**
- Flow mới `rec_save_background.yaml`: bắt đầu quay → Home → mở thông báo → Dừng → mở app → kiểm tra thư viện có video mới và màn kết quả.
- Flow `rec_save_notification.yaml`: Dừng ngay từ thông báo khi app ở nền.
- Chạy lại tối thiểu 3 lần, lưu ảnh/log vào `test-results/`.

---

## 4. Lỗi B — quay sạch không tự tạo đánh dấu

### 4.1. Hiện tượng cần tái hiện

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| B1 | Chế độ Hướng dẫn, “Đánh dấu: Tự động sau khi quay”, quay 30 s có 5 lần chạm, dừng | Video gốc sạch; mở trình sửa thấy ≥ 5 dấu đánh số đúng chỗ, có zoom theo cài đặt |
| B2 | Như B1 nhưng **chưa cấp quyền “Hiển thị trên ứng dụng khác”** | App phải xin quyền trước khi quay hoặc báo rõ; không được quay xong mới im lặng ra 0 dấu |
| B3 | Máy đã dùng phiên bản cũ (có `marker.touchSource` = manual/dots), nâng cấp lên bản mới, chọn Hướng dẫn | Cấu hình Hướng dẫn phải bật `TouchSource.auto`, không bị bản lưu cũ đè thành “không đánh dấu” |
| B4 | Quay sạch, không chạm gì, dừng | Không có dấu là đúng; nhưng phải có thông báo “Không phát hiện thao tác” + nút “Tìm thao tác lại”, không im lặng |
| B5 | Quay sạch, chạm ở vùng Android không trả toạ độ (x/y = -1) | Vẫn phải có dấu (vị trí suy luận) hoặc ít nhất caption + đánh số; không được 0 dấu khi có chạm |

### 4.2. Giả thuyết gốc — phải kiểm chứng từng cái

1. **Thiếu quyền overlay nhưng không kiểm tra.**
   `RecorderController.start()` chỉ kiểm tra `canOverlay()` khi `floatingBar` hoặc `countdown > 0`:
   ```dart
   if ((floatingBar || countdown > 0) && !await _native.canOverlay()) { ... }
   ```
   Trong khi `TouchWatcher` là `TYPE_APPLICATION_OVERLAY`; thiếu quyền thì `addView` ném lỗi, `show()` chỉ log warning và **nuốt lỗi**. Kết quả: `watchTouches = true` nhưng không nghe được chạm nào → 0 dấu.

2. **`_saveDraft` chỉ chạy khi có mark hoặc touch.**
   ```dart
   if (e.marks.isNotEmpty || e.touches.isNotEmpty) { draftReady = _saveDraft(e); }
   ```
   Nếu native không gửi touch (do (1), do app bị kill, do profile cũ), **không có dự án nào được tạo**, không có thông báo.

3. **`_buildFromTouches` bỏ qua khi `heard.isEmpty`.**
   ```dart
   if (heard.isEmpty) return;
   ```
   Trước đó draft cơ sở đã được lưu, nhưng không có dấu. Người dùng thấy video “sạch trơn”.

4. **`events.isEmpty` giữ nguyên draft không dấu.**
   ```dart
   final events = TouchClassifier.classify(placed);
   if (events.isNotEmpty) { ... save(auto); }
   ```
   Nếu classifier loại hết (chạm quá gần nhau, không xác định được vị trí, typing merge…), không có dấu và cũng không có thông báo.

5. **`locateTouches` trả x/y = null.**
   `TouchScan.locate` không tìm được vị trí → `TouchClassifier` có thể chỉ tạo caption/freeze, không tạo marker (test hiện tại khẳng định đúng hành vi này: “moments without places give captions and freezes, no marks”). Với người dùng, “có chạm mà không có dấu” = lỗi.

6. **Cấu hình cũ/migration theo chế độ.**
   `PurposeNotifier.choose` khôi phục bản lưu `purpose.profile.<mode>` nếu đã có. Người dùng nâng cấp từ bản trước có thể có bản lưu Hướng dẫn với `marker.touchSource` = off/manual/dots. `applyPurposeToMarkers` **không được áp dụng** khi bản lưu đã tồn tại → quay sạch nhưng không nghe chạm.

7. **`watchTouches` phụ thuộc đúng một tổ hợp cài đặt.**
   `watchTouches = mk.mode == MarkMode.clean && mk.touchSource == TouchSource.auto`. Nếu UI “Đánh dấu: Tự động” nhưng `mode` hoặc `touchSource` lệch (do lưu/khôi phục), native không nghe chạm.

8. **Cửa sổ loại bỏ chạm cuối quá tay.**
   `dropTrailingTouches()` xoá mọi chạm trong 1,5 s trước khi app quay lại foreground; cộng với `stopTapWindowMs = 1200` khi lọc. Nếu người dùng thao tác sát lúc dừng, một bước hợp lệ có thể bị mất. Cần kiểm tra nhưng **không nới rộng đến mức tính cả nút Dừng**.

### 4.3. Yêu cầu sửa

**B-Fix-1 — Kiểm tra quyền trước khi quay**
- Trong `RecorderController.start()`, điều kiện cần overlay phải bao gồm:
  `floatingBar || countdown > 0 || (mk.mode == MarkMode.clean && mk.touchSource == TouchSource.auto)`.
- Nếu thiếu quyền: trả `StartResult.needsOverlay` và UI giải thích **vì sao** (cần để nghe thao tác), có nút mở Cài đặt.
- Không được bắt đầu quay ở chế độ “tự động tạo dấu” khi biết chắc sẽ không nghe được chạm.

**B-Fix-2 — Không bao giờ im lặng**
- Luôn tạo dự án sau khi quay sạch có bật tự động, kể cả 0 chạm. Dự án cơ sở + trạng thái “chưa có dấu”.
- `ResultScreen`/editor hiển thị kết quả tự động: “Đã tạo N dấu”, “Không nghe được thao tác”, “Đã nghe N chạm nhưng chưa xác định được vị trí”.
- Có nút **Tìm thao tác lại** (gọi `locateTouches`/`scanTouches` lại) và **Tự dựng lại** (AutoDirector).
- Ghi log có cấu trúc: số touch native gửi, số hear sau lọc, số locate được, số event sau classify, số marker tạo ra.

**B-Fix-3 — Luôn có dấu cho mỗi chạm hợp lệ**
Định nghĩa “hợp lệ”: touch không nằm trong `stopTapWindowMs` cuối và không bị `dropTrailingTouches`.
- Nếu `locateTouches` trả vị trí: đặt dấu tại đúng vị trí (như hiện tại).
- Nếu không có vị trí:
  - Thử `scanTouches` chế độ `changes` để tìm điểm thay đổi hình ảnh gần thời điểm đó; nếu có, dùng tâm vùng thay đổi.
  - Nếu vẫn không có: đặt dấu tại **tâm vùng nội dung** hoặc vị trí chạm gần nhất đã biết, đánh dấu `sensitive = false`, và gắn nhãn “vị trí ước lượng” trong inspector (không cần lộ ra video).
- Không biến chạm thành caption thay thế dấu, trừ khi người dùng chọn “chỉ chú thích”. Caption có thể có thêm, nhưng dấu là bắt buộc.
- Giữ nguyên quy tắc: hai chạm < 0,3 s gộp một dấu; gõ phím liên tục gộp thành một bước “Đang nhập/Đã nhập”.

**B-Fix-4 — Khôi phục cấu hình đúng cho người dùng cũ**
- Khi khôi phục `purpose.profile.tutorial` (hoặc bất kỳ profile nào) từ bản lưu cũ, chuẩn hoá:
  - Nếu profile là Hướng dẫn và giá trị `marker.mode` là clean nhưng `marker.touchSource` là off/manual/dots do phiên bản cũ, nâng lên `auto` **một lần**, có cờ migration riêng.
  - Không đụng đến lựa chọn “Không đánh dấu” mà người dùng cố ý chọn (phân biệt bằng `MarkWhen.none` / `mode=clean, touchSource=off` được lưu sau bản mới).
- Viết test migration với các tổ hợp prefs cũ.

**B-Fix-5 — Bền vững khi app bị kill**
- `_pendingKey = 'draft.pending'` đã có; mở rộng để lưu cả **danh sách touch** và **trạng thái đã tạo dấu hay chưa**, không chỉ khi bắt đầu build.
- Khi app khởi động lại, `resumeDraft` phải chạy lại cả trường hợp dự án đã có nhưng 0 dấu và còn touch chưa xử lý.
- Giới hạn số lần thử (`tries`) như hiện tại, nhưng khi bỏ cuộc phải ghi log + hiện thông báo trong editor, không xoá im lặng.

### 4.4. Test bắt buộc cho lỗi B

**Dart (mở rộng `test/clean_mode_test.dart`, `test/draft_resume_test.dart`, `test/purpose_test.dart`)**
- Clean + auto + thiếu overlay → `start()` trả `needsOverlay`, không gọi native `start`.
- Clean + auto + 0 touch → vẫn có project cơ sở + thông báo “không phát hiện thao tác”.
- Có touch nhưng `locateTouches` không trả vị trí → vẫn có marker (vị trí ước lượng/fallback), số marker = số touch hợp lệ sau gộp.
- Touch toàn bộ nằm trong cửa sổ nút Dừng → 0 marker (đúng).
- Migration profile cũ: `marker.mode=clean`, `marker.touchSource=manual` → thành `auto`; nhưng `touchSource=off` do người dùng chọn “Không đánh dấu” thì giữ nguyên.
- Resume khi dự án tồn tại nhưng 0 marker và còn pending touch → hoàn tất và có marker.

**Kotlin**
- `TouchWatcher` khi thiếu quyền phải báo lỗi rõ ràng (callback/`Result`), không chỉ `Log.w`.
- `TouchScan.locate` với các mốc không tìm được vị trí trả cấu trúc phân biệt “không thấy” và “thấy nhưng không có toạ độ”.

**Maestro trên S25**
- `clean_auto_marks.yaml`: Hướng dẫn → tự động → quay một màn có 4–5 thao tác → dừng → mở editor → đếm dấu trên timeline/inspector.
- `clean_auto_no_overlay.yaml`: thu hồi quyền overlay → bấm quay → thấy hộp xin quyền/giải thích, không bắt đầu quay.
- `clean_auto_background_stop.yaml`: dừng từ thông báo khi app ở nền → vẫn có dấu.

---

## 5. Ràng buộc chung khi sửa hai lỗi

- Không thay đổi hành vi của chế độ **dấu nhỏ (dot)**: dấu vẽ trực tiếp lên video như hiện tại.
- Video gốc của chế độ sạch **phải tiếp tục sạch tuyệt đối** (không dấu, không overlay, không corner).
- Không tăng thời gian lưu video quá 10% so với hiện tại trên cùng máy/cùng video.
- Không làm mất dự án đã chỉnh sửa khi tạo lại draft: nếu project đã có thay đổi của người dùng, không ghi đè; chỉ tạo draft khi project chưa tồn tại hoặc đang rỗng.
- Mọi thông báo mới phải có bản dịch **vi + en** trong `lib/l10n/` (không hard-code).

---

## 6. Nâng cấp chỉnh sửa video — nguyên tắc

Đã có (không làm lại): cắt/tách/nhân đôi/nam châm, tốc độ hằng + ramp + chạy ngược, chuyển cảnh, âm lượng/fade/nhạc/giọng/ducking/chuẩn hoá, xoay/cắt/tỉ lệ/màu, marker + zoom + cover + chữ + hình + ảnh + PiP, caption, template, xuất nền/GIF/khung hình, export preset.

Mỗi nâng cấp phải:
- Có trong **xem trước và xuất** (Dart ↔ Kotlin), hoặc nói rõ là “chỉ UI, không ảnh hưởng video”.
- Có **undo một bước** cho thao tác tự động.
- Không thêm dependency.
- Có test model + test widget; nếu là toán/hiệu ứng thì thêm golden test dùng chung.
- Có flow Maestro hoặc test thiết bị thật.

---

## 7. Backlog nâng cấp — làm theo thứ tự ưu tiên

### P1. “Duyệt dấu tự động” (bắt buộc, đi kèm lỗi B)

**Vấn đề:** tự dựng xong, người dùng không biết dấu nào đúng/sai; muốn sửa phải mò trên timeline.

**Làm:**
- Thêm màn/panel **“Dấu tự động”** trong editor (tab Dấu hoặc tab Tự động):
  - Danh sách từng dấu: thời gian, ảnh thu nhỏ khung hình tại mốc, loại dấu, độ tin cậy (cao/thấp).
  - Bật/tắt từng dấu, đổi loại (số/chấm/mũi tên), đổi màu/độ dày hàng loạt (tái dùng `_MarkerBatch`).
  - Nút **“Tìm lại vị trí”** cho các dấu độ tin cậy thấp; nút **“Xoá dấu không tin cậy”**.
  - “Chấp nhận tất cả” / “Hoàn tác toàn bộ lần tự dựng” (một bước undo).
- Hiển thị số lượng: “Nghe 12 chạm · đặt được 9 dấu · 3 vị trí ước lượng”.
- Lưu `confidence`/`source` vào `MarkerItem` dưới dạng field optional, **tương thích JSON cũ** (mặc định cao/không có).

**File dự kiến:** `edit_project.dart`, `auto_director.dart`, `touch_log.dart`, `editor_controller.dart`, `editor_tools.dart`, `marker_inspector.dart`, `lib/l10n/*`.

**Nghiệm thu:** quay sạch 10 chạm, 2 chạm không có toạ độ → panel hiện 10 dấu, 2 dấu đánh dấu “ước lượng”; tắt 2 dấu → timeline cập nhật ngay; undo trả lại đủ.

### P1. “Cắt khoảng lặng / đoạn không đổi” một chạm

**Vấn đề:** `IdleAnalyzer` đã có nhưng chỉ dùng trong “Tự dựng”; người dùng không kiểm soát được.

**Làm:**
- Nút **“Cắt khoảng lặng”** trong tab Cắt hoặc Tự động:
  - Thanh trượt ngưỡng im lặng (0,5–3 s), tốc độ phát lại phần giữ (1× hoặc tua nhanh 2–8×), có/không giữ 200 ms đệm hai đầu.
  - Xem trước danh sách đoạn sẽ cắt (thời gian, độ dài), bật/tắt từng đoạn.
  - Áp dụng một bước undo; không cắt nếu kết quả < 1 s hoặc cắt quá 80% video (cảnh báo).
- Toán cắt dùng chung Dart/Kotlin, golden test.

**Nghiệm thu:** video 30 s có 3 khoảng lặng 5 s → cắt còn ~15 s; xuất đúng độ dài; preview khớp.

### P2. “Lịch sử chỉnh sửa” có thể xem lại

**Vấn đề:** undo 60 bước nhưng không biết đã làm gì.

**Làm:**
- Panel lịch sử (bottom sheet): danh sách thao tác có nhãn người đọc được (“Xoá 3 dấu”, “Đổi tốc độ đoạn 2”, “Tự dựng lại”).
- Nhảy tới một mốc (undo/redo nhiều bước), ghim mốc để không bị dọn.
- Chỉ UI + controller; không ảnh hưởng export.

### P2. “Preset xuất của tôi”

**Vấn đề:** `export_presets.dart` có 5 preset cố định; người dùng lặp lại cùng thiết lập.

**Làm:**
- Lưu preset tự đặt: tên, tỉ lệ, độ phân giải, fps, bitrate/quality, ước lượng dung lượng.
- Sửa/xoá/nhân bản; đặt mặc định cho lần xuất sau.
- Giữ tương thích `ExportPreset` cũ; preset tự đặt là danh sách riêng trong `SettingsStore`.
- Có test planner cho preset tự đặt (không vượt `maxVideoBitrate`).

### P2. “Chuyển cảnh có ảnh xem trước”

**Vấn đề:** chọn chuyển cảnh bằng tên, khó hình dung.

**Làm:**
- Mỗi lựa chọn chuyển cảnh có ảnh động ngắn 0,6 s dựng từ 2 khung hình của chính clip (dùng renderer sẵn có, không thêm dependency).
- Chỉ hiển thị khi đủ dữ liệu; nếu không, dùng icon tĩnh.
- Không thay đổi công thức chuyển cảnh hiện tại.

### P3. “Chú thích theo từ khi đọc” (nếu còn thời gian)

**Vấn đề:** caption hiện hiển thị cả câu; video hướng dẫn cần làm nổi bật từ đang nói.

**Làm:**
- Thêm kiểu caption `karaoke`/`word-highlight` dùng timing từng từ đã có trong `CaptionCue` (nếu chưa có thì tách theo tỉ lệ thời lượng, ghi rõ là ước lượng).
- Renderer Dart + Kotlin cùng công thức; golden test.

> Không làm trong đợt này: làm nét, chuyển cảnh “nước”, nền màu khác viền đen, hiệu ứng cần shader hai khung — lý do đã ghi trong `EDITOR_PRO_HANDOVER.md`.

---

## 8. Thứ tự thực hiện và commit

1. `fix(record): replay the saved event and refresh the library on resume` (A-Fix-1, A-Fix-2)
2. `fix(record): verify MediaStore row and never drop the file on index failure` (A-Fix-3, A-Fix-5)
3. `fix(record): wait longer for the media index and tell the user` (A-Fix-4)
4. `fix(marker): require overlay for automatic clean marks` (B-Fix-1)
5. `fix(marker): always build marks for heard touches, with fallback places` (B-Fix-2, B-Fix-3)
6. `fix(marker): migrate old tutorial profiles to automatic touch listening` (B-Fix-4)
7. `fix(marker): resume unfinished mark building after a kill` (B-Fix-5)
8. `feat(editor): review panel for automatic marks` (P1)
9. `feat(editor): one-tap silence cut with preview` (P1)
10. `feat(editor): readable edit history` (P2)
11. `feat(editor): custom export presets` (P2)
12. `feat(editor): animated transition previews` (P2)
13. `docs: changelog, test results, known limits`

Mỗi commit phải tự chứa: code + test + docs liên quan, và **pass toàn bộ lệnh kiểm tra** trước khi sang commit sau.

---

## 9. Định nghĩa hoàn thành (Definition of Done)

- [ ] Tái hiện được lỗi A và B trước khi sửa; lưu log/ảnh vào `test-results/`.
- [ ] A1–A4 đều đạt, chạy 3 lần mỗi kịch bản.
- [ ] B1–B5 đều đạt, gồm cả thiếu quyền overlay và profile cũ.
- [ ] Video quay sạch vẫn không có dấu nào bị “đốt” vào file gốc.
- [ ] Không có sự kiện lưu nào bị mất khi app ở nền/bị kill; không mở màn kết quả lặp.
- [ ] `flutter analyze` sạch; `flutter test` xanh; `:app:testDebugUnitTest` xanh.
- [ ] `flutter build apk --release` thành công, APK không tăng quá 5%.
- [ ] Maestro: các flow cũ liên quan (record, clean, editor, export) vẫn PASS; flow mới PASS trên S25.
- [ ] Xuất thử một video có dấu tự động: `verify_export.ps1` xác nhận đúng số dấu/độ dài/độ phân giải.
- [ ] `docs/CHANGELOG.md`, `docs/PLAN_CHE_DO_QUAY.md` (nếu đổi hành vi dấu), `docs/EDITOR_PRO_PLAN.md` (nếu thêm tính năng) được cập nhật.
- [ ] Báo cáo cuối: nguyên nhân gốc từng lỗi, cách sửa, bằng chứng, rủi ro còn lại, việc chưa làm.

---

## 10. Mẫu báo cáo cuối

```
## Kết quả

### Lỗi A — lưu vào thư viện
- Nguyên nhân gốc: ...
- Sửa: ...
- Bằng chứng: A1..A4 (log/ảnh), test ...
- Rủi ro: ...

### Lỗi B — đánh dấu tự động
- Nguyên nhân gốc: ...
- Sửa: ...
- Bằng chứng: B1..B5, số dấu thực tế ...
- Rủi ro: ...

### Nâng cấp editor
| Mục | Trạng thái | Bằng chứng |
...

### Lệnh đã chạy
...
```
