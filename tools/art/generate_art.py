"""Generates the storybook cartoon art for Patch and the Pop-Up Kingdom.

Every texture in assets/art is produced here so the look stays consistent and
can be regenerated after tweaks. Run from the repo root:

    python3 tools/art/generate_art.py

Requires Pillow and numpy. Output is deterministic (fixed random seed).
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "assets", "art")

# Storybook cartoon palette: bright, saturated, flat colors under a thick dark outline.
INK = (40, 30, 46, 255)
PAPER = (255, 248, 226, 255)
MARIGOLD = (255, 156, 44, 255)
TOMATO = (240, 76, 92, 255)
SAGE = (104, 208, 190, 255)
GRASS = (112, 204, 84, 255)
TAN = (240, 170, 104, 255)
CARDBOARD = (222, 150, 86, 255)
SOGGY = (118, 150, 200, 255)
CREAM = (255, 252, 240, 255)
SKY = (255, 234, 104, 255)
WOOD = (196, 116, 62, 255)
TEAL = (110, 214, 204, 255)
LILAC = (150, 144, 196, 255)
SKYBLUE = (96, 178, 240, 255)

rng = random.Random(1987)


def out(*parts):
    path = os.path.join(ART, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def jitter(points, amount):
    # The cartoon style wants clean shapes, so only a hint of hand-drawn wobble.
    amount *= 0.25
    return [(x + rng.uniform(-amount, amount), y + rng.uniform(-amount, amount)) for x, y in points]


def subdivide(points, closed=True, steps=6):
    """Adds midpoints along each edge."""
    result = []
    count = len(points) if closed else len(points) - 1
    for i in range(count):
        a = points[i]
        b = points[(i + 1) % len(points)]
        for s in range(steps):
            t = s / steps
            result.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    if not closed:
        result.append(points[-1])
    return result


def chaikin(points, iterations=3, closed=True):
    """Rounds a polygon's corners so shapes read as soft and chunky."""
    pts = list(points)
    for _ in range(iterations):
        result = []
        count = len(pts) if closed else len(pts) - 1
        if not closed:
            result.append(pts[0])
        for i in range(count):
            a = pts[i]
            b = pts[(i + 1) % len(pts)]
            result.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            result.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        if not closed:
            result.append(pts[-1])
        pts = result
    return pts


