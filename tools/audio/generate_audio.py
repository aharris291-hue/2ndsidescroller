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


if __name__ == "__main__":
    build_theme()
    build_sfx()
    print("Audio written to", AUDIO)
