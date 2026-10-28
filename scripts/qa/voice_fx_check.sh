#!/usr/bin/env bash
# Voice effects and noise reduction on a real device, measured:
#   scripts/qa/voice_fx_check.sh SERIAL
# 1. makes three sources with ffmpeg (a 440 Hz tone, noise + tone bursts, Windows text-to-speech)
# 2. runs integration_test/voice_fx_device_test.dart (the native code does the work)
# 3. pulls every result and prints: length, level, pitch of the tone, noise in the pauses
set -uo pipefail
S=${1:?serial}

# The phone must stay awake and unlocked while the test runs (a sleeping screen stops the frames).
awake() {
  adb -s "$S" shell input keyevent KEYCODE_WAKEUP
  adb -s "$S" shell wm dismiss-keyguard >/dev/null 2>&1
  adb -s "$S" shell svc power stayon usb >/dev/null 2>&1
}

FF=${FFMPEG:-/c/ffmpeg/bin/ffmpeg.exe}
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(cygpath -m "$(pwd)")/build/vfx
mkdir -p "$W/out"
"$FF" -y -loglevel error -f lavfi -i "sine=frequency=440:duration=6" -c:a aac "$W/it_tone.m4a"
"$FF" -y -loglevel error -f lavfi -i "sine=frequency=440:duration=10,volume='if(lt(mod(t,2),1),0.5,0)':eval=frame" \
  -f lavfi -i "anoisesrc=color=pink:amplitude=0.03:duration=10:seed=3" \
  -filter_complex "amix=inputs=2:duration=first:normalize=0" -c:a aac "$W/it_noisy.m4a"
powershell -NoProfile -Command "Add-Type -AssemblyName System.Speech; \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; \$s.SetOutputToWaveFile('$W/speech.wav'); \$s.Speak('This is a short test of the voice effects. The quick brown fox jumps over the lazy dog. One, two, three, four, five.'); \$s.Dispose()"
"$FF" -y -loglevel error -i "$W/speech.wav" -c:a aac -ar 44100 -ac 1 "$W/it_speech.m4a"

awake
LOG="$W/run.log"; : > "$LOG"
flutter test integration_test/voice_fx_device_test.dart -d "$S" > "$LOG" 2>&1 &
PID=$!
pushed=""
pulled=""
grep_outs() { grep "^OUT " "$LOG" > "$W/outs.txt"; }
while kill -0 $PID 2>/dev/null; do
  if [ -z "$pushed" ] && grep -q "STEP need_voice" "$LOG"; then
    for f in it_tone it_noisy it_speech; do
      MSYS_NO_PATHCONV=1 adb -s "$S" push "$W/$f.m4a" /data/local/tmp/$f.m4a >/dev/null
      MSYS_NO_PATHCONV=1 adb -s "$S" shell run-as com.huluca.escreenrecorder cp /data/local/tmp/$f.m4a files/$f.m4a
    done
    pushed=1
  fi
  # The test waits a few seconds after "STEP done": pull the results then (the app is removed afterwards).
  if [ -z "$pulled" ] && grep -q "STEP done" "$LOG"; then
    grep_outs
    while read -r _ src fx dn path ms; do
      MSYS_NO_PATHCONV=1 adb -s "$S" exec-out run-as com.huluca.escreenrecorder cat "$path" > "$W/out/${src}_${fx}_${dn}.m4a"
    done < "$W/outs.txt"
    pulled=1
  fi
  sleep 1
done
wait $PID; RC=$?
grep -E "All tests passed|Some tests failed" "$LOG" | tail -1
for f in it_tone it_noisy it_speech; do cp "$W/$f.m4a" "$W/out/${f}_orig.m4a"; done
python "$HERE/voice_fx_report.py" "$W/out" "$FF"
exit $RC
