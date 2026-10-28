"""Measures the results of voice_fx_check.sh with ffmpeg: duration, peak, pitch, noise in the pauses."""
import glob
import math
import os
import struct
import subprocess
import sys

RATE = 16000
if sys.argv[1] == '--freq':
    folder, ffmpeg = None, sys.argv[3]
else:
    folder, ffmpeg = sys.argv[1], sys.argv[2]


def pcm(path):
    raw = subprocess.run(
        [ffmpeg, "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
        capture_output=True, check=True,
    ).stdout
    return struct.unpack("<%dh" % (len(raw) // 2), raw)


def rms(x):
    return (sum(v * v for v in x) / max(1, len(x))) ** 0.5 / 32768


def db(v):
    return 20 * math.log10(max(v, 1e-9))


def freq(x):
    """Dominant frequency: rising zero crossings per half second, median over the loud half seconds."""
    win = RATE // 2
    parts = []
    for s in range(0, max(1, len(x) - win), win):
        seg = x[s:s + win]
        n = sum(1 for a, b in zip(seg, seg[1:]) if a < 0 <= b)
        parts.append((rms(seg), n * RATE / max(1, len(seg))))
    top = max(r for r, _ in parts)
    loud = sorted(f for r, f in parts if r > 0.5 * top)
    return loud[len(loud) // 2]


if folder is None:
    x = pcm(sys.argv[2])
    print('dominant frequency of the exported sound: %.0f Hz (median of the loud half seconds, %d s long)' % (freq(x), len(x) // RATE))
    sys.exit(0)

rows = []
for path in sorted(glob.glob(os.path.join(folder, "*.m4a"))):
    name = os.path.basename(path)[:-4]
    x = pcm(path)
    peak = max(abs(v) for v in x) / 32768
    rows.append((name, len(x) / RATE, db(peak), db(rms(x)), x))

print("%-28s %6s %8s %8s" % ("file", "sec", "peak dB", "rms dB"))
for name, sec, pk, rm, _ in rows:
    print("%-28s %6.2f %8.1f %8.1f" % (name, sec, pk, rm))

by = {n: x for n, _, _, _, x in rows}
print()
if "it_tone_orig" in by:
    f0 = freq(by["it_tone_orig"])
    print("pitch of the 440 Hz tone (zero crossings): original %.0f Hz" % f0)
    for fx, ratio in (("deep", 0.78), ("high", 1.25), ("chipmunk", 1.6)):
        k = "it_tone_%s_off" % fx
        if k in by:
            f = freq(by[k])
            ok = "OK" if abs(f / f0 - ratio) < 0.08 else "CHECK"
            print("  %-9s %.0f Hz (expected about %.0f) -> %s" % (fx, f, f0 * ratio, ok))
if "it_noisy_orig" in by:
    def pauses_speech(x):
        p, s = [], []
        for sec in range(0, len(x) // RATE):
            seg = x[sec * RATE + RATE // 10:(sec + 1) * RATE - RATE // 10]
            (s if sec % 2 == 0 else p).append(rms(seg))
        return sum(p) / max(1, len(p)), sum(s) / max(1, len(s))

    p0, s0 = pauses_speech(by["it_noisy_orig"])
    print("noise in the pauses / tone level: original %.1f dB / %.1f dB" % (db(p0), db(s0)))
    for dn in ("light", "strong"):
        k = "it_noisy_none_%s" % dn
        if k in by:
            p, s = pauses_speech(by[k])
            print("  %-7s pauses %.1f dB (%.1f dB quieter), tone %.1f dB (%.1f dB change)"
                  % (dn, db(p), db(p0) - db(p), db(s), db(s) - db(s0)))
