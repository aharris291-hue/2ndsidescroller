"""Dark-rebuild backdrops for the Prologue and Thistledown pages.

- bg_meadow_drowned.png (3840x1080): the painted drowned-kingdom plate, mirrored
  into a seamless strip so pages can repeat it every 3840 px, graded mossy and cold.
- bg_bookshelf_drowned.png (1920x1080): the old night bookshelf, drained of colour
  blurred and sunk into the dark, still tiling every 1920 px both ways as before.

Run after dark_assets.py: python3 tools/art/dark_backgrounds.py
"""
import os

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
DARK = os.path.join(ROOT, "assets", "art", "dark")
BACK = os.path.join(ROOT, "assets", "art", "backgrounds")


def grade(img: Image.Image, mul, lift=(0, 0, 0)) -> Image.Image:
    a = np.asarray(img.convert("RGB"), np.float32)
    a = a * np.array(mul, np.float32) + np.array(lift, np.float32)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def grain(img: Image.Image, amount: float, seed: int) -> Image.Image:
    a = np.asarray(img, np.float32)
    n = np.random.default_rng(seed).normal(0, amount, a.shape[:2])[..., None]
    return Image.fromarray(np.clip(a + n, 0, 255).astype(np.uint8))


def meadow() -> None:
    src = Image.open(os.path.join(DARK, "bg_drowned.png")).convert("RGB")
    w = round(src.width * 1080 / src.height)
    plate = src.resize((w, 1080), Image.LANCZOS)
    left = (w - 1920) // 2
    plate = plate.crop((left, 0, left + 1920, 1080))
    strip = Image.new("RGB", (3840, 1080))
    strip.paste(plate, (0, 0))
    strip.paste(ImageOps.mirror(plate), (1920, 0))
    strip = grade(strip, (0.92, 0.98, 0.86), (2, 4, 0))
    strip = ImageEnhance.Color(strip).enhance(0.8)
    strip.save(os.path.join(DARK, "bg_meadow_drowned.png"))


def bookshelf() -> None:
    src = Image.open(os.path.join(BACK, "bg_bookshelf_night.png")).convert("RGB")
    img = ImageEnhance.Color(src).enhance(0.28)
    img = ImageEnhance.Contrast(img).enhance(0.85)
    img = grade(img, (0.42, 0.48, 0.6), (4, 6, 12))
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    img = grain(img, 4.0, 7)
    img.save(os.path.join(DARK, "bg_bookshelf_drowned.png"))


if __name__ == "__main__":
    meadow()
    bookshelf()
    print("wrote backdrops to", DARK)
