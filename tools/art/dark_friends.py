"""Painted friends for the dark rebuild (docs/ART_STYLE.md).

Inputs are ElevenLabs paintings kept in tools/art/source (<name>_raw.png), all facing
right (the companions' script flips them toward Patch from there):
  shepherd_fluff, lost_sheep, dot, corrugate, bindwell, lamplighter_sisters, crumple

Writes to assets/art/dark/friends/<name>.png, each cut out, trimmed and
FRIEND_HEIGHT[name] px tall. Each scene shows its sprite at the scale that gives the
on-screen height in docs/ART_STYLE.md, standing on the same spot as before.

Run: python3 tools/art/dark_friends.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from dark_enemies import cut, fit_height  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
OUT = os.path.join(ROOT, "assets", "art", "dark", "friends")

# Texture heights: twice the main on-screen height, so they stay sharp when zoomed.
FRIEND_HEIGHT = {
    "shepherd_fluff": 300,
    "lost_sheep": 200,
    "dot": 140,
    "corrugate": 320,
    "bindwell": 420,
    "lamplighter_sisters": 420,
    "crumple": 240,
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, height in FRIEND_HEIGHT.items():
        im = fit_height(cut(os.path.join(SRC, name + "_raw.png")), height)
        im.save(os.path.join(OUT, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    main()