def round_corners(points, radius=7.0, steps=6):
    """Softens each corner with a small curve while keeping the shape's silhouette."""
    n = len(points)
    if n < 3:
        return list(points)
    result = []
    for i in range(n):
        p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % n]
        la = math.dist(p0, p1)
        lb = math.dist(p1, p2)
        if la < 1e-6 or lb < 1e-6:
            continue
        r = min(radius, la * 0.45, lb * 0.45)
        a = (p1[0] + (p0[0] - p1[0]) * r / la, p1[1] + (p0[1] - p1[1]) * r / la)
        b = (p1[0] + (p2[0] - p1[0]) * r / lb, p1[1] + (p2[1] - p1[1]) * r / lb)
        for k in range(steps + 1):
            t = k / steps
            result.append((
                (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t * t * b[0],
                (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t * t * b[1],
            ))
    return result


def ellipse_points(cx, cy, rx, ry, count=36):
    return [(cx + math.cos(i / count * math.tau) * rx, cy + math.sin(i / count * math.tau) * ry) for i in range(count)]


def shade(color, amount):
    r, g, b, a = color
    return (
        max(0, min(255, int(r + amount))),
        max(0, min(255, int(g + amount))),
        max(0, min(255, int(b + amount))),
        a,
    )


def _supersample(img):
    """How much bigger to draw before scaling down, for smooth edges."""
    return 4 if img.size[0] * img.size[1] <= 400_000 else 2


def crayon_layer(size, color, density=1.0, angle=-0.6, stroke_len=(10, 26)):
    """A full-size flat layer of one color (kept for the old call sites)."""
    return Image.new("RGBA", size, color[:3] + (255,))


def _shifted(mask, dx, dy):
    moved = Image.new("L", mask.size, 0)
    moved.paste(mask, (int(dx), int(dy)))
    return moved


def edge_color(color):
    """Paper shapes are edged in a deep shade of their own colour, part-way to ink."""
    dark = shade(color, -110)
    return tuple(int(a * 0.55 + b * 0.45) for a, b in zip(dark[:3], INK[:3])) + (255,)


def crayon_poly(img, points, color, outline=True, width=5, wobble=1.6, density=1.0, smooth=None, shadow=None):
    """Draws a shape cut from coloured paper, in the style of Patch's turnaround sheet.

    Outlined shapes get rounded corners and a cut edge in a deep shade of their own
    colour, and are folded into flat facets that catch the top-left light.
    """
    ss = _supersample(img)
    w, h = img.size
    if smooth is None:
        smooth = outline
    if shadow is None:
        shadow = outline
    pts = round_corners(points, radius=max(3.0, width * 1.6)) if smooth and len(points) > 2 else list(points)
    hp = [(x * ss, y * ss) for x, y in pts]
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if outline:
        ow = max(2.0, width * 0.9) * ss
        edge = edge_color(color)
        d.line(hp + [hp[0], hp[1]], fill=edge, width=int(ow * 2), joint="curve")
        for x, y in hp[:: max(1, len(hp) // 24)]:
            d.ellipse([x - ow, y - ow, x + ow, y + ow], fill=edge)
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).polygon(hp, fill=255)
    layer.paste(color[:3] + (255,), (0, 0), mask)
    img.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    if shadow:
        seed = (sum(int(x * 7 + y * 13) for x, y in pts[:6]) % 100000) / 100000.0
        facets(img, mask.resize((w, h), Image.LANCZOS), seed)


def facets(img, mask, seed, cell=None, wrap=False, strength=1.0):
    """Folds the paper inside `mask` into flat facets (a jittered-grid Voronoi pattern):
    each facet tilts at random and catches the top-left light a little differently,
    with faint creases where facets meet. With `wrap`, the pattern tiles seamlessly
    (the image size must be a multiple of `cell`)."""
    box = (0, 0) + img.size if wrap else mask.getbbox()
    if box is None:
        return
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    if cell is None:
        cell = min(44.0, max(11.0, min(bw, bh) / 2.3))
    gen = np.random.default_rng(int(seed * 1e6) + 1)
    nx, ny = int(math.ceil(bw / cell)) + 2, int(math.ceil(bh / cell)) + 2
    jitter = gen.uniform(-0.42, 0.42, (ny, nx, 2)) * cell
    tilt = gen.uniform(-1.0, 1.0, (ny, nx, 2))
    light = 0.93 + 0.08 * strength * (-0.55 * tilt[..., 0] - 0.85 * tilt[..., 1]) + gen.uniform(-0.025, 0.025, (ny, nx)) * strength
    yy, xx = np.mgrid[0:bh, 0:bw].astype(np.float32)
    ci, cj = np.floor(xx / cell).astype(int), np.floor(yy / cell).astype(int)
    best = np.full((bh, bw), 1e9, np.float32)
    second = np.full((bh, bw), 1e9, np.float32)
    best_light = np.ones((bh, bw), np.float32)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            gi, gj = ci + di, cj + dj
            if wrap:
                ki, kj = gi % (bw // int(cell)), gj % (bh // int(cell))
            else:
                ki, kj = np.clip(gi + 1, 0, nx - 1), np.clip(gj + 1, 0, ny - 1)
            px = (gi + 0.5) * cell + jitter[kj, ki, 0]
            py = (gj + 0.5) * cell + jitter[kj, ki, 1]
            dist = np.sqrt((xx - px) ** 2 + (yy - py) ** 2)
            closer = dist < best
            second = np.where(closer, best, np.minimum(second, dist))
            best_light = np.where(closer, light[kj, ki], best_light)
            best = np.where(closer, dist, best)
    # Larger shapes are a little darker toward the bottom, as if lit from above.
    best_light -= 0.05 * strength * (yy / max(1.0, bh) - 0.5)
    gap = second - best
    factor = np.where(gap < 1.0, best_light * (1 - 0.07 * strength), np.where(gap < 2.0, best_light * (1 + 0.015 * strength), best_light))
    factor = factor + gen.normal(0.0, 0.018 * strength, factor.shape)
    region = np.asarray(img.crop(box)).astype(np.float32)
    m = np.asarray(mask.crop(box)).astype(np.float32)[..., None] / 255.0
    region[..., :3] = region[..., :3] * (1 - m) + region[..., :3] * factor[..., None] * m
    img.paste(Image.fromarray(np.clip(region, 0, 255).astype(np.uint8)), box[:2])


def ink_line(img, points, width=5, wobble=1.6, closed=False, color=INK):
    ss = _supersample(img)
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = [(x * ss, y * ss) for x, y in points]
    if closed:
        pts.append(pts[0])
    lw = max(2.0, width * 1.2) * ss
    d.line(pts, fill=color, width=int(lw), joint="curve")
    r = lw / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)
    img.alpha_composite(layer.resize((w, h), Image.LANCZOS))


def paper_grain(img, strength=10):
    """A whisper of paper texture so flat colors still feel printed."""
    arr = np.array(img).astype(np.int16)
    gen = np.random.default_rng(7)
    noise = gen.normal(0, strength * 0.3, arr.shape[:2])
    for c in range(3):
        arr[..., c] += noise.astype(np.int16)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def button_eye(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK)
    hr = r * 0.35
    d.ellipse([cx - r * 0.45 - hr / 2, cy - r * 0.45 - hr / 2, cx - r * 0.45 + hr / 2, cy - r * 0.45 + hr / 2], fill=CREAM)


# --------------------------------------------------------------------------- tiles

TILE = 64


def _flower(img, x, y, r, petal=CREAM, middle=MARIGOLD):
    """A little four-petal clover flower, the page doodle seen all over the book."""
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        px, py = x + math.cos(ang) * r * 0.7, y + math.sin(ang) * r * 0.7
        crayon_poly(img, ellipse_points(px, py, r * 0.62, r * 0.62, 14), petal, width=2, shadow=False)
    crayon_poly(img, ellipse_points(x, y, r * 0.38, r * 0.38, 12), middle, width=1.5, shadow=False)


def tile_soggy():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    top = [(x, 10 + math.sin(x / TILE * math.tau * 2) * 3) for x in range(0, TILE + 1, 2)]
    crayon_poly(img, top + [(TILE, TILE), (0, TILE)], SOGGY, outline=False, smooth=False)
    ink_line(img, top, width=4)
    for x, y, r in ((18, 34, 5), (44, 48, 4), (30, 56, 3)):
        crayon_poly(img, ellipse_points(x, y, r, r, 12), shade(SOGGY, 40), width=1.5, shadow=False)
    return img


def tile_table_wood():
    img = Image.new("RGBA", (TILE, TILE), WOOD)
    for y in (12, 34, 54):
        pts = [(x, y + math.sin(x / TILE * math.tau + y) * 3) for x in range(-4, TILE + 5, 4)]
        ink_line(img, pts, width=2, color=shade(WOOD, -40))
    return img


def tile_page_floor():
    img = Image.new("RGBA", (TILE, TILE), SKY)
    d = ImageDraw.Draw(img)
    if rng.random() < 0.9:
        _flower(img, rng.uniform(18, 46), rng.uniform(18, 46), 7)
    for _ in range(2):
        x, y = rng.uniform(8, 56), rng.uniform(8, 56)
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=shade(SKY, -40))
    return img


def tile_book_wall():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    y = 2
    for c in (TOMATO, TEAL, MARIGOLD):
        crayon_poly(img, [(4, y), (TILE - 4, y), (TILE - 4, y + 18), (4, y + 18)], c, width=3)
        ink_line(img, [(14, y + 9), (24, y + 9)], width=2, color=shade(c, 60))
        y += 21
    return img


def tile_ink_puddle():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    crayon_poly(img, ellipse_points(32, 34, 27, 21, 24), (60, 70, 130, 255), width=3)
    crayon_poly(img, ellipse_points(24, 28, 7, 4, 12), (130, 150, 220, 255), outline=False)
    return img


SEABED = (78, 92, 150, 255)


def tile_seabed_top():
    """The floor under the harbor flap: navy sand with a scalloped coral-pink rim."""
    img = Image.new("RGBA", (TILE, TILE), SEABED)
    edge = [(x, 16 + abs(math.sin(x / TILE * math.tau)) * 7) for x in range(TILE, -1, -2)]
    crayon_poly(img, [(0, 2), (TILE, 2)] + edge, (246, 134, 150, 255), outline=False, smooth=False)
    ink_line(img, [(p[0], p[1]) for p in edge], width=3)
    ink_line(img, [(-4, 3), (TILE + 4, 3)], width=4)
    d = ImageDraw.Draw(img)
    for x, y in ((16, 44), (46, 52)):
        d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=shade(SEABED, 40))
    return img


def tile_seabed_fill():
    img = Image.new("RGBA", (TILE, TILE), SEABED)
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x, y = rng.uniform(12, 52), rng.uniform(12, 52)
        d.ellipse([x - 4, y - 3, x + 4, y + 3], fill=shade(SEABED, -30))
        d.ellipse([x - 3, y - 3, x + 1, y - 1], fill=shade(SEABED, 36))
    return img


def build_tiles():
    import chapter3_art
    import finale_art
    import page_art

    snow_row, winter_row = chapter3_art.tiles()
    makers = [
        [page_art.tile_ground_top, page_art.tile_ground_fill, page_art.tile_plank, tile_soggy],
        [tile_table_wood, tile_page_floor, tile_book_wall, tile_ink_puddle],
        [page_art.tile_cobble, page_art.tile_boardwalk, page_art.tile_harbor_water, tile_seabed_top],
        [tile_seabed_fill, page_art.tile_hedge] + snow_row,
        winter_row,
        finale_art.tiles(),
    ]
    atlas = Image.new("RGBA", (TILE * 4, TILE * len(makers)), (0, 0, 0, 0))
    for row, funcs in enumerate(makers):
        for col, fn in enumerate(funcs):
            atlas.paste(fn(), (col * TILE, row * TILE))
    paper_grain(atlas, 10).save(out("tiles", "paper_tiles.png"))


# --------------------------------------------------------------------------- props


def build_props():
    # Bookmark checkpoint: a ribbon on a stick, grey when unset, red when set.
    for name, color in (("bookmark_off", (170, 160, 150, 255)), ("bookmark_on", TOMATO)):
        img = Image.new("RGBA", (64, 128), (0, 0, 0, 0))
        crayon_poly(img, [(28, 10), (34, 10), (34, 126), (28, 126)], CARDBOARD, width=3)
        crayon_poly(img, [(34, 12), (62, 16), (52, 30), (62, 44), (34, 46)], color, width=4)
        paper_grain(img).save(out("props", name + ".png"))

    # Pull-tab: a paper strip with an arrow.
    img = Image.new("RGBA", (96, 48), (0, 0, 0, 0))
    crayon_poly(img, [(4, 10), (80, 10), (92, 24), (80, 38), (4, 38)], MARIGOLD, width=4)
    ink_line(img, [(18, 24), (64, 24)], width=4, wobble=0.4)
    ink_line(img, [(54, 16), (66, 24), (54, 32)], width=4, wobble=0.4)
    paper_grain(img).save(out("props", "pull_tab.png"))

    # Moving cardboard platform.
    img = Image.new("RGBA", (192, 32), (0, 0, 0, 0))
    crayon_poly(img, [(2, 3), (190, 3), (190, 29), (2, 29)], CARDBOARD, width=4)
    for x in range(14, 190, 16):
        ink_line(img, [(x, 9), (x, 23)], width=1, wobble=0.3, color=shade(CARDBOARD, -50))
    paper_grain(img).save(out("props", "cardboard_platform.png"))

    # Page-corner door to the Margin.
    img = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    crayon_poly(img, [(6, 6), (90, 6), (90, 122), (6, 122)], (236, 222, 190, 255), width=4)
    crayon_poly(img, [(48, 122), (90, 80), (90, 122)], CREAM, width=4)
    ink_line(img, [(22, 46), (74, 46)], width=3, wobble=0.6)
    ink_line(img, [(22, 62), (66, 62)], width=3, wobble=0.6)
    paper_grain(img).save(out("props", "page_corner_door.png"))

    # Collectibles: a Scrap is a bright paper star, a Lost Letter is a sealed envelope.
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    star = []
    for i in range(10):
        r = 20 if i % 2 == 0 else 9
        a = -math.pi / 2 + i * math.pi / 5
        star.append((24 + math.cos(a) * r, 25 + math.sin(a) * r))
    crayon_poly(img, star, MARIGOLD, width=3)
    paper_grain(img).save(out("props", "scrap.png"))

    img = Image.new("RGBA", (64, 56), (0, 0, 0, 0))
    crayon_poly(img, [(6, 10), (58, 10), (58, 48), (6, 48)], CREAM, width=4)
    ink_line(img, [(8, 12), (32, 22), (56, 12)], width=2.5)
    paper_grain(img).save(out("props", "lost_letter.png"))

    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    crayon_poly(img, jitter(ellipse_points(24, 24, 20, 20, 20), 1), (226, 214, 160, 255), width=4)
    crayon_poly(img, jitter(ellipse_points(24, 24, 9, 9, 14), 0.6), PAPER, width=3)
    paper_grain(img).save(out("props", "tape.png"))

    img = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    crayon_poly(img, [(4, 24), (60, 6), (34, 28), (60, 42)], (232, 236, 244, 255), width=4)
    ink_line(img, [(10, 24), (34, 28)], width=2, wobble=0.3)
    paper_grain(img).save(out("props", "paper_dart.png"))


# ------------------------------------------------------------------------------- ui


def build_ui():
    # Health tokens: crisp, creased and torn paper.
    for name, mode in (("health_crisp", 0), ("health_creased", 1), ("health_torn", 2)):
        img = Image.new("RGBA", (56, 56), (0, 0, 0, 0))
        if mode == 2:
            crayon_poly(img, [(8, 10), (48, 8), (46, 48), (10, 46)], (210, 200, 182, 160), width=3, wobble=1.2)
            ink_line(img, [(20, 8), (30, 24), (22, 32), (34, 48)], width=3, wobble=0.6)
        else:
            crayon_poly(img, [(8, 10), (48, 8), (46, 48), (10, 46)], MARIGOLD, width=4, wobble=1.0)
            crayon_poly(img, [(18, 20), (24, 12), (28, 22), (34, 12), (38, 22), (36, 36), (20, 36)], TOMATO, width=2, wobble=0.4)
            if mode == 1:
                ink_line(img, [(8, 28), (48, 32)], width=2, wobble=0.8)
        paper_grain(img).save(out("ui", name + ".png"))


# ------------------------------------------------------------------------ backgrounds


def blob(img, circles, color, width=6, shade_amount=-34):
    """A puffy shape made of overlapping circles with one outline around the whole thing."""
    ss = _supersample(img)
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    mask = Image.new("L", layer.size, 0)
    md = ImageDraw.Draw(mask)
    ow = width * 0.9
    for cx, cy, r in circles:
        R = (r + ow) * ss
        d.ellipse([cx * ss - R, cy * ss - R, cx * ss + R, cy * ss + R], fill=edge_color(color))
    for cx, cy, r in circles:
        R = r * ss
        md.ellipse([cx * ss - R, cy * ss - R, cx * ss + R, cy * ss + R], fill=255)
    layer.paste(color[:3] + (255,), (0, 0), mask)
    img.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    facets(img, mask.resize((w, h), Image.LANCZOS), (sum(int(c[0] + c[1]) for c in circles) % 1000) / 1000.0)


def _sky_gradient(w, h, top, bottom):
    """A soft vertical gradient with a warm glow around the sun, for depth."""
    t = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
    top_c = np.array(top[:3], np.float32)[None, None, :]
    bottom_c = np.array(bottom[:3], np.float32)[None, None, :]
    rgb = np.broadcast_to(top_c * (1 - t) + bottom_c * t, (h, w, 3)).copy()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    glow = np.exp(-(((xx - 1460) / 520) ** 2 + ((yy - 210) / 380) ** 2))
    rgb += glow[..., None] * np.array([40, 26, 0], np.float32)
    alpha = np.full((h, w, 1), 255, np.float32)
    return Image.fromarray(np.concatenate([np.clip(rgb, 0, 255), alpha], axis=-1).astype(np.uint8), "RGBA")


def build_backgrounds():
    import page_art

    w, h = 1920, 1080
    page_art.build_thistledown()

    # The Margin: the giant real-world table, viewed from above with lamp light.
    img = Image.new("RGBA", (w, h), WOOD)
    for y in range(40, h, 70):
        ink_line(img, [(x, y + math.sin(x / 140 + y) * 6) for x in range(-20, w + 21, 20)], width=3, color=shade(WOOD, -36))
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * 0.2, -h * 0.4, w * 0.9, h * 0.8], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    img = Image.composite(Image.new("RGBA", (w, h), (255, 214, 140, 255)), img, glow)
    paper_grain(img, 6).convert("RGB").save(out("backgrounds", "bg_margin_table.png"))


