param(
  [string]$Lang = "vi",
  [switch]$Collect   # copy the newest Maestro store_<lang> screenshots into store/raw/<lang> first
)
# Frames the raw screenshots into Play Store images and renders the feature graphic.
#   1) powershell scripts\run_flow.ps1 store_vi -Cold        (device connected; writes screenshots under ~/.maestro/tests)
#   2) powershell scripts\store\make_store_assets.ps1 -Collect
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $root
if ($Collect) {
  $dirs = Get-ChildItem "$env:USERPROFILE\.maestro\tests" -Directory | Sort-Object LastWriteTime -Descending
  $shots = $null
  foreach ($d in $dirs) {
    $hit = Get-ChildItem $d.FullName -Recurse -Filter "${Lang}_0*.png" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "takeScreenshot" }
    if ($hit.Count -ge 5) { $shots = $hit; break }
  }
  if (-not $shots) { throw "No store screenshots found. Run: scripts\run_flow.ps1 store_$Lang -Cold" }
  New-Item -ItemType Directory -Force "store/raw/$Lang" | Out-Null
  foreach ($f in $shots) { Copy-Item $f.FullName ("store/raw/$Lang/" + ($f.Name -replace "^${Lang}_", "")) -Force }
  "Collected $($shots.Count) screenshots."
}
flutter test tool/make_store_assets_test.dart
python tool/gen_store_meta.py
"Done. Check with scripts\store\check_assets.ps1"
