"""Synthesizes placeholder music-box music and sound effects.

Run from the repo root:

    python3 tools/audio/generate_audio.py

Writes 16-bit mono WAV files into assets/audio. Requires numpy.
"""

import os
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")
RATE = 22050
gen = np.random.default_rng(42)


def write(name, samples):
    path = os.path.join(AUDIO, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(samples, -1.0, 1.0)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((data * 32000).astype("<i2").tobytes())


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def note_freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def music_box_note(midi, length=1.6):
    """A plucked metal tine: bright attack, inharmonic partials, long decay."""
    x = t(length)
    f = note_freq(midi)
    env = np.exp(-x * 3.2)
    tone = np.sin(2 * np.pi * f * x) + 0.35 * np.sin(2 * np.pi * f * 3.01 * x) * np.exp(-x * 9) + 0.15 * np.sin(2 * np.pi * f * 5.4 * x) * np.exp(-x * 16)
    click = gen.normal(0, 1, len(x)) * np.exp(-x * 400) * 0.2
    return (tone * env + click) * 0.32


def build_theme():
    """'Foldwick Lullaby', a 16-bar waltz in F major (3/4, 92 bpm)."""
    beat = 60 / 92
    melody = [
        (72, 1), (74, 1), (76, 1), (77, 2), (76, 1), (74, 1), (72, 1), (69, 1), (72, 3),
        (70, 1), (72, 1), (74, 1), (76, 2), (74, 1), (72, 1), (70, 1), (67, 1), (69, 3),
        (72, 1), (74, 1), (76, 1), (77, 2), (79, 1), (81, 2), (79, 1), (77, 3),
        (76, 1), (74, 1), (72, 1), (74, 2), (76, 1), (77, 3), (77, 3),
    ]
    bass = [53, 60, 60, 58, 65, 65, 53, 60, 60, 48, 55, 55, 50, 57, 57, 46, 53, 53, 48, 55, 55, 53, 60, 60]
    total_beats = sum(d for _, d in melody)
    length = total_beats * beat
    out = np.zeros(int(RATE * (length + 2)))
    pos = 0.0
    for midi, dur in melody:
        n = music_box_note(midi, 1.8)
        i = int(pos * RATE)
        out[i:i + len(n)] += n
        pos += dur * beat
    for b in range(int(total_beats)):
        midi = bass[b % len(bass)]
        n = music_box_note(midi, 1.2) * (0.55 if b % 3 == 0 else 0.3)
        i = int(b * beat * RATE)
        out[i:i + len(n)] += n
    # Fold the tail back onto the start so the loop point is seamless.
    loop_len = int(length * RATE)
    tail = out[loop_len:]
    out = out[:loop_len]
    out[:len(tail)] += tail
    write("music/foldwick_lullaby.wav", out * 0.8)


def accordion_note(midi, length):
    """A soft reedy squeeze-box chord tone: detuned saws with a slow swell."""
    x = t(length)
    f = note_freq(midi)
    saw = sum(((x * f * d) % 1.0) * 2 - 1 for d in (1.0, 1.004, 0.997)) / 3
    env = np.minimum(1.0, x * 6) * np.exp(-x * 0.9) * (1 + 0.08 * np.sin(2 * np.pi * 5 * x))
    smooth = np.convolve(saw, np.ones(6) / 6, mode="same")
    return smooth * env * 0.12


def glock_note(midi, length=1.0):
    x = t(length)
    f = note_freq(midi)
    return (np.sin(2 * np.pi * f * x) + 0.25 * np.sin(2 * np.pi * f * 2.76 * x) * np.exp(-x * 12)) * np.exp(-x * 4.5) * 0.22


def _loop(out, length):
    loop_len = int(length * RATE)
    tail = out[loop_len:]
    out = out[:loop_len]
    out[:len(tail)] += tail
    return out


def build_lanternfold():
    """'Lanterns on the Water', a 3/4 harbor waltz in D minor turning to F (112 bpm):
    music box melody, accordion chords, glockenspiel sparkle."""
    beat = 60 / 112
    melody = [
        (69, 2), (74, 1), (72, 2), (70, 1), (69, 2), (65, 1), (67, 3),
        (69, 2), (70, 1), (72, 2), (74, 1), (76, 3), (77, 3),
        (77, 2), (76, 1), (74, 2), (72, 1), (70, 2), (69, 1), (67, 3),
        (65, 2), (67, 1), (69, 2), (70, 1), (69, 3), (74, 3),
    ]
    chords = [(50, 57, 62), (46, 53, 58), (48, 55, 60), (53, 57, 60), (50, 57, 62), (46, 53, 58), (45, 52, 61), (50, 57, 62)]
    total_beats = sum(d for _, d in melody)
    length = total_beats * beat
    out = np.zeros(int(RATE * (length + 3)))
    pos = 0.0
    for midi, dur in melody:
        n = music_box_note(midi, 1.8)
        i = int(pos * RATE)
        out[i:i + len(n)] += n
        if dur >= 3:
            g = glock_note(midi + 12, 1.0)
            out[i:i + len(g)] += g
        pos += dur * beat
    bars = int(total_beats // 3)
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        start = int(bar * 3 * beat * RATE)
        root = accordion_note(chord[0], beat * 1.0) * 1.3
        out[start:start + len(root)] += root
        for b in (1, 2):
            i = start + int(b * beat * RATE)
            for m in chord[1:]:
                n = accordion_note(m + 12, beat * 0.9)
                out[i:i + len(n)] += n
    write("music/lanternfold_waltz.wav", _loop(out, length) * 0.8)


def build_ink_deep():
    """The Sogg's theme: the Foldwick lullaby on a waterlogged music box, too slow and too low."""
    beat = 60 / 64
    melody = [(67, 1), (69, 1), (71, 1), (72, 2), (71, 1), (69, 1), (67, 1), (64, 1), (67, 3),
              (65, 1), (67, 1), (69, 1), (71, 2), (69, 1), (67, 1), (65, 1), (62, 1), (64, 3)]
    total_beats = sum(d for _, d in melody)
    length = total_beats * beat
    out = np.zeros(int(RATE * (length + 3)))
    pos = 0.0
    for midi, dur in melody:
        n = music_box_note(midi - 5, 2.6)
        # A little pitch sag on every note, like a soggy spring.
        n = np.interp(np.arange(len(n)) * (1 - 0.012 * np.linspace(0, 1, len(n))), np.arange(len(n)), n)
        i = int(pos * RATE)
        out[i:i + len(n)] += n
        pos += dur * beat
    for b in range(int(total_beats)):
        if b % 3 == 0:
            n = music_box_note(43 if (b // 9) % 2 == 0 else 41, 2.0) * 0.6
            i = int(b * beat * RATE)
            out[i:i + len(n)] += n
    rumble = np.convolve(gen.normal(0, 1, len(out)), np.ones(400) / 400, mode="same") * 0.6
    write("music/ink_deep.wav", _loop(out + rumble, length) * 0.85)


def celesta_note(midi, length=1.4):
    """A celesta: a soft struck bar with a bell-like octave, rounder than the music box."""
    x = t(length)
    f = note_freq(midi)
    tone = np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * f * 2 * x) * np.exp(-x * 5) + 0.08 * np.sin(2 * np.pi * f * 4.1 * x) * np.exp(-x * 14)
    return tone * np.minimum(1.0, x * 400) * np.exp(-x * 2.4) * 0.24


def string_note(midi, length):
    """A low bowed string: detuned saws, a slow bow attack and a gentle vibrato."""
    x = t(length)
    f = note_freq(midi) * (1 + 0.003 * np.sin(2 * np.pi * 5.2 * x) * np.minimum(1.0, x))
    phase = np.cumsum(f) / RATE
    saw = sum(((phase * d) % 1.0) * 2 - 1 for d in (1.0, 1.003, 0.998)) / 3
    smooth = np.convolve(saw, np.ones(10) / 10, mode="same")
    env = np.minimum(1.0, x / 0.5) * np.minimum(1.0, (length - x) / 0.6)
    return smooth * env * 0.16


def build_spine_peaks():
    """'The Long Climb', the Spine Peaks theme: a celesta melody in E minor over low
    strings (84 bpm, 4/4), with the music box answering high up, like snow falling."""
    beat = 60 / 84
    melody = [
        (64, 2), (67, 1), (71, 1), (69, 3), (67, 1), (66, 2), (67, 1), (69, 1), (71, 4),
        (72, 2), (71, 1), (69, 1), (67, 3), (64, 1), (66, 2), (67, 1), (66, 1), (64, 4),
        (64, 2), (67, 1), (71, 1), (76, 3), (74, 1), (72, 2), (71, 1), (69, 1), (71, 4),
        (72, 2), (74, 1), (72, 1), (71, 3), (67, 1), (69, 2), (66, 2), (64, 4),
    ]
    chords = [(40, 47), (36, 43), (38, 45), (35, 42), (36, 43), (40, 47), (38, 45), (40, 47)]
    total_beats = sum(d for _, d in melody)
    length = total_beats * beat
    out = np.zeros(int(RATE * (length + 4)))
    pos = 0.0
    for k, (midi, dur) in enumerate(melody):
        n = celesta_note(midi + 12, 1.6)
        i = int(pos * RATE)
        out[i:i + len(n)] += n
        if dur >= 4:
            echo = music_box_note(midi + 24, 1.4) * 0.35
            j = i + int(beat * 2 * RATE)
            out[j:j + len(echo)] += echo
        pos += dur * beat
    bars = int(total_beats // 4)
    for bar in range(bars):
        start = int(bar * 4 * beat * RATE)
        for m in chords[bar % len(chords)]:
            n = string_note(m, beat * 4.2)
            out[start:start + len(n)] += n
    write("music/spine_peaks.wav", _loop(out, length) * 0.85)


def build_chapter3_sfx():
    # Pop-Up Slam: a deep cardboard thump with a crunch of folding paper on top.
    thump = sweep(140, 40, 0.4, decay=7) * 0.8
    crunch = np.convolve(gen.normal(0, 1, int(RATE * 0.4)), np.ones(3) / 3, mode="same") * np.exp(-t(0.4) * 14) * 0.5
    write("sfx/slam.wav", (thump + crunch) * 0.75)


def sweep(f0, f1, length, wave_fn=np.sin, decay=8.0):
    x = t(length)
    freq = np.linspace(f0, f1, len(x))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return wave_fn(phase) * np.exp(-x * decay)


def build_sfx():
    write("sfx/jump.wav", sweep(320, 720, 0.18, decay=10) * 0.5)
    noise = gen.normal(0, 1, int(RATE * 0.16))
    swish = np.convolve(noise, np.ones(12) / 12, mode="same") * np.exp(-t(0.16) * 18) * np.sin(np.linspace(0, np.pi, len(noise)))
    write("sfx/swipe.wav", swish * 1.6)
    write("sfx/hurt.wav", (sweep(420, 140, 0.3, wave_fn=lambda p: np.sign(np.sin(p)), decay=7) * 0.25))
    pickup = np.concatenate([music_box_note(84, 0.12), music_box_note(91, 0.5)])
    write("sfx/pickup.wav", pickup * 1.2)
    rustle = gen.normal(0, 1, int(RATE * 0.5))
    rustle = np.convolve(rustle, np.ones(30) / 30, mode="same") * (np.sin(np.linspace(0, np.pi, len(rustle))) ** 2)
    write("sfx/page_flip.wav", rustle * 2.2)
    write("sfx/checkpoint.wav", np.concatenate([music_box_note(77, 0.15), music_box_note(81, 0.15), music_box_note(84, 1.0)]))
    write("sfx/tab_pull.wav", sweep(180, 260, 0.25, decay=6) * 0.4 + gen.normal(0, 0.05, int(RATE * 0.25)))
    write("sfx/enemy_pop.wav", sweep(600, 120, 0.22, decay=9) * 0.5)
    # One short voice blip; the dialogue system re-pitches it per speaker.
    x = t(0.07)
    blip = (np.sin(2 * np.pi * 440 * x) + 0.4 * np.sin(2 * np.pi * 880 * x)) * np.sin(np.linspace(0, np.pi, len(x)))
    write("sfx/voice_blip.wav", blip * 0.35)
    # Tape Tail: a sticky zip of tape peeling off the roll.
    peel = gen.normal(0, 1, int(RATE * 0.3))
    peel = np.convolve(peel, np.ones(4) / 4, mode="same") * np.exp(-t(0.3) * 7) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 60 * t(0.3))))
    write("sfx/grapple.wav", peel * 0.7 + sweep(500, 1400, 0.3, decay=9) * 0.25)


if __name__ == "__main__":
    import sys

    if "chapter3" in sys.argv:
        # Quick path: only the Chapter 3 music and sounds.
        build_spine_peaks()
        build_chapter3_sfx()
        sys.exit(0)
    build_theme()
    build_sfx()
    build_lanternfold()
    build_ink_deep()
    build_spine_peaks()
    build_chapter3_sfx()
    print("Audio written to", AUDIO)
