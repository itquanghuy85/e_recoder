#!/usr/bin/env bash
# Runs an integration test on a device and helps it along:
#  - when the test prints "STEP need_clip" the test clip is pushed into the app folder
#  - after every "STEP <name>" a screenshot is saved to OUT/<name>.png (the test pauses there)
#   scripts/qa/run_integration.sh SERIAL integration_test/editor_zoom_test.dart [OUT_DIR]
set -uo pipefail
S=${1:?serial}; TEST=${2:?test file}; OUT=${3:-build/it_shots}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; LOG="$OUT/run.log"; : > "$LOG"
adb -s "$S" shell am force-stop com.huluca.escreenrecorder
flutter test "$TEST" -d "$S" > "$LOG" 2>&1 &
PID=$!
seen=""
while kill -0 $PID 2>/dev/null; do
  for step in $(grep -o "^STEP [A-Za-z_]*" "$LOG" | awk '{print $2}' | sort -u); do
    case " $seen " in *" $step "*) continue;; esac
    seen="$seen $step"
    if [ "$step" = "need_clip" ]; then bash "$HERE/push_it_clip.sh" "$S" >/dev/null; continue; fi
    adb -s "$S" exec-out screencap -p > "$OUT/$step.png"
    echo "screenshot: $step"
  done
  sleep 1
done
wait $PID; RC=$?
grep -E "All tests passed|Some tests failed" "$LOG" | tail -1
exit $RC
