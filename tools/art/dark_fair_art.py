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

Part 2:
  bg_ghost_train.png    1920x1080, inside the drowned ghost train (5-4)
  bg_big_top_climb.png  1920x1080, the rigging over the big top (5-5)
  bg_big_top.png        1920x1080, the empty ring inside (the Barker's arena)
  enemies/barker.png    the Barker, BARKER_HEIGHT px tall, feet on the bottom edge
  enemies/pop_ghoul.png a ghost train scare on its spring, GHOUL_HEIGHT px tall
  props/ghost_cart.png  a ghost train car, CART_WIDTH px wide, cut off at the top of
                        the rail it was painted on (the game draws its own rail there)

Run: python3 tools/art/dark_fair_art.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")
HORSE_HEIGHT = 300
GONDOLA_WIDTH = 176
BARKER_HEIGHT = 560
GHOUL_HEIGHT = 220
CART_WIDTH = 220
# The cart's painted rail starts this far down its cut-out (px, before scaling).
CART_RAIL_TOP = 566


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
    for name, out in (("ghost_train_raw.png", "bg_ghost_train.png"), ("big_top_climb_raw.png", "bg_big_top_climb.png"), ("big_top_raw.png", "bg_big_top.png")):
        ImageEnhance.Brightness(fit(os.path.join(SRC, name))).enhance(0.9).save(os.path.join(DARK, out))
    barker = cutout("barker_raw.png")
    barker = barker.resize((round(barker.width * BARKER_HEIGHT / barker.height), BARKER_HEIGHT), Image.LANCZOS)
    barker.save(os.path.join(DARK, "enemies", "barker.png"))
    ghoul = cutout("ghoul_raw.png")
    ghoul = ghoul.resize((round(ghoul.width * GHOUL_HEIGHT / ghoul.height), GHOUL_HEIGHT), Image.LANCZOS)
    ghoul.save(os.path.join(DARK, "enemies", "pop_ghoul.png"))
    cart = cutout("ghost_cart_raw.png")
    cart = cart.crop((0, 0, cart.width, CART_RAIL_TOP))
    cart = cart.resize((CART_WIDTH, round(cart.height * CART_WIDTH / cart.width)), Image.LANCZOS)
    cart.save(os.path.join(DARK, "props", "ghost_cart.png"))
    print("wrote part 2: barker %s, ghoul %s, cart %s" % (barker.size, ghoul.size, cart.size))
    print("wrote the Fair's art: horse %s, gondola %s" % (horse.size, gondola.size))


if __name__ == "__main__":
    main()