def build_desk():
    """The real desk the open book lies on, framed around every page (BookFrame)."""
    w, h = 1920, 1080
    desk = (150, 86, 50, 255)
    img = Image.new("RGBA", (w, h), desk)
    for y in range(0, h, 90):
        ink_line(img, [(-20, y), (w + 20, y)], width=3, color=shade(desk, -34))
        for _ in range(3):
            x0 = rng.uniform(0, w)
            ink_line(img, [(x0 + i * 12, y + 45 + math.sin(i / 3) * 8) for i in range(14)], width=2, color=shade(desk, -22))
    # Things lying on the desk: a pencil, paper clips, an eraser, a roll of tape.
    crayon_poly(img, [(1330, 30), (1690, 70), (1686, 104), (1326, 64)], SKYBLUE, width=5)
    crayon_poly(img, [(1690, 70), (1760, 92), (1686, 104)], (240, 210, 160, 255), width=5)
    crayon_poly(img, [(1270, 24), (1330, 30), (1326, 64), (1266, 58)], TOMATO, width=5)
    for cx, cy, col in ((120, 40, TOMATO), (1840, 1000, SKYBLUE), (60, 1010, MARIGOLD)):
        ImageDraw.Draw(img)
        ink_line(img, [(cx - 30, cy), (cx + 30, cy), (cx + 30, cy + 22), (cx - 24, cy + 22), (cx - 24, cy + 8), (cx + 18, cy + 8)], width=5, color=INK)
        ink_line(img, [(cx - 30, cy), (cx + 30, cy), (cx + 30, cy + 22), (cx - 24, cy + 22), (cx - 24, cy + 8), (cx + 18, cy + 8)], width=3, color=col)
    crayon_poly(img, [(40, 400), (130, 380), (150, 450), (60, 470)], (250, 170, 190, 255), width=5)
    crayon_poly(img, ellipse_points(1850, 520, 70, 70, 36), (236, 226, 176, 255), width=6)
    crayon_poly(img, ellipse_points(1850, 520, 32, 32, 24), desk, width=4, shadow=False)
    # Warm lamp light falling across the middle of the desk.
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * 0.1, -h * 0.3, w * 0.9, h * 0.9], fill=80)
    glow = glow.filter(ImageFilter.GaussianBlur(200))
    img = Image.composite(Image.new("RGBA", (w, h), (255, 200, 120, 255)), img, glow)
    paper_grain(img, 6).convert("RGB").save(out("backgrounds", "bg_desk.png"))


