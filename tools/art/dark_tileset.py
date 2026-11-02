"""Dark-rebuild tile atlas for the text-map levels (TextLevel).

Writes assets/art/dark/tiles/dark_tiles.png, an 8 x 4 atlas of 64 px tiles, and the
matching TileSet resources/dark_tiles.tres.

Rows are materials, columns are pieces. TextLevel picks the piece from each cell's
neighbours, so a map only says which material goes where.

  rows:    0 shelf wood   1 stacked books   2 sodden paper earth   3 damp stone
  columns: 0 fill A   1 fill B   2 top   3 top-left   4 top-right   5 left   6 right
           7 one-way plank (thin board, collides on its top only)

Every top surface carries a pale, lit lip so standable ground always reads against
the dark (Level Design Bible: "safe ground is pale paper").

Run: python3 tools/art/dark_tileset.py
"""
import os

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT_PNG = os.path.join(ROOT, "assets", "art", "dark", "tiles", "dark_tiles.png")
OUT_TRES = os.path.join(ROOT, "resources", "dark_tiles.tres")
T = 64
COLS, ROWS = 8, 4
LIP = np.array([196, 184, 160], np.float32)  # pale lit paper edge
OUTLINE = np.array([10, 8, 8], np.float32)


def noise(seed: int, sigma: float, shape=(T, T)) -> np.ndarray:
    """Periodic noise in [-1, 1] that tiles seamlessly."""
    n = np.random.default_rng(seed).normal(0, 1, shape)
    n = gaussian_filter(n, sigma, mode="wrap")
    return n / (np.abs(n).max() + 1e-6)


def ramp(t: np.ndarray, dark, light) -> np.ndarray:
    d, l = np.array(dark, np.float32), np.array(light, np.float32)
    return d + (l - d) * np.clip(t, 0, 1)[..., None]


# --- materials (periodic fills) ----------------------------------------------

def wood(variant: int) -> np.ndarray:
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    warp = noise(10 + variant, 6) * 5.0
    grain = 0.5 + 0.5 * np.sin((yy + warp) * 0.55 + noise(20 + variant, 2) * 1.5)
    t = 0.32 + 0.22 * grain + 0.12 * noise(30 + variant, 1.2)
    rgb = ramp(t, (14, 10, 8), (104, 74, 52))
    # plank seams every 32 px with a knot on variant B
    seam = (yy % 32 < 2)
    rgb[seam] *= 0.45
    if variant == 1:
        d = np.sqrt((xx - 40) ** 2 + ((yy - 18) * 2.2) ** 2)
        rgb *= (1 - 0.45 * np.exp(-(d / 5.0) ** 2))[..., None]
    return rgb


SPINES = [(92, 30, 26), (36, 44, 66), (62, 66, 40), (110, 82, 40), (52, 36, 50), (70, 56, 46)]


def books(variant: int) -> np.ndarray:
    rnd = np.random.default_rng(40 + variant)
    rgb = np.zeros((T, T, 3), np.float32)
    y = 0
    while y < T:
        h = int(rnd.choice([10, 12, 14, 16])) if T - y > 18 else T - y
        col = np.array(SPINES[int(rnd.integers(len(SPINES)))], np.float32) * rnd.uniform(0.7, 1.0)
        band = np.linspace(1.15, 0.6, h, dtype=np.float32)[:, None, None]  # rounded spine
        rgb[y:y + h] = col * band
        # gilt bands near the ends of the spine, worn
        for bx in (6 + variant * 4, T - 12):
            rgb[y + 2:y + h - 2, bx:bx + 2] = np.array([120, 98, 52], np.float32) * 0.8
        rgb[y + h - 1:y + h] = OUTLINE
        y += h
    rgb *= (1 + 0.12 * noise(50 + variant, 1.0))[..., None]
    return rgb


def earth(variant: int) -> np.ndarray:
    yy, _ = np.mgrid[0:T, 0:T].astype(np.float32)
    warp = noise(60 + variant, 5) * 4.0
    strata = 0.5 + 0.5 * np.sin((yy + warp) * 0.42)
    t = 0.25 + 0.2 * strata + 0.15 * noise(70 + variant, 1.0)
    rgb = ramp(t, (16, 14, 14), (92, 84, 72))
    # paper flecks
    fleck = noise(80 + variant, 0.6) > 0.55
    rgb[fleck] = rgb[fleck] * 0.5 + np.array([120, 112, 96], np.float32) * 0.5
    return rgb


