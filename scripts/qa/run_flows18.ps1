param(
  [string]$Serial = "R5CY6323KMX",
  [string[]]$Flows = @("e1_edit_core","e2_overlays","e2_pick_probe","e2_pip_s25","e2b_crop_rotate","e3_motion","e8_tools_zoom","e10_regions","e11_region_motion","e14_pip_portrait","e16_build_from_touches","g3_editor","g7_auto_direct","s1_icon_audit","store_vi","store_en","store_pro","store_video_b"),
  [string]$OutDir = "test-results\flows18",
  [int]$TimeoutMin = 12,
  # Android hides overlay windows over Samsung Settings: flows that record "another app" use this one.
  [string]$OtherApp = "com.sec.android.app.popupcalculator"
)
# Runs the editor flows one after another, each from a cold app, and writes one line per flow to
# $OutDir\results.csv (flow, exit code, first failure line). It never skips or retries a failure.
$ErrorActionPreference = "Continue"
# -Flows "a,b,c" from the command line arrives as one string
$Flows = @($Flows | ForEach-Object { $_ -split "," } | Where-Object { $_ })
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$csv = Join-Path $OutDir "results.csv"
if (-not (Test-Path $csv)) { "flow,exit,first_failure" | Set-Content $csv -Encoding UTF8 }
foreach ($f in $Flows) {
  adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
  adb -s $Serial shell am force-stop com.huluca.escreenrecorder | Out-Null
  # A flow that failed in the system picker leaves it on top of everything: close those too, so one failure
  # cannot make the next flow fail.
  foreach ($pkg in "com.google.android.documentsui","com.android.documentsui","com.sec.android.app.myfiles","com.google.android.apps.photos","com.android.settings","com.sec.android.app.popupcalculator") { adb -s $Serial shell am force-stop $pkg | Out-Null }
  adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
  adb -s $Serial shell cmd statusbar collapse | Out-Null
  $log = Join-Path $OutDir "$f.log"
  $p = Start-Process -FilePath $maestro -ArgumentList @("--device", $Serial, "test", "-e", "OTHER_APP=$OtherApp", "--test-output-dir", "$OutDir\$f", "maestro\$f.yaml") -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -NoNewWindow
  $null = $p.Handle
  if (-not $p.WaitForExit($TimeoutMin * 60000)) { Stop-Process -Id $p.Id -Force; $code = 124 } else { $p.WaitForExit(); $code = $p.ExitCode }
  $fail = ""
  if ($code -ne 0) {
    $m = Select-String -Path $log -Pattern "FAILED|Assertion is false|not found" -SimpleMatch:$false | Select-Object -First 1
    if ($m) { $fail = ($m.Line -replace ",", ";").Trim() } elseif ($code -eq 124) { $fail = "timeout" }
  }
  "$f,$code,$fail" | Add-Content $csv -Encoding UTF8
  Write-Output "$f exit=$code $fail"
}
adb -s $Serial shell am force-stop com.huluca.escreenrecorder | Out-Null



