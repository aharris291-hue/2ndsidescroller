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
    print("Art written to", ART)
