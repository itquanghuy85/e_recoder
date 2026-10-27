param(
  [string]$Out = "site_dist",
  [string]$Email = ""   # preview only: overrides developer.supportEmail without touching the config
)
# Fills the {{TOKENS}} in site/ from store/store_config.json and writes the ready-to-host copy to $Out.
# Refuses to build while the support e-mail is empty: a privacy policy without a contact is rejected by Google Play.
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$cfg = Get-Content (Join-Path $root "store/store_config.json") -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Email) { $cfg.developer.supportEmail = $Email }
if (-not $cfg.developer.supportEmail) { throw "Set developer.supportEmail in store/store_config.json first." }
$map = @{
  "{{SUPPORT_EMAIL}}" = $cfg.developer.supportEmail
  "{{DEVELOPER}}"     = $cfg.developer.name
  "{{PLAY_URL}}"      = $cfg.playUrl
  "{{UPDATED}}"       = $cfg.site.updated
  "{{YEAR}}"          = (Get-Date).Year.ToString()
}
$dest = Join-Path $root $Out
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Copy-Item (Join-Path $root "site") $dest -Recurse
Get-ChildItem $dest -Recurse -Include *.html | ForEach-Object {
  $t = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
  foreach ($k in $map.Keys) { $t = $t.Replace($k, $map[$k]) }
  [IO.File]::WriteAllText($_.FullName, $t, (New-Object Text.UTF8Encoding($false)))
}
$left = Get-ChildItem $dest -Recurse -Include *.html | Select-String -Pattern "\{\{[A-Z_]+\}\}"
if ($left) { throw "Unfilled tokens: $($left | Select-Object -First 3 | ForEach-Object { $_.Line.Trim() })" }
"Built $dest. Privacy URL: $($cfg.site.baseUrl)/vi/privacy.html"