def build_icon():
    s = 512
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    crayon_poly(img, jitter(ellipse_points(256, 256, 236, 236, 40), 2), CREAM, width=12, density=0.4)
    head = [(130, 220), (160, 70), (220, 190), (292, 190), (352, 70), (382, 220), (400, 300), (330, 410), (256, 440), (182, 410), (112, 300)]
    crayon_poly(img, head, MARIGOLD, width=12, wobble=2.5)
    crayon_poly(img, [(160, 190), (170, 110), (204, 190)], TOMATO, width=6, wobble=1)
    crayon_poly(img, [(308, 190), (342, 110), (352, 190)], TOMATO, width=6, wobble=1)
    crayon_poly(img, [(196, 330), (256, 300), (316, 330), (256, 432)], CREAM, width=8, wobble=1.2)
    d = ImageDraw.Draw(img)
    d.ellipse([236, 330, 276, 362], fill=INK)
    button_eye(img, 196, 270, 22)
    button_eye(img, 316, 270, 22)
    # A strip of tape across one ear: the mended look.
    crayon_poly(img, [(330, 120), (392, 104), (398, 128), (336, 144)], (236, 226, 176, 255), width=5, wobble=0.6, density=0.5)
    img = paper_grain(img, 6)
    img.save(os.path.join(ROOT, "icon.png"))
    img.save(os.path.join(ROOT, "icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


# ------------------------------------------------------------------ chapter 1 art


def build_windmill():
    w, h = 256, 400
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    crayon_poly(img, [(70, 396), (186, 396), (164, 120), (92, 120)], CARDBOARD, width=6)
    crayon_poly(img, [(80, 126), (128, 50), (176, 126)], TOMATO, width=6)
    crayon_poly(img, [(110, 396), (146, 396), (146, 330), (128, 316), (110, 330)], (120, 84, 54, 255), width=4)
    crayon_poly(img, jitter(ellipse_points(128, 200, 16, 16, 12), 0.6), SKY, width=4)
    paper_grain(img).save(out("props", "windmill.png"))

    s = 320
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    c = s / 2
    for i in range(4):
        a = i * math.pi / 2
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        blade = [(c + dx * 24 + px * 10, c + dy * 24 + py * 10), (c + dx * 150 + px * 10, c + dy * 150 + py * 10),
                 (c + dx * 150 + px * 44, c + dy * 150 + py * 44), (c + dx * 40 + px * 44, c + dy * 40 + py * 44)]
        crayon_poly(img, blade, CREAM, width=4, wobble=1.0)
        ink_line(img, [(c, c), (c + dx * 152, c + dy * 152)], width=6, wobble=0.6)
    crayon_poly(img, jitter(ellipse_points(c, c, 18, 18, 12), 0.5), MARIGOLD, width=4)
    paper_grain(img).save(out("props", "windmill_sails.png"))


def build_millwheel():
    """Old Millwheel: a waterlogged windmill golem, the Chapter 1 boss."""
    w, h = 360, 440
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    soggy_wood = (128, 120, 112, 255)
    crayon_poly(img, [(70, 436), (290, 436), (250, 130), (110, 130)], soggy_wood, width=7)
    crayon_poly(img, [(90, 138), (180, 30), (270, 138)], (110, 96, 120, 255), width=7)
    d = ImageDraw.Draw(img)
    for _ in range(14):
        x, y = rng.uniform(100, 260), rng.uniform(150, 420)
        d.ellipse([x - 7, y - 6, x + 7, y + 6], fill=(108, 132, 96, 220))
    for x in (100, 150, 210, 258):
        crayon_poly(img, [(x - 6, 430), (x + 6, 430), (x, 440)], (92, 120, 160, 255), outline=False)
    # Angry window-eyes and a plank frown.
    for ex in (140, 220):
        crayon_poly(img, [(ex - 26, 230), (ex + 26, 222), (ex + 22, 262), (ex - 22, 262)], (40, 36, 44, 255), width=5)
        d.ellipse([ex - 9, 236, ex + 9, 254], fill=MARIGOLD)
    ink_line(img, [(110, 206), (166, 222)], width=7, wobble=0.5)
    ink_line(img, [(250, 206), (194, 222)], width=7, wobble=0.5)
    crayon_poly(img, [(130, 320), (230, 320), (220, 360), (140, 360)], (52, 40, 36, 255), width=5)
    for x in range(146, 222, 18):
        ink_line(img, [(x, 322), (x + 4, 340)], width=3, wobble=0.3, color=CREAM)
    paper_grain(img).save(out("characters", "millwheel_body.png"))

    s = 560
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    c = s / 2
    for i in range(4):
        a = i * math.pi / 2 + 0.2
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        blade = [(c + dx * 40 + px * 14, c + dy * 40 + py * 14), (c + dx * 270 + px * 14, c + dy * 270 + py * 14),
                 (c + dx * 262 + px * 74, c + dy * 262 + py * 74), (c + dx * 60 + px * 70, c + dy * 60 + py * 70)]
        crayon_poly(img, jitter(blade, 4), SOGGY, width=6, wobble=2.0)
        ink_line(img, [(c, c), (c + dx * 272, c + dy * 272)], width=9, wobble=1.0)
    paper_grain(img).save(out("characters", "millwheel_sails.png"))

    img = Image.new("RGBA", (112, 112), (0, 0, 0, 0))
    crayon_poly(img, jitter(ellipse_points(56, 56, 46, 46, 24), 1.0), MARIGOLD, width=6, density=1.5)
    d = ImageDraw.Draw(img)
    for hx, hy in ((44, 44), (68, 44), (44, 68), (68, 68)):
        d.ellipse([hx - 6, hy - 6, hx + 6, hy + 6], fill=INK)
    paper_grain(img).save(out("characters", "millwheel_core.png"))


def build_boat_race():
    img = Image.new("RGBA", (176, 112), (0, 0, 0, 0))
    crayon_poly(img, [(8, 60), (168, 60), (140, 100), (36, 100)], (238, 236, 226, 255), width=5)
    crayon_poly(img, [(88, 8), (88, 60), (40, 60)], (232, 226, 210, 255), width=4)
    crayon_poly(img, [(92, 14), (132, 60), (92, 60)], (220, 214, 196, 255), width=4)
    ink_line(img, [(40, 72), (136, 72)], width=2, wobble=0.6)
    paper_grain(img).save(out("props", "paper_boat.png"))

    img = Image.new("RGBA", (112, 96), (0, 0, 0, 0))
    crayon_poly(img, jitter(ellipse_points(56, 52, 50, 38, 16), 3), (150, 140, 130, 255), width=5)
    crayon_poly(img, jitter(ellipse_points(44, 40, 14, 9, 10), 1), (186, 178, 168, 255), outline=False)
    paper_grain(img).save(out("props", "stream_rock.png"))

    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), GRASS)
    img.alpha_composite(crayon_layer((w, h), GRASS, density=0.2, angle=-1.2, stroke_len=(8, 20)))
    top = [(x, 250 + math.sin(x / w * math.tau * 3) * 30) for x in range(-20, w + 40, 40)]
    bottom = [(x, 860 + math.sin(x / w * math.tau * 2 + 1) * 30) for x in range(w + 20, -40, -40)]
    crayon_poly(img, top + bottom, (110, 168, 214, 255), width=7, wobble=2.0, density=0.5)
    for _ in range(30):
        x = rng.uniform(20, w - 20)
        y = rng.choice([rng.uniform(30, 200), rng.uniform(920, 1060)])
        _flower(img, x, y, rng.uniform(9, 13))
    d = ImageDraw.Draw(img)
    for y in range(330, 820, 70):
        for x0 in range(0, w, 240):
            x = (x0 + y * 3) % w
            d.arc([x, y, x + 90, y + 24], 200, 340, fill=CREAM, width=4)
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_ribbon_stream.png"))


