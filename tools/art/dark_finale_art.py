"""Art for the finale (Phase 3), from the painted ElevenLabs renders in tools/art/source/.

Backdrops (assets/art/dark/):
  bg_gutter_descent.png  1920x1080, looking down into the crease at the middle of the
                         book, its stitches hanging across it (F-1 The Gutter Descent)
Sprites:
  bosses/sogg_arm.png    one of the Sogg's arms, hanging down to a fist, ARM_HEIGHT px
                         tall (F-2 The Deepest Fold)

Run: python3 tools/art/dark_finale_art.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")
ARM_HEIGHT = 720


def fit(path: str) -> Image.Image:
    return ImageOps.fit(Image.open(path).convert("RGB"), (1920, 1080), Image.LANCZOS)


def cutout(name: str) -> Image.Image:
    import numpy as np
    from rembg import new_session, remove
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    a = np.array(remove(img, session=new_session("isnet-general-use")))
    alpha = a[:, :, 3]
    alpha[alpha < 24] = 0
    out = Image.fromarray(a)
    return out.crop(out.getbbox())


def main() -> None:
    bg = fit(os.path.join(SRC, "gutter_descent_raw.png"))
    # A little darker, so Patch and the tiles read against it.
    bg = ImageEnhance.Brightness(bg).enhance(0.8)
    bg.save(os.path.join(DARK, "bg_gutter_descent.png"))
    arm = cutout("sogg_arm_raw.png")
    arm = arm.resize((round(arm.width * ARM_HEIGHT / arm.height), ARM_HEIGHT), Image.LANCZOS)
    arm.save(os.path.join(DARK, "bosses", "sogg_arm.png"))


if __name__ == "__main__":
    main()
