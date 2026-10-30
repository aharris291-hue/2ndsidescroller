"""Generates the 3D material textures for the real-world desk (the Margin).

Wood albedo and normal maps for the desk, plus a paper normal map for the book
page lying on it. Run from the repo root:

    python3 tools/art/generate_materials.py

Requires Pillow and numpy. Output is deterministic (fixed random seed).
"""

import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "materials")
SIZE = 1024


def smooth_noise(gen, shape, scale):
    """Value noise: random grid blown up with bicubic smoothing."""
    small = gen.random((max(2, shape[0] // scale), max(2, shape[1] // scale)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((shape[1], shape[0]), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def normal_from_height(height, strength):
    gy, gx = np.gradient(height)
    nx, ny = -gx * strength, -gy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


def build_wood():
    gen = np.random.default_rng(42)
    h = w = SIZE
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    planks = 4
    plank_h = h / planks
    albedo = np.zeros((h, w, 3), np.float32)
    height = np.zeros((h, w), np.float32)
    base_colors = [(176, 112, 66), (190, 124, 74), (165, 102, 60), (184, 120, 70)]
    warp = smooth_noise(gen, (h, w), 128) * 70 + smooth_noise(gen, (h, w), 24) * 10
    fine = smooth_noise(gen, (h, w), 2)
    for p in range(planks):
        rows = slice(int(p * plank_h), int((p + 1) * plank_h))
        local_y = y[rows] - p * plank_h
        # Grain: stretched sine bands warped by noise, different phase per plank.
        grain = np.sin((local_y + warp[rows]) * (0.12 + 0.025 * p) + p * 3.1)
        grain = (grain * 0.5 + 0.5) ** 2.2
        streak = smooth_noise(gen, (rows.stop - rows.start, w), 8)
        col = np.array(base_colors[p], np.float32) / 255.0
        shade = 0.88 + 0.12 * (1 - grain) - 0.10 * streak + 0.04 * fine[rows]
        albedo[rows] = col[None, None, :] * shade[..., None]
        height[rows] = grain * 0.6 + fine[rows] * 0.15
        # Seam between planks: a dark groove.
        edge = np.minimum(local_y, plank_h - 1 - local_y)
        groove = np.clip(1.0 - edge / 3.0, 0, 1)
        albedo[rows] *= (1 - 0.55 * groove)[..., None]
        height[rows] -= groove * 2.0
        # Butt joint somewhere along each plank.
        jx = int(gen.uniform(0.2, 0.8) * w)
        joint = np.clip(1.0 - np.abs(x[rows] - jx) / 2.5, 0, 1)
        albedo[rows] *= (1 - 0.5 * joint)[..., None]
        height[rows] -= joint * 2.0
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "wood_albedo.png"))
    normal_from_height(height, 3.0).save(os.path.join(OUT, "wood_normal.png"))


def build_paper():
    gen = np.random.default_rng(7)
    height = smooth_noise(gen, (512, 512), 4) * 0.6 + smooth_noise(gen, (512, 512), 1) * 0.4
    img = Image.fromarray((height * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    height = np.asarray(img).astype(np.float32) / 255.0
    normal_from_height(height, 2.0).save(os.path.join(OUT, "paper_normal.png"))


def build_cardboard():
    """Corrugated cardboard: ribbed normal map for book covers and boxes."""
    gen = np.random.default_rng(3)
    y, x = np.mgrid[0:512, 0:512].astype(np.float32)
    height = np.sin(x * 0.35) * 0.5 + smooth_noise(gen, (512, 512), 2) * 0.3
    normal_from_height(height, 1.2).save(os.path.join(OUT, "cardboard_normal.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build_wood()
    build_paper()
    build_cardboard()
    print("Materials written to", OUT)
