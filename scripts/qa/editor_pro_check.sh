#!/usr/bin/env bash
# Editor round on a real phone: play/pause x10, three clips reordered, free rotation, overlay frame, export.
#   scripts/qa/editor_pro_check.sh SERIAL [OUT_DIR]
# After the run the exported video is pulled and the corners of a frame are measured: with the 30 degree
# turn no corner may be black (the picture is enlarged to fill the frame).
set -uo pipefail
S=${1:?serial}; OUT=${2:-build/pro_shots}
HERE=$(cd "$(dirname "$0")" && pwd)
FF=${FFMPEG:-/c/ffmpeg/bin/ffmpeg.exe}
bash "$HERE/run_integration.sh" "$S" integration_test/editor_pro_device_test.dart "$OUT" | tail -3
grep -E "SEGMENTS" "$OUT/run.log" | head -2
NEWEST=$(MSYS_NO_PATHCONV=1 adb -s "$S" shell "ls -t '/sdcard/Movies/E Screen Recorder/'ESR_edit_* | head -1" | tr -d '\r')
MSYS_NO_PATHCONV=1 adb -s "$S" pull "$NEWEST" "$OUT/exported.mp4" >/dev/null
"$FF" -hide_banner -i "$OUT/exported.mp4" 2>&1 | grep -E "Stream #0.*Video|Duration" | cut -c1-140
for t in 0.5 2.5 4; do
  "$FF" -y -loglevel error -ss $t -i "$OUT/exported.mp4" -frames:v 1 "$OUT/f_$t.png"
  for c in "0:0" "iw-24:0" "0:ih-24" "iw-24:ih-24"; do
    v=$("$FF" -loglevel error -i "$OUT/f_$t.png" -vf "crop=24:24:${c%%:*}:${c##*:},scale=1:1,format=gray" -f rawvideo -pix_fmt gray - | od -An -tu1 | tr -d ' ')
    echo "t=$t corner($c) brightness=$v"
  done
done
