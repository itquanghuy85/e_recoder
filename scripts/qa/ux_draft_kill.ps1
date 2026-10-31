param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_draft_kill"
)
# The app killed while it builds the automatic edit of a recording: runs maestro/ux_third_party.yaml in the
# background (Google Calculator, four taps), kills the whole process as soon as the build job is written down
# (draft.pending in the settings), then launches the app again and reads the project: the marks must be
# there and the job crossed out. Debug build (run-as). The video is kept.
$ErrorActionPreference = "Continue"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$prefs = "shared_prefs/FlutterSharedPreferences.xml"
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
$m = Start-Process -FilePath $maestro -ArgumentList @("--device", $Serial, "test", "--test-output-dir", $OutDir, "maestro\ux_third_party.yaml") -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\draft_kill.log"
$seen = $false
for ($i = 0; $i -lt 600; $i++) {
  Start-Sleep -Milliseconds 300
  if ((adb -s $Serial shell "run-as $Package cat $prefs") -match "draft\.pending") { $seen = $true; break }
}
adb -s $Serial shell am force-stop $Package
Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue
Write-Output "build job seen: $seen; app killed"
$db = Join-Path $env:TEMP "draft_kill.db"
cmd /c "adb -s $Serial exec-out run-as $Package cat databases/projects.db > `"$db`""
Write-Output "right after the kill:"
python -I "$PSScriptRoot\marks_of_latest.py" $db
$pending = (adb -s $Serial shell "run-as $Package cat $prefs") -match "draft\.pending"
Write-Output "job still written down: $pending"
adb -s $Serial shell am start -n "$Package/.MainActivity" | Out-Null
Start-Sleep 30
cmd /c "adb -s $Serial exec-out run-as $Package cat databases/projects.db > `"$db`""
Write-Output "after launching again (30 s):"
python -I "$PSScriptRoot\marks_of_latest.py" $db
$pending = (adb -s $Serial shell "run-as $Package cat $prefs") -match "draft\.pending"
Write-Output "job still written down: $pending"
