import json
import sqlite3
import sys

# Prints the marks of the project saved last: type, step number, place as a fraction of the frame.
db = sqlite3.connect(sys.argv[1])
row = db.execute("select id, json from projects order by updatedAt desc limit 1").fetchone()
p = json.loads(row[1])
print("project:", row[0][-24:])
for m in sorted(p.get("markers", []), key=lambda m: m["cueStartMs"]):
    s = m["spec"]
    print("  mark %-8s step %s at x=%.2f y=%.2f" % (s["type"], s.get("number"), s["x0"], s["y0"]))
print("  marks:", len(p.get("markers", [])))
