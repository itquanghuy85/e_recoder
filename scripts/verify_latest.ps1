param(
  [string]$Serial = "T4E6S8IFU4AQBM8L",
  [string]$Out = "D:\JOB\_tools\verify",
  [switch]$Sheet
)
# Pulls the newest recording from the device and prints its streams (QA evidence helper).
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force $Out | Out-Null
$name = (adb -s $Serial shell "ls -t '/sdcard/Movies/E Screen Recorder/' | head -1").Trim()
$dest = Join-Path $Out "latest"
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $dest | Out-Null
adb -s $Serial pull "/sdcard/Movies/E Screen Recorder/$name" $dest | Out-Null
$f = Join-Path $dest $name
"file: $name"
& C:\ffmpeg\bin\ffprobe.exe -v error -show_entries stream=codec_name,codec_type,width,height,duration -of compact $f
& C:\ffmpeg\bin\ffprobe.exe -v error -show_entries format=duration,size -of compact $f
if ($Sheet) {
  & C:\ffmpeg\bin\ffmpeg.exe -y -loglevel error -i $f -vf "fps=1/2,scale=240:-1,tile=6x2" -frames:v 1 (Join-Path $Out "sheet.png")
  "sheet: $(Join-Path $Out 'sheet.png')"
}
