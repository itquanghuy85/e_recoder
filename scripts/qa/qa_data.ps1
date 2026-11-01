param(
  [ValidateSet("record", "list", "clean")][string]$Action = "list",
  [string]$Serial = "R5CY6323KMX",
  # record: this file name; default the newest ESR_edit_* export on the phone
  [string]$Name = "",
  # clean: really delete. Without it nothing is changed (dry run).
  [switch]$Apply,
  [string]$Package = "com.huluca.escreenrecorder",
  # clean: also remove the project of a video a test picked from Downloads (not in MediaStore as ours):
  # the end of its project uri, e.g. "msf%3A248"
  [string[]]$PickedProject = @()
)
# Test data made by QA runs (exports and the projects opened from them).
#
# Safety rules, so real user data is never touched:
#  * Only files named in the manifest (test-results/qa_created_files.txt) are ever deleted. The manifest
#    is filled by `-Action record` / verify_caption_export.ps1, i.e. by a test that made the file.
#  * The projects database is only edited when `adb run-as` works, which a release build never allows,
#    on a COPY (backed up first), and only the rows of the media being deleted.
#  * Dry run by default.
$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifest = Join-Path $root "test-results\qa_created_files.txt"
New-Item -ItemType Directory -Force (Split-Path $manifest) | Out-Null
if (-not (Test-Path $manifest)) { New-Item -ItemType File $manifest | Out-Null }
$dir = "/sdcard/Movies/E Screen Recorder"

function Get-MediaId([string]$display) {
  # Filtered here, not with --where: quoting a SQL string through adb on Windows is unreliable.
  $rows = adb -s $Serial shell "content query --uri content://media/external/video/media --projection _id:_display_name"
  foreach ($r in $rows) {
    if ($r -match "_id=(\d+), _display_name=(.*)$" -and $Matches[2].Trim() -eq $display) { return $Matches[1] }
  }
  return $null
}

if ($Action -eq "record") {
  if (-not $Name) { $Name = (adb -s $Serial shell "ls -t '$dir' | grep ESR_edit | head -1").Trim() }
  if (-not $Name) { Write-Error "no ESR_edit file on the phone"; exit 1 }
  if (-not ((Get-Content $manifest) -contains $Name)) { Add-Content $manifest $Name }
  Write-Output "recorded: $Name"
  exit 0
}

$names = @(Get-Content $manifest | Where-Object { $_.Trim() })
if ($Action -eq "list") {
  if ($names.Count -eq 0) { Write-Output "manifest is empty: nothing to clean"; exit 0 }
  foreach ($n in $names) {
    $id = Get-MediaId $n
    Write-Output ("{0}  media id: {1}" -f $n, $(if ($id) { $id } else { "(not on the phone)" }))
  }
  exit 0
}

# clean
if ($names.Count -eq 0 -and $PickedProject.Count -eq 0) { Write-Output "manifest is empty: nothing to clean"; exit 0 }
$ids = @()
foreach ($n in $names) {
  $id = Get-MediaId $n
  if ($id) { $ids += $id }
  Write-Output ("{0}: {1}" -f $(if ($Apply) { "delete" } else { "would delete" }), "$n (media $id)")
  if ($Apply -and $id) {
    adb -s $Serial shell "rm '$dir/$n'" | Out-Null
    adb -s $Serial shell "content delete --uri content://media/external/video/media/$id" | Out-Null
  }
}
# The projects of those videos live in the app's debug database.
$canRunAs = $false
try { $null = adb -s $Serial shell "run-as $Package ls databases" 2>&1; $canRunAs = ($LASTEXITCODE -eq 0) } catch {}
if (($ids.Count -gt 0 -or $PickedProject.Count -gt 0) -and $canRunAs) {
  $orig = Join-Path $env:TEMP "esr_projects_orig.db"
  $edit = Join-Path $env:TEMP "esr_projects_edit.db"
  adb -s $Serial shell "am force-stop $Package" | Out-Null
  cmd /c "adb -s $Serial exec-out run-as $Package cat databases/projects.db > `"$orig`""
  Copy-Item $orig $edit -Force
  $refs = @($ids) + @($PickedProject | ForEach-Object { "uri:$_" })
  $removed = python "$PSScriptRoot\projects_db.py" $edit @refs
  Write-Output ("{0}: {1} project row(s) of those videos" -f $(if ($Apply) { "remove" } else { "would remove" }), $removed)
  if ($Apply -and [int]$removed -gt 0) {
    $bak = Join-Path $root ("test-results\projects_backup_{0}.db" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    Copy-Item $orig $bak -Force
    adb -s $Serial push $edit /data/local/tmp/esr_projects.db | Out-Null
    adb -s $Serial shell "run-as $Package cp /data/local/tmp/esr_projects.db databases/projects.db; rm /data/local/tmp/esr_projects.db" | Out-Null
    Write-Output "backup of the database before the edit: $bak"
  }
} elseif ($ids.Count -gt 0) {
  Write-Output "run-as not available (release build?): projects database left alone"
}
if ($Apply) { Set-Content $manifest @(); Write-Output "manifest cleared" }
