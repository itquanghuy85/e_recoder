#!/usr/bin/env bash
# Puts a small test clip (720x1600, 8 s, with a tone) into the app's own folder so that
# integration_test/ can open the editor on it. Needs a debug build (run-as) and ffmpeg.
#   scripts/qa/push_it_clip.sh SERIAL [path-in-app-files, default files/it_clip.mp4]
set -euo pipefail
S=${1:?serial}
DEST=${2:-files/it_clip.mp4}
FF=${FFMPEG:-/c/ffmpeg/bin/ffmpeg.exe}
TMP=$(cygpath -m "$(pwd)")/build/_it_clip
mkdir -p "$TMP"
"$FF" -y -loglevel error -f lavfi -i "testsrc=duration=8:size=720x1600:rate=30" \
  -f lavfi -i "sine=frequency=440:duration=8" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$TMP/it_clip.mp4"
MSYS_NO_PATHCONV=1 adb -s "$S" push "$TMP/it_clip.mp4" /data/local/tmp/it_clip.mp4 >/dev/null
MSYS_NO_PATHCONV=1 adb -s "$S" shell run-as com.huluca.escreenrecorder cp /data/local/tmp/it_clip.mp4 "$DEST"
MSYS_NO_PATHCONV=1 adb -s "$S" shell rm -f /data/local/tmp/it_clip.mp4
rm -rf "$TMP"
echo "pushed to $DEST"
