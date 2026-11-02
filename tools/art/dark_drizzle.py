"""Cut the painted Drizzle (ElevenLabs render, tools/art/source/drizzle_painted_raw.png) off
its flat grey background and write the game sprites:
  assets/art/dark/characters/drizzle.png         (floating, 360 px tall)
  assets/art/dark/characters/drizzle_pinned.png  (squashed and tilted, for P-2)

Run: python3 tools/art/dark_drizzle.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
RAW = os.path.join(ROOT, "tools", "art", "source", "drizzle_painted_raw.png")
OUT = os.path.join(ROOT, "assets", "art", "dark", "characters")


def cut() -> Image.Image:
    img = Image.open(RAW).convert("RGB")
    a = np.asarray(img, np.float32)
    h, w = a.shape[:2]
    corners = np.concatenate([a[:20, :20].reshape(-1, 3), a[:20, -20:].reshape(-1, 3),
                              a[-20:, :20].reshape(-1, 3), a[-20:, -20:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(-1))
    # background = connected to the border and close to the grey
    near = dist < 14
    labels, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    background = np.isin(labels, list(border))
    alpha = np.where(background, 0.0, 1.0)
    # soft edge: fade pixels that are only a little different from the grey
    edge = ndimage.binary_dilation(background, iterations=2) & ~background
    alpha[edge] = np.clip((dist[edge] - 8) / 30.0, 0, 1)
    alpha = ndimage.gaussian_filter(alpha, 0.7)
    rgba = np.dstack([a, alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    return out.crop(out.getbbox())


def main() -> None:
    sprite = cut()
    scale = 360 / sprite.height
    floating = sprite.resize((round(sprite.width * scale), 360), Image.LANCZOS)
    floating.save(os.path.join(OUT, "drizzle.png"))
    pinned = sprite.resize((round(sprite.width * scale * 1.1), round(360 * 0.72)), Image.LANCZOS)
    pinned = pinned.rotate(8, resample=Image.BICUBIC, expand=True)
    pinned.save(os.path.join(OUT, "drizzle_pinned.png"))
    print("wrote", floating.size, pinned.size)


if __name__ == "__main__":
    main()
