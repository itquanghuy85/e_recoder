#!/bin/bash
# A2/A3: stop a running recording from its notification while the app is in the background, then
# open the app and check the result screen. ColorOS keeps the recording notification collapsed in
# "silent notifications"; its arrow (android:id/expand_button) and the "Dừng" action are found with
# `maestro hierarchy` (uiautomator would knock Maestro's driver offline).
# Usage: scripts/qa/notif_stop.sh <serial> <out-dir>
export MSYS_NO_PATHCONV=1 JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"
D=$1; OUT=$2; mkdir -p "$OUT"
M="${MAESTRO:-/c/Users/Mr Huy/maestro/maestro/bin/maestro}"
find_el() { # $1 = python condition on (rid, text, desc); prints "x y" of the match nearest the bottom
  "$M" --device $D hierarchy 2>/dev/null > "$OUT/h.json"
  PYTHONIOENCODING=utf-8 python - "$OUT/h.json" "$1" <<'P'
import json,re,sys
s=open(sys.argv[1],encoding='utf-8',errors='ignore').read(); d=json.loads(s[s.index('{'):])
cond=sys.argv[2]; hits=[]; app_y=[None]
def walk(n):
    a=n.get('attributes',{}); rid=a.get('resource-id',''); text=a.get('text',''); desc=a.get('accessibilityText','')
    b=re.findall(r'\d+',a.get('bounds',''))
    if len(b)==4:
        x0,y0,x1,y1=map(int,b)
        if text=='E Screen Recorder': app_y[0]=(y0+y1)//2
        hits.append((rid,text,desc,(x0+x1)//2,(y0+y1)//2))
    for c in n.get('children',[]): walk(c)
walk(d)
for rid,text,desc,x,y in hits:
    if eval(cond): print(x,y); break
P
}
adb -s $D shell cmd statusbar expand-notifications; sleep 2
H=$(adb -s $D shell wm size | grep -oE '[0-9]+$')
# Our card sits in "silent notifications", often below the fold: scroll the shade until it shows.
for k in 1 2 3 4 5; do
  [ -n "$(find_el "text=='E Screen Recorder'")" ] && break
  adb -s $D shell input swipe 540 $((H * 85 / 100)) 540 $((H * 45 / 100)) 400; sleep 1
done
xy=$(find_el "text=='Dừng'")
if [ -z "$xy" ]; then
  # the arrow on the same row as our app name
  "$M" --device $D hierarchy 2>/dev/null > "$OUT/h.json"
  y=$(PYTHONIOENCODING=utf-8 python - "$OUT/h.json" <<'P'
import json,re,sys
s=open(sys.argv[1],encoding='utf-8',errors='ignore').read(); d=json.loads(s[s.index('{'):])
rows=[]; app=None
def walk(n):
    global app
    a=n.get('attributes',{}); b=list(map(int,re.findall(r'\d+',a.get('bounds','')) or [0,0,0,0]))
    if a.get('text')=='E Screen Recorder': app=(b[1]+b[3])//2
    if a.get('resource-id')=='android:id/expand_button': rows.append(((b[0]+b[2])//2,(b[1]+b[3])//2))
    for c in n.get('children',[]): walk(c)
walk(d)
if app is not None:
    x,y=min(rows,key=lambda r:abs(r[1]-app)); print(x,y)
P
)
  [ -z "$y" ] && { echo "FAIL no recording notification"; exit 1; }
  adb -s $D shell input tap $y; sleep 1.5
  # the actions of an expanded card at the bottom can be cut off: bring them up
  adb -s $D shell input swipe 540 $((H * 85 / 100)) 540 $((H * 55 / 100)) 400; sleep 1
  xy=$(find_el "text=='Dừng'")
fi
[ -z "$xy" ] && { echo "FAIL no Stop action"; adb -s $D exec-out screencap -p > "$OUT/shade.png"; exit 1; }
adb -s $D exec-out screencap -p > "$OUT/1_shade.png"
adb -s $D shell input tap $xy
sleep 5
adb -s $D shell input keyevent KEYCODE_HOME; sleep 2
adb -s $D shell monkey -p com.huluca.escreenrecorder -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
for i in $(seq 1 15); do
  sleep 2
  if [ -n "$(find_el "text in ('Quay xong rồi',) or desc.startswith('Quay xong')")" ]; then
    adb -s $D exec-out screencap -p > "$OUT/2_result.png"; echo "PASS result screen"; exit 0
  fi
done
adb -s $D exec-out screencap -p > "$OUT/2_noresult.png"; echo "FAIL no result screen"; exit 1
