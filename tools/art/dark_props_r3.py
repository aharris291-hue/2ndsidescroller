"""Props for Region 3, Watermark Marsh (Phase 3).

Writes to assets/art/dark/props/:
  patch_blot.png     Patch as a blot of ink while he Blot Dives: a glossy black fox-shaped
                     splash with a pale paper rim, his two X-stitched eyes and a thread of
                     red bandana, 112 x 80
  ink_current.png    a streak of pale silt carried along an ink current, 128 x 24
  sluice_wheel.png   the gate's iron hand wheel, 64 x 64

Run: python3 tools/art/dark_props_r3.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

PROPS = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "dark", "props")
S = 4


def patch_blot():
    """A fox-shaped splash: a long glossy body with two ear points at the front and a
    torn wisp of tail behind, edged in a pale paper rim so it reads against the ink."""
    w, h = 112, 80
    rnd = random.Random(7)
    cx, cy = 54 * S, 46 * S
    shape = Image.new("L", (w * S, h * S), 0)
    d = ImageDraw.Draw(shape)
    pts = []
    for i in range(48):
        a = i / 48 * math.tau
        # longer and lower behind, rounder in front (he faces right)
        rx = (36 if math.cos(a) < 0 else 30) + rnd.uniform(-2, 2)
        ry = 17 + 3 * math.sin(a * 4 + 0.6) + rnd.uniform(-1.5, 1.5)
        pts.append((cx + math.cos(a) * rx * S, cy + math.sin(a) * ry * S))
    d.polygon(pts, fill=255)
    # ears: two points pricked up over the eyes
    for ex, lean in ((70, 2), (84, 5)):
        d.polygon([((ex - 7) * S, 36 * S), ((ex + lean) * S, 14 * S), ((ex + 7) * S, 36 * S)], fill=255)
    # the torn stump of tail, trailing off in drops
    d.polygon([(22 * S, 40 * S), (6 * S, 30 * S), (10 * S, 40 * S), (4 * S, 46 * S), (22 * S, 52 * S)], fill=255)
    for x, y, r in ((3, 24, 2.5), (8, 58, 2), (16, 64, 1.5)):
        d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=255)
    shape = shape.filter(ImageFilter.GaussianBlur(0.8 * S))
    shape = shape.point(lambda v: 255 if v > 110 else int(v * 2.3))
    rim = shape.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.2 * S))
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    img.paste((150, 158, 186, 255), (0, 0), rim.point(lambda v: int(v * 0.55)))
    body = Image.new("RGBA", (w * S, h * S), (10, 11, 18, 255))
    img.paste(body, (0, 0), shape)
    d = ImageDraw.Draw(img)
    # gloss along the back
    d.arc([cx - 30 * S, cy - 16 * S, cx + 26 * S, cy + 10 * S], 205, 300, fill=(120, 132, 170, 170), width=2 * S)
    d.arc([cx - 20 * S, cy - 10 * S, cx + 8 * S, cy + 6 * S], 210, 260, fill=(170, 180, 210, 120), width=S)
    # the bandana's thread, still knotted at his neck
    d.line([(cx + 4 * S, cy + 10 * S), (cx - 10 * S, cy + 14 * S), (cx - 18 * S, cy + 24 * S)], fill=(160, 32, 30, 235), width=2 * S)
    # X-stitched button eyes
    for ex in (cx + 14 * S, cx + 28 * S):
        ey = cy - 6 * S
        d.ellipse([ex - 5.5 * S, ey - 5.5 * S, ex + 5.5 * S, ey + 5.5 * S], fill=(200, 206, 218, 255))
        for sx in (-1, 1):
            d.line([(ex - 3.2 * S, ey - 3.2 * S * sx), (ex + 3.2 * S, ey + 3.2 * S * sx)], fill=(26, 34, 70, 255), width=int(1.6 * S))
    return img.resize((w, h), Image.LANCZOS)


def ink_current():
    w, h = 128, 24
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (y, a) in enumerate(((8, 120), (12, 160), (16, 90))):
        x0 = (i * 18) * S
        d.line([(x0, y * S), (w * S - (2 - i) * 14 * S, (y + (1 if i == 1 else -1)) * S)], fill=(170, 176, 160, a), width=int(1.5 * S))
    img = img.filter(ImageFilter.GaussianBlur(1.2 * S))
    return img.resize((w, h), Image.LANCZOS)


def sluice_wheel():
    w = 64
    img = Image.new("RGBA", (w * S, w * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = w * S / 2
    iron = (60, 58, 60, 255)
    d.ellipse([4 * S, 4 * S, (w - 4) * S, (w - 4) * S], outline=iron, width=5 * S)
    for i in range(6):
        a = i / 6 * math.tau
        d.line([(c, c), (c + math.cos(a) * 26 * S, c + math.sin(a) * 26 * S)], fill=iron, width=3 * S)
    d.ellipse([c - 6 * S, c - 6 * S, c + 6 * S, c + 6 * S], fill=(96, 70, 44, 255))
    d.arc([6 * S, 6 * S, (w - 6) * S, (w - 6) * S], 200, 260, fill=(150, 140, 130, 200), width=S)
    return img.resize((w, w), Image.LANCZOS)


def main():
    patch_blot().save(os.path.join(PROPS, "patch_blot.png"))
    ink_current().save(os.path.join(PROPS, "ink_current.png"))
    sluice_wheel().save(os.path.join(PROPS, "sluice_wheel.png"))
    print("wrote patch_blot, ink_current and sluice_wheel")


if __name__ == "__main__":
    main()
