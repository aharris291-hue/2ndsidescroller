"""Art for the post-game, from the painted ElevenLabs renders in tools/art/source/.

Sprites:
  props/proof_press.png  Gran's proof press on its bench in the Spine's gallery (the
                         boss rematches), PRESS_HEIGHT px tall, feet on the bottom row

Run: python3 tools/art/dark_postgame_art.py
"""
import os

import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")
PRESS_HEIGHT = 300


def cutout(name: str) -> Image.Image:
    from rembg import new_session, remove
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    a = np.array(remove(img, session=new_session("isnet-general-use")))
    alpha = a[:, :, 3]
    alpha[alpha < 24] = 0
    out = Image.fromarray(a)
    return out.crop(out.getbbox())


def main() -> None:
    press = cutout("proof_press_raw.png")
    press = press.resize((round(press.width * PRESS_HEIGHT / press.height), PRESS_HEIGHT), Image.LANCZOS)
    rgb = ImageEnhance.Brightness(press.convert("RGB")).enhance(0.7)
    rgb.putalpha(press.getchannel("A"))
    rgb.save(os.path.join(DARK, "props", "proof_press.png"))


if __name__ == "__main__":
    main()