def stone(variant: int) -> np.ndarray:
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    t = 0.38 + 0.18 * noise(90 + variant, 2.5) + 0.08 * noise(95 + variant, 0.7)
    rgb = ramp(t, (20, 22, 26), (104, 104, 104))
    row = (yy // 32).astype(int)
    offset = np.where(row % 2 == 0, 0, 32 if variant == 0 else 16)
    mortar = (yy % 32 < 3) | (((xx + offset) % 64) < 3)
    rgb[mortar] *= 0.35
    # damp stain running down
    stain = np.clip(noise(99 + variant, 4) * 1.5, 0, 1) * np.linspace(0.2, 1, T)[:, None]
    rgb *= (1 - 0.35 * stain)[..., None]
    return rgb


MATERIALS = [wood, books, earth, stone]
# Moss on earth tops, nothing on the others.
TOP_GROWTH = [None, None, (44, 56, 34), (38, 44, 36)]


# --- pieces --------------------------------------------------------------------

def apply_top(rgb: np.ndarray, alpha: np.ndarray, mat: int, seed: int) -> None:
    rnd = np.random.default_rng(seed)
    edge = np.clip(np.round(3 + noise(seed, 3, (1, T))[0] * (3 if mat == 2 else 1)), 1, 7).astype(int)
    for x in range(T):
        e = edge[x]
        alpha[:e, x] = 0
        rgb[e:e + 2, x] = OUTLINE
        lip_h = 3 if mat != 1 else 4
        rgb[e + 2:e + 2 + lip_h, x] = LIP * rnd.uniform(0.82, 1.0)
        rgb[e + 2 + lip_h:e + 4 + lip_h, x] *= 0.55  # shadow under the lip
        if TOP_GROWTH[mat] is not None and rnd.random() < 0.5:
            h = int(rnd.integers(1, 4))
            rgb[max(e - h, 0):e, x] = np.array(TOP_GROWTH[mat], np.float32)
            alpha[max(e - h, 0):e, x] = 255
    # soft light falloff below the lip
    rgb *= np.concatenate([np.linspace(1.15, 1.0, 18), np.ones(T - 18)])[:, None, None]


def apply_side(rgb: np.ndarray, alpha: np.ndarray, side: str, seed: int) -> None:
    edge = np.clip(np.round(2 + noise(seed, 3, (T, 1))[:, 0] * 1.5), 0, 4).astype(int)
    for y in range(T):
        e = edge[y]
        if side == "left":
            alpha[y, :e] = 0
            rgb[y, e:e + 2] = OUTLINE
            rgb[y, e + 2:e + 10] *= np.linspace(0.55, 1.0, 8)[:, None]
        else:
            alpha[y, T - e:] = 0
            rgb[y, T - e - 2:T - e] = OUTLINE
            rgb[y, T - e - 10:T - e - 2] *= np.linspace(1.0, 0.55, 8)[:, None]


def cut_corner(alpha: np.ndarray, side: str, r: int = 10) -> None:
    yy, xx = np.mgrid[0:T, 0:T]
    cx = r if side == "left" else T - 1 - r
    outside = (yy < r) & ((xx < r) if side == "left" else (xx > T - 1 - r))
    alpha[outside & ((xx - cx) ** 2 + (yy - r) ** 2 > r * r)] = 0


def plank(mat: int) -> tuple[np.ndarray, np.ndarray]:
    base = MATERIALS[0](0) if mat != 3 else MATERIALS[3](0)
    rgb = base.copy()
    alpha = np.zeros((T, T), np.uint8)
    alpha[2:22] = 255
    rgb[2:4] = OUTLINE
    rgb[4:7] = LIP
    rgb[7:9] *= 0.55
    rgb[20:22] = OUTLINE
    # iron bracket under each end
    for bx in (6, T - 10):
        alpha[22:34, bx:bx + 4] = 255
        rgb[22:34, bx:bx + 4] = np.array([40, 38, 40], np.float32)
    return rgb, alpha


def piece(mat: int, col: int) -> np.ndarray:
    if col == 7:
        rgb, alpha = plank(mat)
    else:
        rgb = MATERIALS[mat](1 if col == 1 else 0).copy()
        alpha = np.full((T, T), 255, np.uint8)
        seed = 1000 + mat * 10 + col
        if col in (2, 3, 4):
            apply_top(rgb, alpha, mat, seed)
        if col in (3, 5):
            apply_side(rgb, alpha, "left", seed + 1)
        if col in (4, 6):
            apply_side(rgb, alpha, "right", seed + 2)
        if col == 3:
            cut_corner(alpha, "left")
        if col == 4:
            cut_corner(alpha, "right")
    # fine grain everywhere
    rgb = rgb * (1 + np.random.default_rng(mat * 31 + col).normal(0, 0.035, (T, T)))[..., None]
    out = np.zeros((T, T, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = alpha
    return out


def write_tres() -> None:
    lines = [
        '[gd_resource type="TileSet" format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/art/dark/tiles/dark_tiles.png" id="1_tiles"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_dark"]',
        'texture = ExtResource("1_tiles")',
        "texture_region_size = Vector2i(64, 64)",
    ]
    full = "PackedVector2Array(-32, -32, 32, -32, 32, 32, -32, 32)"
    board = "PackedVector2Array(-32, -30, 32, -30, 32, -12, -32, -12)"
    for r in range(ROWS):
        for c in range(COLS):
            lines.append(f"{c}:{r}/0 = 0")
            lines.append(f"{c}:{r}/0/physics_layer_0/polygon_0/points = {board if c == 7 else full}")
            if c == 7:
                lines.append(f"{c}:{r}/0/physics_layer_0/polygon_0/one_way = true")
    lines += [
        "",
        "[resource]",
        "tile_size = Vector2i(64, 64)",
        "physics_layer_0/collision_layer = 1",
        "physics_layer_0/collision_mask = 0",
        'sources/0 = SubResource("TileSetAtlasSource_dark")',
        "",
    ]
    with open(OUT_TRES, "w") as f:
        f.write("\n".join(lines))


def main() -> None:
    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    atlas = np.zeros((ROWS * T, COLS * T, 4), np.uint8)
    for r in range(ROWS):
        for c in range(COLS):
            atlas[r * T:(r + 1) * T, c * T:(c + 1) * T] = piece(r, c)
    Image.fromarray(atlas).save(OUT_PNG)
    write_tres()
    print("wrote", OUT_PNG, "and", OUT_TRES)


if __name__ == "__main__":
    main()
