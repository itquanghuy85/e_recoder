# Generates the static site in site/ (privacy policy, security, support) in Vietnamese and English.
# The pages keep {{TOKENS}} that scripts/store/build_site.ps1 fills from store/store_config.json.
# Run:  python tool/gen_site.py
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, 'site')

CSS = """
:root{--bg:#f6f8fb;--card:#fff;--ink:#0e1116;--mute:#5b6577;--line:#dde3ec;--tally:#e0443c;--cue:#b86e00;--key:#00687a;--chip:#eaeef4}
@media (prefers-color-scheme:dark){:root{--bg:#0e1116;--card:#181e29;--ink:#e8ecf3;--mute:#a3aec2;--line:#2a3345;--tally:#ff5a52;--cue:#ffb938;--key:#4dd6e8;--chip:#1f2633}}
*{box-sizing:border-box}html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.65 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif}
a{color:var(--key);text-underline-offset:3px}a:hover{text-decoration-thickness:2px}
.wrap{max-width:860px;margin:0 auto;padding:0 20px}
header.site{border-bottom:1px solid var(--line);background:var(--card)}
header.site .wrap{display:flex;align-items:center;gap:14px;min-height:64px;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:10px;font-weight:650;color:var(--ink);text-decoration:none;letter-spacing:.2px}
.brand img{width:34px;height:34px;border-radius:9px}
nav.main{display:flex;gap:4px;flex-wrap:wrap;margin-left:auto}
nav.main a{color:var(--mute);text-decoration:none;padding:8px 12px;border-radius:10px;font-size:15px}
nav.main a:hover,nav.main a[aria-current=page]{background:var(--chip);color:var(--ink)}
.lang{font-size:14px;border:1px solid var(--line);border-radius:999px;padding:5px 12px;color:var(--mute);text-decoration:none}
main{padding:40px 0 64px}
h1{font-size:clamp(28px,5vw,40px);line-height:1.15;margin:0 0 12px;letter-spacing:-.01em}
h2{font-size:22px;margin:40px 0 10px;letter-spacing:-.005em}
h3{font-size:17px;margin:24px 0 6px}
p,li{max-width:70ch}
.lead{font-size:19px;color:var(--mute);max-width:60ch}
.meta{color:var(--mute);font-size:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px 22px;margin:16px 0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:14px;margin:20px 0}
.grid .card{margin:0}
.pill{display:inline-block;background:var(--chip);border-radius:999px;padding:3px 11px;font-size:13px;color:var(--mute)}
.ok{border-left:4px solid var(--key)}
.warn{border-left:4px solid var(--cue)}
table{border-collapse:collapse;width:100%;font-size:15px}
th,td{border-bottom:1px solid var(--line);padding:10px 8px;text-align:left;vertical-align:top}
th{color:var(--mute);font-weight:600;font-size:13px;text-transform:uppercase;letter-spacing:.04em}
.hero{display:flex;gap:28px;align-items:center;flex-wrap:wrap;margin-bottom:8px}
.hero img{width:112px;height:112px;border-radius:26px;box-shadow:0 10px 30px rgba(14,17,22,.25)}
.btn{display:inline-block;background:var(--tally);color:#fff;padding:12px 20px;border-radius:12px;font-weight:600;text-decoration:none}
footer{border-top:1px solid var(--line);padding:24px 0 40px;color:var(--mute);font-size:14px}
footer .wrap{display:flex;gap:18px;flex-wrap:wrap}
footer a{color:var(--mute)}
:focus-visible{outline:3px solid var(--key);outline-offset:2px;border-radius:6px}
img{max-width:100%;height:auto}h1,h2,h3,p,li,td{overflow-wrap:anywhere}
@media (max-width:640px){table{display:block;overflow-x:auto}.hero img{width:88px;height:88px}main{padding-top:28px}}
@media (prefers-reduced-motion:no-preference){a,.btn{transition:background .15s,color .15s}}
"""

