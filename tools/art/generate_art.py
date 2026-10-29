"""Generates the placeholder ink-and-crayon art for Patch and the Pop-Up Kingdom.

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

INK = (43, 33, 24, 255)
PAPER = (247, 238, 214, 255)
MARIGOLD = (242, 169, 59, 255)
TOMATO = (222, 88, 61, 255)
SAGE = (134, 170, 102, 255)
GRASS = (104, 160, 72, 255)
TAN = (214, 178, 128, 255)
CARDBOARD = (190, 142, 92, 255)
SOGGY = (126, 146, 164, 255)
CREAM = (252, 246, 228, 255)
SKY = (250, 226, 170, 255)
WOOD = (176, 120, 72, 255)

rng = random.Random(1987)


def out(*parts):
    path = os.path.join(ART, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def jitter(points, amount):
    return [(x + rng.uniform(-amount, amount), y + rng.uniform(-amount, amount)) for x, y in points]


def subdivide(points, closed=True, steps=6):
    """Adds midpoints so outlines can wobble like a hand-drawn line."""
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


def crayon_layer(size, color, density=1.0, angle=-0.6, stroke_len=(10, 26)):
    """A full-size layer of waxy crayon strokes in one color."""
    w, h = size
    layer = Image.new("RGBA", size, shade(color, 18)[:3] + (235,))
    d = ImageDraw.Draw(layer)
    strokes = int(w * h / 22 * density)
    dx, dy = math.cos(angle), math.sin(angle)
    for _ in range(strokes):
        x, y = rng.uniform(-10, w + 10), rng.uniform(-10, h + 10)
        length = rng.uniform(*stroke_len)
        c = shade(color, rng.uniform(-22, 12))
        d.line([(x, y), (x + dx * length, y + dy * length)], fill=c[:3] + (rng.randint(150, 255),), width=rng.choice([1, 2, 2, 3]))
    # Wax skips: tiny paper-colored flecks that show the grain through.
    arr = np.array(layer)
    noise = np.random.default_rng(rng.randint(0, 99999)).random((h, w))
    arr[noise > 0.965, :3] = np.array(shade(color, 45)[:3])
    return Image.fromarray(arr)


def crayon_poly(img, points, color, outline=True, width=5, wobble=1.6, density=1.0):
    """Fills a polygon with crayon texture and inks its outline."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    fill = crayon_layer(img.size, color, density)
    img.paste(fill, (0, 0), ImageChops.multiply(mask, fill.getchannel("A")))
    if outline:
        ink_line(img, points, width=width, wobble=wobble, closed=True)


