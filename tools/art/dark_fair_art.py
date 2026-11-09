"""Art for Region 5, Gatefold Fair (Phase 3), from the painted ElevenLabs renders in
tools/art/source/.

Backdrops (assets/art/dark/):
  bg_midway.png         3840x1080, the drowned midway (5-1), mirrored strip
  bg_big_wheel.png      1920x1080, under the ferris wheel (5-2)
  bg_gatefold.png       1920x1080, inside the fold-out funhouse (5-3)
Sprites:
  enemies/carousel_horse.png   a carousel horse on its pole, cut off its white ground,
                               HORSE_HEIGHT px tall (the pole's foot is the bottom edge)
  props/gondola.png            a ferris wheel gondola, GONDOLA_WIDTH px wide (the hook's
                               tip is the top edge)

Run: python3 tools/art/dark_fair_art.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")
HORSE_HEIGHT = 300
GONDOLA_WIDTH = 176


def fit(path: str) -> Image.Image:
    return ImageOps.fit(Image.open(path).convert("RGB"), (1920, 1080), Image.LANCZOS)


def strip(img: Image.Image) -> Image.Image:
    out = Image.new("RGB", (3840, 1080))
    out.paste(img, (0, 0))
    out.paste(ImageOps.mirror(img), (1920, 0))
    return out


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
    ImageEnhance.Brightness(strip(fit(os.path.join(SRC, "midway_raw.png")))).enhance(0.9).save(os.path.join(DARK, "bg_midway.png"))
    ImageEnhance.Brightness(fit(os.path.join(SRC, "big_wheel_raw.png"))).enhance(0.85).save(os.path.join(DARK, "bg_big_wheel.png"))
    ImageEnhance.Brightness(fit(os.path.join(SRC, "gatefold_raw.png"))).enhance(0.9).save(os.path.join(DARK, "bg_gatefold.png"))
    horse = cutout("carousel_horse_raw.png")
    horse = horse.resize((round(horse.width * HORSE_HEIGHT / horse.height), HORSE_HEIGHT), Image.LANCZOS)
    horse.save(os.path.join(DARK, "enemies", "carousel_horse.png"))
    gondola = cutout("gondola_raw.png")
    gondola = gondola.resize((GONDOLA_WIDTH, round(gondola.height * GONDOLA_WIDTH / gondola.width)), Image.LANCZOS)
    gondola.save(os.path.join(DARK, "props", "gondola.png"))
    print("wrote the Fair's art: horse %s, gondola %s" % (horse.size, gondola.size))


if __name__ == "__main__":
    main()