T = {
    'vi': {
        'code': 'vi', 'other': 'en', 'other_label': 'English',
        'nav': [('index', 'Trang chủ'), ('privacy', 'Quyền riêng tư'), ('security', 'Bảo mật'), ('support', 'Hỗ trợ')],
        'updated': 'Cập nhật lần cuối: {{UPDATED}}',
        'footer': '© {{YEAR}} {{DEVELOPER}}. E Screen Recorder là ứng dụng miễn phí, không quảng cáo.',
        'pages': {
            'index': {
                'title': 'E Screen Recorder — Quay màn hình, người xem biết trước chỗ bạn sắp bấm',
                'desc': 'Ứng dụng quay màn hình Android miễn phí, không quảng cáo. Dấu báo trước chỗ sắp bấm, chỉnh sửa ngay trên máy, video ở lại trên máy của bạn.',
                'body': """
<div class="hero"><img src="../assets/logo.png" alt="Biểu tượng E Screen Recorder" width="112" height="112"><div>
<h1>E Screen Recorder</h1>
<p class="lead">Quay màn hình mà người xem luôn biết bạn sắp bấm vào đâu.</p>
<p><a class="btn" href="{{PLAY_URL}}">Tải trên Google Play</a></p></div></div>
<div class="grid">
<div class="card"><h3>Dấu báo trước</h3><p>Ngón tay, chạm kiểu giọt nước, mũi tên, vòng tròn, khung, bút, số bước. Vòng báo trước thu vào đích rồi mới đến lúc bấm.</p></div>
<div class="card"><h3>Hai cách đánh dấu</h3><p>Chấm nhỏ ở góc màn hình, hoặc quay sạch hoàn toàn rồi dựng dấu đẹp trong trình chỉnh sửa.</p></div>
<div class="card"><h3>Chỉnh sửa trên máy</h3><p>Cắt, ghép, đổi tốc độ, thêm chữ, che thông tin nhạy cảm, tự phóng to vào chỗ đánh dấu. Xuất MP4 hoặc GIF.</p></div>
<div class="card ok"><h3>Riêng tư tuyệt đối</h3><p>Không tài khoản, không quảng cáo, không thu thập dữ liệu. Ứng dụng thậm chí không xin quyền Internet.</p></div>
</div>
<p>Cần Android 10 trở lên. Xem <a href="privacy.html">chính sách quyền riêng tư</a> và <a href="security.html">cách chúng tôi bảo vệ bạn</a>.</p>
""",
            },
            'privacy': {
                'title': 'Chính sách quyền riêng tư — E Screen Recorder',
                'desc': 'E Screen Recorder không thu thập, không gửi và không chia sẻ dữ liệu của bạn. Video ở lại trên thiết bị.',
                'body': """
<h1>Chính sách quyền riêng tư</h1>
<p class="meta">{{UPDATED_LINE}}</p>
<p class="lead">Tóm lại: video của bạn ở lại trên máy của bạn. E Screen Recorder không có tài khoản, không quảng cáo, không phân tích sử dụng và không gửi bất kỳ dữ liệu nào ra khỏi thiết bị.</p>
<div class="card ok"><strong>Bản phát hành không có quyền Internet.</strong> Ứng dụng không khai báo quyền <code>INTERNET</code>, nên về mặt kỹ thuật nó không thể tải dữ liệu của bạn lên bất kỳ máy chủ nào.</div>

<h2>1. Ai chịu trách nhiệm</h2>
<p>{{DEVELOPER}} (nhà phát triển ứng dụng). Liên hệ: <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>.</p>

<h2>2. Dữ liệu ứng dụng xử lý trên thiết bị</h2>
<table><thead><tr><th>Dữ liệu</th><th>Dùng để</th><th>Lưu ở đâu</th></tr></thead><tbody>
<tr><td>Hình ảnh màn hình bạn chọn quay (sau khi bạn đồng ý trong hộp thoại của Android)</td><td>Tạo tệp video</td><td>Thư mục <code>Movies/E Screen Recorder</code> trên thiết bị</td></tr>
<tr><td>Âm thanh micro hoặc âm thanh trong máy (chỉ khi bạn bật)</td><td>Ghi tiếng vào video</td><td>Nằm trong tệp video</td></tr>
<tr><td>Dự án chỉnh sửa: vị trí cắt, dấu, chữ, khối che</td><td>Cho bạn sửa tiếp lần sau</td><td>Cơ sở dữ liệu cục bộ của ứng dụng</td></tr>
<tr><td>Cài đặt: độ phân giải, giao diện, kiểu dấu</td><td>Nhớ lựa chọn của bạn</td><td>Bộ nhớ cục bộ của ứng dụng</td></tr>
<tr><td>Ảnh GIF bạn xuất</td><td>Chia sẻ ảnh động</td><td>Thư mục <code>Pictures/E Screen Recorder</code></td></tr>
</tbody></table>

<h2>3. Những gì ứng dụng không làm</h2>
<ul>
<li>Không tải video, âm thanh, ảnh màn hình hay dự án lên máy chủ nào.</li>
<li>Không dùng tài khoản, định danh quảng cáo, công cụ phân tích hay báo lỗi tự động.</li>
<li>Không hiện quảng cáo, không bán hay chia sẻ dữ liệu cho bên thứ ba.</li>
<li>Không đọc tin nhắn, danh bạ, vị trí, ảnh hay tệp khác trên máy của bạn.</li>
</ul>
<p>Chỉ khi bạn bấm <strong>Chia sẻ</strong>, tệp bạn chọn được gửi tới ứng dụng bạn chọn qua hộp thoại chia sẻ của Android. Từ lúc đó, tệp thuộc quyền của ứng dụng nhận.</p>

<h2>4. Quyền Android và lý do</h2>
<table><thead><tr><th>Quyền</th><th>Lý do</th></tr></thead><tbody>
<tr><td>Quay màn hình (hộp thoại hệ thống, hỏi mỗi lần)</td><td>Ghi lại nội dung hiển thị. Android luôn hỏi bạn trước.</td></tr>
<tr><td><code>FOREGROUND_SERVICE</code> (loại <em>mediaProjection</em>, <em>microphone</em>)</td><td>Giữ việc quay chạy ổn định khi bạn chuyển sang ứng dụng khác. Có thông báo đang quay.</td></tr>
<tr><td><code>RECORD_AUDIO</code> (micro)</td><td>Chỉ khi bạn chọn quay có tiếng micro.</td></tr>
<tr><td><code>SYSTEM_ALERT_WINDOW</code> (hiện trên ứng dụng khác)</td><td>Hiện chấm đánh dấu, đếm ngược 3·2·1 và dấu báo trước lên màn hình đang quay.</td></tr>
<tr><td><code>POST_NOTIFICATIONS</code></td><td>Hiện nút Tạm dừng / Dừng khi đang quay.</td></tr>
<tr><td><code>VIBRATE</code></td><td>Rung nhẹ xác nhận đã đánh dấu ở chế độ quay sạch.</td></tr>
</tbody></table>

<h2>5. Nội dung nhạy cảm trên màn hình</h2>
<p>Màn hình có thể chứa mật khẩu, tin nhắn, số điện thoại hay thông tin tài chính. Hãy kiểm tra video trước khi chia sẻ và dùng <strong>khối che</strong> trong trình chỉnh sửa để che thông tin nhạy cảm. Chấm đánh dấu và dấu vẽ lúc quay ở chế độ "chấm nhỏ" được ghi vào video; chế độ "quay sạch" không ghi gì ngoài màn hình thật. Các ứng dụng đặt cờ bảo vệ nội dung (ví dụ ngân hàng) sẽ hiện màn hình đen trong video — đó là cơ chế bảo vệ của Android.</p>

<h2>6. Trẻ em</h2>
<p>Ứng dụng không nhắm tới trẻ em dưới 13 tuổi và không thu thập thông tin cá nhân của bất kỳ ai.</p>

<h2>7. Xoá dữ liệu của bạn</h2>
<ul>
<li>Xoá video trong mục <strong>Thư viện</strong> của ứng dụng, hoặc bằng ứng dụng Ảnh/Tệp.</li>
<li>Gỡ cài đặt ứng dụng sẽ xoá dự án chỉnh sửa và cài đặt. Video đã xuất nằm trong thư mục Movies/Pictures và do bạn quản lý.</li>
<li>Vì chúng tôi không giữ dữ liệu nào của bạn, không có gì để yêu cầu xoá trên máy chủ.</li>
</ul>

<h2>8. Thay đổi chính sách</h2>
<p>Nếu sau này ứng dụng thay đổi cách xử lý dữ liệu, chính sách này sẽ được cập nhật trước khi bản mới phát hành và ngày cập nhật ở đầu trang sẽ đổi.</p>

<h2>9. Liên hệ</h2>
<p>Câu hỏi về quyền riêng tư: <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>.</p>
""",
            },
            'security': {
                'title': 'Bảo mật — E Screen Recorder',
                'desc': 'Cách E Screen Recorder bảo vệ bạn: dữ liệu ở lại trên máy, không có quyền Internet, quyền tối thiểu, và cách báo lỗi bảo mật.',
                'body': """
<h1>Bảo mật</h1>
<p class="meta">{{UPDATED_LINE}}</p>
<p class="lead">Cách an toàn nhất để giữ dữ liệu của bạn là không bao giờ rời khỏi thiết bị. Đó là cách E Screen Recorder được thiết kế.</p>
<div class="grid">
<div class="card ok"><h3>Không có đường ra mạng</h3><p>Bản phát hành không xin quyền Internet. Không có máy chủ, không có tài khoản, không có SDK quảng cáo hay phân tích.</p></div>
<div class="card ok"><h3>Quyền tối thiểu, hỏi đúng lúc</h3><p>Micro chỉ khi bạn chọn quay có tiếng. Quay màn hình do Android hỏi mỗi lần. Không đọc ảnh, danh bạ, tin nhắn hay vị trí.</p></div>
<div class="card ok"><h3>Lưu đúng chỗ của Android</h3><p>Video lưu qua MediaStore vào thư mục riêng của ứng dụng trong Movies; không cần quyền truy cập toàn bộ bộ nhớ.</p></div>
<div class="card ok"><h3>Công cụ che thông tin</h3><p>Khối che trong trình chỉnh sửa được in thẳng vào video khi xuất, không thể gỡ ra khỏi tệp đã xuất.</p></div>
</div>

<h2>Điều bạn nên biết khi quay</h2>
<div class="card warn"><ul>
<li>Thông báo hệ thống, mật khẩu hay tin nhắn hiện trên màn hình sẽ nằm trong video. Bật "Không làm phiền" trước khi quay.</li>
<li>Ứng dụng đặt cờ bảo vệ nội dung (ngân hàng, một số trình phát) hiện màn hình đen trong video.</li>
<li>Kiểm tra video và che thông tin nhạy cảm trước khi chia sẻ.</li>
</ul></div>

<h2>Tính toàn vẹn của ứng dụng</h2>
<ul>
<li>Phát hành qua Google Play, ký bằng khoá riêng với Play App Signing. Không tải ứng dụng từ nguồn khác.</li>
<li>Mã được thu nhỏ và làm rối (R8) trong bản phát hành.</li>
<li>Ứng dụng nhắm tới phiên bản Android mới nhất và tuân theo các hạn chế dịch vụ nền của Android.</li>
</ul>

<h2>Báo lỗi bảo mật</h2>
<p>Nếu bạn tìm thấy lỗ hổng, vui lòng gửi mô tả và các bước tái hiện tới <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>. Chúng tôi sẽ phản hồi và sửa trong thời gian sớm nhất. Vui lòng không công bố công khai trước khi có bản sửa.</p>
""",
            },
            'support': {
                'title': 'Hỗ trợ — E Screen Recorder',
                'desc': 'Câu hỏi thường gặp và cách liên hệ hỗ trợ E Screen Recorder.',
                'body': """
<h1>Hỗ trợ</h1>
<p class="lead">Gặp vấn đề hoặc có góp ý? Viết cho chúng tôi: <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>.</p>
<h2>Câu hỏi thường gặp</h2>
<div class="card"><h3>Ứng dụng có mất phí hay có quảng cáo không?</h3><p>Không. Miễn phí hoàn toàn, không quảng cáo, không mua trong ứng dụng.</p></div>
<div class="card"><h3>Video của tôi được lưu ở đâu?</h3><p>Trong thư mục <code>Movies/E Screen Recorder</code> trên thiết bị, và hiện trong mục Thư viện của ứng dụng.</p></div>
<div class="card"><h3>Vì sao video bị màn hình đen?</h3><p>Ứng dụng bạn quay đặt cờ bảo vệ nội dung (ví dụ ngân hàng, một số dịch vụ xem phim). Android chặn quay những màn hình này.</p></div>
<div class="card"><h3>Chấm đánh dấu hay thanh điều khiển lọt vào video, làm sao để video sạch?</h3><p>Vào Cài đặt → Dấu đánh dấu → chọn <strong>Quay sạch, dựng sau</strong>. Khi đó không có gì hiện trên màn hình lúc quay; dấu được vẽ trong trình chỉnh sửa.</p></div>
<div class="card"><h3>Làm sao biết người xem thấy dấu trước khi tôi bấm?</h3><p>Bấm chấm nhỏ ở góc (hoặc vùng ẩn ở chế độ quay sạch), chạm vào chỗ sắp bấm rồi mới bấm thật. Vòng báo trước thu vào đích 0,5 giây trước khi dấu hiện rõ.</p></div>
<div class="card"><h3>Quay bị dừng khi tôi chuyển ứng dụng (Xiaomi, Oppo, Vivo, Huawei)?</h3><p>Tắt tối ưu pin cho E Screen Recorder trong Cài đặt hệ thống → Pin, và cho phép tự khởi chạy. Ứng dụng có hướng dẫn mở đúng màn hình này trong Cài đặt → Quyền.</p></div>
<div class="card"><h3>Tôi muốn xoá mọi dữ liệu.</h3><p>Xoá video trong Thư viện và gỡ cài đặt ứng dụng. Chúng tôi không giữ dữ liệu nào trên máy chủ.</p></div>
""",
            },
        },
    },
    'en': {
        'code': 'en', 'other': 'vi', 'other_label': 'Tiếng Việt',
        'nav': [('index', 'Home'), ('privacy', 'Privacy'), ('security', 'Security'), ('support', 'Support')],
        'updated': 'Last updated: {{UPDATED}}',
        'footer': '© {{YEAR}} {{DEVELOPER}}. E Screen Recorder is free and has no ads.',
        'pages': {
            'index': {
                'title': 'E Screen Recorder — Screen recorder that shows where you are about to tap',
                'desc': 'Free Android screen recorder with no ads. Point-ahead markers, on-device editing, and your videos never leave your phone.',
                'body': """
<div class="hero"><img src="../assets/logo.png" alt="E Screen Recorder icon" width="112" height="112"><div>
<h1>E Screen Recorder</h1>
<p class="lead">Record your screen so viewers always know where you are about to tap.</p>
<p><a class="btn" href="{{PLAY_URL}}">Get it on Google Play</a></p></div></div>
<div class="grid">
<div class="card"><h3>Point-ahead markers</h3><p>Finger, water-drop tap, arrow, circle, box, pen, step numbers. A cue ring closes in on the target before the tap happens.</p></div>
<div class="card"><h3>Two ways to mark</h3><p>A small corner dot, or record completely clean and draw beautiful markers afterwards in the editor.</p></div>
<div class="card"><h3>Edit on your phone</h3><p>Cut, join, change speed, add text, cover sensitive info, auto-zoom into your markers. Export MP4 or GIF.</p></div>
<div class="card ok"><h3>Private by design</h3><p>No account, no ads, no data collection. The app does not even request the Internet permission.</p></div>
</div>
<p>Requires Android 10 or newer. Read the <a href="privacy.html">privacy policy</a> and <a href="security.html">how we protect you</a>.</p>
""",
            },
            'privacy': {
                'title': 'Privacy Policy — E Screen Recorder',
                'desc': 'E Screen Recorder does not collect, send or share your data. Your videos stay on your device.',
                'body': """
<h1>Privacy Policy</h1>
<p class="meta">{{UPDATED_LINE}}</p>
<p class="lead">In short: your videos stay on your phone. E Screen Recorder has no accounts, no ads, no analytics and sends no data off your device.</p>
<div class="card ok"><strong>The release build has no Internet permission.</strong> The app does not declare <code>INTERNET</code>, so technically it cannot upload your data to any server.</div>

<h2>1. Who is responsible</h2>
<p>{{DEVELOPER}} (the app developer). Contact: <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>.</p>

<h2>2. Data the app handles on your device</h2>
<table><thead><tr><th>Data</th><th>Used for</th><th>Stored</th></tr></thead><tbody>
<tr><td>What is on screen when you choose to record (after you agree in Android's dialog)</td><td>Creating the video file</td><td><code>Movies/E Screen Recorder</code> on the device</td></tr>
<tr><td>Microphone or device audio (only if you turn it on)</td><td>Adding sound to the video</td><td>Inside the video file</td></tr>
<tr><td>Edit projects: cuts, markers, text, covers</td><td>Letting you continue editing later</td><td>The app's local database</td></tr>
<tr><td>Settings: resolution, theme, marker style</td><td>Remembering your choices</td><td>The app's local storage</td></tr>
<tr><td>GIFs you export</td><td>Sharing animated images</td><td><code>Pictures/E Screen Recorder</code></td></tr>
</tbody></table>

<h2>3. What the app does not do</h2>
<ul>
<li>It does not upload videos, audio, screenshots or projects to any server.</li>
<li>It uses no accounts, advertising IDs, analytics or automatic crash reporting.</li>
<li>It shows no ads and does not sell or share data with third parties.</li>
<li>It does not read your messages, contacts, location, photos or other files.</li>
</ul>
<p>Only when you tap <strong>Share</strong> is the file you chose sent to the app you choose through Android's share sheet. From then on the file belongs to the receiving app.</p>

<h2>4. Android permissions and why</h2>
<table><thead><tr><th>Permission</th><th>Why</th></tr></thead><tbody>
<tr><td>Screen capture (system dialog, asked every time)</td><td>To record what is on screen. Android always asks you first.</td></tr>
<tr><td><code>FOREGROUND_SERVICE</code> (types <em>mediaProjection</em>, <em>microphone</em>)</td><td>Keeps recording reliable while you use other apps. A recording notification is shown.</td></tr>
<tr><td><code>RECORD_AUDIO</code> (microphone)</td><td>Only if you choose to record with microphone sound.</td></tr>
<tr><td><code>SYSTEM_ALERT_WINDOW</code> (display over other apps)</td><td>To show the marker dot, the 3·2·1 countdown and point-ahead markers on the screen being recorded.</td></tr>
<tr><td><code>POST_NOTIFICATIONS</code></td><td>To show Pause / Stop buttons while recording.</td></tr>
<tr><td><code>VIBRATE</code></td><td>A light buzz confirming a marker in clean-recording mode.</td></tr>
</tbody></table>

<h2>5. Sensitive content on screen</h2>
<p>Your screen may show passwords, messages, phone numbers or financial details. Review your video before sharing and use the <strong>cover</strong> tool in the editor to hide sensitive information. The marker dot and markers drawn while recording in "small dot" mode are recorded into the video; "clean" mode records nothing but the real screen. Apps that protect their content (for example banking apps) appear black in recordings — that is Android's protection at work.</p>

<h2>6. Children</h2>
<p>The app is not directed to children under 13 and does not collect personal information from anyone.</p>

<h2>7. Deleting your data</h2>
<ul>
<li>Delete videos in the app's <strong>Library</strong>, or with your Photos/Files app.</li>
<li>Uninstalling the app removes edit projects and settings. Exported videos live in Movies/Pictures and are yours to manage.</li>
<li>Because we hold no data about you, there is nothing to delete on a server.</li>
</ul>

<h2>8. Changes to this policy</h2>
<p>If the app ever changes how it handles data, this policy will be updated before the new version ships, and the date at the top will change.</p>

<h2>9. Contact</h2>
<p>Privacy questions: <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>.</p>
""",
            },
            'security': {
                'title': 'Security — E Screen Recorder',
                'desc': 'How E Screen Recorder protects you: data stays on device, no Internet permission, minimal permissions, and how to report a vulnerability.',
                'body': """
<h1>Security</h1>
<p class="meta">{{UPDATED_LINE}}</p>
<p class="lead">The safest way to protect your data is to never let it leave your device. That is how E Screen Recorder is built.</p>
<div class="grid">
<div class="card ok"><h3>No way out to the network</h3><p>The release build requests no Internet permission. No servers, no accounts, no advertising or analytics SDKs.</p></div>
<div class="card ok"><h3>Minimal permissions, asked at the right time</h3><p>Microphone only if you choose sound. Screen capture is confirmed by Android every time. No access to photos, contacts, messages or location.</p></div>
<div class="card ok"><h3>Saved where Android wants it</h3><p>Videos are saved through MediaStore into the app's own folder under Movies; no broad storage access is needed.</p></div>
<div class="card ok"><h3>Cover tool for secrets</h3><p>Covers added in the editor are burned into the exported video and cannot be removed from the exported file.</p></div>
</div>

<h2>What to know while recording</h2>
<div class="card warn"><ul>
<li>System notifications, passwords or messages that appear on screen end up in the video. Turn on Do Not Disturb before recording.</li>
<li>Apps that protect their content (banking, some video players) appear black in recordings.</li>
<li>Review the video and cover sensitive information before sharing.</li>
</ul></div>

<h2>App integrity</h2>
<ul>
<li>Distributed through Google Play, signed with a private key using Play App Signing. Do not install the app from other sources.</li>
<li>Code is shrunk and obfuscated (R8) in release builds.</li>
<li>The app targets the latest Android release and follows Android's background-service restrictions.</li>
</ul>

<h2>Report a vulnerability</h2>
<p>If you find a vulnerability, please send a description and steps to reproduce to <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>. We will respond and fix it as soon as possible. Please do not disclose publicly before a fix is available.</p>
""",
            },
            'support': {
                'title': 'Support — E Screen Recorder',
                'desc': 'Frequently asked questions and how to contact E Screen Recorder support.',
                'body': """
<h1>Support</h1>
<p class="lead">Problem or suggestion? Write to us: <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>.</p>
<h2>Frequently asked questions</h2>
<div class="card"><h3>Does it cost anything or show ads?</h3><p>No. It is completely free, with no ads and no in-app purchases.</p></div>
<div class="card"><h3>Where are my videos saved?</h3><p>In <code>Movies/E Screen Recorder</code> on your device, and they appear in the app's Library.</p></div>
<div class="card"><h3>Why is my video black?</h3><p>The app you recorded protects its content (for example banking or some streaming apps). Android blocks recording those screens.</p></div>
<div class="card"><h3>The marker dot or control bar ended up in the video. How do I get a clean video?</h3><p>Go to Settings → Markers → choose <strong>Record clean, edit later</strong>. Nothing shows on screen while recording; markers are drawn in the editor.</p></div>
<div class="card"><h3>How do viewers see the marker before I tap?</h3><p>Tap the small corner dot (or the hidden zone in clean mode), touch where you are about to press, then press for real. The cue ring closes in on the target half a second before the marker appears.</p></div>
<div class="card"><h3>Recording stops when I switch apps (Xiaomi, Oppo, Vivo, Huawei)?</h3><p>Turn off battery optimisation for E Screen Recorder in system Settings → Battery and allow auto-start. The app can open the right screen from Settings → Permissions.</p></div>
<div class="card"><h3>I want all my data deleted.</h3><p>Delete the videos in the Library and uninstall the app. We keep no data on any server.</p></div>
""",
            },
        },
    },
}