def ink_line(img, points, width=5, wobble=1.6, closed=False, color=INK):
    d = ImageDraw.Draw(img)
    pts = jitter(subdivide(points, closed=closed), wobble)
    if closed:
        pts.append(pts[0])
    d.line(pts, fill=color, width=width, joint="curve")
    r = width / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def paper_grain(img, strength=10):
    arr = np.array(img).astype(np.int16)
    gen = np.random.default_rng(7)
    noise = gen.normal(0, strength, arr.shape[:2])
    noise = np.array(Image.fromarray(((noise + 64).clip(0, 255)).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.int16) - 64
    for c in range(3):
        arr[..., c] += noise
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def button_eye(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK)
    hr = r * 0.35
    d.ellipse([cx - r * 0.45 - hr / 2, cy - r * 0.45 - hr / 2, cx - r * 0.45 + hr / 2, cy - r * 0.45 + hr / 2], fill=CREAM)


# --------------------------------------------------------------------------- tiles

TILE = 64


def tile_ground_top():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    crayon_poly(img, [(0, 10), (TILE, 10), (TILE, TILE), (0, TILE)], TAN, outline=False)
    crayon_poly(img, [(0, 4), (TILE, 4), (TILE, 22), (0, 22)], GRASS, outline=False, density=1.4)
    ink_line(img, [(0, 4), (TILE / 2, 3), (TILE, 4)], width=4, wobble=1.0)
    d = ImageDraw.Draw(img)
    for x in range(4, TILE, 9):
        d.line([(x, 22), (x + rng.uniform(-2, 2), 27)], fill=shade(GRASS, -25), width=2)
    return img


def tile_ground_fill():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    crayon_poly(img, [(0, 0), (TILE, 0), (TILE, TILE), (0, TILE)], TAN, outline=False)
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rng.uniform(8, 56), rng.uniform(8, 56)
        d.arc([x - 5, y - 3, x + 5, y + 3], 200, 340, fill=shade(TAN, -45), width=2)
    return img


def tile_plank():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    crayon_poly(img, [(0, 2), (TILE, 2), (TILE, 20), (0, 20)], CARDBOARD, width=4, wobble=0.8)
    d = ImageDraw.Draw(img)
    for x in range(6, TILE, 8):
        d.line([(x, 6), (x, 16)], fill=shade(CARDBOARD, -30), width=1)
    return img


def tile_soggy():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    crayon_poly(img, [(0, 8), (TILE, 8), (TILE, TILE), (0, TILE)], SOGGY, outline=False)
    ink_line(img, [(0, 8), (20, 11), (44, 7), (TILE, 10)], width=4, wobble=1.0, color=(52, 64, 82, 255))
    d = ImageDraw.Draw(img)
    for _ in range(4):
        x, y = rng.uniform(6, 58), rng.uniform(20, 58)
        d.ellipse([x - 4, y - 3, x + 4, y + 3], fill=(96, 118, 98, 200))
    return img


def tile_table_wood():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    crayon_poly(img, [(0, 0), (TILE, 0), (TILE, TILE), (0, TILE)], WOOD, outline=False, density=0.8)
    d = ImageDraw.Draw(img)
    for y in (14, 31, 50):
        pts = [(x, y + math.sin(x / 9 + y) * 2) for x in range(0, TILE + 1, 4)]
        d.line(pts, fill=shade(WOOD, -35), width=2)
    return img


def tile_page_floor():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    crayon_poly(img, [(0, 0), (TILE, 0), (TILE, TILE), (0, TILE)], (200, 222, 150, 255), outline=False, density=0.6)
    d = ImageDraw.Draw(img)
    for _ in range(5):
        x, y = rng.uniform(4, 60), rng.uniform(6, 60)
        d.line([(x, y), (x - 2, y - 6)], fill=shade(GRASS, -10), width=2)
        d.line([(x, y), (x + 2, y - 5)], fill=shade(GRASS, -10), width=2)
    return img


def tile_book_wall():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    colors = [TOMATO, (96, 132, 186, 255), MARIGOLD]
    y = 2
    for c in colors:
        hgt = 20
        crayon_poly(img, [(3, y), (TILE - 3, y), (TILE - 3, y + hgt - 1), (3, y + hgt - 1)], c, width=3, wobble=0.6)
        y += hgt + 1
    return img


def tile_ink_puddle():
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    pts = jitter(ellipse_points(32, 32, 28, 22, 18), 3)
    crayon_poly(img, pts, (60, 78, 112, 255), width=3, wobble=0.8, density=1.4)
    return img


def build_tiles():
    makers = [
        [tile_ground_top, tile_ground_fill, tile_plank, tile_soggy],
        [tile_table_wood, tile_page_floor, tile_book_wall, tile_ink_puddle],
    ]
    atlas = Image.new("RGBA", (TILE * 4, TILE * 2), (0, 0, 0, 0))
    for row, funcs in enumerate(makers):
        for col, fn in enumerate(funcs):
            atlas.paste(fn(), (col * TILE, row * TILE))
    atlas.save(out("tiles", "paper_tiles.png"))


# ---------------------------------------------------------------------- characters


def build_patch():
    """Patch, the paper fox, side view facing right with a torn stump for a tail."""
    s = 160
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    # Legs (behind body).
    for lx in (52, 66, 98, 112):
        crayon_poly(img, [(lx, 112), (lx + 10, 112), (lx + 11, 146), (lx - 1, 146)], shade(MARIGOLD, -30), width=4)
        crayon_poly(img, [(lx - 2, 140), (lx + 13, 140), (lx + 13, 150), (lx - 3, 150)], INK, outline=False)
    # Torn tail stump: a jagged paper edge.
    stump = [(40, 84), (26, 78), (32, 86), (20, 88), (30, 94), (22, 100), (40, 104)]
    crayon_poly(img, stump, MARIGOLD, width=4)
    # Body.
    body = [(36, 80), (70, 70), (112, 72), (130, 84), (128, 116), (96, 122), (52, 120), (36, 106)]
    crayon_poly(img, body, MARIGOLD, width=5)
    # Cream chest.
    crayon_poly(img, [(104, 92), (126, 90), (124, 116), (106, 118)], CREAM, width=3)
    # Head.
    head = [(102, 44), (114, 14), (124, 40), (134, 38), (146, 12), (150, 46), (156, 58), (154, 72), (136, 84), (110, 82), (100, 64)]
    crayon_poly(img, head, MARIGOLD, width=5)
    # Inner ears.
    crayon_poly(img, [(110, 40), (115, 24), (121, 40)], TOMATO, width=2, wobble=0.5)
    crayon_poly(img, [(137, 38), (145, 22), (147, 42)], TOMATO, width=2, wobble=0.5)
    # Cream muzzle and nose.
    crayon_poly(img, [(132, 62), (156, 58), (154, 72), (136, 80)], CREAM, width=3)
    d = ImageDraw.Draw(img)
    d.ellipse([150, 56, 160, 64], fill=INK)
    button_eye(img, 134, 52, 6)
    # Stitch mark across the body: the first visible mend.
    for i in range(3):
        x = 76 + i * 9
        ink_line(img, [(x, 88), (x + 4, 100)], width=2, wobble=0.4)
    ink_line(img, [(73, 94), (104, 94)], width=2, wobble=0.6)
    paper_grain(img).save(out("characters", "patch.png"))


def build_soggy():
    s = 112
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    blob = jitter(ellipse_points(56, 66, 46, 38, 22), 4)
    crayon_poly(img, blob, SOGGY, width=5)
    d = ImageDraw.Draw(img)
    # Crumpled folds.
    for _ in range(5):
        x, y = rng.uniform(26, 86), rng.uniform(44, 92)
        ink_line(img, [(x, y), (x + rng.uniform(-12, 12), y + rng.uniform(4, 12))], width=2, wobble=0.6, color=(70, 84, 104, 255))
    # Mildew spots.
    for _ in range(6):
        x, y = rng.uniform(22, 90), rng.uniform(40, 96)
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(108, 132, 96, 220))
    # Drips.
    for x in (30, 58, 84):
        crayon_poly(img, [(x - 5, 96), (x + 5, 96), (x, 110)], (92, 120, 160, 255), width=2, wobble=0.4)
    # Grumpy eyes.
    button_eye(img, 42, 58, 7)
    button_eye(img, 70, 58, 7)
    ink_line(img, [(32, 46), (50, 52)], width=4, wobble=0.3)
    ink_line(img, [(80, 46), (62, 52)], width=4, wobble=0.3)
    ink_line(img, [(46, 80), (56, 76), (66, 80)], width=3, wobble=0.3)
    paper_grain(img).save(out("characters", "soggy.png"))


