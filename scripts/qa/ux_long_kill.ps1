param(
  [string]$Serial = "R5CY6323KMX",
  [string]$Package = "com.huluca.escreenrecorder",
  [string]$OutDir = "test-results\ux_long_kill"
)
# A real kill in the middle of a long export: part A starts it, then the whole process is killed
# (am force-stop, the export service included), then part B reopens and exports again. Prints the files
# and the export cache at each step. Run scripts/qa/ux_long.ps1 once first (it puts the test video in place).
$ErrorActionPreference = "Continue"
$env:MSYS_NO_PATHCONV = "1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$dir = "/sdcard/Movies/E Screen Recorder"
$maestro = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
function Files { (adb -s $Serial shell "ls '$dir/'") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
function Cache($label) { Write-Output "export cache ($label):"; adb -s $Serial shell "run-as $Package ls -la cache/export 2>/dev/null" }
$before = Files
# Part A runs in the background; as soon as the export service is up, the whole process is killed.
$a = Start-Process -FilePath $maestro -ArgumentList @("--device", $Serial, "test", "--test-output-dir", "$OutDir\a", "maestro\ux_long_kill_a.yaml") -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\kill_a.log"
$up = $false
for ($i = 0; $i -lt 120; $i++) {
  Start-Sleep 1
  if ((adb -s $Serial shell "dumpsys activity services $Package") -match "ExportService") { $up = $true; break }
}
Start-Sleep 3
adb -s $Serial shell am force-stop $Package
Write-Output "export service seen running: $up; killed the app 3 s later"
Stop-Process -Id $a.Id -Force -ErrorAction SilentlyContinue
$codeA = $(if ($up) { 0 } else { 1 })
Start-Sleep 5
$mid = Files
Write-Output "part A exit=$codeA; new files right after the kill (expected none):"
$mid | Where-Object { $before -notcontains $_ } | ForEach-Object { Write-Output "  $_" }
Cache "after the kill"
& $maestro --device $Serial test --test-output-dir "$OutDir\b" maestro\ux_long_kill_b.yaml | Out-Null
$codeB = $LASTEXITCODE
Write-Output "part B exit=$codeB; new files after reopening and exporting again (expected one):"
Files | Where-Object { $mid -notcontains $_ } | ForEach-Object { Write-Output "  $_" }
Cache "after the new export"
if ($codeA -eq 0 -and $codeB -eq 0) { Write-Output "RESULT: flow PASS" } else { Write-Output "RESULT: FAIL"; exit 1 }
