param(
  [string]$Serial = "T4E6S8IFU4AQBM8L",
  # seconds at which to cut frames for the contact sheet
  [double[]]$At = @(0.5, 2, 4, 6, 8),
  [string]$Out = "$env:TEMP\esr_verify"
)
# Pulls the newest edited export (ESR_edit_*.mp4) from the phone and reports what is really in it:
# container length, streams, size, and a contact sheet of frames (view $Out\sheet.png).
$ff = "C:\ffmpeg\bin\ffmpeg.exe"
$fp = "C:\ffmpeg\bin\ffprobe.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$env:MSYS_NO_PATHCONV = "1"
$name = (adb -s $Serial shell "ls -t '/sdcard/Movies/E Screen Recorder/' | grep ESR_edit | head -1").Trim()
if (-not $name) { Write-Error "no ESR_edit file on $Serial"; exit 1 }
$local = Join-Path $Out $name
adb -s $Serial pull "/sdcard/Movies/E Screen Recorder/$name" $local | Out-Null
Write-Output "file: $name"
& $fp -v error -show_entries "format=duration,size:stream=codec_type,codec_name,width,height,nb_frames,duration" -of "default=nw=1" $local
$i = 0
$pngs = @()
foreach ($t in $At) {
  $png = Join-Path $Out ("f{0}.png" -f $i)
  & $ff -y -loglevel error -ss $t -i $local -frames:v 1 -vf "scale=-2:360" $png
  if (Test-Path $png) { $pngs += $png }
  $i++
}
if ($pngs.Count -gt 0) {
  $inputs = @()
  foreach ($p in $pngs) { $inputs += @("-i", $p) }
  & $ff -y -loglevel error @inputs -filter_complex "hstack=inputs=$($pngs.Count)" (Join-Path $Out "sheet.png")
  Write-Output "contact sheet: $Out\sheet.png"
}
# loudness over the whole file and per half (spot a muted or ducked stretch)
& $ff -hide_banner -i $local -af volumedetect -vn -f null NUL 2>&1 | Select-String "mean_volume|max_volume"
