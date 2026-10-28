"""How long was a marker visible in a recording?

    python scripts/qa/marker_lifetime.py VIDEO X Y [X Y ...]

X, Y are fractions (0..1) of the frame where a marker was placed. For each spot the script follows
the average brightness of a small square around it (10 samples a second) and prints when it first
changed (the marker's cue ring appears) and when it was last different from the final steady value
(the marker has faded out). Needs ffmpeg (FFMPEG env var or C:\ffmpeg\bin\ffmpeg.exe).
"""
import os
import subprocess
import sys

FFMPEG = os.environ.get("FFMPEG", r"C:\ffmpeg\bin\ffmpeg.exe")
FPS = 10


GRID = 8


def series(video, fx, fy, half=0.06):
    """Per-frame list of GRID x GRID grey samples around the spot."""
    crop = f"crop=iw*{2 * half}:iw*{2 * half}:iw*{fx - half}:ih*{fy}-iw*{half}"
    cmd = [FFMPEG, "-v", "error", "-i", video, "-vf",
           f"fps={FPS},{crop},scale={GRID}:{GRID}:flags=area,format=gray", "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = GRID * GRID
    return [raw[i:i + n] for i in range(0, len(raw) - n + 1, n)]


def report(frames, label):
    if len(frames) < 30:
        print(f"{label}: video too short")
        return
    # The steady picture: per-sample median of the last two seconds (the marker is long gone).
    n = GRID * GRID
    tail = frames[-20:]
    steady = [sorted(f[k] for f in tail)[len(tail) // 2] for k in range(n)]
    diff = [sum(abs(f[k] - steady[k]) for k in range(n)) / n for f in frames]
    changed = [i for i, d in enumerate(diff) if d > 4]
    if not changed:
        print(f"{label}: no marker seen")
        return
    # Group the changed samples into bursts (gaps up to 0.6 s belong to the same one).
    runs, start, prev = [], changed[0], changed[0]
    for i in changed[1:]:
        if i - prev > 0.6 * FPS:
            runs.append((start, prev))
            start = i
        prev = i
    runs.append((start, prev))
    text = ", ".join(f"{a / FPS:.1f}-{(b + 1) / FPS:.1f}s ({(b - a + 1) / FPS:.1f}s)" for a, b in runs)
    print(f"{label}: {text}")


if __name__ == "__main__":
    video = sys.argv[1]
    coords = [float(a) for a in sys.argv[2:]]
    for i in range(0, len(coords) - 1, 2):
        report(series(video, coords[i], coords[i + 1]), f"({coords[i]}, {coords[i + 1]})")
