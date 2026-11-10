"""Dark-rebuild tile atlases for the text-map levels (TextLevel), one per region.

Each region gets an 8 x 4 atlas of 64 px tiles and a matching TileSet:
  shelf (the Prologue)  assets/art/dark/tiles/dark_tiles.png, resources/dark_tiles.tres
  any other region      assets/art/dark/tiles/dark_tiles_<region>.png,
                        resources/dark_tiles_<region>.tres

Rows are materials, columns are pieces. TextLevel picks the piece from each cell's
neighbours, so a map only says which material goes where, and its `region` picks the
atlas. Every region fills the same four roles, so one map reads in any region:

  row  map  role          shelf          meadow      harbor       marsh       peaks         fair           index           gutter         blank
  0    #    main ground   shelf wood     turf        pier planks  peat        folded slate  boardwalk      drawer fronts   ink pulp       blank sheets
  1    %    built         stacked books  hay bales   crates       logs        board stacks  stall canvas   ledger stacks   drowned books  folded sheets
  2    &    soft ground   sodden earth   mud         black silt   bog         scree         sawdust        paper pulp      ink sludge     wet pulp
  3    $    hard stone    damp stone     fieldstone  sea wall     flagstones  granite       painted brick  marble          black stone    grey slate

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


# --- region materials -------------------------------------------------------------

def stones(variant: int, seed: int, dark, light, cells: int = 9) -> np.ndarray:
    """Rounded stones packed together (a periodic Voronoi), dark joints between them."""
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    rnd = np.random.default_rng(seed + variant)
    pts = rnd.uniform(0, T, (cells, 2))
    d1 = np.full((T, T), 1e9, np.float32)
    d2 = np.full((T, T), 1e9, np.float32)
    tone = np.zeros((T, T), np.float32)
    for i, (px, py) in enumerate(pts):
        shade = rnd.uniform(0.3, 0.7)
        for ox in (-T, 0, T):
            for oy in (-T, 0, T):
                d = np.sqrt((xx - px - ox) ** 2 + (yy - py - oy) ** 2)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                tone = np.where(closer, shade, tone)
                d1 = np.where(closer, d, d1)
    joint = np.clip((d2 - d1) / 4.0, 0, 1)
    t = tone + 0.12 * noise(seed + 5 + variant, 1.0) - 0.25 * (1 - joint)
    # each stone lit from the upper left
    t += 0.08 * np.clip(-np.gradient(d1, axis=0) - np.gradient(d1, axis=1), -1, 1)
    return ramp(t, dark, light)


def bricks(variant: int, seed: int, dark, light, h: int = 16, w: int = 32) -> np.ndarray:
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    row = (yy // h).astype(int)
    shift = np.where(row % 2 == 0, 0, w // 2)
    col = ((xx + shift) // w).astype(int)
    rnd = np.random.default_rng(seed + variant)
    shades = rnd.uniform(0.35, 0.65, (T // h + 1, T // w + 2))
    t = shades[row, col] + 0.1 * noise(seed + 3 + variant, 1.0)
    rgb = ramp(t, dark, light)
    mortar = (yy % h < 2) | (((xx + shift) % w) < 2)
    rgb[mortar] *= 0.4
    return rgb


def strata(variant: int, seed: int, dark, light, slope: float = 0.0, freq: float = 0.42) -> np.ndarray:
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    warp = noise(seed + variant, 5) * 4.0
    band = 0.5 + 0.5 * np.sin((yy + xx * slope + warp) * freq)
    t = 0.25 + 0.22 * band + 0.14 * noise(seed + 7 + variant, 1.0)
    return ramp(t, dark, light)


def specks(rgb: np.ndarray, seed: int, colour, amount: float = 0.55, sigma: float = 0.6) -> np.ndarray:
    fleck = noise(seed, sigma) > amount
    rgb[fleck] = rgb[fleck] * 0.45 + np.array(colour, np.float32) * 0.55
    return rgb


def sheen(rgb: np.ndarray, seed: int, strength: float = 40.0) -> np.ndarray:
    """Wet patches catching cold light."""
    wet = np.clip(noise(seed, 4) * 2 - 0.6, 0, 1)
    return rgb + wet[..., None] * np.array([0.7, 0.75, 0.9], np.float32) * strength


# meadow (Thistledown): drowned farmland
def turf(v):
    return specks(strata(v, 300, (14, 14, 10), (78, 72, 54)), 305 + v, (60, 70, 44), 0.4)


def hay(v):
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    straw = 0.5 + 0.5 * np.sin(yy * 1.7 + noise(310 + v, 1.2) * 3 + xx * 0.05)
    t = 0.3 + 0.3 * straw + 0.1 * noise(312 + v, 0.6)
    rgb = ramp(t, (30, 22, 10), (150, 118, 62))
    rgb[(xx % 32 > 13) & (xx % 32 < 17)] *= 0.5  # twine round the bale
    return rgb


def mud(v):
    return sheen(strata(v, 320, (14, 11, 9), (70, 54, 40), freq=0.3), 325 + v, 26)


def fieldstone(v):
    return stones(v, 330, (18, 18, 16), (110, 104, 92))


# harbor (Lanternfold): a flooded port
def pier(v):
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    warp = noise(340 + v, 6) * 4.0
    grain = 0.5 + 0.5 * np.sin((xx + warp) * 0.6 + noise(342 + v, 2) * 1.4)
    t = 0.28 + 0.2 * grain + 0.1 * noise(344 + v, 1.0)
    rgb = ramp(t, (12, 12, 12), (88, 78, 64))
    rgb[(xx % 16) < 2] *= 0.4  # board gaps
    for nx in range(7, T, 16):  # nail heads
        for ny in (10, 50):
            m = (xx - nx) ** 2 + (yy - ny) ** 2 < 2.5
            rgb[m] = np.array([60, 56, 58], np.float32)
    return sheen(rgb, 346 + v, 30)


def crates(v):
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    flute = 0.5 + 0.5 * np.sin(xx * 0.9)
    t = 0.38 + 0.1 * flute + 0.12 * noise(350 + v, 2.0)
    rgb = ramp(t, (30, 22, 14), (140, 108, 70))
    rgb[(yy % 32 < 2) | (xx % 64 < 2)] *= 0.35  # box seams
    tape = (np.abs(yy - (40 if v else 16)) < 5)
    rgb[tape] = rgb[tape] * 0.7 + np.array([150, 128, 80], np.float32) * 0.3
    stain = np.clip(noise(352 + v, 5) * 1.6, 0, 1) * np.linspace(0.3, 1, T)[:, None]
    return rgb * (1 - 0.4 * stain)[..., None]


def silt(v):
    return specks(strata(v, 360, (8, 8, 10), (52, 50, 50), freq=0.25), 365 + v, (90, 86, 78), 0.6)


def seawall(v):
    rgb = bricks(v, 370, (16, 20, 22), (92, 96, 96), h=32, w=64)
    algae = np.clip(noise(372 + v, 3) * 1.5, 0, 1) * np.linspace(0.1, 1, T)[:, None]
    return rgb * (1 - 0.3 * algae)[..., None] + algae[..., None] * np.array([18, 30, 22], np.float32)


# marsh (Watermark Marsh)
def peat(v):
    yy, _ = np.mgrid[0:T, 0:T].astype(np.float32)
    fibre = 0.5 + 0.5 * np.sin(yy * 1.2 + noise(380 + v, 2) * 6)
    return ramp(0.2 + 0.2 * fibre + 0.12 * noise(382 + v, 1.0), (10, 9, 6), (66, 56, 40))


def logs(v):
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    rgb = np.zeros((T, T, 3), np.float32)
    for top in (0, 32):
        local = yy - top
        inside = (local >= 0) & (local < 32)
        round_ = 1.1 - ((local - 16) / 16) ** 2 * 0.7  # each log rounds away from the light
        bark = 0.5 + 0.5 * np.sin(xx * 0.35 + noise(390 + v + top, 2) * 3)
        t = (0.25 + 0.2 * bark) * round_
        rgb[inside] = ramp(t, (12, 10, 8), (96, 78, 54))[inside]
    rgb[(yy % 32) > 29] *= 0.3
    return sheen(rgb, 394 + v, 18)


def bog(v):
    return sheen(strata(v, 400, (6, 8, 6), (42, 44, 34), freq=0.2), 405 + v, 34)


def flagstones(v):
    rgb = bricks(v, 410, (14, 18, 16), (84, 90, 80), h=32, w=64)
    return sheen(rgb, 412 + v, 22)


# peaks (Spine Peaks): cold folded slate
def slate(v):
    return strata(v, 420, (16, 18, 24), (92, 98, 108), slope=0.6, freq=0.5)


def board_stack(v):
    rgb = books(v + 2) * 0.55 + np.array([24, 28, 36], np.float32) * 0.45
    return rgb


def scree(v):
    return stones(v, 430, (14, 16, 20), (100, 104, 112), cells=22)


def granite(v):
    rgb = ramp(0.45 + 0.15 * noise(440 + v, 2.5), (30, 32, 36), (128, 128, 130))
    return specks(rgb, 442 + v, (30, 30, 34), 0.5, 0.5)


# fair (Gatefold Fair): a washed-out carnival
def boardwalk(v):
    rgb = wood(v)
    yy, _ = np.mgrid[0:T, 0:T].astype(np.float32)
    paint = np.where((yy // 32) % 2 == 0, 0, 1)
    tint = np.array([[54, 70, 66], [96, 80, 46]], np.float32)[paint]
    flake = noise(450 + v, 1.2) > -0.2
    return np.where(flake[..., None], rgb * 0.6 + tint * 0.4, rgb)


def canvas(v):
    _, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    stripe = ((xx // 16) % 2 == 0)
    rgb = np.where(stripe[..., None], np.array([104, 52, 42], np.float32), np.array([150, 132, 98], np.float32))
    rgb = rgb * (0.7 + 0.25 * noise(460 + v, 3))[..., None]
    sag = np.clip(noise(462 + v, 6) * 1.5, 0, 1)
    return rgb * (1 - 0.35 * sag)[..., None]


def sawdust(v):
    return specks(strata(v, 470, (24, 18, 12), (110, 90, 62), freq=0.2), 475 + v, (150, 126, 86), 0.4, 0.5)


def painted_brick(v):
    rgb = bricks(v, 480, (26, 14, 12), (96, 62, 50))
    flake = noise(482 + v, 1.5) > 0.2
    rgb[flake] = rgb[flake] * 0.5 + np.array([92, 96, 86], np.float32) * 0.5
    return rgb


# index (the Index): an archive of drawers and ledgers
def drawers(v):
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    rgb = wood(v) * 0.85
    rgb[(yy % 32 < 2) | (xx % 32 < 2)] = OUTLINE
    plate = (np.abs(xx % 32 - 16) < 6) & (np.abs(yy % 32 - 11) < 3)
    rgb[plate] = np.array([118, 98, 56], np.float32)
    pull = ((xx % 32 - 16) ** 2 + ((yy % 32 - 21) * 1.6) ** 2) < 9
    rgb[pull] = np.array([84, 70, 44], np.float32)
    return rgb


def ledgers(v):
    yy, _ = np.mgrid[0:T, 0:T].astype(np.float32)
    leaves = 0.5 + 0.5 * np.sin(yy * 2.4 + noise(490 + v, 2) * 2)
    rgb = ramp(0.35 + 0.25 * leaves + 0.1 * noise(492 + v, 1.0), (40, 34, 26), (164, 150, 122))
    rgb[(yy % 21) < 3] = np.array([60, 40, 30], np.float32)  # ledger covers
    return rgb


def paper_pulp(v):
    return specks(strata(v, 500, (22, 22, 24), (104, 100, 94), freq=0.3), 505 + v, (140, 134, 120), 0.35, 0.5)


def marble(v):
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    vein = np.abs(np.sin((xx + yy * 0.6 + noise(510 + v, 6) * 18) * 0.12))
    rgb = ramp(0.5 + 0.12 * noise(512 + v, 3), (40, 40, 44), (140, 136, 130))
    return rgb * (0.65 + 0.35 * np.clip(vein * 3, 0, 1))[..., None]


# gutter: where the ink drains
def ink_pulp(v):
    return sheen(strata(v, 520, (6, 6, 8), (44, 40, 40), freq=0.35), 525 + v, 30)


def drowned_books(v):
    return books(v + 4) * 0.45 + np.array([8, 8, 12], np.float32) * 0.55


def ink_sludge(v):
    return sheen(strata(v, 530, (4, 4, 6), (28, 26, 30), freq=0.18), 535 + v, 44)


def black_stone(v):
    return stones(v, 540, (8, 8, 10), (60, 58, 60), cells=7)


# blank: the unwritten margins, white paper going grey in the rain
def blank_sheets(v):
    """The edge of a stack of blank pages: fine leaves, a seam every few, water stains."""
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    warp = noise(550 + v, 4) * 3
    leaf = (yy + warp) % 4.0
    rgb = ramp(0.6 + 0.1 * noise(552 + v, 1.0), (66, 66, 72), (150, 148, 144))
    rgb[leaf < 1.0] *= 0.72
    seam = ((yy + warp * 2) % 16.0) < 1.4
    rgb[seam] = rgb[seam] * 0.45
    stain = gaussian_filter(np.random.default_rng(556 + v).normal(0, 1, (T, T)), 7)
    stain = np.clip((stain - 0.04) * 40, 0, 1)
    rgb *= (1 - 0.35 * stain)[..., None]
    rgb[..., 2] += 6 * stain
    return rgb


def folded_sheets(v):
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    fold = np.abs(((xx + yy * 0.5 + v * 13) % 32) - 16) / 16.0
    return ramp(0.45 + 0.35 * fold + 0.06 * noise(560 + v, 1.0), (58, 60, 68), (168, 168, 172))


def wet_pulp(v):
    return sheen(strata(v, 570, (40, 42, 50), (120, 122, 130), freq=0.25), 575 + v, 34)


def grey_slate(v):
    return stones(v, 580, (34, 36, 42), (110, 112, 118), cells=8)


def material(fill, growth=None, rough=False, lip_h=3) -> dict:
    return {"fill": fill, "growth": growth, "rough": rough, "lip_h": lip_h}


MOSS = (44, 56, 34)
REGIONS = {
    "shelf": [material(wood), material(books, lip_h=4), material(earth, MOSS, True), material(stone, (38, 44, 36))],
    "meadow": [material(turf, (52, 62, 36), True), material(hay, lip_h=4), material(mud, None, True), material(fieldstone, MOSS)],
    "harbor": [material(pier), material(crates, lip_h=4), material(silt, None, True), material(seawall, (30, 44, 36))],
    "marsh": [material(peat, (46, 58, 34), True), material(logs), material(bog, (34, 44, 30), True), material(flagstones, MOSS)],
    "peaks": [material(slate, rough=True), material(board_stack, lip_h=4), material(scree, None, True), material(granite)],
    "fair": [material(boardwalk), material(canvas, lip_h=4), material(sawdust, None, True), material(painted_brick)],
    "index": [material(drawers), material(ledgers, lip_h=4), material(paper_pulp, None, True), material(marble)],
    "gutter": [material(ink_pulp, None, True), material(drowned_books, lip_h=4), material(ink_sludge, None, True), material(black_stone)],
    "blank": [material(blank_sheets), material(folded_sheets, lip_h=4), material(wet_pulp, None, True), material(grey_slate)],
}
# Which row's material the one-way planks are cut from (shelf: wood boards, and iron
# grates in damp stone).
PLANK_FROM = {"shelf": [0, 0, 0, 3]}


# --- pieces --------------------------------------------------------------------

def apply_top(rgb: np.ndarray, alpha: np.ndarray, spec: dict, seed: int) -> None:
    rnd = np.random.default_rng(seed)
    edge = np.clip(np.round(3 + noise(seed, 3, (1, T))[0] * (3 if spec["rough"] else 1)), 1, 7).astype(int)
    for x in range(T):
        e = edge[x]
        alpha[:e, x] = 0
        rgb[e:e + 2, x] = OUTLINE
        lip_h = spec["lip_h"]
        rgb[e + 2:e + 2 + lip_h, x] = LIP * rnd.uniform(0.82, 1.0)
        rgb[e + 2 + lip_h:e + 4 + lip_h, x] *= 0.55  # shadow under the lip
        if spec["growth"] is not None and rnd.random() < 0.5:
            h = int(rnd.integers(1, 4))
            rgb[max(e - h, 0):e, x] = np.array(spec["growth"], np.float32)
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


def plank(fill) -> tuple[np.ndarray, np.ndarray]:
    rgb = fill(0).copy()
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


def piece(region: str, mat: int, col: int) -> np.ndarray:
    specs = REGIONS[region]
    salt = list(REGIONS).index(region) * 1000
    if col == 7:
        rgb, alpha = plank(specs[PLANK_FROM.get(region, [0, 0, 0, 0])[mat]]["fill"])
    else:
        rgb = specs[mat]["fill"](1 if col == 1 else 0).copy()
        alpha = np.full((T, T), 255, np.uint8)
        seed = 1000 + mat * 10 + col + salt
        if col in (2, 3, 4):
            apply_top(rgb, alpha, specs[mat], seed)
        if col in (3, 5):
            apply_side(rgb, alpha, "left", seed + 1)
        if col in (4, 6):
            apply_side(rgb, alpha, "right", seed + 2)
        if col == 3:
            cut_corner(alpha, "left")
        if col == 4:
            cut_corner(alpha, "right")
    # fine grain everywhere
    rgb = rgb * (1 + np.random.default_rng(mat * 31 + col + salt).normal(0, 0.035, (T, T)))[..., None]
    out = np.zeros((T, T, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = alpha
    return out


def names(region: str) -> tuple[str, str]:
    stem = "dark_tiles" if region == "shelf" else "dark_tiles_" + region
    return (os.path.join(ROOT, "assets", "art", "dark", "tiles", stem + ".png"),
            os.path.join(ROOT, "resources", stem + ".tres"))


def write_tres(region: str) -> None:
    png, tres = names(region)
    lines = [
        '[gd_resource type="TileSet" format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/art/dark/tiles/%s" id="1_tiles"]' % os.path.basename(png),
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
    with open(tres, "w") as f:
        f.write("\n".join(lines))


def main() -> None:
    for region in REGIONS:
        png, tres = names(region)
        os.makedirs(os.path.dirname(png), exist_ok=True)
        atlas = np.zeros((ROWS * T, COLS * T, 4), np.uint8)
        for r in range(ROWS):
            for c in range(COLS):
                atlas[r * T:(r + 1) * T, c * T:(c + 1) * T] = piece(region, r, c)
        Image.fromarray(atlas).save(png)
        write_tres(region)
        print("wrote", os.path.relpath(png, ROOT), "and", os.path.relpath(tres, ROOT))


if __name__ == "__main__":
    main()
