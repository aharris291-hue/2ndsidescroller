"""Painted bosses for the dark rebuild (docs/ART_STYLE.md).

Inputs are ElevenLabs paintings kept in tools/art/source (<name>_raw.png):
  millwheel_body, millwheel_sails, millwheel_core   the Old Millwheel
  kraken_body, kraken_eye, kraken_tentacle         the Blotch Kraken
  sogg_body                                        the Sogg
The Drizzle-heart is built here from the painted Drizzle, trapped in a knot of ink.

Writes to assets/art/dark/bosses/, and prints where each painted landmark (the
Millwheel's axle and door, the Kraken's eye socket, the Sogg's chest) sits relative to
its sprite's centre, so the scenes can line the art up with their gameplay nodes.

Run (from anywhere): python3 tools/art/dark_bosses.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from dark_enemies import cut, fit_height  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
OUT = os.path.join(ROOT, "assets", "art", "dark", "bosses")
DRIZZLE = os.path.join(ROOT, "assets", "art", "dark", "characters", "drizzle.png")

# The sail hitboxes (boss_millwheel.tscn) sit at 19.5 degrees + n * 90 degrees, from 42
# to 272 px out from the hub. The painting's arms lie on the diagonals (45 degrees), so
# turn it by the difference and size it so the arm tips reach just past the hitboxes.
SAIL_TURN = 25.5
SAIL_TIP_RADIUS = 285
# The Sogg painting's chest hollow sits this far right of the figure's centre (px at
# 560 tall), and this far above it.
SOGG_CHEST_X = 34
SOGG_CHEST_Y = -65


def raw(name: str) -> Image.Image:
    return cut(os.path.join(SRC, name + "_raw.png"))


def square(im: Image.Image, size: int) -> Image.Image:
    """Fit a round piece into a size x size canvas, centred."""
    im = im.copy()
    im.thumbnail((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size))
    out.paste(im, ((size - im.width) // 2, (size - im.height) // 2))
    return out


def sails() -> Image.Image:
    im = raw("millwheel_sails")
    # Centre on the hub: the arms cross at the middle of the cut-out's bounding box.
    side = max(im.size)
    pad = Image.new("RGBA", (side, side))
    pad.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    turned = pad.rotate(SAIL_TURN, resample=Image.BICUBIC, expand=True)
    turned = turned.crop(turned.getbbox())
    # The tip radius is half the diagonal span of the arms, about half the larger side.
    alpha = np.asarray(turned.getchannel("A"))
    ys, xs = np.nonzero(alpha > 60)
    cx, cy = turned.width / 2, turned.height / 2
    tip = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()
    scale = SAIL_TIP_RADIUS / tip
    size = (round(turned.width * scale), round(turned.height * scale))
    turned = turned.resize(size, Image.LANCZOS)
    side = max(size)
    out = Image.new("RGBA", (side, side))
    out.paste(turned, ((side - size[0]) // 2, (side - size[1]) // 2))
    return out


def dark_hole(im: Image.Image, box: tuple) -> tuple:
    """Centre of the darkest round hollow inside `box` (fractions of the image), in px
    from the image's centre. Used for the Kraken's socket and the Millwheel's axle."""
    a = np.asarray(im.convert("RGBA"), np.float32)
    lum = a[..., :3].mean(-1) * (a[..., 3] / 255)
    h, w = lum.shape
    x0, y0, x1, y1 = int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)
    region = ndimage.uniform_filter(lum, size=max(8, w // 14))[y0:y1, x0:x1]
    region += (a[y0:y1, x0:x1, 3] < 200) * 1000  # stay inside the figure
    y, x = np.unravel_index(np.argmin(region), region.shape)
    return (x + x0 - w / 2, y + y0 - h / 2)


def drizzle_heart() -> Image.Image:
    """Drizzle, small and curled, trapped in a knot of ink that glows a cold grey."""
    w, h = 220, 200
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = (xx - w / 2) / (w * 0.44), (yy - h / 2) / (h * 0.44)
    rng = np.random.default_rng(7)
    angle = np.arctan2(ny, nx)
    wobble = 1 + 0.08 * np.sin(angle * 5 + 1.3) + 0.05 * np.sin(angle * 11)
    r = np.sqrt(nx ** 2 + ny ** 2) / wobble
    mask = np.clip((1.0 - r) * 30, 0, 1)
    # ink tendrils reaching out of the knot
    tendrils = np.zeros((h, w), np.float32)
    for _ in range(9):
        a0 = rng.uniform(0, math.tau)
        for t in np.linspace(0.85, 1.12, 40):
            px = w / 2 + math.cos(a0 + (t - 0.85) * 0.8) * t * w * 0.44
            py = h / 2 + math.sin(a0 + (t - 0.85) * 0.8) * t * h * 0.44
            thick = 3.0 * (1.12 - t) / 0.27 + 0.6
            tendrils = np.maximum(tendrils, np.clip(thick - np.sqrt((xx - px) ** 2 + (yy - py) ** 2), 0, 1))
    alpha = np.clip(np.maximum(mask, tendrils), 0, 1)
    ink = np.array([16, 14, 18], np.float32)
    glow = np.exp(-(r / 0.6) ** 2)[..., None] * np.array([150, 158, 176], np.float32)
    rgb = ink + glow
    rim = np.exp(-(((xx - w * 0.36) / 18) ** 2 + ((yy - h * 0.26) / 9) ** 2))  # wet sheen, upper left
    rgb += rim[..., None] * 70
    base = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
    # Drizzle inside, dimmed, as if seen through dark water.
    drizzle = Image.open(DRIZZLE).convert("RGBA")
    drizzle = fit_height(drizzle, 138).rotate(-12, resample=Image.BICUBIC, expand=True)
    d = np.asarray(drizzle, np.float32)
    d[..., :3] = d[..., :3] * 0.85 + np.array([40, 46, 60]) * 0.15
    d[..., 3] *= 0.97
    drizzle = Image.fromarray(d.astype(np.uint8), "RGBA")
    base.alpha_composite(drizzle, ((w - drizzle.width) // 2, (h - drizzle.height) // 2 + 4))
    # a few ink threads across him, so he reads as trapped
    over = np.zeros((h, w), np.float32)
    for k in range(3):
        y_line = h * (0.38 + 0.14 * k) + np.sin(xx[0] * 0.05 + k) * 6
        over = np.maximum(over, np.clip(1.6 - np.abs(yy - y_line[None, :]), 0, 1) * (mask > 0.5))
    a = np.asarray(base, np.float32)
    a[..., :3] = a[..., :3] * (1 - over[..., None] * 0.85) + ink * over[..., None] * 0.85
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    body = fit_height(raw("millwheel_body"), 470)
    body.save(os.path.join(OUT, "millwheel_body.png"))
    print("millwheel_body", body.size, "axle at", dark_hole(body, (0.3, 0.05, 0.7, 0.4)))
    sails().save(os.path.join(OUT, "millwheel_sails.png"))
    square(raw("millwheel_core"), 124).save(os.path.join(OUT, "millwheel_core.png"))
    kraken = fit_height(raw("kraken_body"), 440)
    kraken.save(os.path.join(OUT, "kraken_body.png"))
    print("kraken_body", kraken.size, "socket at", dark_hole(kraken, (0.3, 0.1, 0.7, 0.5)))
    square(raw("kraken_eye"), 150).save(os.path.join(OUT, "kraken_eye.png"))
    fit_height(raw("kraken_tentacle"), 600).save(os.path.join(OUT, "kraken_tentacle.png"))
    sogg = fit_height(raw("sogg_body"), 560)
    # Pad so the glowing chest hollow (where the heart sits) is centred left to right:
    # the body flips to face Patch, and the heart must stay in the hollow when it does.
    pad = Image.new("RGBA", (sogg.width + 2 * SOGG_CHEST_X, sogg.height))
    pad.paste(sogg, (0, 0))
    sogg = pad
    sogg.save(os.path.join(OUT, "sogg_body.png"))
    print("sogg_body", sogg.size)
    drizzle_heart().save(os.path.join(OUT, "drizzle_heart.png"))
    for name in sorted(os.listdir(OUT)):
        if name.endswith(".png"):
            print(name, Image.open(os.path.join(OUT, name)).size)


if __name__ == "__main__":
    main()
