#!/bin/bash
# Recording modes on the S25 (maestro/ux_modes_record.yaml): each purpose keeps its own settings, and a
# recording uses the chosen purpose's. Backs the app settings up first and always puts them back. Reads the
# saved copy of each purpose and measures the two recordings it makes (game, then tutorial).
# Debug build (run-as). Videos are kept. Usage: bash scripts/qa/ux_modes_record.sh [serial]
export MSYS_NO_PATHCONV=1
S=${1:-R5CY6323KMX}
A=com.huluca.escreenrecorder
P=shared_prefs/FlutterSharedPreferences.xml
OUT=test-results/ux_modes_record
MAESTRO="/c/Users/Mr Huy/maestro/maestro/bin/maestro"
FF=/c/ffmpeg/bin
cd "$(dirname "$0")/../.."
rm -rf "$OUT"; mkdir -p "$OUT"

adb -s $S shell am force-stop $A
adb -s $S exec-out run-as $A cat $P > "$OUT/prefs_before.xml"
restore() {
  adb -s $S shell am force-stop $A
  adb -s $S push "$OUT/prefs_before.xml" /data/local/tmp/ux_prefs.xml > /dev/null
  adb -s $S shell "cat /data/local/tmp/ux_prefs.xml | run-as $A sh -c 'cat > $P'"
  adb -s $S shell rm /data/local/tmp/ux_prefs.xml
  adb -s $S exec-out run-as $A cat $P | cmp -s - "$OUT/prefs_before.xml" && echo "settings put back (identical)" || echo "settings put back: DIFFERENT"
}
trap restore EXIT

BEFORE=$(adb -s $S shell "ls /sdcard/Movies/*/ESR_2*.mp4 2>/dev/null" | tr -d '\r' | sort)
adb -s $S shell input keyevent KEYCODE_WAKEUP
adb -s $S shell wm dismiss-keyguard
JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8" \
  "$MAESTRO" --device $S test --test-output-dir "$OUT/maestro" maestro/ux_modes_record.yaml > "$OUT/maestro.log" 2>&1
echo "maestro exit: $?"
grep -E "FAILED" "$OUT/maestro.log" | head -3

adb -s $S exec-out run-as $A cat $P > "$OUT/prefs_after.xml"
python -I - "$OUT/prefs_after.xml" <<'EOF'
import html, json, re, sys
s = open(sys.argv[1], encoding="utf-8").read()
for p in ("tutorial", "game", "plain"):
    m = re.search(r'<string name="flutter\.purpose\.profile\.%s">(.*?)</string>' % p, s, re.S)
    if not m:
        print("copy %-8s none" % p)
        continue
    d = json.loads(html.unescape(m.group(1)))
    print("copy %-8s resolution=%s fps=%s marker.mode=%s touchSource=%s" % (
        p, d.get("rec.resolution"), d.get("rec.fps"), d.get("marker.mode"), d.get("marker.touchSourceV2")))
EOF

AFTER=$(adb -s $S shell "ls /sdcard/Movies/*/ESR_2*.mp4 2>/dev/null" | tr -d '\r' | sort)
NEW=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER"))
echo "new recordings: $(echo "$NEW" | grep -c .)"
echo "$NEW" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  i=$((i + 1))
  adb -s $S pull "$f" "$OUT/rec_$i.mp4" > /dev/null
  info=$("$FF/ffprobe" -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate,r_frame_rate,nb_frames -show_entries format=duration -of csv=p=0 "$OUT/rec_$i.mp4" | tr '\n' ' ')
  echo "rec_$i $(basename "$f"): $info"
done
