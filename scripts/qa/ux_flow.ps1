param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_flow",
  [ValidateSet("tutorial", "game", "plain")][string]$Purpose = "tutorial"
)
# Runs maestro/ux_simple_flow.yaml (first run: asks the purpose, one big button, result screen, export).
#
# The flow needs the first-run state, so this script:
#  1. backs up the app's settings file (debug build, `adb run-as`) and removes only the keys
#     onboarded and purpose from the working copy,
#  2. runs the flow with screenshots into $OutDir,
#  3. checks that an ESR_edit_* file was exported and lists it,
#  4. puts the phone's own settings file back, so nothing the person had configured is lost.
# Nothing in the projects database or the media is touched here; remove the test videos with qa_data.ps1.
$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$prefs = "shared_prefs/FlutterSharedPreferences.xml"
$backup = Join-Path $root "test-results\prefs_backup_ux.xml"
New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null

adb -s $Serial shell am force-stop $Package
cmd /c "adb -s $Serial exec-out run-as $Package cat $prefs > `"$backup`""
$xml = Get-Content $backup -Raw -Encoding UTF8
if ($xml -notmatch "<map") { throw "could not read the settings file (is it a debug build?)" }
$work = $xml -replace '<boolean name="flutter\.onboarded"[^>]*/>', '' -replace '<(long|int) name="flutter\.purpose"[^>]*/>', ''
$tmp = Join-Path $env:TEMP "ux_prefs.xml"
[IO.File]::WriteAllText($tmp, $work, (New-Object Text.UTF8Encoding $false))
adb -s $Serial push $tmp /data/local/tmp/ux_prefs.xml | Out-Null
adb -s $Serial shell "run-as $Package cp /data/local/tmp/ux_prefs.xml $prefs"

$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
$before = (adb -s $Serial shell "ls '/sdcard/Movies/E Screen Recorder/'") -join "`n"
try {
  $button = @{ tutorial = "Quay hướng dẫn tự động"; game = "Quay game"; plain = "Quay video" }[$Purpose]
  & $maestro --device $Serial test -e "PURPOSE=$Purpose" -e "BUTTON=$button" --test-output-dir $OutDir maestro\ux_simple_flow.yaml
  $code = $LASTEXITCODE
} finally {
  adb -s $Serial shell am force-stop $Package
  adb -s $Serial push $backup /data/local/tmp/ux_prefs_restore.xml | Out-Null
  adb -s $Serial shell "run-as $Package cp /data/local/tmp/ux_prefs_restore.xml $prefs"
  adb -s $Serial shell "rm /data/local/tmp/ux_prefs.xml /data/local/tmp/ux_prefs_restore.xml"
  Write-Output "settings of the phone put back"
}
$after = (adb -s $Serial shell "ls -t '/sdcard/Movies/E Screen Recorder/'") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$new = $after | Where-Object { $before -notmatch [regex]::Escape($_) }
Write-Output "new files:"
$new | ForEach-Object { Write-Output "  $_" }
$edit = $new | Where-Object { $_ -like "ESR_edit_*" }
if ($code -eq 0 -and $edit) { Write-Output "RESULT: flow PASS and the exported file exists: $($edit -join ', ')" }
else { Write-Output "RESULT: FAIL (maestro exit $code, exported file: $($edit -join ', '))" ; exit 1 }
