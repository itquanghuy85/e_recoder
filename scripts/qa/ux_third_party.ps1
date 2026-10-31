param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_third_party"
)
# Records Google Calculator (installed from Google Play) with five real taps, exports, then prints the
# marks of the saved project (type, step, place). Needs a debug build (adb run-as). Videos are kept.
$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
adb -s $Serial shell input keyevent KEYCODE_HOME
adb -s $Serial shell am force-stop $Package
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
& $maestro --device $Serial test --test-output-dir $OutDir maestro\ux_third_party.yaml
$code = $LASTEXITCODE
$db = Join-Path $env:TEMP "third_party_projects.db"
cmd /c "adb -s $Serial exec-out run-as $Package cat databases/projects.db > `"$db`""
python -I "$PSScriptRoot\marks_of_latest.py" $db
adb -s $Serial shell am force-stop $Package
if ($code -eq 0) { Write-Output "RESULT: flow PASS (read the marks above)" } else { Write-Output "RESULT: FAIL (maestro exit $code)"; exit 1 }
