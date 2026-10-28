#!/usr/bin/env bash
# Automatic captions on a real device with real speech:
#   scripts/qa/auto_captions_check.sh SERIAL [vi|en]
# 1. the integration test installs the (debug) app and waits for a clip
# 2. this script has the phone's own text-to-speech voice say three sentences (DebugTts, debug builds
#    only), joins them with pauses into a video, and puts it in the app's folder
# 3. the test drives the editor: Text tab -> automatic captions -> language -> start -> captions
#    (checked in the saved project), undo/redo, export; frames of the export are pulled for a look
set -uo pipefail
S=${1:?serial}

# The phone must stay awake and unlocked while the test runs (a sleeping screen stops the frames).
awake() {
  adb -s "$S" shell input keyevent KEYCODE_WAKEUP
  adb -s "$S" shell wm dismiss-keyguard >/dev/null 2>&1
  adb -s "$S" shell svc power stayon usb >/dev/null 2>&1
}

LANG_SHORT=${2:-vi}
FF=${FFMPEG:-/c/ffmpeg/bin/ffmpeg.exe}
W=$(cygpath -m "$(pwd)")/build/ac_$LANG_SHORT
rm -rf "$W"; mkdir -p "$W"
PKG=com.huluca.escreenrecorder

if [ "$LANG_SHORT" = "vi" ]; then
  TAG=vi-VN
  S1="Xin chào các bạn, đây là video thử nghiệm phụ đề tự động."
  S2="Hôm nay mình sẽ hướng dẫn cách quay màn hình điện thoại."
  S3="Cảm ơn các bạn đã xem video."
else
  TAG=en-US
  S1="Hello everyone, this is a test video for automatic captions."
  S2="Today I will show you how to record your phone screen."
  S3="Thank you for watching this video."
fi

awake
LOG="$W/run.log"; : > "$LOG"
flutter test integration_test/auto_captions_device_test.dart -d "$S" --dart-define=CAPTION_LANG=$LANG_SHORT > "$LOG" 2>&1 &
PID=$!
seen=""
speak() { # index text
  MSYS_NO_PATHCONV=1 adb -s "$S" shell "am broadcast -n $PKG/.DebugTts -a com.huluca.escreenrecorder.DEBUG_TTS --es text '$2' --es lang $TAG --es out tts_$1.wav" >/dev/null
  for i in $(seq 1 60); do
    r=$(MSYS_NO_PATHCONV=1 adb -s "$S" shell run-as $PKG cat files/tts_$1.wav.done 2>/dev/null | tr -d '\r')
    [ -n "$r" ] && break
    sleep 1
  done
  echo "tts $1: $r"
  MSYS_NO_PATHCONV=1 adb -s "$S" exec-out run-as $PKG cat files/tts_$1.wav > "$W/tts_$1.wav"
}
while kill -0 $PID 2>/dev/null; do
  for step in $(grep -o "^STEP [A-Za-z_]*" "$LOG" | awk '{print $2}' | sort -u); do
    case " $seen " in *" $step "*) continue;; esac
    seen="$seen $step"
    case "$step" in
      need_files)
        sleep 3
        speak 1 "$S1"; speak 2 "$S2"; speak 3 "$S3"
        "$FF" -y -loglevel error -f lavfi -i "anullsrc=r=22050:cl=mono" -t 1.2 "$W/sil.wav"
        printf "file '%s'\nfile '%s'\nfile '%s'\nfile '%s'\nfile '%s'\nfile '%s'\n" "$W/sil.wav" "$W/tts_1.wav" "$W/sil.wav" "$W/tts_2.wav" "$W/sil.wav" "$W/tts_3.wav" > "$W/list.txt"
        "$FF" -y -loglevel error -f concat -safe 0 -i "$W/list.txt" -ar 22050 -ac 1 "$W/speech.wav"
        DUR=$("$FF" -i "$W/speech.wav" 2>&1 | grep -o "Duration: [0-9:.]*" | head -1)
        echo "speech clip: $DUR"
        "$FF" -y -loglevel error -f lavfi -i "testsrc=size=720x1600:rate=30" -i "$W/speech.wav" -shortest \
          -c:v libx264 -pix_fmt yuv420p -c:a aac "$W/it_speech.mp4"
        MSYS_NO_PATHCONV=1 adb -s "$S" push "$W/it_speech.mp4" /data/local/tmp/it_speech.mp4 >/dev/null
        MSYS_NO_PATHCONV=1 adb -s "$S" shell run-as $PKG cp /data/local/tmp/it_speech.mp4 files/it_speech.mp4;;
      exported)
        sleep 1
        NEWEST=$(MSYS_NO_PATHCONV=1 adb -s "$S" shell "ls -t '/sdcard/Movies/E Screen Recorder/'ESR_edit_* | head -1" | tr -d '\r')
        MSYS_NO_PATHCONV=1 adb -s "$S" pull "$NEWEST" "$W/exported.mp4" >/dev/null;;
      *) adb -s "$S" exec-out screencap -p > "$W/$step.png";;
    esac
  done
  sleep 1
done
wait $PID; RC=$?
echo "----- captions the app made ($TAG) -----"
grep "^CAP " "$LOG"
echo "----- the sentences that were spoken -----"
printf "%s\n%s\n%s\n" "$S1" "$S2" "$S3"
grep -E "All tests passed|Some tests failed" "$LOG" | tail -1
if [ -f "$W/exported.mp4" ]; then
  n=0
  grep "^CAP " "$LOG" | head -3 | while read -r _ a b rest; do
    n=$((n+1)); mid=$(( (a + b) / 2 ))
    t=$(awk -v m=$mid 'BEGIN{printf "%.2f", m/1000}')
    "$FF" -y -loglevel error -ss "$t" -i "$W/exported.mp4" -frames:v 1 -vf scale=360:-1 "$W/frame_$n.png"
  done
fi
exit $RC
