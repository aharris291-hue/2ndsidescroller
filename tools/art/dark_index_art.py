"""Art for Region 6, the Index (Phase 3), from the painted ElevenLabs renders in
tools/art/source/.

Backdrops (assets/art/dark/):
  bg_back_pages.png      3840x1080, the archive at the back of the book (6-1), mirrored strip
  bg_card_catalogue.png  1920x1080, inside the great card catalogue (6-2)
  bg_reading_room.png    1920x1080, the domed reading room (6-3)
Sprites:
  enemies/silverfish.png  a book-eating silverfish, SILVERFISH_WIDTH px long, facing left
  props/index_drawer.png  a card catalogue drawer in profile, DRAWER_WIDTH px long, its
                          front (handle) at the right
  props/index_shutter.png a roll shutter, SHUTTER_WIDTH px wide; its red tab hangs below
                          the bottom rail (the game cuts the tab off and draws its own)

Run: python3 tools/art/dark_index_art.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")
SILVERFISH_WIDTH = 230
DRAWER_WIDTH = 256
SHUTTER_WIDTH = 96


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


def to_width(img: Image.Image, w: int) -> Image.Image:
    return img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)


def main() -> None:
    ImageEnhance.Brightness(strip(fit(os.path.join(SRC, "back_pages_raw.png")))).enhance(0.9).save(os.path.join(DARK, "bg_back_pages.png"))
    ImageEnhance.Brightness(fit(os.path.join(SRC, "card_catalogue_raw.png"))).enhance(0.9).save(os.path.join(DARK, "bg_card_catalogue.png"))
    ImageEnhance.Brightness(fit(os.path.join(SRC, "reading_room_raw.png"))).enhance(0.85).save(os.path.join(DARK, "bg_reading_room.png"))
    fish = to_width(cutout("silverfish_raw.png"), SILVERFISH_WIDTH)
    fish.save(os.path.join(DARK, "enemies", "silverfish.png"))
    drawer = to_width(cutout("drawer_raw.png"), DRAWER_WIDTH)
    drawer.save(os.path.join(DARK, "props", "index_drawer.png"))
    shutter = cutout("shutter_raw.png")
    # Cut off the hanging tab: keep down to the bottom rail (the last wide row).
    import numpy as np
    alpha = np.array(shutter)[:, :, 3]
    widths = (alpha > 0).sum(axis=1)
    rail = max(i for i, w in enumerate(widths) if w > shutter.width * 0.8)
    shutter = to_width(shutter.crop((0, 0, shutter.width, rail + 1)), SHUTTER_WIDTH)
    shutter.save(os.path.join(DARK, "props", "index_shutter.png"))
    print("wrote the Index's art: silverfish %s, drawer %s, shutter %s" % (fish.size, drawer.size, shutter.size))


if __name__ == "__main__":
    main()