def build_sheep():
    w, h = 128, 112
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for lx in (38, 56, 74, 90):
        crayon_poly(img, [(lx, 80), (lx + 8, 80), (lx + 8, 106), (lx, 106)], INK, outline=False)
    for cx, cy, r in [(40, 56, 24), (64, 46, 26), (88, 56, 24), (52, 72, 22), (78, 72, 22)]:
        crayon_poly(img, jitter(ellipse_points(cx, cy, r, r * 0.9, 16), 2), CREAM, width=4)
    crayon_poly(img, jitter(ellipse_points(108, 52, 15, 18, 14), 1.5), (70, 58, 52, 255), width=4)
    button_eye(img, 112, 48, 4)
    # Tiny round spectacles: Shepherd Fluff is old and wise.
    d = ImageDraw.Draw(img)
    d.ellipse([105, 41, 119, 55], outline=CREAM, width=2)
    paper_grain(img).save(out("characters", "shepherd_fluff.png"))


def build_dot():
    """Dot, the runaway full stop: a round ink blot with button eyes and tiny feet."""
    s = 72
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    crayon_poly(img, jitter(ellipse_points(36, 32, 26, 26, 24), 0.8), (52, 44, 40, 255), width=4, density=1.6)
    d = ImageDraw.Draw(img)
    for ex in (27, 45):
        d.ellipse([ex - 6, 22, ex + 6, 34], fill=CREAM)
        d.ellipse([ex - 3, 26, ex + 3, 32], fill=INK)
    ink_line(img, [(28, 58), (26, 68)], width=3, wobble=0.3)
    ink_line(img, [(44, 58), (46, 68)], width=3, wobble=0.3)
    paper_grain(img).save(out("characters", "dot.png"))


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

    # Collectibles.
    img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    crayon_poly(img, [(6, 10), (30, 4), (36, 26), (14, 36)], CREAM, width=3)
    crayon_poly(img, [(12, 14), (26, 10), (28, 24), (16, 28)], MARIGOLD, outline=False)
    paper_grain(img).save(out("props", "scrap.png"))

    img = Image.new("RGBA", (56, 56), (0, 0, 0, 0))
    crayon_poly(img, jitter(ellipse_points(28, 28, 24, 24, 20), 1.2), CREAM, width=4)
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


