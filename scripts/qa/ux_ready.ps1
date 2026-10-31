param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_ready"
)
# The "Ready to record?" screen on the phone: take the overlay permission away, run ux_ready_a (the screen
# lists it, recording does not start), give it back, run ux_ready_b (it is seen as on, Ready opens, recording
# works). The permission's previous app-op value and the app's settings file are put back at the end.
$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$prefs = "shared_prefs/FlutterSharedPreferences.xml"
$backup = Join-Path $root "test-results\prefs_backup_ready.xml"
New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"

$prev = ((adb -s $Serial shell appops get $Package SYSTEM_ALERT_WINDOW) -split ":")[1].Trim().Split(";")[0].Trim()
Write-Output "overlay app-op before: $prev"
$before = (adb -s $Serial shell "ls '/sdcard/Movies/E Screen Recorder/'") -join "`n"
adb -s $Serial shell am force-stop $Package
cmd /c "adb -s $Serial exec-out run-as $Package cat $prefs > `"$backup`""
$xml = Get-Content $backup -Raw -Encoding UTF8
if ($xml -notmatch "<map") { throw "could not read the settings file (is it a debug build?)" }
# purpose = plain (2), already past the introduction
$work = $xml -replace '<(long|int) name="flutter\.purpose"[^>]*/>', ''
$work = $work -replace '<boolean name="flutter\.onboarded"[^>]*/>', ''
$work = $work -replace '</map>', '<boolean name="flutter.onboarded" value="true" /><long name="flutter.purpose" value="2" /></map>'
$tmp = Join-Path $env:TEMP "ready_prefs.xml"
[IO.File]::WriteAllText($tmp, $work, (New-Object Text.UTF8Encoding $false))
adb -s $Serial push $tmp /data/local/tmp/ready_prefs.xml | Out-Null
adb -s $Serial shell "run-as $Package cp /data/local/tmp/ready_prefs.xml $prefs"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
$codeA = 1; $codeB = 1
try {
  adb -s $Serial shell appops set $Package SYSTEM_ALERT_WINDOW deny
  & $maestro --device $Serial test --test-output-dir "$OutDir\a" maestro\ux_ready_a.yaml
  $codeA = $LASTEXITCODE
  adb -s $Serial shell appops set $Package SYSTEM_ALERT_WINDOW allow
  & $maestro --device $Serial test --test-output-dir "$OutDir\b" maestro\ux_ready_b.yaml
  $codeB = $LASTEXITCODE
} finally {
  adb -s $Serial shell appops set $Package SYSTEM_ALERT_WINDOW $prev
  adb -s $Serial shell am force-stop $Package
  adb -s $Serial push $backup /data/local/tmp/ready_restore.xml | Out-Null
  adb -s $Serial shell "run-as $Package cp /data/local/tmp/ready_restore.xml $prefs"
  adb -s $Serial shell "rm /data/local/tmp/ready_prefs.xml /data/local/tmp/ready_restore.xml"
  Write-Output "permission back to '$prev' and settings of the phone put back"
}
$after = (adb -s $Serial shell "ls -t '/sdcard/Movies/E Screen Recorder/'") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$new = $after | Where-Object { $before -notmatch [regex]::Escape($_) }
Write-Output "new files (remove with qa_data.ps1): $($new -join ', ')"
if ($codeA -eq 0 -and $codeB -eq 0) { Write-Output "RESULT: PASS (A=$codeA, B=$codeB)" } else { Write-Output "RESULT: FAIL (A=$codeA, B=$codeB)"; exit 1 }
