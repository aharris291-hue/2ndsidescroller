"""Detailed page art: textured tiles and the Thistledown Meadow illustration.

Tiles carry real material detail (soil strata and pebbles, grass blades,
flagstones, wood grain, rippling water, leafy hedges) and still tile
seamlessly. The meadow is drawn like a printed storybook plate: layered hills
fading into the distance, hedgerows and fields, proper trees, and fine ink
hatching for shade.

Called from generate_art.py (build_tiles and build_backgrounds).
"""

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from generate_art import INK, TILE, blob, crayon_poly, edge_color, ellipse_points, facets, ink_line, out, paper_grain, shade

SOIL = (190, 120, 72, 255)
GRASS_TOP = (110, 178, 76, 255)
STONE = (206, 178, 146, 255)
PLANK = (178, 116, 66, 255)
WATER = (52, 98, 160, 255)
HEDGE_LEAF = (214, 104, 52, 255)


def periodic_noise(size, seed, blur, wrap=True):
    """Smooth noise in 0-1 that tiles seamlessly when `wrap` is set."""
    gen = np.random.default_rng(seed)
    if size > 256:
        # Big pictures: upscale a coarse grid of random values (tiled so it still wraps).
        n = max(2, int(size / max(1.0, blur * 2)))
        grid = (gen.random((n, n)) * 255).astype(np.uint8)
        big = Image.fromarray(np.tile(grid, (3, 3))).resize((size * 3, size * 3), Image.BICUBIC)
        arr = np.asarray(big.filter(ImageFilter.GaussianBlur(max(1.0, blur * 0.3)))).astype(np.float32)[size:size * 2, size:size * 2] / 255.0
        lo, hi = arr.min(), arr.max()
        return (arr - lo) / max(1e-6, hi - lo)
    base = gen.random((size, size)).astype(np.float32)
    big = np.tile(base, (3, 3)) if wrap else base
    img = Image.fromarray((big * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    arr = np.asarray(img).astype(np.float32) / 255.0
    if wrap:
        arr = arr[size:size * 2, size:size * 2]
    lo, hi = arr.min(), arr.max()
    return (arr - lo) / max(1e-6, hi - lo)


def mottle(color, size, seed, blur=3.0, amount=36, fine=10):
    """A flat colour broken up by soft blotches and fine grain, tiling seamlessly."""
    n = periodic_noise(size, seed, blur)
    f = periodic_noise(size, seed + 1, 0.6)
    rgb = np.array(color[:3], np.float32)[None, None, :] + ((n - 0.5) * amount + (f - 0.5) * fine)[..., None]
    alpha = np.full((size, size, 1), 255, np.float32)
    return Image.fromarray(np.concatenate([np.clip(rgb, 0, 255), alpha], -1).astype(np.uint8), "RGBA")


def _soil(seed):
    img = mottle(SOIL, TILE, seed, blur=4, amount=40)
    d = ImageDraw.Draw(img)
    # Faint strata running across, wrapping at the tile edges.
    for y0, tone in ((18, -22), (40, 14), (56, -16)):
        pts = [(x, y0 + math.sin(x / TILE * math.tau + seed) * 3) for x in range(0, TILE + 1, 4)]
        d.line(pts, fill=shade(SOIL, tone)[:3] + (110,), width=3)
    r = random.Random(seed)
    # A couple of half-buried stones, soft so the repeat doesn't show.
    for _ in range(2):
        x, y, rad = r.uniform(10, 54), r.uniform(14, 52), r.uniform(2.0, 3.5)
        d.ellipse([x - rad * 1.3, y - rad, x + rad * 1.3, y + rad], fill=shade(SOIL, -34)[:3] + (200,))
        d.ellipse([x - rad, y - rad * 0.9, x + rad * 0.4, y - rad * 0.1], fill=shade(SOIL, 22)[:3] + (200,))
    # A thin root.
    x0, y0 = r.uniform(10, 40), r.uniform(20, 44)
    ink_line(img, [(x0, y0), (x0 + 6, y0 + 4), (x0 + 14, y0 + 3), (x0 + 18, y0 + 8)], width=1.2, wobble=0,
             color=shade(SOIL, -60)[:3] + (180,))
    return fold_tile(img, seed / 100)


def tile_ground_fill():
    return _soil(11)


def fold_tile(img, seed, cell=32, strength=0.8):
    """Folds a whole tile into facets that still tile seamlessly."""
    facets(img, img.split()[3], seed, cell=cell, wrap=True, strength=strength)
    return img


def tile_ground_top():
    img = _soil(12)
    # Turf: a strip of torn green paper laid over the soil. Its ragged lower edge
    # uses whole-number waves so neighbouring tiles line up.
    edge = [(x, 21 + 2.4 * math.sin(x / TILE * math.tau * 3) + 1.4 * math.sin(x / TILE * math.tau * 7 + 1.0)
             + 0.8 * math.sin(x / TILE * math.tau * 13 + 2.0)) for x in range(0, TILE + 1, 2)]
    turf = [(0, 0), (TILE, 0)] + edge[::-1]
    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).polygon(turf, fill=255)
    shadow = Image.new("L", (TILE, TILE), 0)
    shadow.paste(mask, (0, 3))
    arr = np.asarray(img).astype(np.float32)
    arr[..., :3] *= 1.0 - 0.3 * (np.asarray(shadow.filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32)[..., None] / 255.0)
    img = Image.fromarray(arr.astype(np.uint8))
    img.paste(TORN_EDGE, (0, 0), mask.filter(ImageFilter.MaxFilter(3)))
    img.paste(mottle(GRASS_TOP, TILE, 21, blur=2, amount=18, fine=8), (0, 0), mask)
    facets(img, mask, 0.21, cell=16, wrap=True, strength=0.9)
    d = ImageDraw.Draw(img)
    # Little cut-paper grass blades and a clover or two.
    for i in range(10):
        x = i * 6.4 + 3
        y = 6 + (i % 3) * 4
        d.polygon([(x - 2, y + 3), (x, y - 4), (x + 2, y + 3)], fill=shade(GRASS_TOP, -28 if i % 2 else 22))
    d.ellipse([33, 12, 37, 16], fill=(250, 248, 236, 255))
    d.ellipse([34.3, 13.3, 35.7, 14.7], fill=(240, 190, 60, 255))
    ink_line(img, [(-4, 1.5), (TILE + 4, 1.5)], width=2.4, wobble=0, color=edge_color(GRASS_TOP))
    return img


def tile_plank():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    wood = mottle(PLANK, TILE, 31, blur=1.2, amount=20, fine=8)
    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).rectangle([0, 4, TILE, 26], fill=255)
    img.paste(wood, (0, 0), mask)
    d = ImageDraw.Draw(img)
    for y in (9, 14, 19):
        d.line([(x, y + math.sin(x / 9 + y) * 1.2) for x in range(0, TILE + 1, 3)], fill=shade(PLANK, -40)[:3] + (150,), width=1)
    d.rectangle([0, 21, TILE, 26], fill=shade(PLANK, -46))
    for x in (6, 38):
        d.ellipse([x - 2, 10, x + 2, 14], fill=(90, 84, 80, 255))
        d.point((x - 1, 11), fill=(200, 200, 200, 255))
    d.line([(31, 5), (31, 21)], fill=shade(PLANK, -70), width=2)
    ink_line(img, [(-4, 4), (TILE + 4, 4)], width=2.6, wobble=0)
    ink_line(img, [(-4, 26), (TILE + 4, 26)], width=2.6, wobble=0)
    return fold_tile(img, 0.33)


