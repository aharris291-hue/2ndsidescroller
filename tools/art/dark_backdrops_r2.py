"""Backdrops for Region 2, Lanternfold at full size (Phase 3), from the painted
ElevenLabs renders in tools/art/source/.

  bg_drowned_quay.png 3840x1080, the drowned harbour at night (2-1), mirrored strip
  bg_lighthouse.png   1920x1080, inside the drowned lighthouse (2-2, vertical)
  bg_lamp_room.png    1920x1080, the lamp room floor seen from above (2-3, top-down)
  bg_shadow_wharf.png 3840x1080, the net sheds and cranes of the wharf (2-4), mirrored strip
  bg_lightkeepers_store.png 1920x1080, the lighthouse's flooded store under the stair
                      (the sealed back page): the lighthouse painting, darker and colder

Run: python3 tools/art/dark_backdrops_r2.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")


def fit(name: str) -> Image.Image:
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    return ImageOps.fit(img, (1920, 1080), Image.LANCZOS)


def strip(img: Image.Image) -> Image.Image:
    out = Image.new("RGB", (3840, 1080))
    out.paste(img, (0, 0))
    out.paste(ImageOps.mirror(img), (1920, 0))
    return out


def main() -> None:
    quay = strip(fit("drowned_quay_raw.png"))
    ImageEnhance.Brightness(quay).enhance(0.9).save(os.path.join(DARK, "bg_drowned_quay.png"))
    light = fit("lighthouse_raw.png")
    ImageEnhance.Brightness(light).enhance(0.8).save(os.path.join(DARK, "bg_lighthouse.png"))
    room = fit("lamp_room_raw.png")
    ImageEnhance.Brightness(room).enhance(0.72).save(os.path.join(DARK, "bg_lamp_room.png"))
    wharf = strip(fit("shadow_wharf_raw.png"))
    ImageEnhance.Brightness(wharf).enhance(0.9).save(os.path.join(DARK, "bg_shadow_wharf.png"))
    store = ImageOps.mirror(fit("lighthouse_raw.png"))
    store = ImageEnhance.Color(store).enhance(0.6)
    ImageEnhance.Brightness(store).enhance(0.5).save(os.path.join(DARK, "bg_lightkeepers_store.png"))
    print("wrote quay, lighthouse, lamp room, wharf and store backdrops")


if __name__ == "__main__":
    main()
