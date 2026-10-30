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

from generate_art import INK, TILE, crayon_poly, ellipse_points, ink_line, out, paper_grain, shade

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
    return img


def tile_ground_fill():
    return _soil(11)


def tile_ground_top():
    img = _soil(12)
    d = ImageDraw.Draw(img)
    r = random.Random(5)
    # Turf: a band of grass whose lower edge breaks into hanging blade tips.
    edge = []
    for i in range(0, TILE + 1, 4):
        edge.append((i, 20 + (6 if (i // 4) % 2 else 0) + math.sin(i / TILE * math.tau * 2) * 2))
    turf = [(0, 0), (TILE, 0)] + edge[::-1]
    layer = mottle(GRASS_TOP, TILE, 21, blur=2, amount=30, fine=14)
    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).polygon(turf, fill=255)
    img.paste(layer, (0, 0), mask)
    # Shadow the turf casts on the soil, and a darker underside to the grass.
    for x, y in edge:
        d.line([(x, y + 1), (x, y + 4)], fill=shade(SOIL, -50)[:3] + (120,), width=4)
    d.line(edge, fill=shade(GRASS_TOP, -50), width=2)
    # Blades of grass drawn in light and dark strokes.
    for i in range(46):
        x = (i * 7.3 + r.uniform(-2, 2)) % TILE
        y = r.uniform(5, 20)
        ln = r.uniform(5, 9)
        lean = r.uniform(-2.5, 2.5)
        tone = shade(GRASS_TOP, 38) if i % 3 == 0 else shade(GRASS_TOP, -34)
        d.line([(x, y), (x + lean, y - ln)], fill=tone, width=1)
    # Clover and a tiny daisy now and then.
    for x, y in ((14, 12), (47, 9)):
        for a in range(3):
            ang = a * math.tau / 3 - 0.5
            d.ellipse([x + math.cos(ang) * 2 - 2, y + math.sin(ang) * 2 - 2, x + math.cos(ang) * 2 + 2, y + math.sin(ang) * 2 + 2],
                      fill=shade(GRASS_TOP, -20))
    d.ellipse([33, 13, 37, 17], fill=(250, 248, 236, 255))
    d.ellipse([34.3, 14.3, 35.7, 15.7], fill=(240, 190, 60, 255))
    # Crisp ink line along the top, where the page's ground begins.
    ink_line(img, [(-4, 1.5), (TILE + 4, 1.5)], width=2.6, wobble=0)
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
    return img


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
    return img


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
    return img


def tile_harbor_water():
    img = mottle(WATER, TILE, 71, blur=5, amount=24, fine=6)
    d = ImageDraw.Draw(img)
    for y, amp, tone in ((10, 2.0, 34), (26, 2.5, 50), (42, 2.0, 30), (56, 2.5, 46)):
        pts = [(x, y + math.sin(x / TILE * math.tau * 2 + y) * amp) for x in range(0, TILE + 1, 2)]
        d.line(pts, fill=shade(WATER, tone)[:3] + (200,), width=2)
        d.line([(px, py + 3) for px, py in pts], fill=shade(WATER, -24)[:3] + (140,), width=1)
    for x, y in ((14, 18), (46, 50)):
        d.line([(x - 3, y), (x + 3, y)], fill=(236, 246, 255, 255), width=1)
    return img


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
    return img


# ------------------------------------------------------------ Thistledown Meadow


def _ridge_y(x, w, base, amps, phase):
    return base - sum(a * math.sin(x / w * math.tau * k + phase * k) for k, a in amps)


def _ridge(w, base, amps, phase):
    """A hill line made of whole-number sine waves, so the picture tiles sideways."""
    return [(x, _ridge_y(x, w, base, amps, phase)) for x in range(-40, w + 41, 8)]


def _hatch(img, mask, spacing, angle, color, width=1):
    """Fine parallel ink hatching inside a mask, like an engraved illustration."""
    w, h = img.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    dx, dy = math.cos(angle), math.sin(angle)
    span = w + h
    for t in range(-span, span, spacing):
        cx, cy = w / 2 + -dy * t, h / 2 + dx * t
        d.line([(cx - dx * span, cy - dy * span), (cx + dx * span, cy + dy * span)], fill=color, width=width)
    img.paste(layer, (0, 0), Image.fromarray(np.minimum(np.asarray(mask), np.asarray(layer.split()[3]))))


def _fill(img, pts, color, w, h, seed, blur=8, amount=26):
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    tex = mottle(color, max(w, h), seed, blur=blur, amount=amount, fine=8).crop((0, 0, w, h))
    img.paste(tex, (0, 0), mask)
    return mask


def _tree(img, x, base, size, leaf, seed, ink_w=3):
    """A rounded deciduous tree: forked trunk and branches under clustered foliage."""
    r = random.Random(seed)
    bark = (120, 82, 58, 255)
    tw = size * 0.11
    trunk = [(x - tw, base), (x - tw * 0.6, base - size * 0.45), (x - tw * 1.4, base - size * 0.75), (x - tw * 0.4, base - size * 0.72),
             (x, base - size * 0.55), (x + tw * 0.5, base - size * 0.78), (x + tw * 1.5, base - size * 0.74), (x + tw * 0.7, base - size * 0.45),
             (x + tw * 1.2, base)]
    crayon_poly(img, trunk, bark, width=ink_w, smooth=True)
    cy = base - size * 0.95
    clusters = [(x + r.uniform(-0.45, 0.45) * size, cy + r.uniform(-0.3, 0.2) * size, size * r.uniform(0.2, 0.3)) for _ in range(7)]
    clusters.sort(key=lambda c: c[1])
    for i, (cx, ccy, cr) in enumerate(clusters):
        pts = [(cx + math.cos(a) * cr * (1 + 0.12 * math.sin(a * 5 + i)), ccy + math.sin(a) * cr * 0.85 * (1 + 0.12 * math.cos(a * 4 + i)))
               for a in np.linspace(0, math.tau, 28, endpoint=False)]
        crayon_poly(img, pts, shade(leaf, r.randint(-16, 14)), width=ink_w, smooth=False)
    # Leaf texture: little scalloped strokes on the lit side.
    d = ImageDraw.Draw(img)
    for _ in range(int(size * 0.6)):
        cx, ccy, cr = r.choice(clusters)
        a = r.uniform(math.pi * 0.9, math.pi * 1.9)
        rad = cr * r.uniform(0.2, 0.8)
        px, py = cx + math.cos(a) * rad, ccy + math.sin(a) * rad * 0.85
        d.arc([px - 4, py - 3, px + 4, py + 3], 200, 340, fill=shade(leaf, -46), width=2)


def build_thistledown():
    w, h = 1920, 1080
    r = random.Random(1987)
    # Sky: a clear blue fading to warm gold at the horizon, with soft watercolour blooms.
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None] ** 1.3
    top = np.array([118, 178, 214], np.float32)
    low = np.array([252, 226, 150], np.float32)
    rgb = np.broadcast_to(top * (1 - t) + low * t, (h, w, 3)).copy()
    bloom = periodic_noise(1920, 3, 60)[:h, :w]
    rgb += (bloom[..., None] - 0.5) * np.array([18, 18, 10], np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rgb += np.exp(-(((xx - 1460) / 420) ** 2 + ((yy - 230) / 300) ** 2))[..., None] * np.array([50, 36, 0], np.float32)
    img = Image.fromarray(np.concatenate([np.clip(rgb, 0, 255), np.full((h, w, 1), 255, np.float32)], -1).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)

    # The sun, painted with an inked ring of rays.
    crayon_poly(img, ellipse_points(1460, 230, 74, 74, 48), (255, 214, 96, 255), width=4)
    for i in range(16):
        a = i / 16 * math.tau
        r0, r1 = 92, 118 if i % 2 == 0 else 106
        ink_line(img, [(1460 + math.cos(a) * r0, 230 + math.sin(a) * r0), (1460 + math.cos(a) * r1, 230 + math.sin(a) * r1)],
                 width=2.4, wobble=0, color=(200, 130, 40, 255))

    # Clouds: flat-bottomed cumulus, shaded underneath.
    for cx, cy, s in ((300, 200, 1.0), (820, 130, 0.8), (1120, 320, 0.7), (1780, 150, 0.6)):
        lobes = [(cx - 90 * s, cy, 46 * s), (cx - 30 * s, cy - 34 * s, 62 * s), (cx + 44 * s, cy - 20 * s, 52 * s), (cx + 100 * s, cy + 2 * s, 38 * s)]
        mask = Image.new("L", (w, h), 0)
        md = ImageDraw.Draw(mask)
        for lx, ly, lr in lobes:
            md.ellipse([lx - lr, ly - lr, lx + lr, ly + lr], fill=255)
        md.rectangle([0, cy + 20 * s, w, h], fill=0)
        outline = mask.filter(ImageFilter.MaxFilter(7))
        img.paste((70, 80, 110, 255), (0, 0), outline)
        cloud = Image.new("RGBA", (w, h), (255, 252, 244, 255))
        under = np.clip((yy - (cy - 20 * s)) / (40 * s), 0, 1)
        shade_arr = np.asarray(cloud).astype(np.float32)
        shade_arr[..., :3] -= under[..., None] * np.array([46, 40, 20], np.float32)
        img.paste(Image.fromarray(shade_arr.astype(np.uint8)), (0, 0), mask)

    # Birds.
    for bx, by in ((620, 300), (660, 280), (700, 310), (1000, 220)):
        ink_line(img, [(bx - 9, by - 4), (bx, by + 1), (bx + 9, by - 4)], width=1.8, wobble=0)

    # Far hills: hazy blue, with tiny tree lines and a distant windmill.
    FAR, MID, NEAR = (640, ((2, 46), (5, 14)), 0.4), (790, ((2, 60), (3, 18)), 1.7), (930, ((2, 34), (5, 10)), 3.1)
    far = _ridge(w, *FAR)
    _fill(img, far + [(w + 40, h), (-40, h)], (150, 180, 186, 255), w, h, 5)
    ink_line(img, far, width=2.2, wobble=0, color=(80, 100, 120, 255))
    x = 10.0
    while x < w:
        y = _ridge_y(x, w, *FAR)
        size = r.uniform(7, 14)
        if r.random() < 0.7:
            ink_line(img, [(x, y + 2), (x, y - size)], width=1.4, wobble=0, color=(90, 110, 110, 255))
            crayon_poly(img, ellipse_points(x, y - size * 1.3, size * 0.7, size, 14), (112, 146, 138, 255), width=1.2, smooth=False, shadow=False)
        x += r.uniform(18, 70)
    wx, wy = 1180, _ridge_y(1180, w, *FAR)
    crayon_poly(img, [(wx - 12, wy), (wx - 7, wy - 54), (wx + 7, wy - 54), (wx + 12, wy)], (230, 220, 200, 255), width=1.6, shadow=False)
    for a in (0.4, 0.4 + math.pi / 2, 0.4 + math.pi, 0.4 + 1.5 * math.pi):
        ink_line(img, [(wx, wy - 54), (wx + math.cos(a) * 38, wy - 54 + math.sin(a) * 38)], width=2.4, wobble=0, color=(90, 100, 110, 255))

    # Middle hills: patchwork fields stitched with hedgerows.
    mid = _ridge(w, *MID)
    mid_mask = _fill(img, mid + [(w + 40, h), (-40, h)], (150, 196, 104, 255), w, h, 6)
    for k in range(12):
        x0 = k * 160 + 40
        field = Image.new("L", (w, h), 0)
        ImageDraw.Draw(field).polygon([(x0, 700), (x0 + 150, 700), (x0 + 120, h), (x0 - 30, h)], fill=255)
        field = Image.fromarray(np.minimum(np.asarray(field), np.asarray(mid_mask)))
        tint = [(176, 206, 110), (204, 196, 112), (132, 186, 96), (196, 210, 130)][k % 4]
        img.paste(mottle(tint + (255,), 1920, 20 + k, blur=6, amount=16).crop((0, 0, w, h)), (0, 0), field)
        if k % 2 == 0:
            _hatch(img, field, 9, 1.3, (110, 120, 70, 70))
    d = ImageDraw.Draw(img)
    for k in range(13):
        x0 = k * 160 + 40
        for s in range(0, 40):
            yy0 = 700 + s * 10
            px = x0 - 30 * s / 38
            if mid_mask.getpixel((int(min(w - 1, max(0, px))), int(min(h - 1, yy0)))) > 0:
                d.ellipse([px - 6, yy0 - 5, px + 6, yy0 + 5], fill=(84, 130, 70, 255), outline=(50, 70, 50, 255))
    ink_line(img, mid, width=3.2, wobble=0, color=(50, 70, 50, 255))
    for i, tx in enumerate((200, 560, 1000, 1380, 1760)):
        ty = _ridge_y(tx, w, *MID)
        _tree(img, tx, ty + 18, r.uniform(130, 170), (96, 160, 92, 255), 100 + i)

    # Near hill: a deep green slope with shaded hatching.
    near = _ridge(w, *NEAR)
    near_mask = _fill(img, near + [(w + 40, h), (-40, h)], (104, 170, 80, 255), w, h, 7)
    shadow = Image.fromarray((np.asarray(near_mask).astype(np.float32) * np.clip((yy - 930) / 160, 0, 1)).astype(np.uint8))
    _hatch(img, shadow, 7, 2.2, (40, 80, 40, 90))
    ink_line(img, near, width=4, wobble=0, color=(40, 60, 40, 255))
    d = ImageDraw.Draw(img)
    for _ in range(260):
        x = r.uniform(0, w)
        y = _ridge_y(x, w, *NEAR) + r.uniform(14, 140)
        d.line([(x, y), (x + r.uniform(-3, 3), y - r.uniform(6, 12))], fill=(64, 120, 56, 255), width=2)
    for _ in range(40):
        x = r.uniform(0, w)
        y = _ridge_y(x, w, *NEAR) + r.uniform(20, 120)
        c = r.choice([(250, 248, 236, 255), (200, 120, 200, 255), (250, 210, 80, 255)])
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=c, outline=(60, 60, 50, 255))

    paper_grain(img, 6).convert("RGB").save(out("backgrounds", "bg_thistledown.png"))