def tile_cobble():
    """Lanternfold's paved streets from above: irregular flagstones in dark mortar."""
    img = mottle(shade(STONE, -70), TILE, 41, blur=2, amount=20)
    r = random.Random(41)
    # Two rows of stones, offset like brickwork, inset from the tile edges by half a joint.
    stones = [(2, 2, 34, 30), (36, 2, 62, 30), (2, 34, 18, 62), (20, 34, 48, 62), (50, 34, 62, 62)]
    for i, (x0, y0, x1, y1) in enumerate(stones):
        j = lambda v: v + r.uniform(-1.2, 1.2)
        pts = [(j(x0 + 2), j(y0)), (j(x1 - 2), j(y0)), (j(x1), j(y0 + 2)), (j(x1), j(y1 - 2)), (j(x1 - 2), j(y1)),
               (j(x0 + 2), j(y1)), (j(x0), j(y1 - 2)), (j(x0), j(y0 + 2))]
        tone = shade(STONE, r.randint(-22, 12))
        layer = mottle(tone, TILE, 50 + i, blur=1.5, amount=26, fine=12)
        mask = Image.new("L", (TILE, TILE), 0)
        ImageDraw.Draw(mask).polygon(pts, fill=255)
        img.paste(layer, (0, 0), mask)
        d = ImageDraw.Draw(img)
        # Worn highlight on the top-left edge, shadow on the bottom-right.
        d.line(pts[7:] + pts[:2], fill=shade(tone, 34), width=1)
        d.line(pts[3:6], fill=shade(tone, -40), width=1)
        if r.random() < 0.5:
            cx, cy = r.uniform(x0 + 4, x1 - 4), r.uniform(y0 + 4, y1 - 4)
            d.line([(cx, cy), (cx + r.uniform(-6, 6), cy + r.uniform(3, 7))], fill=shade(tone, -50), width=1)
    return fold_tile(img, 0.58)


