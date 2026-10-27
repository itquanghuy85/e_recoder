# Writes the store listing texts in the layout fastlane `supply` (Google Play) and `deliver` (App Store) read.
# Edit the texts here, run `python tool/gen_store_meta.py`, commit the output.
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ANDROID = {
    'vi-VN': {
        'title': 'E Screen Recorder',
        'short': 'Quay màn hình có dấu báo trước chỗ sắp bấm, chỉnh sửa ngay trên máy.',
        'full': """Quay video hướng dẫn mà người xem luôn biết bạn sắp bấm vào đâu.

E Screen Recorder là ứng dụng quay màn hình miễn phí, không quảng cáo, làm một việc mà các ứng dụng khác bỏ qua: cho người xem thấy chỗ bạn sắp chạm TRƯỚC khi màn hình đổi.

DẤU BÁO TRƯỚC, ĐẸP NHƯ HIỆU ỨNG NƯỚC
• Ngón tay, chạm kiểu giọt nước, mũi tên, vòng tròn, khung, bút và số bước.
• Dấu có gradient và chuyển động: sóng lan, dải sáng chảy, mũi tên gật về phía đích.
• Vòng vàng thu vào đích trước khi dấu hiện rõ, rồi mới tới lúc bấm.
• Chọn màu, độ dày; phóng to, thu nhỏ, xoay dấu trong trình chỉnh sửa.

HAI CÁCH ĐÁNH DẤU KHI QUAY
• Chấm nhỏ ở góc: chọn dấu trước, khi quay chỉ còn một chấm. Bấm chấm, chạm chỗ sắp bấm, rồi bấm thật.
• Quay sạch, dựng sau: không có gì chen vào video. Chạm vùng ẩn ở góc (máy rung nhẹ), chạm chỗ sắp bấm, bấm thật. Dấu được vẽ đẹp trong trình chỉnh sửa.

CHỈNH SỬA NGAY TRÊN MÁY
• Cắt, tách, xoá, nhân đôi, kéo đổi thứ tự đoạn; đóng băng khung, chèn đoạn trống.
• Tốc độ từ 0,25× đến 8×, tua nhanh dần (ramp), chạy ngược đoạn ngắn.
• Chuyển cảnh: mờ qua đen/trắng, trượt, phóng.
• Nhạc nền từ file của bạn, thu giọng nói, tự hạ nhạc khi có giọng.
• Xoay, cắt khung, đổi tỉ lệ, chỉnh màu; chèn chữ, hình vẽ, ảnh, hình-trong-hình.
• Thêm chữ, khối che thông tin nhạy cảm, phóng to vào vùng quan trọng.
• Dựng tự động: tự phóng to vào chỗ đánh dấu, đánh số lại các bước, tua nhanh đoạn màn hình đứng yên.
• Hoàn tác không giới hạn, dự án tự lưu.
• Xuất MP4 (gốc, 1080p, 720p, 480p) hoặc GIF, chia sẻ ngay.

QUAY ỔN ĐỊNH
• 720p, 1080p hoặc gốc; 30 hoặc 60 fps.
• Quay có tiếng micro hoặc âm thanh trong máy (Android 10 trở lên).
• Đếm ngược, tạm dừng, tiếp tục; điều khiển bằng thông báo.
• Giao diện sáng và tối, tiếng Việt và tiếng Anh.

RIÊNG TƯ TUYỆT ĐỐI
• Không tài khoản, không quảng cáo, không thu thập dữ liệu.
• Ứng dụng không xin quyền Internet: video ở lại trên máy của bạn.

Lưu ý: nội dung được bảo vệ bản quyền hoặc màn hình ứng dụng ngân hàng sẽ hiện màu đen trong video, đây là cơ chế bảo vệ của Android.""",
        'changelog': 'Phiên bản đầu tiên: quay màn hình có dấu báo trước, hai cách đánh dấu, trình chỉnh sửa và dựng tự động, xuất MP4/GIF.',
    },
    'en-US': {
        'title': 'E Screen Recorder',
        'short': 'Screen recorder that shows where you are about to tap. Edit on device.',
        'full': """Record tutorial videos where viewers always know where you are about to tap.

E Screen Recorder is a free screen recorder with no ads that does what other recorders skip: it shows viewers where you are about to touch BEFORE the screen changes.

POINT-AHEAD MARKERS WITH A WATER-LIKE LOOK
• Finger, water-drop tap, arrow, circle, box, pen and step numbers.
• Gradients and motion: spreading ripples, flowing shine, an arrow that nods toward the target.
• An amber ring closes in on the target before the marker appears, then the tap happens.
• Pick colour and thickness; scale, rotate and recolour markers in the editor.

TWO WAYS TO MARK WHILE RECORDING
• Small corner dot: choose the marker beforehand and only a dot stays on screen. Tap the dot, touch where you are about to press, then press for real.
• Record clean, edit later: nothing on screen. Touch the hidden corner (the phone buzzes), touch where you are about to press, press for real. Markers are drawn beautifully in the editor.

EDIT ON YOUR PHONE
• Cut, split, delete, duplicate and reorder clips; freeze frames and blank gaps.
• Speed from 0.25× to 8×, gradual speed ramps, reverse short clips.
• Transitions: dip to black/white, slide, zoom.
• Background music from your own files, voice-over, music ducks automatically under your voice.
• Rotate, crop, change aspect ratio, colour looks; add text, shapes, images and picture-in-picture.
• Add text, cover sensitive info, zoom into what matters.
• Auto direct: zooms into your markers, renumbers the steps, speeds up stretches where the screen does not change.
• Unlimited undo, projects save automatically.
• Export MP4 (original, 1080p, 720p, 480p) or GIF and share instantly.

RELIABLE RECORDING
• 720p, 1080p or native; 30 or 60 fps.
• Record with the microphone or device audio (Android 10+).
• Countdown, pause, resume; control from the notification.
• Light and dark themes, Vietnamese and English.

PRIVATE BY DESIGN
• No account, no ads, no data collection.
• The app does not request the Internet permission: your videos stay on your phone.

Note: copy-protected content and banking apps appear black in recordings; that is Android's protection at work.""",
        'changelog': 'First release: point-ahead markers, two ways to mark, on-device editor with auto direct, MP4/GIF export.',
    },
}

