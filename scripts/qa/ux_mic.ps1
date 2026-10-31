param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_mic"
)
# Takes the microphone permission away, runs maestro/ux_mic_denied.yaml, and puts back what it changed:
# the permission is granted again and the sound choice (rec.audio) goes back to its default (microphone).
# Needs a debug build (adb run-as). Leftover system dialogs from an earlier run are closed first.
$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$prefs = "shared_prefs/FlutterSharedPreferences.xml"
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
try {
  adb -s $Serial shell input keyevent KEYCODE_BACK
  adb -s $Serial shell input keyevent KEYCODE_HOME
  adb -s $Serial shell am force-stop $Package
  adb -s $Serial shell pm revoke $Package android.permission.RECORD_AUDIO
  & $maestro --device $Serial test --test-output-dir $OutDir maestro\ux_mic_denied.yaml
  $code = $LASTEXITCODE
} finally {
  adb -s $Serial shell am force-stop $Package
  adb -s $Serial shell pm grant $Package android.permission.RECORD_AUDIO
  $tmp = Join-Path $env:TEMP "ux_mic_prefs.xml"
  cmd /c "adb -s $Serial exec-out run-as $Package cat $prefs > `"$tmp`""
  $xml = Get-Content $tmp -Raw -Encoding UTF8
  if ($xml -match "<map") {
    $xml = $xml -replace '<(long|int) name="flutter\.rec\.audio"[^>]*/>', ''
    [IO.File]::WriteAllText($tmp, $xml, (New-Object Text.UTF8Encoding $false))
    adb -s $Serial push $tmp /data/local/tmp/ux_mic_prefs.xml | Out-Null
    adb -s $Serial shell "run-as $Package cp /data/local/tmp/ux_mic_prefs.xml $prefs; rm /data/local/tmp/ux_mic_prefs.xml"
  }
  Write-Output "microphone permission and sound choice put back"
}
if ($code -eq 0) { Write-Output "RESULT: flow PASS" } else { Write-Output "RESULT: FAIL (maestro exit $code)"; exit 1 }
