#!/bin/bash
# Mark timing on the S25: clean recording of Samsung Calculator (maestro/ux_mark_timing.yaml), then reads the
# saved project (scripts/qa/marks_timing.py) and cuts frames around the last mark out of the exported video.
# Sets marker.mode = 1 (clean) for the run and always puts the old value back. Debug build (run-as).
# Videos are kept. Usage: bash scripts/qa/ux_mark_timing.sh [serial]
export MSYS_NO_PATHCONV=1
S=${1:-R5CY6323KMX}
A=com.huluca.escreenrecorder
P=shared_prefs/FlutterSharedPreferences.xml
OUT=test-results/ux_mark_timing
MAESTRO="/c/Users/Mr Huy/maestro/maestro/bin/maestro"
FF=/c/ffmpeg/bin
cd "$(dirname "$0")/../.."
rm -rf "$OUT"; mkdir -p "$OUT"

set_mode() { # value
  adb -s $S shell am force-stop $A
  adb -s $S exec-out run-as $A cat $P > "$OUT/prefs.xml"
  python -I - "$OUT/prefs.xml" "$1" <<'EOF'
import re, sys
p, v = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
s, n = re.subn(r'(<long name="flutter\.marker\.mode" value=")\d+(" />)', r"\g<1>" + v + r"\g<2>", s)
if n == 0:
    s = s.replace("<map>", '<map>\n    <long name="flutter.marker.mode" value="%s" />' % v, 1)
open(p, "w", encoding="utf-8", newline="\n").write(s)
EOF
  adb -s $S push "$OUT/prefs.xml" /data/local/tmp/ux_prefs.xml > /dev/null
  adb -s $S shell "cat /data/local/tmp/ux_prefs.xml | run-as $A sh -c 'cat > $P'"
  adb -s $S shell rm /data/local/tmp/ux_prefs.xml
  rm -f "$OUT/prefs.xml"
}

adb -s $S exec-out run-as $A cat $P > "$OUT/prefs_before.xml"
OLD=$(grep -oE 'flutter\.marker\.mode" value="[0-9]+' "$OUT/prefs_before.xml" | grep -oE '[0-9]+$')
OLD=${OLD:-0}
echo "marker.mode before: $OLD"
trap 'set_mode $OLD; echo "marker.mode put back to $OLD"' EXIT
set_mode 1

adb -s $S shell input keyevent KEYCODE_WAKEUP
adb -s $S shell wm dismiss-keyguard
adb -s $S shell am force-stop com.sec.android.app.popupcalculator
JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8" \
  "$MAESTRO" --device $S test --test-output-dir "$OUT/maestro" maestro/ux_mark_timing.yaml > "$OUT/maestro.log" 2>&1
echo "maestro exit: $?"
grep -E "FAILED" "$OUT/maestro.log" | head -3

adb -s $S exec-out run-as $A cat databases/projects.db > "$OUT/projects.db"
python -I scripts/qa/marks_timing.py "$OUT/projects.db" | tee "$OUT/marks.txt"

VID=$(adb -s $S shell "ls -t /sdcard/Movies/*/ESR_edit_*.mp4 2>/dev/null | head -1" | tr -d '\r')
echo "exported: $VID"
[ -n "$VID" ] && adb -s $S pull "$VID" "$OUT/exported.mp4" > /dev/null
read -r _ TAKE END < <(grep LAST_OUT "$OUT/marks.txt")
if [ -f "$OUT/exported.mp4" ] && [ -n "$TAKE" ]; then
  FROM=$(( TAKE > 600 ? TAKE - 600 : 0 ))
  "$FF/ffmpeg" -v error -y -ss $(awk "BEGIN{print $FROM/1000}") -i "$OUT/exported.mp4" -t 3 \
    -vf "fps=6,scale=240:-1,tile=6x3" \
    -frames:v 1 "$OUT/last_mark_frames.png"
  echo "frames from ${FROM} ms (last take $TAKE, end $END) -> $OUT/last_mark_frames.png"
fi
