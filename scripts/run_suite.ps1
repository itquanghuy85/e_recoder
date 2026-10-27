param(
  [string]$Serial = "T4E6S8IFU4AQBM8L",
  [string[]]$Flows = @(
    "g0_smoke", "g1_record", "g1_library", "g1_no_bar",
    "g2_marker_gallery", "g2_live_markers",
    "g3_editor", "g3_gif", "g3_join", "g3_project",
    "g4_onboarding", "g5_dot_mode", "g6_clean_mode", "g7_auto_direct"
  )
)
# Accepts -Flows a,b,c even through "powershell -File" (which passes one string).
$Flows = @($Flows | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
# Runs every Maestro flow once (cold start each) and prints a PASS/FAIL table.
$root = Split-Path $PSScriptRoot -Parent
$rows = @()
foreach ($f in $Flows) {
  $t0 = Get-Date
  $out = & powershell -File (Join-Path $PSScriptRoot "run_flow.ps1") $f -Serial $Serial -Cold 2>&1 | Select-Object -Last 3
  $res = ($out | Where-Object { $_ -match "RESULT:" } | Select-Object -Last 1)
  if (-not $res) { $res = "RESULT: FAIL ($f) no result" }
  $rows += [pscustomobject]@{ Flow = $f; Result = ($res -replace "RESULT: ", ""); Seconds = [int]((Get-Date) - $t0).TotalSeconds }
}
$rows | Format-Table -AutoSize | Out-String -Width 200
$failed = @($rows | Where-Object { $_.Result -notmatch "^PASS" }).Count
"SUITE: $($rows.Count - $failed)/$($rows.Count) passed"
if ($failed -gt 0) { exit 1 }