def build_prologue_art():
    w, h = 1920, 1080
    night = (62, 70, 112, 255)
    img = Image.new("RGBA", (w, h), night)
    img.alpha_composite(crayon_layer((w, h), night, density=0.25, angle=-0.3, stroke_len=(30, 70)))
    # Rainy window.
    crayon_poly(img, [(1240, 140), (1700, 140), (1700, 600), (1240, 600)], (40, 48, 86, 255), width=10, density=0.6)
    ink_line(img, [(1470, 140), (1470, 600)], width=8)
    ink_line(img, [(1240, 370), (1700, 370)], width=8)
    d = ImageDraw.Draw(img)
    for _ in range(90):
        x, y = rng.uniform(1250, 1690), rng.uniform(150, 590)
        d.line([(x, y), (x - 6, y + 22)], fill=(150, 170, 220, 255), width=2)
    # Shelves full of books.
    for shelf_y in (300, 620):
        crayon_poly(img, [(80, shelf_y), (1100, shelf_y), (1100, shelf_y + 24), (80, shelf_y + 24)], WOOD, width=5, density=0.6)
        x = 100
        while x < 1060:
            bw = rng.randint(34, 70)
            bh = rng.randint(150, 230)
            col = rng.choice([TOMATO, MARIGOLD, SAGE, (96, 132, 186, 255), (150, 110, 170, 255)])
            col = shade(col, -40)
            crayon_poly(img, [(x, shelf_y - bh), (x + bw, shelf_y - bh), (x + bw, shelf_y), (x, shelf_y)], col, width=4, wobble=0.8, density=0.5)
            x += bw + rng.randint(2, 10)
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_bookshelf_night.png"))

    img = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
    water = (82, 116, 170, 230)
    pts = [(x, 30 + math.sin(x / 256 * math.tau * 2) * 12) for x in range(0, 257, 8)] + [(256, 128), (0, 128)]
    crayon_poly(img, pts, water, outline=False, density=1.2)
    ink_line(img, pts[:-2], width=4, wobble=0.6, color=(40, 56, 96, 255))
    paper_grain(img, 6).save(out("props", "rising_water.png"))


