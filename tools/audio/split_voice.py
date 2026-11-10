"""Splits one batched ElevenLabs speech take into a clip per dialogue line.

Each speaker's lines were generated as one take, joined by "[long pause]"
(tools/audio/voice_cast.json lists the cast and how the batches were made).
This finds the N-1 longest silences in the take, cuts there, trims each clip and
writes assets/audio/vo/<conversation>_<line>.ogg. It refuses a take whose clips'
lengths don't follow their lines' lengths (a cut in the wrong place).

Run: python3 tools/audio/split_voice.py <take.mp3> <plan.json> <chunk number> [--check]
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "audio", "vo")


def silences(path: str) -> list:
    log = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af",
        "silencedetect=noise=-38dB:d=0.3", "-f", "null", "-"], capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", log)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", log)]
    dur = float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", log).groups()[2]) + \
        60 * float(re.search(r"Duration: (\d+):(\d+):", log).groups()[1])
    return [(s, e) for s, e in zip(starts, ends)], dur


def split(path: str, items: list, check_only: bool) -> bool:
    gaps, dur = silences(path)
    inner = [g for g in gaps if g[0] > 0.2 and g[1] < dur - 0.2]
    n = len(items)
    if len(inner) < n - 1:
        print("too few silences: %d for %d lines" % (len(inner), n))
        return False
    cuts = sorted(sorted(inner, key=lambda g: g[1] - g[0], reverse=True)[:n - 1])
    bounds = [0.0] + [(a + b) / 2 for a, b in cuts] + [dur]
    lens = [bounds[i + 1] - bounds[i] for i in range(n)]
    rates = sorted(l / max(len(it[2]), 12) for l, it in zip(lens, items))
    median = rates[len(rates) // 2]
    ok = all(0.3 * median <= l / max(len(it[2]), 12) <= 3.2 * median for l, it in zip(lens, items))
    if not ok:
        print("clip lengths don't follow the lines:", [round(l, 1) for l in lens])
        return False
    if check_only:
        return True
    os.makedirs(OUT, exist_ok=True)
    for i, it in enumerate(items):
        out = os.path.join(OUT, "%s_%d.ogg" % (it[0], it[1]))
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", path,
            "-ss", "%.3f" % bounds[i], "-to", "%.3f" % bounds[i + 1],
            "-af", "silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
                   "silenceremove=start_periods=1:start_threshold=-45dB,areverse,apad=pad_dur=0.15,"
                   "loudnorm=I=-18:TP=-2,aresample=44100",
            "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    return True


if __name__ == "__main__":
    take, plan_path, chunk = sys.argv[1], sys.argv[2], int(sys.argv[3])
    plan = json.load(open(plan_path))
    items = next(p["items"] for p in plan if p["chunk"] == chunk)
    sys.exit(0 if split(take, items, "--check" in sys.argv) else 1)
