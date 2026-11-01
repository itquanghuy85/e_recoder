param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_modes"
)
# Runs maestro/ux_editor_modes.yaml. It first removes only the saved editor mode (flutter.editor.advanced)
# so the first look is the default (Basic). The flow ends in Basic, which is also the default.
# Needs a debug build (adb run-as). Nothing is deleted.
$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$prefs = "shared_prefs/FlutterSharedPreferences.xml"
adb -s $Serial shell input keyevent KEYCODE_HOME
adb -s $Serial shell am force-stop $Package
$tmp = Join-Path $env:TEMP "ux_modes_prefs.xml"
cmd /c "adb -s $Serial exec-out run-as $Package cat $prefs > `"$tmp`""
$xml = Get-Content $tmp -Raw -Encoding UTF8
if ($xml -notmatch "<map") { throw "could not read the settings file (is it a debug build?)" }
$xml = $xml -replace '<boolean name="flutter\.editor\.advanced"[^>]*/>', ''
[IO.File]::WriteAllText($tmp, $xml, (New-Object Text.UTF8Encoding $false))
adb -s $Serial push $tmp /data/local/tmp/ux_modes_prefs.xml | Out-Null
adb -s $Serial shell "run-as $Package cp /data/local/tmp/ux_modes_prefs.xml $prefs; rm /data/local/tmp/ux_modes_prefs.xml"
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
& $maestro --device $Serial test --test-output-dir $OutDir maestro\ux_editor_modes.yaml
$code = $LASTEXITCODE
adb -s $Serial shell am force-stop $Package
if ($code -eq 0) { Write-Output "RESULT: flow PASS" } else { Write-Output "RESULT: FAIL (maestro exit $code)"; exit 1 }
