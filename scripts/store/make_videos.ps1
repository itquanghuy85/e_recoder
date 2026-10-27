param(
  [string]$Serial = "T4E6S8IFU4AQBM8L",
  [string]$Lang = "vi",
  [string]$Work = "$env:TEMP\esr_video",
  [switch]$ComposeOnly   # reuse $Work\a.mp4 and $Work\consent from an earlier run (no device needed)
)
# Builds store/video/promo.mp4 and store/video/permission_demo.mp4.
#  1) store_video_a: the app records itself in dot mode while a Maestro flow uses another app
#     (point first, then press). A screencap job grabs the system consent dialog, because a screen
#     recording cannot film itself before capture starts.
#  2) ffmpeg joins title card + (consent frames) + the recording + still screens + end card, 1080x1920.
# Needs: device connected with the app installed and overlay permission granted (unless -ComposeOnly),
# flutter, ffmpeg (C:\ffmpeg\bin). Run `flutter test tool/make_store_assets_test.dart` first so the stills exist.
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $root
$ff = "C:\ffmpeg\bin\ffmpeg.exe"
New-Item -ItemType Directory -Force $Work, "store/video" | Out-Null

flutter test tool/make_store_assets_test.dart --plain-name "video cards" | Out-Null
flutter test tool/make_store_assets_test.dart --plain-name "notification card" | Out-Null

function Warm-App {
  # A freshly started app answers Maestro reliably; a cold start straight into a flow often does not on ColorOS.
  # force-stop also ends a recording service left behind by an earlier failed run (its overlays confuse the next flow).
  adb -s $Serial shell am force-stop com.huluca.escreenrecorder | Out-Null
  adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
  adb -s $Serial shell am start -n com.huluca.escreenrecorder/.MainActivity | Out-Null
  Start-Sleep 10
}

if (-not $ComposeOnly) {
  Remove-Item "$Work\*" -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force "$Work\consent" | Out-Null
  Warm-App
  $loop = Start-Job -ScriptBlock {
    param($s, $dir)
    # Wait for the system screen-capture dialog, then grab frames while it is on screen.
    $deadline = (Get-Date).AddSeconds(150)
    while ((Get-Date) -lt $deadline) {
      $focus = (adb -s $s shell dumpsys window | Select-String "mCurrentFocus") -join " "
      if ($focus -match "MediaProjectionPermission") { break }
      Start-Sleep -Milliseconds 250
    }
    for ($i = 1; $i -le 18; $i++) {
      $name = Join-Path $dir ("f{0:D3}.png" -f $i)
      # cmd keeps the PNG bytes intact; a PowerShell pipeline would turn them into text.
      cmd /c "adb -s $s exec-out screencap -p > `"$name`""
    }
  } -ArgumentList $Serial, "$Work\consent"
  & powershell -File (Join-Path $PSScriptRoot "..\run_flow.ps1") maestro\helpers\prep_dot.yaml -Serial $Serial
  & powershell -File (Join-Path $PSScriptRoot "..\run_flow.ps1") store_video_a -Serial $Serial
  Wait-Job $loop -Timeout 20 | Out-Null
  Stop-Job $loop -ErrorAction SilentlyContinue
  Remove-Job $loop -Force -ErrorAction SilentlyContinue
  $a = (adb -s $Serial shell "ls -t '/sdcard/Movies/E Screen Recorder/' | head -1").Trim()
  adb -s $Serial pull "/sdcard/Movies/E Screen Recorder/$a" "$Work\a.mp4" | Out-Null
}

# --- compose -----------------------------------------------------------------------------------
$vf = "scale=1080:1920:force_original_aspect_ratio=decrease:flags=lanczos,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=0x0E1116,fps=30,format=yuv420p"
# Recordings of a screen that waits: drop near-identical frames so the demo stays brisk.
$vfc = "mpdecimate=hi=768:lo=320:frac=0.33,setpts=N/30/TB," + $vf

function Still($png, $seconds, $out) {
  & $ff -y -loglevel error -loop 1 -t $seconds -i $png -vf "fade=in:0:10,fade=out:st=$($seconds - 0.4):d=0.4,fps=30,format=yuv420p" -c:v libx264 -crf 20 $out
}
Still "store/video/cards/title_$Lang.png" 3 "$Work\t.mp4"
Still "store/video/cards/notification_$Lang.png" 4 "$Work\n.mp4"
Still "store/video/cards/end_$Lang.png" 3 "$Work\e.mp4"
$shots = @("2_editor", "3_auto", "4_modes")
$loc = if ($Lang -eq "vi") { "vi-VN" } else { "en-US" }
$i = 0
foreach ($s in $shots) {
  $i++
  $png = "fastlane/metadata/android/$loc/images/phoneScreenshots/$s.png"
  if (Test-Path $png) { Still $png 3.2 "$Work\s$i.mp4" }
}

$frames = @(Get-ChildItem "$Work\consent" -Filter f*.png -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 1000 })
if ($frames.Count -ge 4) {
  & $ff -y -loglevel error -framerate 3 -i "$Work\consent\f%03d.png" -vf $vf -c:v libx264 -crf 20 "$Work\c.mp4"
} else {
  Write-Warning "No consent-dialog frames captured; permission_demo.mp4 will not show the dialog."
  Remove-Item "$Work\c.mp4" -ErrorAction SilentlyContinue
}
# Skip the first seconds (the home screen before the other app opens).
& $ff -y -loglevel error -ss 4 -i "$Work\a.mp4" -vf $vfc -an -c:v libx264 -crf 20 -preset medium "$Work\a2.mp4"

function Join-Videos($list, $out) {
  $txt = Join-Path $Work "list.txt"
  ($list | Where-Object { Test-Path $_ } | ForEach-Object { "file '" + $_.Replace('\', '/') + "'" }) | Set-Content $txt -Encoding ASCII
  & $ff -y -loglevel error -f concat -safe 0 -i $txt -c copy $out
}
Join-Videos @("$Work\t.mp4", "$Work\a2.mp4", "$Work\s1.mp4", "$Work\s2.mp4", "$Work\s3.mp4", "$Work\e.mp4") "store/video/promo.mp4"
Join-Videos @("$Work\t.mp4", "$Work\c.mp4", "$Work\a2.mp4", "$Work\n.mp4", "$Work\e.mp4") "store/video/permission_demo.mp4"
Get-Item store/video/*.mp4 | Select-Object Name, @{n = "MB"; e = { [math]::Round($_.Length / 1MB, 1) } }
