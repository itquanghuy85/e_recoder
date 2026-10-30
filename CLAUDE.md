# CLAUDE.md
Repo e_recoder — Android screen recorder (Flutter + Kotlin native). Tính năng Auto Caption.
Đọc docs/CAPTION_PLAN.md trước mỗi phiên.
Commands: flutter analyze | flutter test | ./gradlew :app:testDebugUnitTest | ./gradlew :app:assembleDebug | adb devices | maestro --device <udid> test maestro/*.yaml
Thiết bị test nghiệm thu: Galaxy S25 Ultra.
Rules: chạy tuần tự, commit từng bước, không tự thêm dep, không đổi tên cũ, rollback test bắt buộc, native render chung.
