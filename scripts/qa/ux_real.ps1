param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_real"
)
# Runs maestro/ux_real_user.yaml as a person would: a fresh start (settings file backed up first and
# NOT put back, so the phone is left the way a new user would have it) and the videos are kept for
# a person to look at; nothing is deleted. Needs a debug build (adb run-as).
$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$prefs = "shared_prefs/FlutterSharedPreferences.xml"
$backup = Join-Path $root "test-results\prefs_backup_real.xml"
New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null
adb -s $Serial shell am force-stop $Package
cmd /c "adb -s $Serial exec-out run-as $Package cat $prefs > `"$backup`""
adb -s $Serial shell "run-as $Package rm -f $prefs"
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
$before = (adb -s $Serial shell "ls '/sdcard/Movies/E Screen Recorder/'") -join "`n"
& $maestro --device $Serial test --test-output-dir $OutDir maestro\ux_real_user.yaml
$code = $LASTEXITCODE
adb -s $Serial shell am force-stop $Package
$after = (adb -s $Serial shell "ls -t '/sdcard/Movies/E Screen Recorder/'") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$after | Where-Object { $before -notmatch [regex]::Escape($_) } | ForEach-Object { Write-Output "new video kept: $_" }
if ($code -eq 0) { Write-Output "RESULT: flow PASS" } else { Write-Output "RESULT: FAIL (maestro exit $code)"; exit 1 }
