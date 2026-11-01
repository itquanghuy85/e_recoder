"""Removes the project rows of QA media from a COPY of the app's debug projects.db.

Usage: python projects_db.py <db-copy> <ref> [<ref> ...]

<ref> is a MediaStore id (digits): the row of that media is removed ("…/media/<id>"), or
"uri:<end of the project uri>": the row whose id ends exactly with that text (for a video the test
picked from Downloads, e.g. "uri:msf%3A248"). Nothing else in the database is touched. Prints how many rows went. Used by qa_data.ps1; never run it on a
database that did not come from `adb run-as` on a debuggable build.
"""
import sqlite3
import sys


def main(argv):
    if len(argv) < 3:
        print("usage: projects_db.py <db> <media-id>...", file=sys.stderr)
        return 2
    db, ids = argv[1], argv[2:]
    con = sqlite3.connect(db)
    removed = 0
    for ref in ids:
        if ref.startswith("uri:") and len(ref) > 8:
            tail = ref[4:]
            # the end of the id, compared as plain text (no LIKE, so % and _ in the uri are just characters)
            cur = con.execute(
                "delete from projects where length(id) >= ? and substr(id, -?) = ?",
                (len(tail), len(tail), tail),
            )
        elif ref.isdigit():
            cur = con.execute("delete from projects where id like ?", (f"%/media/{ref}",))
        else:
            print(f"skip {ref!r}: not a media id or uri:<tail>", file=sys.stderr)
            continue
        removed += cur.rowcount
    con.commit()
    con.close()
    print(removed)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
