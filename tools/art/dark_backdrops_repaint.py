"""Painted replacements for every backdrop still drawn in the old bright style.

Inputs are ElevenLabs paintings kept in tools/art/source/<name>_raw.png (1280 x 720).
Each is graded, softened and sized for how its scene uses it, and written to
assets/art/dark/backdrops/<name>.png:

  in-book pages (behind gameplay, repeating sideways in a Parallax2D every ~1920 px):
    bg_ink_sea        the Ink Sea: under the flap, and the Blotch Kraken's arena
    bg_spine_summit   the Spine: the climb, and the Sogg's arena
    bg_frostfold      Frostfold Slopes
    bg_gutter         the Gutter and the Deepest Fold
    bg_nell_page      Nell's crayon page at the back of the book
    bg_ribbon_stream  the Ribbon Regatta river, seen from above
  single screens (not repeated):
    bg_shadow_theater the shadow-theatre stage (the script draws the lit screen on top)
    bg_table_*        the real-world interludes at Gran's kitchen table
    bg_desk           the desk the book lies on (BookFrame)

Repeating pages are made seamless by cross-fading the right edge into the left, so the
join never shows as the backdrop scrolls. Gameplay backdrops are softened and pushed a
little darker and colder than the characters (docs/ART_STYLE.md, Readability).

Run: python3 tools/art/dark_backdrops_repaint.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
OUT = os.path.join(ROOT, "assets", "art", "dark", "backdrops")
W, H = 1920, 1080
FADE = 320  # px of cross-fade where a repeating backdrop wraps round

REPEATING = ["bg_ink_sea", "bg_spine_summit", "bg_frostfold", "bg_gutter", "bg_nell_page", "bg_ribbon_stream"]
SINGLE = ["bg_shadow_theater", "bg_table_evening", "bg_table_late", "bg_table_night",
          "bg_table_dryer", "bg_table_morning", "bg_desk"]
# Gameplay backdrops: (brightness, cold tint) so characters and tiles read in front.
GRADE = {
    "bg_ink_sea": (1.05, 0.0),
    "bg_spine_summit": (0.8, 0.04),
    "bg_frostfold": (0.8, 0.05),
    "bg_gutter": (0.95, 0.03),
    "bg_nell_page": (0.82, 0.02),
    "bg_ribbon_stream": (0.85, 0.03),
    "bg_shadow_theater": (0.9, 0.0),
}


def load(name: str) -> np.ndarray:
    return np.asarray(Image.open(os.path.join(SRC, name + "_raw.png")).convert("RGB"), np.float32)


def grade(a: np.ndarray, gain: float, cold: float) -> np.ndarray:
    a = a * gain
    lum = a.mean(-1, keepdims=True)
    a = a * (1 - cold) + lum * np.array([0.92, 0.98, 1.12], np.float32) * cold
    return np.clip(a, 0, 245)  # keep pure white for the parry glint


def seamless(img: Image.Image) -> Image.Image:
    """Size to W + FADE wide, then fade the extra right edge over the left edge."""
    big = img.resize((W + FADE, round((W + FADE) * img.height / img.width)), Image.LANCZOS)
    top = (big.height - H) // 2
    a = np.asarray(big.crop((0, top, W + FADE, top + H)), np.float32)
    t = np.linspace(0, 1, FADE, dtype=np.float32)
    t = (t * t * (3 - 2 * t))[None, :, None]
    out = a[:, :W].copy()
    out[:, :FADE] = a[:, W:] * (1 - t) + a[:, :FADE] * t
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name in REPEATING + SINGLE:
        a = load(name)
        if name in GRADE:
            a = grade(a, *GRADE[name])
        img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
        img = seamless(img) if name in REPEATING else img.resize((W, H), Image.LANCZOS)
        if name in GRADE:
            img = img.filter(ImageFilter.GaussianBlur(1.1))
        img.save(os.path.join(OUT, name + ".png"))
        print(name, img.size)


if __name__ == "__main__":
    main()
