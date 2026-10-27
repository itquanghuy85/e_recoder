# Verifies that everything the Play Console asks for exists and has the right size / length.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fail = @()
function Check($ok, $msg) { if ($ok) { "  ok   $msg" } else { "  FAIL $msg"; $script:fail += $msg } }
function Size($p) { $i = [System.Drawing.Image]::FromFile($p); $r = @($i.Width, $i.Height); $i.Dispose(); $r }

$cfg = Get-Content (Join-Path $root "store/store_config.json") -Raw -Encoding UTF8 | ConvertFrom-Json
"Config"
Check ([bool]$cfg.developer.supportEmail) "developer.supportEmail is set"
Check ([bool]$cfg.site.baseUrl) "site.baseUrl is set (privacy policy URL)"

foreach ($loc in @("vi-VN", "en-US")) {
  "Listing $loc"
  $m = Join-Path $root "fastlane/metadata/android/$loc"
  $t = (Get-Content "$m/title.txt" -Raw -Encoding UTF8).Trim()
  $s = (Get-Content "$m/short_description.txt" -Raw -Encoding UTF8).Trim()
  $f = (Get-Content "$m/full_description.txt" -Raw -Encoding UTF8).Trim()
  Check ($t.Length -le 30 -and $t.Length -gt 0) "title <= 30 chars ($($t.Length))"
  Check ($s.Length -le 80 -and $s.Length -gt 0) "short description <= 80 chars ($($s.Length))"
  Check ($f.Length -le 4000 -and $f.Length -gt 200) "full description <= 4000 chars ($($f.Length))"
  Check (Test-Path "$m/changelogs/1.txt") "changelog for versionCode 1"
  $icon = "$m/images/icon.png"
  if (Test-Path $icon) { $d = Size $icon; Check ($d[0] -eq 512 -and $d[1] -eq 512 -and (Get-Item $icon).Length -lt 1MB) "icon 512x512 < 1 MB" } else { Check $false "icon.png exists" }
  $fg = "$m/images/featureGraphic.png"
  if (Test-Path $fg) { $d = Size $fg; Check ($d[0] -eq 1024 -and $d[1] -eq 500) "feature graphic 1024x500" } else { Check $false "featureGraphic.png exists" }
  $ph = @(Get-ChildItem "$m/images/phoneScreenshots" -Filter *.png -ErrorAction SilentlyContinue)
  Check ($ph.Count -ge 2 -and $ph.Count -le 8) "2-8 phone screenshots ($($ph.Count))"
  foreach ($p in $ph) {
    $d = Size $p.FullName
    $ratio = [Math]::Max($d[0], $d[1]) / [Math]::Min($d[0], $d[1])
    Check ($d[0] -ge 320 -and $d[1] -ge 320 -and $d[0] -le 3840 -and $d[1] -le 3840 -and $ratio -le 2) "$($p.Name) $($d[0])x$($d[1]) ratio $([Math]::Round($ratio,2))"
  }
}
"Videos"
Check (Test-Path (Join-Path $root "store/video/promo.mp4")) "store/video/promo.mp4"
Check (Test-Path (Join-Path $root "store/video/permission_demo.mp4")) "store/video/permission_demo.mp4"
"Build"
Check (Test-Path (Join-Path $root "android/key.properties")) "android/key.properties (upload key) present"
if ($fail.Count) { "`n$($fail.Count) problem(s)."; exit 1 } else { "`nOK" }