def tile_boardwalk():
    img = Image.new("RGBA", (TILE, TILE), shade(PLANK, -80))
    d = ImageDraw.Draw(img)
    for i in range(4):
        y = i * 16
        tone = shade(PLANK, [8, -6, 2, -12][i])
        layer = mottle(tone, TILE, 60 + i, blur=1.0, amount=18, fine=8)
        mask = Image.new("L", (TILE, TILE), 0)
        ImageDraw.Draw(mask).rectangle([0, y + 1, TILE, y + 13], fill=255)
        img.paste(layer, (0, 0), mask)
        for gy in (y + 4, y + 8, y + 11):
            d.line([(x, gy + math.sin(x / 7 + gy) * 0.8) for x in range(0, TILE + 1, 3)], fill=shade(tone, -34)[:3] + (140,), width=1)
        d.line([(0, y + 1), (TILE, y + 1)], fill=shade(tone, 28), width=1)
        for x in ([10, 54], [26], [42], [6, 58])[i]:
            d.ellipse([x - 1.6, y + 5, x + 1.6, y + 8.2], fill=(70, 64, 62, 255))
        if i in (1, 3):
            d.line([(36 if i == 1 else 20, y + 1), (36 if i == 1 else 20, y + 13)], fill=shade(PLANK, -80), width=2)
    return fold_tile(img, 0.78)


def tile_harbor_water():
    img = mottle(WATER, TILE, 71, blur=5, amount=24, fine=6)
    d = ImageDraw.Draw(img)
    for y, amp, tone in ((10, 2.0, 34), (26, 2.5, 50), (42, 2.0, 30), (56, 2.5, 46)):
        pts = [(x, y + math.sin(x / TILE * math.tau * 2 + y) * amp) for x in range(0, TILE + 1, 2)]
        d.line(pts, fill=shade(WATER, tone)[:3] + (200,), width=2)
        d.line([(px, py + 3) for px, py in pts], fill=shade(WATER, -24)[:3] + (140,), width=1)
    for x, y in ((14, 18), (46, 50)):
        d.line([(x - 3, y), (x + 3, y)], fill=(236, 246, 255, 255), width=1)
    return fold_tile(img, 0.9)


def tile_hedge():
    """An autumn hedge from above: dense clusters of copper and amber leaves."""
    img = mottle(shade(HEDGE_LEAF, -70), TILE, 81, blur=3, amount=30)
    r = random.Random(81)
    d = ImageDraw.Draw(img)
    for i in range(150):
        x, y = r.uniform(-4, TILE + 4), r.uniform(-4, TILE + 4)
        ang = r.uniform(0, math.pi)
        tone = shade(HEDGE_LEAF, r.randint(-40, 30))
        for wx in (-TILE, 0, TILE):
            for wy in (-TILE, 0, TILE):
                cx, cy = x + wx, y + wy
                if -6 < cx < TILE + 6 and -6 < cy < TILE + 6:
                    pts = [(cx + math.cos(ang) * 4, cy + math.sin(ang) * 4), (cx + math.cos(ang + 1.8) * 1.8, cy + math.sin(ang + 1.8) * 1.8),
                           (cx - math.cos(ang) * 4, cy - math.sin(ang) * 4), (cx + math.cos(ang - 1.8) * 1.8, cy + math.sin(ang - 1.8) * 1.8)]
                    d.polygon(pts, fill=tone)
                    d.line([pts[0], pts[2]], fill=shade(tone, -40), width=1)
    return fold_tile(img, 0.11)