APPSTORE = {
    'vi': {
        'name': 'E Screen Recorder',
        'subtitle': 'Quay màn hình, dấu báo trước',
        'keywords': 'quay màn hình,screen recorder,hướng dẫn,chỉnh sửa video,gif,đánh dấu,tutorial',
        'promo': 'Cho người xem biết trước chỗ bạn sắp bấm.',
    },
    'en-US': {
        'name': 'E Screen Recorder',
        'subtitle': 'Show where you will tap',
        'keywords': 'screen recorder,tutorial,video editor,gif,markers,annotate,screencast',
        'promo': 'Show viewers where you are about to tap.',
    },
}


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text.strip() + '\n')


def main():
    for loc, d in ANDROID.items():
        base = os.path.join(ROOT, 'fastlane', 'metadata', 'android', loc)
        assert len(d['title']) <= 30, 'title too long'
        assert len(d['short']) <= 80, ('short too long', len(d['short']))
        assert len(d['full']) <= 4000, ('full too long', len(d['full']))
        assert len(d['changelog']) <= 500
        w(os.path.join(base, 'title.txt'), d['title'])
        w(os.path.join(base, 'short_description.txt'), d['short'])
        w(os.path.join(base, 'full_description.txt'), d['full'])
        w(os.path.join(base, 'changelogs', '1.txt'), d['changelog'])
        w(os.path.join(base, 'video.txt'), '')  # YouTube URL of the promo video, filled after upload
    for loc, d in APPSTORE.items():
        base = os.path.join(ROOT, 'fastlane', 'metadata', 'ios', loc)
        assert len(d['name']) <= 30 and len(d['subtitle']) <= 30 and len(d['keywords']) <= 100
        for k, fn in (('name', 'name.txt'), ('subtitle', 'subtitle.txt'), ('keywords', 'keywords.txt'),
                      ('promo', 'promotional_text.txt')):
            w(os.path.join(base, fn), d[k])
        full = ANDROID['vi-VN' if loc == 'vi' else 'en-US']['full']
        w(os.path.join(base, 'description.txt'), full)
    print('metadata written')


if __name__ == '__main__':
    main()
