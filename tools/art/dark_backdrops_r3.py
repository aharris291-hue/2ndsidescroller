"""Backdrops for Region 3, Watermark Marsh (Phase 3), from the painted ElevenLabs
renders in tools/art/source/.

  bg_sump_road.png      3840x1080, the marsh's boardwalks over black ink (3-1), mirrored strip
  bg_drowned_ledger.png 3840x1080, the sunken archive and its ink channels (3-2), mirrored strip
  bg_sluice_house.png   1920x1080, inside the sluice house (3-3)
  bg_reed_beds.png      3840x1080, paper reeds standing in the ink (3-4), mirrored strip
  bg_herons_reach.png   3840x1080, the black lake with the heron in the mist (3-5), mirrored strip
  bg_heronry.png        1920x1080, the reed ring round the heron's nest (the boss)

Run: python3 tools/art/dark_backdrops_r3.py
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
    road = strip(fit("sump_road_raw.png"))
    ImageEnhance.Brightness(road).enhance(0.85).save(os.path.join(DARK, "bg_sump_road.png"))
    ledger = strip(fit("drowned_ledger_raw.png"))
    ImageEnhance.Brightness(ledger).enhance(0.85).save(os.path.join(DARK, "bg_drowned_ledger.png"))
    sluice = fit("sluice_house_raw.png")
    ImageEnhance.Brightness(sluice).enhance(0.8).save(os.path.join(DARK, "bg_sluice_house.png"))
    for raw, out in (("reed_beds_raw.png", "bg_reed_beds.png"), ("herons_reach_raw.png", "bg_herons_reach.png")):
        ImageEnhance.Brightness(strip(fit(raw))).enhance(0.85).save(os.path.join(DARK, out))
    ImageEnhance.Brightness(fit("heronry_raw.png")).enhance(0.85).save(os.path.join(DARK, "bg_heronry.png"))
    print("wrote the Marsh backdrops")


if __name__ == "__main__":
    main()
