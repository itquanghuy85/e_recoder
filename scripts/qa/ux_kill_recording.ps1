param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_kill_recording"
)
# Kills the app (am force-stop) while it records, right after two taps were made, and reports what is left:
# new videos in the gallery, the recorder's temporary file (cache/rec) and whether it can be played.
# Debug build (run-as). Uses the Samsung calculator only. Nothing is deleted.
$ErrorActionPreference = "Continue"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$dir = "/sdcard/Movies/E Screen Recorder"
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
$before = (adb -s $Serial shell "ls '$dir/'") -join "`n"
Write-Output "cache/rec before:"; adb -s $Serial shell "run-as $Package ls -la cache/rec 2>/dev/null"
$log = "$env:TEMP\kill_rec.log"
$m = Start-Process -FilePath $maestro -ArgumentList @("--device", $Serial, "test", "--test-output-dir", $OutDir, "maestro\ux_kill_recording.yaml") -PassThru -NoNewWindow -RedirectStandardOutput $log
$tapped = $false
for ($i = 0; $i -lt 240; $i++) {
  Start-Sleep 1
  if ((Get-Content $log -Raw -ErrorAction SilentlyContinue) -match 'Tap on "5"\.\.\. COMPLETED') { $tapped = $true; break }
}
Start-Sleep 1
adb -s $Serial shell am force-stop $Package
Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue
Write-Output "taps made while recording: $tapped; app killed while recording"
Start-Sleep 3
Write-Output "new videos in the gallery:"
(adb -s $Serial shell "ls '$dir/'") | Where-Object { $before -notmatch [regex]::Escape($_.Trim()) } | ForEach-Object { Write-Output "  $_" }
Write-Output "cache/rec after the kill:"
adb -s $Serial shell "run-as $Package ls -la cache/rec 2>/dev/null"
$f = (adb -s $Serial shell "run-as $Package ls -t cache/rec 2>/dev/null" | Select-Object -First 1)
if ($f) {
  $local = Join-Path $env:TEMP "killed_rec.mp4"
  cmd /c "adb -s $Serial exec-out run-as $Package cat cache/rec/$($f.Trim()) > `"$local`""
  Write-Output "can the left-over file be played?"
  & C:\ffmpeg\bin\ffprobe.exe -v error -show_entries format=duration -of default=nw=1 $local 2>&1 | Select-Object -First 3
}
