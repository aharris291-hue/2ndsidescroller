"""Backdrops for the Spine hub and Region 1 from the painted ElevenLabs renders in
tools/art/source/ (spine_hub_raw.png, sodden_fields_raw.png).

  bg_spine_hub.png      1920x1080, the ruined bindery inside the book's spine
  bg_sodden_fields.png  3840x1080, the flooded meadow mirrored into a seamless strip
  bg_sheepfold.png      3840x1080, Fluff's flooded sheepfold at night (1-2), mirrored strip
  bg_drowned_chapel.png 1920x1080, the chapel floor seen from above (1-3, top-down)

Run: python3 tools/art/dark_backdrops_r1.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")


def fit(name: str) -> Image.Image:
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    return ImageOps.fit(img, (1920, 1080), Image.LANCZOS)


def main() -> None:
    hub = fit("spine_hub_raw.png")
    hub = ImageEnhance.Brightness(hub).enhance(0.8)
    hub.save(os.path.join(DARK, "bg_spine_hub.png"))
    fields = fit("sodden_fields_raw.png")
    strip = Image.new("RGB", (3840, 1080))
    strip.paste(fields, (0, 0))
    strip.paste(ImageOps.mirror(fields), (1920, 0))
    ImageEnhance.Brightness(strip).enhance(0.85).save(os.path.join(DARK, "bg_sodden_fields.png"))
    fold = fit("sheepfold_raw.png")
    strip = Image.new("RGB", (3840, 1080))
    strip.paste(fold, (0, 0))
    strip.paste(ImageOps.mirror(fold), (1920, 0))
    ImageEnhance.Brightness(strip).enhance(0.9).save(os.path.join(DARK, "bg_sheepfold.png"))
    chapel = fit("drowned_chapel_raw.png")
    ImageEnhance.Brightness(chapel).enhance(0.75).save(os.path.join(DARK, "bg_drowned_chapel.png"))
    print("wrote hub, fields, sheepfold and chapel backdrops")


if __name__ == "__main__":
    main()