def build_dad_table():
    """The real world between chapters: Gran's table under one lamp."""
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), (64, 46, 40, 255))
    img.alpha_composite(crayon_layer((w, h), (64, 46, 40, 255), density=0.2, angle=0.0, stroke_len=(50, 120)))
    crayon_poly(img, [(0, 640), (w, 600), (w, h), (0, h)], WOOD, width=8, wobble=2.0, density=0.5)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([560, 120, 1520, 1040], fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(140))
    img = Image.composite(Image.new("RGBA", (w, h), (255, 220, 150, 255)), img, glow)
    # Lamp.
    crayon_poly(img, [(840, 0), (860, 0), (860, 150), (840, 150)], INK, outline=False)
    crayon_poly(img, [(740, 150), (960, 150), (1010, 280), (690, 280)], MARIGOLD, width=7)
    # The open, taped pop-up book.
    crayon_poly(img, [(520, 760), (950, 720), (950, 900), (520, 940)], CREAM, width=6, density=0.5)
    crayon_poly(img, [(950, 720), (1380, 760), (1380, 940), (950, 900)], (244, 236, 214, 255), width=6, density=0.5)
    crayon_poly(img, [(700, 790), (760, 700), (820, 790)], SAGE, width=4)
    crayon_poly(img, [(1080, 800), (1140, 690), (1200, 800)], TOMATO, width=4)
    for x in (640, 1010, 1240):
        crayon_poly(img, [(x, 770), (x + 90, 760), (x + 92, 790), (x + 2, 800)], (236, 226, 176, 220), width=3, wobble=0.6)
    # Tape roll and hairdryer.
    crayon_poly(img, jitter(ellipse_points(1560, 860, 80, 60, 20), 2), (226, 214, 160, 255), width=6)
    crayon_poly(img, jitter(ellipse_points(1560, 860, 34, 24, 14), 1), (90, 66, 50, 255), width=4)
    crayon_poly(img, [(220, 780), (420, 760), (430, 830), (230, 850)], (96, 132, 186, 255), width=6)
    crayon_poly(img, [(300, 840), (350, 836), (360, 980), (310, 984)], (96, 132, 186, 255), width=6)
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_dad_table.png"))


