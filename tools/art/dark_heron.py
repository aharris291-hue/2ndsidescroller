"""The Grey Heron, Watermark Marsh's boss (Phase 3), from the ElevenLabs painting in
tools/art/source/heron_raw.png.

Writes to assets/art/dark/bosses/ (cut out, 640 px tall, facing left):
  heron.png        the whole bird (the bestiary picture)
  heron_body.png   the bird without its head and upper neck
  heron_head.png   the head and upper neck, which lunge on their own when it stabs
Prints where the beak tip, the head and the neck joint sit relative to the bottom
centre (its feet), for scripts/enemies/boss_heron.gd.

Run: python3 tools/art/dark_heron.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from dark_enemies import cut, fit_height  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source", "heron_raw.png")
OUT = os.path.join(ROOT, "assets", "art", "dark", "bosses", "heron.png")
HEIGHT = 640
# The head piece: the head, beak, plume and upper neck, inside this outline (sprite px),
# cut with a soft edge. The neck joint is the middle of its bottom edge.
HEAD_CUT_Y = 150
HEAD_OUTLINE = [(0, 0), (440, 0), (440, 70), (300, 92), (270, 120), (266, 150), (165, 150), (140, 178), (0, 178)]


def main() -> None:
    im = fit_height(cut(SRC), HEIGHT)
    im.save(OUT)
    alpha = np.asarray(im.getchannel("A")) > 80
    h, w = alpha.shape
    top = alpha[: int(h * 0.35)]
    ys, xs = np.nonzero(top)
    i = xs.argmin()
    tip = (int(xs[i]) - w / 2, int(ys[i]) - h)
    # the head: the top of the neck, a little behind where the beak starts
    head_rows = np.nonzero(alpha[: int(h * 0.2)].any(1))[0]
    hy = int(head_rows[0]) + 40
    hx = int(np.nonzero(alpha[hy])[0].mean())
    from PIL import Image, ImageDraw, ImageFilter
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).polygon(HEAD_OUTLINE, fill=255)
    mask = np.asarray(mask.filter(ImageFilter.GaussianBlur(2.5)), np.float32) / 255.0
    a = np.asarray(im).astype(np.float32)
    head = a.copy()
    head[:, :, 3] *= mask
    body = a.copy()
    body[:, :, 3] *= 1.0 - mask
    Image.fromarray(head.astype(np.uint8)).save(OUT.replace("heron.png", "heron_head.png"))
    Image.fromarray(body.astype(np.uint8)).save(OUT.replace("heron.png", "heron_body.png"))
    neck = np.nonzero(alpha[HEAD_CUT_Y - 1, 160:266])[0] + 160
    print("NECK %s" % ((float(neck.mean()) - w / 2, HEAD_CUT_Y - h),))
    print("heron %dx%d  BEAK_TIP %s  HEAD %s" % (w, h, tip, (hx - w / 2, hy - h)))


if __name__ == "__main__":
    main()
