"""Painted regular enemies for the dark rebuild (docs/ART_STYLE.md).

Inputs are ElevenLabs paintings kept in tools/art/source:
  ink_spitter_raw.png   the Ink Spitter, facing left
  tack_knight_raw.png   the Tack Knight, facing left (mirrored here: its script faces right)
The ink blob and ink drip are small enough to paint here in code, in the same palette.

Writes to assets/art/dark/enemies/:
  ink_spitter.png  tack_knight.png  ink_blob.png  ink_drip.png

Run: python3 tools/art/dark_enemies.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
OUT = os.path.join(ROOT, "assets", "art", "dark", "enemies")

# Texture heights (px). Each scene shows them at a scale that gives the on-screen height
# from the size bands in docs/ART_STYLE.md.
SPITTER_H = 220
KNIGHT_H = 330


def cut(path: str) -> Image.Image:
    """Cut a painting off its flat grey background (rembg, then trim matte noise)."""
    from rembg import new_session, remove
    img = Image.open(path).convert("RGB")
    out = np.array(remove(img, session=new_session("isnet-general-use")))
    alpha = out[:, :, 3].astype(np.float32)
    alpha[alpha < 24] = 0
    # Keep only the largest piece plus anything touching it (drops stray specks).
    labels, n = ndimage.label(alpha > 0)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(alpha), labels, range(1, n + 1))
        keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.02])
        alpha[~keep] = 0
    out[:, :, 3] = alpha.astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    return im.crop(im.getbbox())


def fit_height(im: Image.Image, h: int) -> Image.Image:
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)


def centre_body(im: Image.Image) -> Image.Image:
    """Pad the canvas so the body's mass sits in the middle. Sprite2D draws centred, and a
    long lance or cape on one side would otherwise push the body off the collision shape;
    padding (rather than a sprite offset) keeps flip_h mirroring around the body."""
    alpha = np.asarray(im.getchannel("A"), np.float32)
    cx = int(round((alpha.sum(0) * np.arange(im.width)).sum() / alpha.sum()))
    half = max(cx, im.width - cx)
    out = Image.new("RGBA", (half * 2, im.height))
    out.paste(im, (half - cx, 0))
    return out


def ink_blob() -> Image.Image:
    """A gob of ink flying to the right: round head, ragged tail, a few paper flecks."""
    w, h = 72, 48
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    head = ((xx - 46) / 20) ** 2 + ((yy - 24) / 17) ** 2 < 1
    tail = (xx > 8) & (xx < 46) & (np.abs(yy - 24) < (xx - 8) / 38 * 13 + np.sin(xx * 0.7) * 2)
    mask = ndimage.gaussian_filter((head | tail).astype(np.float32), 1.0)
    rgb = np.zeros((h, w, 3), np.float32) + np.array([20, 16, 18])
    # wet sheen from the upper left
    sheen = np.exp(-(((xx - 40) / 7) ** 2 + ((yy - 16) / 4) ** 2))
    rgb += sheen[..., None] * np.array([110, 110, 124])
    rng = np.random.default_rng(3)
    for _ in range(5):  # paper flecks caught in the ink
        cx, cy = rng.integers(20, 60), rng.integers(14, 34)
        fleck = ((xx - cx) ** 2 + (yy - cy) ** 2) < rng.uniform(2, 5)
        rgb[fleck & (mask > 0.6)] = np.array([150, 128, 96])
    out = np.dstack([np.clip(rgb, 0, 255), np.clip(mask * 255, 0, 255)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def ink_drip() -> Image.Image:
    """A falling drop of ink: a teardrop pointing up, with a sheen on the left."""
    w, h = 40, 56
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = 15.0
    cy = h - r - 3
    body = ((xx - w / 2) ** 2 + (yy - cy) ** 2) < r * r
    taper = (yy < cy) & (np.abs(xx - w / 2) < (yy - 3) / (cy - 3) * r) & (yy > 3)
    mask = ndimage.gaussian_filter((body | taper).astype(np.float32), 0.8)
    rgb = np.zeros((h, w, 3), np.float32) + np.array([18, 14, 16])
    sheen = np.exp(-(((xx - 14) / 3.5) ** 2 + ((yy - cy + 4) / 6) ** 2))
    rgb += sheen[..., None] * np.array([120, 120, 136])
    out = np.dstack([np.clip(rgb, 0, 255), np.clip(mask * 255, 0, 255)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    spitter = centre_body(fit_height(cut(os.path.join(SRC, "ink_spitter_raw.png")), SPITTER_H))
    spitter.save(os.path.join(OUT, "ink_spitter.png"))
    knight = fit_height(cut(os.path.join(SRC, "tack_knight_raw.png")), KNIGHT_H)
    knight = centre_body(knight.transpose(Image.FLIP_LEFT_RIGHT))
    knight.save(os.path.join(OUT, "tack_knight.png"))
    ink_blob().save(os.path.join(OUT, "ink_blob.png"))
    ink_drip().save(os.path.join(OUT, "ink_drip.png"))
    for name in ("ink_spitter", "tack_knight", "ink_blob", "ink_drip"):
        print(name, Image.open(os.path.join(OUT, name + ".png")).size)


if __name__ == "__main__":
    main()