def build_drip():
    img = Image.new("RGBA", (40, 56), (0, 0, 0, 0))
    crayon_poly(img, [(20, 4), (34, 32), (30, 46), (20, 52), (10, 46), (6, 32)], (60, 84, 130, 255), width=3, wobble=0.5)
    paper_grain(img).save(out("props", "ink_drip.png"))


def build_chapter1_art():
    build_drip()
    build_windmill()
    build_millwheel()
    build_boat_race()
    build_prologue_art()
    build_dad_table()


if __name__ == "__main__":
    import sys

    import chapter2_art
    import chapter3_art
    import character_art
    import finale_art

    if "characters" in sys.argv:
        # Quick path: only the cast (Patch, NPCs and Soggies).
        character_art.build()
        sys.exit(0)
    if "chapter2" in sys.argv:
        # Quick path: only the Chapter 2 art and the tile atlas.
        build_tiles()
        chapter2_art.build()
        sys.exit(0)
    if "chapter3" in sys.argv:
        # Quick path: only the Chapter 3 art and the tile atlas.
        build_tiles()
        chapter3_art.build()
        sys.exit(0)
    if "finale" in sys.argv:
        # Quick path: only the finale art, the tile atlas and Patch (with his new tail).
        build_tiles()
        finale_art.build()
        character_art.build_patch()
        character_art.build_patch(mended=True)
        sys.exit(0)
    build_tiles()
    build_props()
    build_ui()
    build_backgrounds()
    build_desk()
    build_icon()
    build_chapter1_art()
    chapter2_art.build()
    chapter3_art.build()
    finale_art.build()
    character_art.build()
    print("Art written to", ART)