# ------------------------------------------------------------ Thistledown Meadow


def _ridge_y(x, w, base, amps, phase):
    return base - sum(a * math.sin(x / w * math.tau * k + phase * k) for k, a in amps)


def _ridge(w, base, amps, phase):
    """A hill line made of whole-number sine waves, so the picture tiles sideways."""
    return [(x, _ridge_y(x, w, base, amps, phase)) for x in range(-40, w + 41, 8)]


TORN_EDGE = (250, 244, 230, 255)


def deckle(points, seed, step=6.0, amount=2.2):
    """Roughens a polygon's outline like torn paper."""
    r = random.Random(seed)
    result = []
    n = len(points)
    for k in range(n):
        (ax, ay), (bx, by) = points[k][:2], points[(k + 1) % n][:2]
        length = math.dist((ax, ay), (bx, by))
        steps = max(1, int(length / step))
        nx, ny = -(by - ay) / max(1e-6, length), (bx - ax) / max(1e-6, length)
        for i in range(steps):
            t = i / steps
            off = r.uniform(-amount, amount) + (r.uniform(-amount, amount) * 2 if r.random() < 0.08 else 0)
            result.append((ax + (bx - ax) * t + nx * off, ay + (by - ay) * t + ny * off))
    return result


def paper_layer(img, pts, color, seed, cell=80, shadow=(7, 10), torn=True, strength=0.9, edge=True):
    """Lays a sheet of torn coloured paper on the picture: a soft shadow on what is
    underneath, a white torn fibre rim, the paper itself folded into facets."""
    w, h = img.size
    outline = deckle(pts, seed) if torn else list(pts)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(outline, fill=255)
    if shadow:
        sh = Image.new("L", (w, h), 0)
        sh.paste(mask, shadow)
        sh = np.asarray(sh.filter(ImageFilter.GaussianBlur(7))).astype(np.float32)[..., None] / 255.0
        arr = np.asarray(img).astype(np.float32)
        arr[..., :3] *= 1.0 - 0.32 * sh
        img.paste(Image.fromarray(arr.astype(np.uint8)))
    if torn:
        rim = mask.filter(ImageFilter.MaxFilter(5))
        img.paste(TORN_EDGE, (0, 0), rim)
    if edge:
        img.paste(shade(color, -50), (0, 0), mask)
        inner = mask.filter(ImageFilter.MinFilter(3))
    else:
        inner = mask
    tex = mottle(color, max(w, h), seed, blur=10, amount=14, fine=8).crop((0, 0, w, h))
    img.paste(tex, (0, 0), inner)
    facets(img, inner, (seed % 997) / 997.0, cell=cell, strength=strength)
    return mask


def _paper_tree(img, x, base, size, leaf, seed):
    """A papercraft tree: a folded trunk under a few big low-poly paper canopies."""
    r = random.Random(seed)
    bark = (132, 88, 58, 255)
    tw = size * 0.1
    trunk = [(x - tw, base), (x - tw * 0.7, base - size * 0.5), (x - tw * 1.5, base - size * 0.78), (x - tw * 0.3, base - size * 0.7),
             (x, base - size * 0.6), (x + tw * 0.4, base - size * 0.8), (x + tw * 1.5, base - size * 0.76), (x + tw * 0.8, base - size * 0.48),
             (x + tw * 1.2, base)]
    crayon_poly(img, trunk, bark, width=3, smooth=True)
    cy = base - size * 0.98
    lobes = [(x - size * 0.28, cy + size * 0.06, size * 0.3), (x + size * 0.28, cy + size * 0.08, size * 0.28), (x, cy - size * 0.14, size * 0.36)]
    for i, (cx, ccy, cr) in enumerate(lobes):
        sides = r.choice((6, 7, 8))
        rot = r.uniform(0, math.tau)
        pts = [(cx + math.cos(rot + k / sides * math.tau) * cr * r.uniform(0.88, 1.08),
                ccy + math.sin(rot + k / sides * math.tau) * cr * 0.88 * r.uniform(0.88, 1.08)) for k in range(sides)]
        crayon_poly(img, pts, shade(leaf, [-12, -4, 8][i]), width=3, smooth=False)


