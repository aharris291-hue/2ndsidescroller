"""Synthesises the post-game sound set into assets/audio/postgame/ (one-time builder).

Procedural on purpose: dull, wet, wooden and inky, to sit under the ElevenLabs
combat sounds without competing with them. Run: python3 tools/audio/synth_postgame_sfx.py
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "postgame")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.004, decay=0.2):
    x = np.arange(n) / SR
    return np.minimum(x / attack, 1.0) * np.exp(-x / decay)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandpass(x, lo, hi):
    return lowpass(x, hi) - lowpass(x, lo)


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    tmp = os.path.join(OUT, name + ".wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5",
        os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def press_thud():
    # Gran's proof press: a screw turning, then the platen coming down on wet paper.
    n = int(SR * 1.1)
    creak = np.zeros(n)
    tt = t(0.45)
    saw = ((tt * 95 * (1 + 0.15 * np.sin(tt * 9))) % 1.0) - 0.5
    creak[:len(tt)] = bandpass(saw, 300, 1800) * env(len(tt), 0.08, 0.3) * 0.5
    hit = int(SR * 0.42)
    tb = t(0.68)
    boom = np.sin(2 * np.pi * (52 + 40 * np.exp(-tb * 18)) * tb) * env(len(tb), 0.002, 0.22)
    slap = lowpass(rng.standard_normal(len(tb)), 2400) * env(len(tb), 0.001, 0.035) * 0.8
    creak[hit:hit + len(tb)] += boom + slap
    return creak


def stamp():
    # A sticker pressed into the ledger: a short wooden knock and a paper slap.
    tt = t(0.4)
    knock = np.sin(2 * np.pi * 180 * tt) * env(len(tt), 0.001, 0.05)
    slap = bandpass(rng.standard_normal(len(tt)), 600, 5000) * env(len(tt), 0.001, 0.025)
    return knock + slap * 0.9


def penny():
    # A penny dropped into the theatre's tin slot: inharmonic clink, then a rattle.
    tt = t(0.9)
    x = np.zeros(len(tt))
    for f, a, d in ((2380, 1.0, 0.12), (3710, 0.6, 0.08), (5230, 0.35, 0.05), (1310, 0.4, 0.2)):
        x += a * np.sin(2 * np.pi * f * tt) * env(len(tt), 0.0005, d)
    for k, off in enumerate((0.16, 0.25, 0.31, 0.35)):
        s = int(SR * off)
        m = len(tt) - s
        x[s:] += (0.5 - k * 0.1) * np.sin(2 * np.pi * 2380 * tt[:m]) * env(m, 0.0005, 0.03)
    return x


def rustle():
    # Sheets lifted off Gran's drying rack: crackling bursts of paper.
    n = int(SR * 0.7)
    x = np.zeros(n)
    for _ in range(26):
        s = int(rng.uniform(0, 0.55) * SR)
        m = int(rng.uniform(0.008, 0.04) * SR)
        x[s:s + m] += rng.standard_normal(m) * rng.uniform(0.3, 1.0) * np.hanning(m)
    return bandpass(x, 900, 7000) * env(n, 0.05, 0.4)


def ink_rush():
    # The Runaway lunging: a low, wet swell of ink.
    tt = t(0.6)
    noise = lowpass(rng.standard_normal(len(tt)), 700)
    shape = np.sin(np.pi * np.clip(tt / 0.6, 0, 1)) ** 1.5
    gurgle = 1 + 0.6 * np.sin(2 * np.pi * 23 * tt)
    return noise * shape * gurgle + 0.4 * np.sin(2 * np.pi * 70 * tt) * shape


def heartbeat():
    # Two slow beats, under the true ending's held paw.
    tt = t(1.3)
    x = np.zeros(len(tt))
    for off, a in ((0.0, 1.0), (0.28, 0.7)):
        s = int(SR * off)
        m = len(tt) - s
        tb = tt[:m]
        x[s:] += a * np.sin(2 * np.pi * (48 + 20 * np.exp(-tb * 30)) * tb) * env(m, 0.004, 0.09)
    return x


def drip():
    # One drop of ink landing in a pool (Last Margin ambience, door unlocking).
    tt = t(0.5)
    plink = np.sin(2 * np.pi * (900 + 1400 * np.exp(-tt * 40)) * tt) * env(len(tt), 0.001, 0.06)
    return plink + 0.3 * lowpass(rng.standard_normal(len(tt)), 900) * env(len(tt), 0.001, 0.02)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("press_thud", press_thud), ("stamp", stamp), ("penny", penny),
            ("rustle", rustle), ("ink_rush", ink_rush), ("heartbeat", heartbeat), ("drip", drip)):
        save(name, fn())
        print("wrote", name)
