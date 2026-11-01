import json
import sqlite3
import sys

# Prints the marks of the project saved last with their timing (source ms) and checks that a mark is
# gone before the next one is fully shown. Last line: "LAST_OUT <take> <end>", the last mark's take and
# end on the output timeline (freezes counted), for cutting frames out of the exported video.
CUE, FADE = 500, 300
db = sqlite3.connect(sys.argv[1])
row = db.execute("select id, json from projects order by updatedAt desc limit 1").fetchone()
p = json.loads(row[1])
print("project:", row[0][-24:])
ms = sorted(p.get("markers", []), key=lambda m: m["cueStartMs"])
ok = True
for i, m in enumerate(ms):
    take = m["cueStartMs"] + CUE
    end = take + m["holdMs"] + FADE
    line = "  mark %-7s step %-4s take %6d hold %5d end %6d" % (
        m["spec"]["type"], m["spec"].get("number"), take, m["holdMs"], end)
    if i + 1 < len(ms):
        nxt = ms[i + 1]["cueStartMs"] + CUE
        good = end <= nxt
        ok &= good
        line += "  next take %6d %s" % (nxt, "OK" if good else "OVERLAP")
    print(line)
print("  marks:", len(ms), "| never two full marks:", "PASS" if ok and ms else "FAIL")


def to_out(t):
    # Segments in output order; a freeze at t comes right after the moment t, so t itself is its start.
    acc = 0.0
    for s in p["segments"]:
        speed = s.get("speed", 1.0) or 1.0
        if s.get("freezeMs"):
            if s["startMs"] < t:
                acc += s["freezeMs"]
            continue
        if t < s["startMs"]:
            break
        if t <= s["endMs"]:
            return acc + (t - s["startMs"]) / speed
        acc += (s["endMs"] - s["startMs"]) / speed
    return acc


if ms:
    take = ms[-1]["cueStartMs"] + CUE
    print("LAST_OUT %d %d" % (to_out(take), to_out(take + ms[-1]["holdMs"] + FADE)))
