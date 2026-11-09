"""Backdrops for Region 4, the Spine Peaks (Phase 3), from the painted ElevenLabs
renders in tools/art/source/ (and the frostfold painting from Phase 0).

  bg_rime_slopes.png   3840x1080, the frozen folded mountains (4-1), mirrored strip
  bg_fold_works.png    3840x1080, Bindwell's needle gantries over the pop-up peaks (4-2), mirrored strip
  bg_pattern_room.png  1920x1080, inside Bindwell's pattern room (4-3)
  bg_stitched_ascent.png 3840x1080, the stitched summit cliffs (4-4), mirrored strip
  bg_bindwell_workshop.png 1920x1080, Bindwell's workshop at the top (boss)
  bg_low_point.png     3840x1080, the summit after, darker (4-5), mirrored strip

Run: python3 tools/art/dark_backdrops_r4.py
"""
import os

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")


def fit(path: str) -> Image.Image:
    img = Image.open(path).convert("RGB")
    return ImageOps.fit(img, (1920, 1080), Image.LANCZOS)


def strip(img: Image.Image) -> Image.Image:
    out = Image.new("RGB", (3840, 1080))
    out.paste(img, (0, 0))
    out.paste(ImageOps.mirror(img), (1920, 0))
    return out


def main() -> None:
    slopes = strip(fit(os.path.join(DARK, "backdrops", "bg_frostfold.png")))
    slopes.save(os.path.join(DARK, "bg_rime_slopes.png"))
    works = strip(fit(os.path.join(SRC, "fold_works_raw.png")))
    ImageEnhance.Brightness(works).enhance(0.85).save(os.path.join(DARK, "bg_fold_works.png"))
    room = fit(os.path.join(SRC, "pattern_room_raw.png"))
    ImageEnhance.Brightness(room).enhance(0.85).save(os.path.join(DARK, "bg_pattern_room.png"))
    summit = fit(os.path.join(DARK, "backdrops", "bg_spine_summit.png"))
    strip(summit).save(os.path.join(DARK, "bg_stitched_ascent.png"))
    ImageEnhance.Brightness(strip(ImageOps.mirror(summit))).enhance(0.6).save(os.path.join(DARK, "bg_low_point.png"))
    workshop = fit(os.path.join(SRC, "bindwell_workshop_raw.png"))
    ImageEnhance.Brightness(workshop).enhance(0.9).save(os.path.join(DARK, "bg_bindwell_workshop.png"))
    print("wrote the Peaks backdrops")


if __name__ == "__main__":
    main()
