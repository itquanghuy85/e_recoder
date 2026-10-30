"""Removes the project rows of QA media from a COPY of the app's debug projects.db.

Usage: python projects_db.py <db-copy> <media-id> [<media-id> ...]

A row is removed only when its id ends with "/media/<id>" for one of the given ids, so nothing else
in the database is touched. Prints how many rows went. Used by qa_data.ps1; never run it on a
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
    for media_id in ids:
        if not media_id.isdigit():
            print(f"skip {media_id!r}: not a media id", file=sys.stderr)
            continue
        cur = con.execute("delete from projects where id like ?", (f"%/media/{media_id}",))
        removed += cur.rowcount
    con.commit()
    con.close()
    print(removed)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