def _shadowed(img, draw, offset=(6, 8), strength=0.3):
    """Draws something on its own layer and drops a soft paper shadow under it."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw(layer)
    a = layer.split()[3]
    sh = Image.new("L", img.size, 0)
    sh.paste(a, offset)
    sh = np.asarray(sh.filter(ImageFilter.GaussianBlur(6))).astype(np.float32)[..., None] / 255.0
    arr = np.asarray(img).astype(np.float32)
    arr[..., :3] *= 1.0 - strength * sh
    img.paste(Image.fromarray(arr.astype(np.uint8)))
    img.alpha_composite(layer)


def build_thistledown():
    """Thistledown Meadow as a layered papercraft plate: a folded sheet of blue sky,
    a paper sun and clouds, and hills of torn coloured paper stacked one in front
    of another, each casting a soft shadow on the layer behind."""
    w, h = 1920, 1080
    r = random.Random(1987)
    FAR, MID, NEAR = (640, ((2, 46), (5, 14)), 0.4), (790, ((2, 60), (3, 18)), 1.7), (930, ((2, 34), (5, 10)), 3.1)

    # Sky: one big sheet of blue paper, warming toward the horizon, softly folded.
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None] ** 1.4
    rgb = np.broadcast_to(np.array([138, 190, 222], np.float32) * (1 - t) + np.array([236, 222, 176], np.float32) * t, (h, w, 3)).copy()
    img = Image.fromarray(np.concatenate([rgb, np.full((h, w, 1), 255, np.float32)], -1).astype(np.uint8), "RGBA")
    facets(img, Image.new("L", (w, h), 255), 0.31, cell=160, wrap=True, strength=0.4)

    # Paper sun with cut-paper rays.
    def sun(layer):
        for i in range(12):
            a = i / 12 * math.tau
            r0, r1 = 84, 132 if i % 2 == 0 else 112
            crayon_poly(layer, [(1460 + math.cos(a - 0.13) * r0, 230 + math.sin(a - 0.13) * r0), (1460 + math.cos(a) * r1, 230 + math.sin(a) * r1),
                                (1460 + math.cos(a + 0.13) * r0, 230 + math.sin(a + 0.13) * r0)], (248, 176, 60, 255), width=2.5, smooth=False)
        crayon_poly(layer, ellipse_points(1460, 230, 86, 86, 40), (255, 210, 84, 255), width=3.5)
    _shadowed(img, sun)

    # Paper clouds, each a cut-out with its own shadow.
    for cx, cy, sc in ((300, 200, 1.0), (820, 130, 0.8), (1120, 320, 0.7), (1780, 150, 0.6)):
        lobes = [(cx - 90 * sc, cy, 46 * sc), (cx - 30 * sc, cy - 30 * sc, 60 * sc), (cx + 44 * sc, cy - 16 * sc, 50 * sc), (cx + 98 * sc, cy + 4 * sc, 36 * sc)]
        _shadowed(img, lambda layer, lobes=lobes: blob(layer, lobes, (252, 250, 244, 255), width=3))

    # Birds: tiny folded-paper chevrons.
    for bx, by in ((620, 300), (660, 280), (700, 310), (1000, 220)):
        crayon_poly(img, [(bx - 10, by - 5), (bx, by + 1), (bx + 10, by - 5), (bx, by - 1)], (70, 70, 90, 255), width=1.2, smooth=False, shadow=False)

    # Far hills: pale paper with a row of tiny paper trees and a distant windmill.
    far = _ridge(w, *FAR)
    paper_layer(img, far + [(w + 40, h + 40), (-40, h + 40)], (164, 196, 172, 255), 5, cell=90, strength=0.7)
    x = 10.0
    while x < w:
        y = _ridge_y(x, w, *FAR)
        size = r.uniform(8, 15)
        crayon_poly(img, [(x - size * 0.7, y + 2), (x, y - size * 2.2), (x + size * 0.7, y + 2)], (120, 160, 132, 255), width=1.6, smooth=False)
        x += r.uniform(22, 80)
    wx, wy = 1180, _ridge_y(1180, w, *FAR)
    crayon_poly(img, [(wx - 12, wy + 2), (wx - 7, wy - 54), (wx + 7, wy - 54), (wx + 12, wy + 2)], (236, 224, 204, 255), width=2)
    for a in (0.4, 0.4 + math.pi / 2, 0.4 + math.pi, 0.4 + 1.5 * math.pi):
        tip = (wx + math.cos(a) * 40, wy - 54 + math.sin(a) * 40)
        side = (wx + math.cos(a + 0.25) * 30, wy - 54 + math.sin(a + 0.25) * 30)
        crayon_poly(img, [(wx, wy - 54), tip, side], (226, 214, 196, 255), width=1.6, smooth=False)

    # Middle hills: green paper stitched into fields, with paper trees on top.
    mid = _ridge(w, *MID)
    mid_mask = paper_layer(img, mid + [(w + 40, h + 40), (-40, h + 40)], (142, 192, 100, 255), 6, cell=110)
    for k in range(12):
        x0 = k * 160 + 40
        field = Image.new("L", (w, h), 0)
        ImageDraw.Draw(field).polygon([(x0, 700), (x0 + 150, 700), (x0 + 120, h), (x0 - 30, h)], fill=255)
        field = Image.fromarray(np.minimum(np.asarray(field.filter(ImageFilter.MinFilter(9))), np.asarray(mid_mask.filter(ImageFilter.MinFilter(9)))))
        if k % 2 == 0:
            tint = [(176, 206, 112), (206, 198, 116)][k // 2 % 2]
            tex = mottle(tint + (255,), 1920, 20 + k, blur=8, amount=12).crop((0, 0, w, h))
            img.paste(tex, (0, 0), field)
            facets(img, field, 0.5 + k / 40, cell=90, strength=0.8)
    for k in range(13):
        x0 = k * 160 + 40
        pts = []
        for sidx in range(0, 40):
            yy0 = 700 + sidx * 10
            px = x0 - 30 * sidx / 38
            if mid_mask.getpixel((int(min(w - 1, max(0, px))), int(min(h - 1, yy0)))) > 200:
                pts.append((px, yy0))
        if len(pts) > 2:
            for (ax, ay), (bx, by) in zip(pts[::2], pts[1::2]):
                ink_line(img, [(ax, ay), (bx, by - 3)], width=1.8, wobble=0, color=(250, 240, 214, 255))
    for i, tx in enumerate((200, 560, 1000, 1380, 1760)):
        ty = _ridge_y(tx, w, *MID)
        size = r.uniform(130, 170)
        _shadowed(img, lambda layer, tx=tx, ty=ty, size=size, i=i: _paper_tree(layer, tx, ty + 18, size, (92, 162, 92, 255), 100 + i))

    # Near hill: deeper green paper with paper grass tufts and little paper flowers.
    near = _ridge(w, *NEAR)
    paper_layer(img, near + [(w + 40, h + 40), (-40, h + 40)], (98, 166, 78, 255), 7, cell=120, shadow=(8, 12))
    for _ in range(90):
        x = r.uniform(0, w)
        y = _ridge_y(x, w, *NEAR) + r.uniform(20, 140)
        s = r.uniform(5, 9)
        crayon_poly(img, [(x - s, y), (x - s * 0.4, y - s * 2.2), (x, y - s * 0.6), (x + s * 0.5, y - s * 2.4), (x + s, y)],
                    (80, 146, 64, 255), width=1.4, smooth=False)
    for _ in range(26):
        x = r.uniform(0, w)
        y = _ridge_y(x, w, *NEAR) + r.uniform(24, 120)
        c = r.choice([(250, 246, 236, 255), (214, 120, 196, 255), (250, 206, 80, 255)])
        for a in range(5):
            ang = a * math.tau / 5
            crayon_poly(img, ellipse_points(x + math.cos(ang) * 5, y + math.sin(ang) * 5, 4, 4, 10), c, width=1.2, smooth=False, shadow=False)
        crayon_poly(img, ellipse_points(x, y, 3, 3, 10), (240, 170, 50, 255), outline=False, shadow=False)

    paper_grain(img, 5).convert("RGB").save(out("backgrounds", "bg_thistledown.png"))
