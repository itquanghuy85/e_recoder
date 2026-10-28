#!/usr/bin/env bash
# The voice effect through the real editor UI, then the exported video is measured:
#   scripts/qa/voice_fx_editor_check.sh SERIAL
# A 1000 Hz voice-over with "Deep" (x0.78) must come out of the export near 780 Hz.
set -uo pipefail
S=${1:?serial}
FF=${FFMPEG:-/c/ffmpeg/bin/ffmpeg.exe}
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(cygpath -m "$(pwd)")/build/vfxe
mkdir -p "$W"
"$FF" -y -loglevel error -f lavfi -i "testsrc=duration=8:size=720x1600:rate=30" \
  -f lavfi -i "sine=frequency=440:duration=8" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$W/it_clip.mp4"
"$FF" -y -loglevel error -f lavfi -i "sine=frequency=1000:duration=6" -c:a aac "$W/it_voice.m4a"

adb -s "$S" shell input keyevent KEYCODE_WAKEUP
LOG="$W/run.log"; : > "$LOG"
flutter test integration_test/voice_fx_editor_test.dart -d "$S" > "$LOG" 2>&1 &
PID=$!
seen=""
while kill -0 $PID 2>/dev/null; do
  for step in $(grep -o "^STEP [A-Za-z_]*" "$LOG" | awk '{print $2}' | sort -u); do
    case " $seen " in *" $step "*) continue;; esac
    seen="$seen $step"
    case "$step" in
      need_files)
        for f in it_clip.mp4 it_voice.m4a; do
          MSYS_NO_PATHCONV=1 adb -s "$S" push "$W/$f" /data/local/tmp/$f >/dev/null
          MSYS_NO_PATHCONV=1 adb -s "$S" shell run-as com.huluca.escreenrecorder cp /data/local/tmp/$f files/$f
        done;;
      exported)
        sleep 1
        NEWEST=$(MSYS_NO_PATHCONV=1 adb -s "$S" shell "ls -t '/sdcard/Movies/E Screen Recorder/'ESR_edit_* | head -1" | tr -d '\r')
        MSYS_NO_PATHCONV=1 adb -s "$S" pull "$NEWEST" "$W/exported.mp4" >/dev/null
        adb -s "$S" exec-out screencap -p > "$W/exported.png";;
      *) adb -s "$S" exec-out screencap -p > "$W/$step.png";;
    esac
  done
  sleep 1
done
wait $PID; RC=$?
grep -E "All tests passed|Some tests failed" "$LOG" | tail -1
if [ -f "$W/exported.mp4" ]; then
  python "$HERE/voice_fx_report.py" --freq "$W/exported.mp4" "$FF"
fi
exit $RC
