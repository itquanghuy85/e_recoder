param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_long",
  [string]$Video = "$env:TEMP\esr_media\QA_long_5min.mp4"
)
# Long-video export resilience (maestro/ux_long_export.yaml): background + return, a kill half way, reopen,
# export again. Prints the exports made and the app's export cache before/after. Debug build (run-as).
# Uses only the test file QA_long_5min.mp4 (a test pattern); nothing is deleted.
$ErrorActionPreference = "Continue"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$dir = "/sdcard/Movies/E Screen Recorder"
adb -s $Serial push $Video "/sdcard/Download/QA_long_5min.mp4" | Out-Null
adb -s $Serial shell "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file:///sdcard/Download/QA_long_5min.mp4'" | Out-Null
Start-Sleep 3
$before = (adb -s $Serial shell "ls '$dir/'") -join "`n"
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
& $maestro --device $Serial test --test-output-dir $OutDir maestro\ux_long_export.yaml
$code = $LASTEXITCODE
$after = (adb -s $Serial shell "ls '$dir/'") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$new = $after | Where-Object { $before -notmatch [regex]::Escape($_) }
Write-Output "new files (expected: 2 exports, none from the killed one):"
$new | ForEach-Object { Write-Output "  $_" }
Write-Output "export cache now:"
adb -s $Serial shell "run-as $Package ls -la cache/export cache/export_rev cache/export_pip 2>/dev/null"
if ($code -eq 0) { Write-Output "RESULT: flow PASS" } else { Write-Output "RESULT: FAIL (maestro exit $code)"; exit 1 }
