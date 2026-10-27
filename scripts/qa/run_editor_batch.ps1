param([string]$Serial = "T4E6S8IFU4AQBM8L", [string[]]$Flows = @("e2_overlays", "e2b_crop_rotate", "e3_motion", "e4_audio"))
# Runs editor flows one after another (cold app each time) and verifies the export of each.
foreach ($f in $Flows) {
  adb -s $Serial shell am force-stop com.huluca.escreenrecorder | Out-Null
  adb -s $Serial shell am force-stop dev.mobile.maestro | Out-Null
  adb -s $Serial shell am force-stop dev.mobile.maestro.test | Out-Null
  adb -s $Serial shell am start -n com.huluca.escreenrecorder/.MainActivity | Out-Null
  Start-Sleep 8
  "=== $f"
  & powershell -File "$PSScriptRoot\..\run_flow.ps1" $f -Serial $Serial -OtherApp $env:ESR_OTHER 2>&1 | Select-String "FAILED|RESULT"
  & powershell -File "$PSScriptRoot\verify_export.ps1" -Serial $Serial -Out "$env:TEMP\esr_$f" 2>&1 | Select-String "file:|duration=|width=|height=|mean_volume"
}