def render(lang, page):
    t = T[lang]
    p = t['pages'][page]
    nav = ''.join(
        '<a href="%s.html"%s>%s</a>' % (k, ' aria-current="page"' if k == page else '', label)
        for k, label in t['nav']
    )
    body = p['body'].replace('{{UPDATED_LINE}}', t['updated'])
    return f"""<!doctype html>
<html lang="{t['code']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{p['title']}</title>
<meta name="description" content="{p['desc']}">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="../assets/logo.png">
<link rel="alternate" hreflang="{t['other']}" href="../{t['other']}/{page}.html">
<link rel="stylesheet" href="../assets/style.css">
</head>
<body>
<header class="site"><div class="wrap">
<a class="brand" href="index.html"><img src="../assets/logo.png" alt="" width="34" height="34">E Screen Recorder</a>
<nav class="main" aria-label="{'Điều hướng' if lang == 'vi' else 'Main'}">{nav}</nav>
<a class="lang" href="../{t['other']}/{page}.html" hreflang="{t['other']}">{t['other_label']}</a>
</div></header>
<main><div class="wrap">
{body}
</div></main>
<footer><div class="wrap"><span>{t['footer']}</span><a href="privacy.html">{dict(t['nav'])['privacy']}</a><a href="security.html">{dict(t['nav'])['security']}</a><a href="support.html">{dict(t['nav'])['support']}</a></div></footer>
</body>
</html>
"""


