"""Art for the post-game, from the painted ElevenLabs renders in tools/art/source/.

Sprites:
  props/proof_press.png  Gran's proof press on its bench in the Spine's gallery (the
                         boss rematches), PRESS_HEIGHT px tall, feet on the bottom row
  props/penny_theatre.png the coin-operated penny theatre in the Spine (the minigame
                         arcade), THEATRE_HEIGHT px tall
  props/paper_rack.png   Gran's drying rack of papers in the Spine (Patch's paper
                         finishes), RACK_HEIGHT px tall

Backdrops (1920x1080):
  bg_last_margin.png              the Last Margin (the true ending's level), its edges
                                  blended so its parallax tiles
  backdrops/bg_table_new_flat.png the true ending: the table in the new flat

Run: python3 tools/art/dark_postgame_art.py
"""
import os

import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")
PRESS_HEIGHT = 300
THEATRE_HEIGHT = 300
RACK_HEIGHT = 210


def cutout(name: str) -> Image.Image:
    from rembg import new_session, remove
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    a = np.array(remove(img, session=new_session("isnet-general-use")))
    alpha = a[:, :, 3]
    alpha[alpha < 24] = 0
    out = Image.fromarray(a)
    return out.crop(out.getbbox())


def prop(raw: str, out: str, height: int, brightness: float) -> None:
    img = cutout(raw)
    img = img.resize((round(img.width * height / img.height), height), Image.LANCZOS)
    rgb = ImageEnhance.Brightness(img.convert("RGB")).enhance(brightness)
    rgb.putalpha(img.getchannel("A"))
    rgb.save(os.path.join(DARK, "props", out))


def backdrop(raw: str, out: str, brightness: float, tile: bool = False) -> None:
    """1920x1080. With `tile`, its right edge is blended into a copy of its left, so a
    repeating parallax layer joins without a seam."""
    img = Image.open(os.path.join(SRC, raw)).convert("RGB").resize((1920, 1080), Image.LANCZOS)
    img = ImageEnhance.Brightness(img).enhance(brightness)
    if tile:
        # Cross-fade the last `band` columns over the first ones and drop them: the new
        # first column is the old column W-band, which sat right after the new last one.
        a = np.asarray(img).astype(np.float32)
        band = 320
        t = np.linspace(0.0, 1.0, band)[None, :, None]
        faded = a[:, :-band].copy()
        faded[:, :band] = a[:, -band:] * (1.0 - t) + a[:, :band] * t
        img = Image.fromarray(faded.clip(0, 255).astype(np.uint8)).resize((1920, 1080), Image.LANCZOS)
    img.save(os.path.join(DARK, out))


def main() -> None:
    press = cutout("proof_press_raw.png")
    press = press.resize((round(press.width * PRESS_HEIGHT / press.height), PRESS_HEIGHT), Image.LANCZOS)
    rgb = ImageEnhance.Brightness(press.convert("RGB")).enhance(0.7)
    rgb.putalpha(press.getchannel("A"))
    rgb.save(os.path.join(DARK, "props", "proof_press.png"))
    box = cutout("penny_theatre_raw.png")
    box = box.resize((round(box.width * THEATRE_HEIGHT / box.height), THEATRE_HEIGHT), Image.LANCZOS)
    rgb = ImageEnhance.Brightness(box.convert("RGB")).enhance(0.8)
    rgb.putalpha(box.getchannel("A"))
    rgb.save(os.path.join(DARK, "props", "penny_theatre.png"))
    prop("paper_rack_raw.png", "paper_rack.png", RACK_HEIGHT, 0.75)
    backdrop("last_margin_raw.png", "bg_last_margin.png", 0.9, tile=True)
    backdrop("table_new_flat_raw.png", os.path.join("backdrops", "bg_table_new_flat.png"), 0.95)


if __name__ == "__main__":
    main()