def build_backgrounds():
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), SKY)
    sky = crayon_layer((w, h), SKY, density=0.25, angle=-0.2, stroke_len=(30, 70))
    img.alpha_composite(sky)
    # Button sun.
    crayon_poly(img, jitter(ellipse_points(1460, 220, 110, 110, 30), 2), MARIGOLD, width=7)
    d = ImageDraw.Draw(img)
    for hx, hy in ((1430, 190), (1490, 190), (1430, 250), (1490, 250)):
        d.ellipse([hx - 10, hy - 10, hx + 10, hy + 10], fill=INK)
    # Layered paper hills.
    for base, amp, color, phase in ((760, 90, (182, 206, 128, 255), 0.0), (860, 70, SAGE, 1.7), (960, 50, GRASS, 3.1)):
        # Whole-number frequencies over the width, so the image tiles seamlessly sideways.
        pts = [(x, base - math.sin(x / w * math.tau * 2 + phase) * amp - math.sin(x / w * math.tau * 7 + phase) * 18) for x in range(-20, w + 40, 40)]
        pts += [(w + 20, h + 20), (-20, h + 20)]
        crayon_poly(img, pts, color, width=6, wobble=2.0, density=0.35)
    # Cut-paper clouds.
    for cx, cy in ((320, 200), (840, 140), (1180, 300)):
        pts = []
        for i, r in enumerate((60, 48, 70, 52)):
            pts += ellipse_points(cx - 90 + i * 60, cy + (12 if i % 2 else 0), r, r * 0.7, 10)[5:]
        crayon_poly(img, [(cx - 160, cy + 40), (cx + 150, cy + 40), (cx + 150, cy + 20), (cx - 160, cy + 20)], CREAM, outline=False)
        for i, r in enumerate((60, 48, 70, 52)):
            crayon_poly(img, jitter(ellipse_points(cx - 90 + i * 60, cy + (12 if i % 2 else 0), r, r * 0.7, 18), 1.5), CREAM, width=5, density=0.4)
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_thistledown.png"))

    # The Margin: the giant real-world table, viewed from above with lamp light.
    img = Image.new("RGBA", (w, h), WOOD)
    img.alpha_composite(crayon_layer((w, h), WOOD, density=0.25, angle=0.0, stroke_len=(60, 140)))
    d = ImageDraw.Draw(img)
    for y in range(40, h, 70):
        d.line([(x, y + math.sin(x / 140 + y) * 6) for x in range(0, w + 1, 20)], fill=shade(WOOD, -40), width=3)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * 0.2, -h * 0.4, w * 0.9, h * 0.8], fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    warm = Image.new("RGBA", (w, h), (255, 226, 160, 255))
    img = Image.composite(warm, img, glow)
    paper_grain(img, 6).convert("RGB").save(out("backgrounds", "bg_margin_table.png"))


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


def build_lost_sheep():
    """A flock sheep swollen by the damp: puffier, bluer, and grumpy about it."""
    w, h = 144, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wool = (190, 206, 220, 255)
    for lx in (44, 62, 82, 98):
        crayon_poly(img, [(lx, 94), (lx + 8, 94), (lx + 8, 120), (lx, 120)], INK, outline=False)
    for cx, cy, r in [(42, 62, 30), (70, 48, 32), (100, 62, 30), (56, 84, 26), (88, 84, 26)]:
        crayon_poly(img, jitter(ellipse_points(cx, cy, r, r * 0.9, 16), 2.5), wool, width=4)
    for _ in range(5):
        x, y = rng.uniform(34, 104), rng.uniform(40, 92)
        ImageDraw.Draw(img).ellipse([x - 4, y - 4, x + 4, y + 4], fill=(120, 150, 180, 200))
    crayon_poly(img, jitter(ellipse_points(124, 58, 15, 18, 14), 1.5), (70, 58, 52, 255), width=4)
    button_eye(img, 128, 54, 4)
    ink_line(img, [(118, 70), (126, 66), (134, 70)], width=2, wobble=0.3)
    paper_grain(img).save(out("characters", "lost_sheep.png"))


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
    build_lost_sheep()
    build_windmill()
    build_millwheel()
    build_boat_race()
    build_prologue_art()
    build_dad_table()


if __name__ == "__main__":
    build_tiles()
    build_patch()
    build_soggy()
    build_sheep()
    build_dot()
    build_props()
    build_ui()
    build_backgrounds()
    build_icon()
    build_chapter1_art()
    print("Art written to", ART)
