param([string]$Serial = "T4E6S8IFU4AQBM8L")
# Makes three small test files with ffmpeg and puts them in the phone's Download folder, where the
# system picker finds them (editor QA: picture, music, picture-in-picture video).
$ff = "C:\ffmpeg\bin\ffmpeg.exe"
$dir = Join-Path $env:TEMP "esr_media"
New-Item -ItemType Directory -Force $dir | Out-Null
& $ff -y -loglevel error -f lavfi -i "testsrc=size=400x300:rate=1" -frames:v 1 "$dir\esr_pic.png"
& $ff -y -loglevel error -f lavfi -i "sine=frequency=440:duration=14" -c:a aac "$dir\esr_tone.m4a"
& $ff -y -loglevel error -f lavfi -i "testsrc=duration=6:size=640x360:rate=30" -f lavfi -i "sine=frequency=880:duration=6" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$dir\esr_pip.mp4"
foreach ($f in "esr_pic.png", "esr_tone.m4a", "esr_pip.mp4") {
  adb -s $Serial push "$dir\$f" "/sdcard/Download/$f" | Out-Null
}
Write-Output "pushed to $Serial"
