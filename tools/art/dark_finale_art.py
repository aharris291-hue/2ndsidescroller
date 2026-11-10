"""Art for the finale (Phase 3), from the painted ElevenLabs renders in tools/art/source/.

Backdrops (assets/art/dark/):
  bg_gutter_descent.png  1920x1080, looking down into the crease at the middle of the
                         book, its stitches hanging across it (F-1 The Gutter Descent)

Run: python3 tools/art/dark_finale_art.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")


def fit(path: str) -> Image.Image:
    return ImageOps.fit(Image.open(path).convert("RGB"), (1920, 1080), Image.LANCZOS)


def main() -> None:
    bg = fit(os.path.join(SRC, "gutter_descent_raw.png"))
    # A little darker, so Patch and the tiles read against it.
    bg = ImageEnhance.Brightness(bg).enhance(0.8)
    bg.save(os.path.join(DARK, "bg_gutter_descent.png"))


if __name__ == "__main__":
    main()