def main():
    os.makedirs(os.path.join(SITE, 'assets'), exist_ok=True)
    with open(os.path.join(SITE, 'assets', 'style.css'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(CSS.strip() + '\n')
    for lang in T:
        os.makedirs(os.path.join(SITE, lang), exist_ok=True)
        for page in T[lang]['pages']:
            with open(os.path.join(SITE, lang, page + '.html'), 'w', encoding='utf-8', newline='\n') as f:
                f.write(render(lang, page))
    redirect = """<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>E Screen Recorder</title>
<link rel="icon" href="assets/logo.png">
<meta http-equiv="refresh" content="0;url=vi/index.html">
<script>var l=(navigator.language||'vi').slice(0,2);location.replace(l==='vi'?'vi/index.html':'en/index.html');</script>
</head><body><p><a href="vi/index.html">Tiếng Việt</a> · <a href="en/index.html">English</a></p></body></html>
"""
    with open(os.path.join(SITE, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(redirect)
    src = os.path.join(ROOT, 'assets', 'brand', 'logo_1024.png')
    shutil.copyfile(src, os.path.join(SITE, 'assets', 'logo.png'))
    with open(os.path.join(SITE, '.nojekyll'), 'w') as f:
        f.write('')
    print('site generated')


if __name__ == '__main__':
    main()
