param(
  [Parameter(Mandatory = $true)][string]$Flow,
  [string]$Serial = "T4E6S8IFU4AQBM8L",
  [switch]$Cold,
  # Package the flow opens while recording. Android 12+ hides overlays over Settings on Samsung:
  # pass e.g. com.sec.android.app.popupcalculator there.
  [string]$OtherApp = ""
)
# Runs one Maestro flow on a device the way QA does it here:
#  - UTF-8 JVM flags (Vietnamese selectors),
#  - 3uTools (PC companion) kept out of the foreground,
#  - optional cold start (adb force-stop + start) so a leftover recording/service cannot leak in.
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
$env:Path = "D:\JOB\_tools\maestro\x\maestro\bin;$env:Path"
$pkg = "com.huluca.escreenrecorder"
adb -s $Serial shell input keyevent KEYCODE_WAKEUP | Out-Null
adb -s $Serial shell am force-stop cn.tools3u.mobile | Out-Null
function Test-AppReady {
  # The Flutter tree is up once the semantic ids exist (profile_card on the Record tab, or any
  # screen of ours); a cold debug start can take 10-20 s and 3uTools/launcher may steal focus.
  $xml = (adb -s $Serial exec-out uiautomator dump /dev/tty 2>$null) -join "`n"
  return ($xml -match "package=`"$pkg`"") -and ($xml -match "Tab 1 of 3|editor_play|profile_card|Tab 2 of 3")
}
adb -s $Serial shell am force-stop cn.tools3u.mobile | Out-Null
if ($Cold) {
  adb -s $Serial shell am force-stop $pkg | Out-Null
  adb -s $Serial shell am force-stop com.android.settings | Out-Null
}
for ($i = 0; $i -lt 6; $i++) {
  adb -s $Serial shell am force-stop cn.tools3u.mobile | Out-Null
  adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
  adb -s $Serial shell am start -n "$pkg/.MainActivity" | Out-Null
  $deadline = (Get-Date).AddSeconds($(if ($Cold -and $i -eq 0) { 30 } else { 15 }))
  $ready = $false
  while ((Get-Date) -lt $deadline) {
    Start-Sleep 3
    if (Test-AppReady) { $ready = $true; break }
  }
  if ($ready) { break }
  adb -s $Serial shell am force-stop $pkg | Out-Null
}
$root = Split-Path $PSScriptRoot -Parent
$file = if (Test-Path $Flow) { $Flow } else { Join-Path $root "maestro\$Flow.yaml" }
Push-Location $root
try {
  # maestro prints JVM notices on stderr; do not let PowerShell treat that as an error.
  $ErrorActionPreference = "Continue"
  # The first Maestro run after an install can lose the foreground (the driver apps get
  # (re)installed): if it dies within its first few steps, bring the app back and run once more.
  # 3uTools (PC companion) keeps relaunching its phone app and steals the foreground mid-flow;
  # keep it stopped for the duration of the run (nothing is disabled or uninstalled).
  $guard = Start-Job -ScriptBlock { param($s) while ($true) { adb -s $s shell am force-stop cn.tools3u.mobile 2>$null | Out-Null; Start-Sleep 2 } } -ArgumentList $Serial
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    $envArgs = @(); if ($OtherApp) { $envArgs = @("-e", "OTHER_APP=$OtherApp") }
    $out = & maestro.bat --device $Serial test @envArgs $file 2>&1 | ForEach-Object { "$_" }
    $ran = @($out | Where-Object { $_ -match "COMPLETED" }).Count
    $failed = @($out | Where-Object { $_ -match "FAILED" }).Count
    if ($failed -eq 0 -and $ran -gt 0) { break }
    if ($attempt -eq 1 -and $ran -le 4) {
      adb -s $Serial shell am force-stop $pkg | Out-Null
      adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
      adb -s $Serial shell am start -n "$pkg/.MainActivity" | Out-Null
      Start-Sleep 15
      continue
    }
    break
  }
  $out | Where-Object { $_ -match "FAILED|Assertion is false" } | Select-Object -First 6
  if ($failed -gt 0 -or $ran -eq 0) { "RESULT: FAIL ($Flow) steps=$ran failed=$failed"; exit 1 }
  "RESULT: PASS ($Flow) steps=$ran"
} finally {
  if ($guard) { Stop-Job $guard -ErrorAction SilentlyContinue; Remove-Job $guard -Force -ErrorAction SilentlyContinue }
  Pop-Location
}