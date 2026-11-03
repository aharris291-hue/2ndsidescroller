"""Painted Phase 2 enemies (docs/ART_STYLE.md), cut from ElevenLabs paintings in
tools/art/source (all painted facing left):
  paper_moth_raw.png  inkwell_turret_raw.png  folded_crane_raw.png  mimic_book_raw.png

Writes to assets/art/dark/enemies/ at twice their on-screen size (scenes show them at
scale 0.5). Run: python3 tools/art/dark_enemies_p2.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from dark_enemies import OUT, SRC, centre_body, cut, fit_height  # noqa: E402

# Texture heights (px), 2x the on-screen height (Patch is 150 px tall).
HEIGHTS = {
    "paper_moth": 164,       # ~0.55 x Patch: small, comes in swarms
    "inkwell_turret": 240,   # ~0.8 x Patch
    "folded_crane": 240,     # ~0.8 x Patch tall, wide wings
    "mimic_book": 196,       # ~0.65 x Patch
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, h in HEIGHTS.items():
        im = centre_body(fit_height(cut(os.path.join(SRC, name + "_raw.png")), h))
        im.save(os.path.join(OUT, name + ".png"), optimize=True)
        print(name, im.size)
