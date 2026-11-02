"""Dark-rebuild repaint of the paper tile atlas (assets/art/tiles/paper_tiles.png).

Keeps every tile's silhouette and layout (so the TileSet's collision shapes still
fit) and remaps its colours through a sodden, muted gradient per tile, then adds
water stains, grain and a darker bottom edge so the ground reads as soaked paper
under rain.

The bright original is kept as tools/art/source/paper_tiles_bright.png the first time this runs.
Run: python3 tools/art/dark_tiles.py
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
ATLAS = os.path.join(ROOT, "assets", "art", "tiles", "paper_tiles.png")
BRIGHT = os.path.join(ROOT, "tools", "art", "source", "paper_tiles_bright.png")
T = 64

# (col, row) -> (shadow colour, highlight colour). Missing tiles use DEFAULT.
SOIL = ((22, 18, 16), (92, 78, 64))
WOOD = ((18, 14, 12), (96, 76, 58))
STONE = ((24, 24, 26), (110, 106, 98))
INK = ((6, 10, 14), (52, 70, 82))
FROST = ((30, 36, 44), (150, 158, 166))
PALETTES = {
    (0, 0): ((20, 24, 18), (98, 104, 82)),   # turf over soil: dead moss
    (1, 0): SOIL, (2, 0): WOOD, (3, 0): INK,
    (0, 1): SOIL, (1, 1): ((40, 34, 26), (138, 124, 96)),  # old yellow page -> sodden parchment
    (2, 1): ((24, 16, 14), (120, 56, 44)), (3, 1): ((10, 12, 22), (60, 66, 92)),
    (0, 2): STONE, (1, 2): WOOD, (2, 2): INK, (3, 2): ((16, 14, 22), (96, 60, 66)),
    (0, 3): ((10, 12, 22), (58, 64, 88)), (1, 3): ((26, 12, 8), (120, 60, 34)),
    (2, 3): FROST, (3, 3): FROST,
    (0, 4): ((26, 18, 16), (150, 120, 104)), (1, 4): FROST, (2, 4): FROST, (3, 4): FROST,
    (0, 5): FROST, (1, 5): ((10, 14, 24), (64, 74, 96)),
    (2, 5): ((20, 24, 18), (98, 104, 82)), (3, 5): SOIL,
}
DEFAULT = SOIL


def remap(tile: np.ndarray, shadow, light, seed: int) -> np.ndarray:
    rgb = tile[..., :3].astype(np.float32) / 255.0
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    # Keep detail but squash contrast a little so nothing pops.
    # Squash contrast and cap the highlights so the old bright doodle lines sink
    # into the paper instead of glowing.
    lum = np.minimum(np.clip((lum - 0.5) * 0.75 + 0.5, 0.0, 1.0) ** 1.2, 0.55)
    s, l = np.array(shadow, np.float32), np.array(light, np.float32)
    out = s + (l - s) * lum[..., None]
    rnd = np.random.default_rng(seed)
    # Water stains: soft dark blotches.
    stains = np.zeros((T, T), np.float32)
    for _ in range(3):
        cx, cy, r = rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(8, 22)
        yy, xx = np.mgrid[0:T, 0:T]
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        ring = np.exp(-((d - r) ** 2) / 10.0) * 0.5 + (d < r) * 0.25
        stains = np.maximum(stains, ring)
    out *= (1.0 - 0.22 * stains)[..., None]
    out *= (1.0 + rnd.normal(0, 0.05, (T, T)))[..., None]  # grain
    # Wet, darker bottom of each tile so stacked rows read as layers.
    out *= np.linspace(1.0, 0.82, T, dtype=np.float32)[:, None, None]
    res = tile.copy()
    res[..., :3] = np.clip(out, 0, 255).astype(np.uint8)
    return res


def main() -> None:
    if not os.path.exists(BRIGHT):
        Image.open(ATLAS).save(BRIGHT)
    src = np.array(Image.open(BRIGHT).convert("RGBA"))
    out = src.copy()
    rows, cols = src.shape[0] // T, src.shape[1] // T
    for r in range(rows):
        for c in range(cols):
            tile = src[r * T:(r + 1) * T, c * T:(c + 1) * T]
            shadow, light = PALETTES.get((c, r), DEFAULT)
            out[r * T:(r + 1) * T, c * T:(c + 1) * T] = remap(tile, shadow, light, r * 10 + c)
    Image.fromarray(out).save(ATLAS)
    print("repainted", ATLAS)


if __name__ == "__main__":
    main()
