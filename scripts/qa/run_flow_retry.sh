#!/usr/bin/env bash
# Runs a Maestro flow through scripts/run_flow.ps1; if it dies in its first steps (the driver
# sometimes loses the foreground on the first launch) the app is restarted and it runs again.
#   scripts/qa/run_flow_retry.sh SERIAL flow_name [tries]
S=${1:?serial}; FLOW=${2:?flow}; TRIES=${3:-3}
LOG=$(mktemp)
for i in $(seq 1 "$TRIES"); do
  adb -s "$S" shell am force-stop com.huluca.escreenrecorder
  adb -s "$S" shell input keyevent KEYCODE_WAKEUP
  adb -s "$S" shell input keyevent KEYCODE_HOME; sleep 2
  adb -s "$S" shell am start -n com.huluca.escreenrecorder/.MainActivity >/dev/null; sleep 10
  powershell -File "$(dirname "$0")/../run_flow.ps1" "$FLOW" -Serial "$S" > "$LOG" 2>&1
  R=$(grep RESULT "$LOG" | tail -1)
  steps=$(echo "$R" | sed -n 's/.*steps=\([0-9]*\).*/\1/p')
  case "$R" in *PASS*) echo "$R"; rm -f "$LOG"; exit 0;; esac
  if [ "${steps:-0}" -gt 6 ]; then break; fi
done
echo "$R"; tail -4 "$LOG" | cut -c1-160; rm -f "$LOG"; exit 1
