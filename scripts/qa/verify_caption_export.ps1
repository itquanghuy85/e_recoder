param(
  [string]$Serial = "R5CY6323KMX",
  # seconds at which to cut frames (default: inside word 1, 2, 3, 4 of cue 1, a gap, cue 2, after the last cue)
  [string]$At = "0.6,2.2,3.7,5.2,6.5,7.6,9.6",
  [string]$Out = "$env:TEMP\esr_caption_verify",
  # ffmpeg filter for each frame. Default: the whole frame, 420 px tall. For the lower third only:
  # "crop=iw:ih*0.35:0:ih*0.6,scale=-2:240"
  [string]$Vf = "scale=-2:420",
  # Put the export in the QA manifest, so qa_data.ps1 -Action clean may delete it later. Use it only for
  # exports a test just made, never for a real one.
  [switch]$Record
)
# Pulls the newest edited export (ESR_edit_*.mp4) from the phone and reports what is really in it:
# container, video/audio durations (sync), and a contact sheet of frames (view $Out\sheet.png).
# The test video carries a burned-in timecode, so each frame also shows which source time it is.
$ff = "C:\ffmpeg\bin\ffmpeg.exe"
$fp = "C:\ffmpeg\bin\ffprobe.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$env:MSYS_NO_PATHCONV = "1"
$name = (adb -s $Serial shell "ls -t '/sdcard/Movies/E Screen Recorder/' | grep ESR_edit | head -1").Trim()
if (-not $name) { Write-Error "no ESR_edit file on $Serial"; exit 1 }
$local = Join-Path $Out $name
adb -s $Serial pull "/sdcard/Movies/E Screen Recorder/$name" $local | Out-Null
Write-Output "file: $name"
if ($Record) { & "$PSScriptRoot\qa_data.ps1" -Action record -Name $name -Serial $Serial | Out-Null }
& $fp -v error -show_entries "format=duration,size:stream=codec_type,codec_name,width,height,start_time,duration,nb_frames" -of "default=nw=1" $local
$i = 0
$pngs = @()
foreach ($t in ($At -split "," | ForEach-Object { [double]$_ })) {
  $png = Join-Path $Out ("f{0}.png" -f $i)
  & $ff -y -loglevel error -ss $t -i $local -frames:v 1 -vf $Vf $png
  if (Test-Path $png) { $pngs += $png }
  $i++
}
if ($pngs.Count -gt 0) {
  $inputs = @()
  foreach ($p in $pngs) { $inputs += @("-i", $p) }
  & $ff -y -loglevel error @inputs -filter_complex "hstack=inputs=$($pngs.Count)" (Join-Path $Out "sheet.png")
  Write-Output "contact sheet: $Out\sheet.png"
}
& $ff -hide_banner -i $local -af volumedetect -vn -f null NUL 2>&1 | Select-String "mean_volume|max_volume"
