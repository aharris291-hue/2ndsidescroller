"""Finale art: the Gutter. The drowned crease at the middle of the book, the
hairdryer and its warm air, Drizzle once she is dry, Nell's crayon page, and the
real-world scenes at Gran's table that close the story.

Same papercraft style as the rest of the book (see chapter3_art.py). Nell's page
is the exception: she drew it herself, in crayon. Built by generate_art.py; to
regenerate only the finale:

    python3 tools/art/generate_art.py finale
"""

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from character_art import button, part, stitches
from generate_art import (INK, MARIGOLD, TILE, TOMATO, WOOD, blob, crayon_poly, edge_color, ellipse_points, facets, ink_line,
                          out, paper_grain, shade)
from page_art import _shadowed, deckle, fold_tile, mottle, paper_layer

SOAKED = (66, 80, 126, 255)
SODDEN = (170, 184, 212, 255)
THREAD = (214, 64, 70, 255)
DRYER = (236, 122, 156, 255)
DRIZZLE = (226, 238, 252, 255)
LEMON = (255, 236, 120, 255)
CRAYON_GREEN = (96, 186, 80, 255)
CRAYON_BROWN = (150, 96, 60, 255)
NELL = (58, 110, 165, 255)
HAIR = (60, 40, 34, 255)
SKIN = (238, 196, 160, 255)


# ------------------------------------------------------------------------- tiles


def _soaked(seed):
    """Swollen, waterlogged page bundles: dark blue-grey with wavy page-edge lines."""
    img = mottle(SOAKED, TILE, seed, blur=4, amount=30)
    d = ImageDraw.Draw(img)
    for k, y0 in enumerate(range(6, TILE, 9)):
        pts = [(x, y0 + math.sin(x / TILE * math.tau * (1 + k % 2) + seed + k) * 2.2) for x in range(0, TILE + 1, 4)]
        d.line(pts, fill=shade(SOAKED, 22 if k % 2 else -18)[:3] + (150,), width=2)
    r = random.Random(seed)
    for _ in range(3):
        x = r.uniform(6, 58)
        y = r.uniform(4, 40)
        d.line([(x, y), (x + r.uniform(-1, 1), y + r.uniform(10, 20))], fill=(120, 150, 210, 140), width=2)
    return fold_tile(img, seed / 100)


def tile_gutter_fill():
    return _soaked(301)


def tile_gutter_top():
    """Soaked pages under a sagging strip of pale, sodden paper, beaded with water."""
    img = _soaked(302)
    edge = [(x, 22 + 3.0 * math.sin(x / TILE * math.tau * 2 + 0.4) + 1.2 * math.sin(x / TILE * math.tau * 6 + 1.0))
            for x in range(0, TILE + 1, 2)]
    top = [(0, 0), (TILE, 0)] + edge[::-1]
    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).polygon(top, fill=255)
    shadow = Image.new("L", (TILE, TILE), 0)
    shadow.paste(mask, (0, 3))
    arr = np.asarray(img).astype(np.float32)
    arr[..., :3] *= 1.0 - 0.35 * (np.asarray(shadow.filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32)[..., None] / 255.0)
    img = Image.fromarray(arr.astype(np.uint8))
    img.paste((214, 222, 236, 255), (0, 0), mask.filter(ImageFilter.MaxFilter(3)))
    img.paste(mottle(SODDEN, TILE, 303, blur=3, amount=14, fine=6), (0, 0), mask)
    facets(img, mask, 0.33, cell=18, wrap=True, strength=0.8)
    d = ImageDraw.Draw(img)
    # Beads of water and a sheen along the top.
    for x, y in ((10, 9), (30, 13), (50, 8)):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(150, 196, 240, 255))
        d.ellipse([x - 2, y - 2, x, y], fill=(240, 248, 255, 255))
    d.line([(0, 4), (TILE, 4)], fill=(236, 244, 255, 150), width=2)
    ink_line(img, [(-4, 1.5), (TILE + 4, 1.5)], width=2.2, wobble=0, color=edge_color(SODDEN))
    return img


def _crayon_strokes(img, color, seed, count, length=(8, 18), angle=-0.5, area=(0, 0, TILE, TILE), width=3):
    """Wax crayon scribble that wraps at the tile edges, so neighbours line up."""
    r = random.Random(seed)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = area
    for _ in range(count):
        x, y = r.uniform(x0, x1), r.uniform(y0, y1)
        a = angle + r.uniform(-0.25, 0.25)
        ln = r.uniform(*length)
        tone = shade(color, r.randint(-26, 22))[:3] + (r.randint(150, 230),)
        for dx in (-TILE, 0, TILE):
            d.line([(x + dx, y), (x + dx + math.cos(a) * ln, y + math.sin(a) * ln)], fill=tone, width=width)


def tile_crayon_fill():
    img = Image.new("RGBA", (TILE, TILE), (236, 206, 150, 255))
    _crayon_strokes(img, CRAYON_BROWN, 311, 120)
    return img


def tile_crayon_top():
    """Nell's crayon grass: a scribbled green band over brown earth, a few flowers."""
    img = tile_crayon_fill()
    _crayon_strokes(img, CRAYON_GREEN, 312, 140, length=(8, 16), angle=-1.3, area=(0, -4, TILE, 20), width=3)
    d = ImageDraw.Draw(img)
    for i in range(9):
        x = i * 7.1 + 2
        d.line([(x, 6), (x + 2, -2)], fill=shade(CRAYON_GREEN, -30), width=2)
    for x, c in ((14, TOMATO), (44, (250, 210, 60, 255))):
        for a in range(5):
            ang = a * math.tau / 5
            d.ellipse([x + math.cos(ang) * 4 - 2.5, 8 + math.sin(ang) * 4 - 2.5, x + math.cos(ang) * 4 + 2.5, 8 + math.sin(ang) * 4 + 2.5], fill=c)
        d.ellipse([x - 2, 6, x + 2, 10], fill=(250, 240, 200, 255))
    d.line([(0, 1), (TILE, 1)], fill=shade(CRAYON_GREEN, -60), width=2)
    return img


# ------------------------------------------------------------------------- props


def build_hairdryer():
    """The hairdryer as Patch sees it from inside the book: a huge pink nozzle poking
    down over the page from the Margin, glowing orange inside."""
    w, h = 520, 440
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Barrel coming in from the top, tapering to the nozzle.
    crayon_poly(img, [(70, 0), (450, 0), (420, 200), (370, 300), (150, 300), (100, 200)], DRYER, width=8)
    crayon_poly(img, [(150, 290), (370, 290), (350, 370), (170, 370)], shade(DRYER, -24), width=7)
    # Vent slots down the barrel.
    for x in range(170, 360, 34):
        crayon_poly(img, [(x, 60), (x + 16, 60), (x + 14, 190), (x + 2, 190)], shade(DRYER, -70), width=3, shadow=False)
    # The nozzle mouth, with a grille and the hot glow inside.
    crayon_poly(img, ellipse_points(260, 372, 92, 30, 36), (60, 40, 50, 255), width=6)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([186, 350, 334, 394], fill=(255, 170, 70, 255))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
    for x in range(196, 330, 18):
        ink_line(img, [(x, 352), (x, 392)], width=3, wobble=0, color=(80, 60, 60, 255))
    # A strip of Dad's tape round the barrel: even the hairdryer has been mended.
    crayon_poly(img, [(96, 120), (424, 120), (420, 150), (100, 150)], (246, 230, 160, 220), width=3, smooth=False, shadow=False)
    paper_grain(img, 5).save(out("props", "hairdryer.png"))


def build_warm_beam():
    """The warm air from the hairdryer: a soft orange column with rising heat ripples.
    Drawn additively in the game, so black is see-through."""
    w, h = 360, 1024
    x = np.linspace(-1, 1, w, dtype=np.float32)[None, :]
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    across = np.clip(1 - x ** 2, 0, 1) ** 1.6
    ripple = 0.75 + 0.25 * np.sin(y * 40 + np.sin(x * 3) * 2) * np.sin(x * 9 + y * 6)
    strength = across * ripple * (0.55 + 0.45 * (1 - y))
    color = np.array([255, 170, 80], np.float32)[None, None, :] * strength[..., None]
    img = Image.fromarray(np.concatenate([np.clip(color, 0, 255), np.full((h, w, 1), 255, np.float32)], -1).astype(np.uint8), "RGBA")
    # A few drifting heat curls.
    d = ImageDraw.Draw(img)
    r = random.Random(52)
    for _ in range(18):
        cx, cy = r.uniform(80, 280), r.uniform(40, 980)
        pts = [(cx + math.sin(k * 0.6) * 10, cy - k * 7) for k in range(10)]
        d.line(pts, fill=(255, 220, 160, 255), width=3)
    img = img.filter(ImageFilter.GaussianBlur(2))
    img.save(out("props", "warm_beam.png"))


def build_gutter_gate():
    """A wall of soaked pages, swollen shut and tied with red binding thread."""
    w, h = 112, 330
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for k, x in enumerate(range(10, 100, 22)):
        part(img, [(x, 8 + k % 2 * 6), (x + 24, 4), (x + 26, h - 6), (x + 2, h - 10)], shade(SODDEN, -20 - k * 8), width=4, radius=8, seed=60 + k)
        ink_line(img, [(x + 12, 20), (x + 14, h - 30)], width=1.4, wobble=1.0, color=shade(SODDEN, -80))
    for y in (70, 250):
        ink_line(img, [(4, y), (w - 4, y + 6)], width=9, wobble=0.4, color=shade(THREAD, -60))
        ink_line(img, [(4, y), (w - 4, y + 6)], width=5, wobble=0.4, color=THREAD)
    for x, y in ((30, 160), (76, 120), (58, 300)):
        part(img, [(x - 7, y), (x, y - 18, 0), (x + 7, y), (x, y + 12)], (150, 196, 240, 255), width=2, radius=5)
    paper_grain(img, 5).save(out("props", "gutter_gate.png"))


# -------------------------------------------------------------------- characters


def build_drizzle():
    """Drizzle, dried out at last: a small, fluffy, embarrassed white cloud with
    sewn-on button eyes, pink cheeks and one last nervous raindrop. Drawn 2x."""
    w, h = 300, 260
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    blob(img, [(150, 130, 70), (90, 150, 50), (210, 150, 52), (115, 100, 52), (185, 98, 56), (150, 80, 44), (150, 168, 56)],
         DRIZZLE, width=6)
    stitches(img, [(96, 112), (130, 84), (170, 80), (206, 104)], color=(170, 196, 230, 255), step=10)
    for ex in (124, 176):
        button(img, ex, 136, 13, color=(70, 120, 200, 255))
    for cx in (100, 200):
        blush = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(blush).ellipse([cx - 20, 154, cx + 20, 172], fill=(250, 140, 160, 170))
        img.alpha_composite(blush.filter(ImageFilter.GaussianBlur(3)))
    # A small wobbly, sheepish smile.
    ink_line(img, [(136, 172), (144, 176), (150, 173), (156, 176), (164, 172)], width=2.4, wobble=0, color=(60, 70, 110, 255))
    # One nervous drop off her side.
    part(img, [(236, 196), (244, 176, 0), (252, 196), (244, 208)], (140, 190, 240, 255), width=3, radius=6)
    paper_grain(img, 4).save(out("characters", "drizzle.png"))


# ---------------------------------------------------------------------- backgrounds


def _gradient(w, h, top, bottom, power=1.0):
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None] ** power
    rgb = np.broadcast_to(np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t, (h, w, 3)).copy()
    return Image.fromarray(np.concatenate([rgb, np.full((h, w, 1), 255, np.float32)], -1).astype(np.uint8), "RGBA")


def build_gutter():
    """The Gutter: the drowned crease where the pages meet. Swollen page walls lean in
    from both sides, ink runs down them, lost printed words float in the dark, and far
    above, through the crack, the Great Light glows."""
    w, h = 1920, 1080
    r = random.Random(4040)
    img = _gradient(w, h, (92, 84, 96), (14, 18, 40), 0.7)
    facets(img, Image.new("L", (w, h), 255), 0.44, cell=200, wrap=True, strength=0.35)
    # The Great Light, far above.
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([560, -360, 1360, 260], fill=170)
    img = Image.composite(Image.new("RGBA", (w, h), (255, 200, 130, 255)), img, glow.filter(ImageFilter.GaussianBlur(120)))
    # Page bundles leaning in from both sides, layered, darker as they go back.
    for depth, tone in ((0, -10), (1, 10), (2, 26)):
        x = -40.0 + depth * 70
        k = 0
        while x < w + 40:
            bw = r.uniform(140, 220)
            lean = r.uniform(-60, 60)
            top = r.uniform(80, 260) + depth * 90
            color = shade(SOAKED, tone + r.randint(-10, 10))
            pts = [(x, h + 20), (x + lean, top + 20), (x + bw * 0.5 + lean, top), (x + bw + lean, top + 18), (x + bw, h + 20)]
            paper_layer(img, pts, color, 4100 + depth * 50 + k, cell=80, strength=0.6, shadow=(10, 0))
            for yy in range(int(top) + 40, h, 18):
                fx = (yy - top) / (h - top)
                ink_line(img, [(x + 14 + lean * (1 - fx), yy), (x + bw - 14 + lean * (1 - fx), yy + r.uniform(-3, 3))],
                         width=0.9, wobble=0.5, color=shade(color, -22))
            # Ink running down the sodden pages.
            for _ in range(2):
                sx = x + r.uniform(20, bw - 20)
                sy = top + r.uniform(40, 200)
                ink_line(img, [(sx, sy), (sx + r.uniform(-6, 6), sy + r.uniform(120, 360))], width=r.uniform(3, 7), wobble=1.4,
                         color=(30, 34, 80, 160))
            x += bw * 0.8
            k += 1
        # A haze between the layers.
        haze = Image.new("RGBA", (w, h), (20, 26, 60, 60))
        img.alpha_composite(haze)
    # Lost printed words, floating: torn scraps of type in the dark.
    d = ImageDraw.Draw(img)
    for _ in range(26):
        x, y = r.uniform(40, w - 40), r.uniform(280, h - 260)
        sw, sh = r.uniform(40, 90), r.uniform(18, 30)
        ang = r.uniform(-0.4, 0.4)
        c, s = math.cos(ang), math.sin(ang)
        pts = [(x + px * c - py * s, y + px * s + py * c) for px, py in ((-sw, -sh), (sw, -sh), (sw, sh), (-sw, sh))]
        crayon_poly(img, deckle(pts, int(x), step=8, amount=2), (200, 196, 180, 255), width=2, smooth=False)
        for k in range(3):
            lx = -sw * 0.7 + k * sw * 0.5
            a = (x + lx * c, y + lx * s)
            b = (x + (lx + sw * 0.35) * c, y + (lx + sw * 0.35) * s)
            ink_line(img, [a, b], width=4, wobble=0.4, color=(50, 50, 70, 255))
    # Black water pooling across the bottom, catching the light.
    water = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wd = ImageDraw.Draw(water)
    wd.rectangle([0, h - 160, w, h], fill=(12, 16, 38, 230))
    for _ in range(40):
        x, y = r.uniform(0, w), r.uniform(h - 150, h - 10)
        wd.line([(x, y), (x + r.uniform(30, 90), y)], fill=(255, 210, 150, 90), width=2)
    img.alpha_composite(water)
    paper_grain(img, 6).convert("RGB").save(out("backgrounds", "bg_gutter.png"))


def _table_room(w, h, wall, glow_box, glow_amount, glow_color=(255, 214, 150, 255)):
    img = Image.new("RGBA", (w, h), wall)
    crayon_poly(img, [(0, 640), (w, 600), (w, h), (0, h)], shade(WOOD, -20), width=8)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse(glow_box, fill=glow_amount)
    return Image.composite(Image.new("RGBA", (w, h), glow_color), img, glow.filter(ImageFilter.GaussianBlur(150)))


def _lamp(img):
    crayon_poly(img, [(840, 0), (860, 0), (860, 150), (840, 150)], INK, outline=False)
    crayon_poly(img, [(740, 150), (960, 150), (1010, 280), (690, 280)], MARIGOLD, width=7)


def _open_book(img, left_tone=(244, 240, 226, 255), right_tone=(240, 236, 222, 255), taped=True):
    crayon_poly(img, [(560, 780), (900, 750), (900, 900), (560, 930)], left_tone, width=6)
    crayon_poly(img, [(920, 750), (1260, 780), (1260, 930), (920, 900)], right_tone, width=6)
    ink_line(img, [(900, 744), (910, 820), (902, 900)], width=4, wobble=1.0, color=(90, 60, 50, 255))
    if taped:
        for x, y in ((620, 800), (860, 770), (1000, 790), (1180, 830)):
            crayon_poly(img, [(x, y), (x + 70, y - 6), (x + 72, y + 16), (x + 2, y + 22)], (246, 230, 160, 220), width=2, smooth=False, shadow=False)


def _person(img, cx, base, height, shirt, hair, skin=SKIN, hair_style="short", arm=None, mouth="smile", glasses=False):
    """A cut-paper person from the waist up, sitting or standing at the table, in the
    same papercraft style as the cast: faceted paper parts edged in a darker shade,
    stitched seams and sewn-on button eyes."""
    s = height / 380.0
    top = base - height
    hy = top + 80 * s
    hw, hh = 70 * s, 76 * s
    sh = top + 44 * s  # where the shoulders start, below the big chibi head
    seed = int(cx * 7 + base)
    # Long hair hangs behind the shoulders, so it goes down first.
    if hair_style == "long":
        part(img, [(cx - hw - 8 * s, hy - 10 * s), (cx - hw + 4 * s, hy - hh - 4 * s), (cx + hw - 4 * s, hy - hh - 4 * s),
                   (cx + hw + 8 * s, hy - 10 * s), (cx + hw + 14 * s, hy + 120 * s), (cx + hw - 8 * s, hy + 134 * s, 0),
                   (cx - hw + 8 * s, hy + 134 * s, 0), (cx - hw - 14 * s, hy + 120 * s)], hair, width=5, radius=40 * s, seed=seed)
    # Body: rounded shoulders down to the table edge, with a collar and a stitched placket.
    body = [(cx - 92 * s, base, 0), (cx - 88 * s, sh + 150 * s), (cx - 60 * s, sh + 122 * s), (cx, sh + 112 * s),
            (cx + 60 * s, sh + 122 * s), (cx + 88 * s, sh + 150 * s), (cx + 92 * s, base, 0)]
    part(img, body, shirt, width=6, radius=26 * s, seed=seed + 1)
    part(img, [(cx - 14 * s, hy + 40 * s), (cx + 14 * s, hy + 40 * s), (cx + 16 * s, sh + 124 * s), (cx - 16 * s, sh + 124 * s)],
         shade(skin, -14), width=3, radius=6 * s, shadow=False, seed=seed + 2)
    collar = shade(shirt, 28)
    part(img, [(cx - 40 * s, sh + 116 * s), (cx - 2 * s, sh + 122 * s), (cx - 12 * s, sh + 150 * s, 0)], collar, width=3, radius=5 * s, seed=seed + 3)
    part(img, [(cx + 40 * s, sh + 116 * s), (cx + 2 * s, sh + 122 * s), (cx + 12 * s, sh + 150 * s, 0)], collar, width=3, radius=5 * s, seed=seed + 4)
    stitches(img, [(cx, sh + 152 * s), (cx, base - 10)], color=shade(shirt, 50), step=12 * s, size=3 * s)
    stitches(img, [(cx - 70 * s, sh + 140 * s), (cx - 58 * s, base - 10)], color=shade(shirt, 40), step=12 * s, size=2.5 * s)
    # Head, with ears.
    for ex in (cx - hw + 2 * s, cx + hw - 2 * s):
        crayon_poly(img, ellipse_points(ex, hy + 6 * s, 10 * s, 14 * s, 14), skin, width=3)
    part(img, [(cx - hw, hy - 18 * s), (cx - hw * 0.62, hy - hh), (cx + hw * 0.62, hy - hh), (cx + hw, hy - 18 * s),
               (cx + hw * 0.86, hy + hh * 0.62), (cx, hy + hh), (cx - hw * 0.86, hy + hh * 0.62)], skin, width=5, radius=22 * s, seed=seed + 5)
    # Hair on top.
    if hair_style == "bun":
        part(img, [(cx - 24 * s, hy - hh - 22 * s), (cx + 24 * s, hy - hh - 22 * s), (cx + 22 * s, hy - hh + 8 * s), (cx - 22 * s, hy - hh + 8 * s)],
             hair, width=4, radius=14 * s, seed=seed + 6)
        part(img, [(cx - hw - 4 * s, hy - 4 * s), (cx - hw + 6 * s, hy - hh + 2 * s), (cx + hw - 6 * s, hy - hh + 2 * s), (cx + hw + 4 * s, hy - 4 * s),
                   (cx + hw - 10 * s, hy - 26 * s, 0), (cx - hw + 10 * s, hy - 26 * s, 0)], hair, width=4, radius=40 * s, seed=seed + 7)
    elif hair_style == "long":
        part(img, [(cx - hw - 6 * s, hy + 10 * s), (cx - hw + 2 * s, hy - hh), (cx + hw - 2 * s, hy - hh), (cx + hw + 6 * s, hy + 10 * s),
                   (cx + hw - 8 * s, hy - 22 * s, 0), (cx + 4 * s, hy - 30 * s, 0), (cx - hw + 8 * s, hy - 18 * s, 0)], hair, width=4, radius=40 * s, seed=seed + 8)
    else:
        part(img, [(cx - hw - 4 * s, hy - 6 * s), (cx - hw + 4 * s, hy - hh - 2 * s), (cx + hw - 4 * s, hy - hh - 2 * s), (cx + hw + 4 * s, hy - 6 * s),
                   (cx + hw - 8 * s, hy - 30 * s, 0), (cx - 6 * s, hy - 36 * s, 0), (cx - hw + 8 * s, hy - 26 * s, 0)], hair, width=4, radius=40 * s, seed=seed + 9)
    # Face: button eyes, rosy cheeks and a mouth.
    for ex in (cx - 26 * s, cx + 26 * s):
        button(img, ex, hy + 2 * s, 12 * s, color=(36, 52, 132, 255))
        crayon_poly(img, ellipse_points(ex + (8 if ex > cx else -8) * s, hy + 22 * s, 9 * s, 6 * s, 14), (236, 140, 140, 150), outline=False, shadow=False)
    if glasses:
        d = ImageDraw.Draw(img)
        for ex in (cx - 26 * s, cx + 26 * s):
            d.ellipse([ex - 19 * s, hy - 17 * s, ex + 19 * s, hy + 21 * s], outline=(232, 200, 120, 255), width=max(2, int(3 * s)))
        ink_line(img, [(cx - 7 * s, hy + 2 * s), (cx + 7 * s, hy + 2 * s)], width=2.5 * s, wobble=0, color=(232, 200, 120, 255))
    lip = (150, 60, 66, 255)
    if mouth == "laugh":
        part(img, [(cx - 16 * s, hy + 28 * s), (cx + 16 * s, hy + 28 * s), (cx, hy + 46 * s)], lip, width=3, radius=6 * s, shadow=False, seed=seed + 10)
    elif mouth == "flat":
        ink_line(img, [(cx - 10 * s, hy + 34 * s), (cx + 10 * s, hy + 34 * s)], width=3 * s, wobble=0, color=lip)
    else:
        ink_line(img, [(cx - 12 * s, hy + 30 * s), (cx, hy + 36 * s), (cx + 12 * s, hy + 30 * s)], width=3 * s, wobble=0, color=lip)
    if arm:
        part(img, arm, shirt, width=5, radius=12 * s, seed=seed + 11)
        hx = (arm[2][0] + arm[3][0]) / 2
        hy2 = (arm[2][1] + arm[3][1]) / 2
        crayon_poly(img, ellipse_points(hx, hy2, 20 * s, 18 * s, 18), skin, width=4)


def build_nell_dryer():
    """Interlude 4: Nell at the table in the middle of the night, plugging in the
    hairdryer and pointing it at the book. Gran watches from her chair."""
    w, h = 1920, 1080
    img = _table_room(w, h, (34, 30, 48, 255), [460, 160, 1360, 1040], 140)
    _lamp(img)
    # Gran in her chair on the left, with her glued-together mug.
    crayon_poly(img, [(150, 360), (380, 360), (400, 700), (130, 700)], (120, 80, 120, 255), width=6)
    _person(img, 265, 700, 300, (150, 110, 170, 255), (220, 220, 230, 255), hair_style="bun", glasses=True)
    crayon_poly(img, [(400, 600), (460, 600), (456, 680), (404, 680)], (240, 236, 220, 255), width=5)
    for y in (620, 640, 660):
        ink_line(img, [(406, y), (452, y + 6)], width=1.6, wobble=0.6, color=(200, 160, 60, 255))
    _open_book(img)
    # Nell standing over the book, hairdryer in both hands.
    _person(img, 1220, 760, 420, NELL, HAIR, hair_style="long", mouth="flat",
            arm=[(1170, 540), (1120, 590), (1080, 630), (1110, 660), (1170, 620), (1230, 560)])
    crayon_poly(img, [(960, 560), (1120, 520), (1140, 600), (980, 640)], DRYER, width=6)
    crayon_poly(img, [(1080, 600), (1120, 600), (1130, 700), (1090, 700)], DRYER, width=5)
    crayon_poly(img, ellipse_points(960, 600, 20, 40, 20), (60, 40, 50, 255), width=4)
    # Warm air rolling over the book.
    air = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ad = ImageDraw.Draw(air)
    for k in range(5):
        y0 = 600 + k * 30
        ad.line([(940 - j * 30, y0 + j * 26 + math.sin(j + k) * 10) for j in range(10)], fill=(255, 190, 110, 150), width=6)
    img.alpha_composite(air.filter(ImageFilter.GaussianBlur(4)))
    # The cord running to the plug, plugged into the wall at last.
    ink_line(img, [(1110, 700), (1240, 880), (1520, 940), (1700, 900), (1760, 720)], width=5, wobble=0.8, color=(60, 60, 70, 255))
    crayon_poly(img, [(1730, 640), (1800, 640), (1800, 720), (1730, 720)], (236, 232, 220, 255), width=4)
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_nell_dryer.png"))


def build_morning_table():
    """The ending: morning sun through the window. The book is open between them,
    lumpy and taped and a little warped, with Nell's crayon page in the middle. Dad,
    Nell and Gran are laughing."""
    w, h = 1920, 1080
    img = _table_room(w, h, (246, 210, 150, 255), [200, 0, 1720, 900], 120, glow_color=(255, 244, 210, 255))
    # The window, with morning light.
    crayon_poly(img, [(1300, 80), (1700, 80), (1700, 460), (1300, 460)], (180, 220, 250, 255), width=8, smooth=False)
    ink_line(img, [(1500, 80), (1500, 460)], width=8, wobble=0, color=(150, 100, 70, 255))
    ink_line(img, [(1300, 270), (1700, 270)], width=8, wobble=0, color=(150, 100, 70, 255))
    crayon_poly(img, ellipse_points(1600, 170, 40, 40, 24), (255, 236, 140, 255), width=3)
    # Dad, Nell and Gran round the table, laughing.
    _person(img, 360, 700, 380, (110, 120, 150, 255), (96, 70, 56, 255), mouth="laugh",
            arm=[(420, 520), (520, 600), (600, 690), (560, 710), (480, 640), (400, 580)])
    _person(img, 960, 660, 360, NELL, HAIR, hair_style="long", mouth="laugh")
    _person(img, 1520, 700, 330, (150, 110, 170, 255), (220, 220, 230, 255), hair_style="bun", mouth="laugh", glasses=True)
    # The mended book, lumpy and proud.
    crayon_poly(img, [(600, 760), (940, 720), (950, 900), (590, 940)], (250, 244, 226, 255), width=6)
    crayon_poly(img, [(960, 724), (1320, 770), (1320, 940), (960, 900)], LEMON, width=6)
    for x, y in ((630, 790), (880, 760), (1000, 760), (1240, 800), (760, 880)):
        crayon_poly(img, [(x, y), (x + 70, y - 6), (x + 72, y + 16), (x + 2, y + 22)], (246, 230, 160, 230), width=2, smooth=False, shadow=False)
    # Nell's crayon drawing on the right page: a sun, a hill, a fox with a striped tail.
    crayon_poly(img, ellipse_points(1250, 800, 26, 26, 20), (255, 180, 40, 255), width=3)
    crayon_poly(img, [(980, 900), (1080, 830), (1200, 860), (1310, 910)], CRAYON_GREEN, width=3)
    crayon_poly(img, [(1090, 850), (1130, 820), (1160, 850), (1140, 870), (1100, 870)], (238, 120, 40, 255), width=3)
    crayon_poly(img, [(1090, 856), (1040, 830), (1030, 800), (1060, 820)], (240, 222, 168, 255), width=3)
    # Crayons scattered on the table and Gran's mug with its glue lines.
    for k, (x, c) in enumerate(((700, TOMATO), (760, (70, 130, 200, 255)), (820, CRAYON_GREEN), (1400, (255, 200, 40, 255)))):
        crayon_poly(img, [(x, 980 + k * 6), (x + 90, 960 + k * 6), (x + 94, 976 + k * 6), (x + 4, 996 + k * 6)], c, width=3)
    crayon_poly(img, [(1640, 820), (1720, 820), (1714, 920), (1646, 920)], (240, 236, 220, 255), width=5)
    for y in (840, 870, 896):
        ink_line(img, [(1648, y), (1712, y + 8)], width=2, wobble=0.6, color=(200, 160, 60, 255))
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_morning_table.png"))


def build_nell_page():
    """The new page Nell drew for the book, in crayon on lemon paper: a big sun, a sky
    full of scribbled clouds (one of them smiling), hills, and taped seams she left
    showing on purpose."""
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), LEMON)
    facets(img, Image.new("L", (w, h), 255), 0.5, cell=220, wrap=True, strength=0.25)
    r = random.Random(77)
    d = ImageDraw.Draw(img)
    # Sky scribble: loose blue crayon strokes across the top.
    for _ in range(2600):
        x, y = r.uniform(-20, w), r.uniform(-10, 620 + r.uniform(-60, 60))
        a = -0.4 + r.uniform(-0.2, 0.2)
        ln = r.uniform(20, 46)
        d.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], fill=(110, 170, 236, r.randint(60, 150)), width=4)
    # The sun, with wobbly rays.
    for k in range(12):
        ang = k * math.tau / 12
        d.line([(300 + math.cos(ang) * 120, 200 + math.sin(ang) * 120), (300 + math.cos(ang) * 190, 200 + math.sin(ang) * 190)],
               fill=(255, 170, 40, 255), width=10)
    for _ in range(500):
        a, rr = r.uniform(0, math.tau), r.uniform(0, 100)
        x, y = 300 + math.cos(a) * rr, 200 + math.sin(a) * rr
        d.line([(x, y), (x + 14, y - 6)], fill=(255, 196, 40, 220), width=5)
    # Clouds, one of them Drizzle with a smile.
    for cx, cy, s, face in ((900, 200, 1.0, True), (1450, 140, 0.8, False), (1700, 330, 0.6, False)):
        for dx, dy, rr in ((-60, 10, 50), (0, -20, 64), (60, 6, 52), (0, 24, 50)):
            for _ in range(int(160 * s)):
                a, q = r.uniform(0, math.tau), r.uniform(0, rr * s)
                x, y = cx + dx * s + math.cos(a) * q, cy + dy * s + math.sin(a) * q
                d.line([(x, y), (x + 10, y - 3)], fill=(255, 255, 255, 220), width=4)
        if face:
            for ex in (cx - 24, cx + 24):
                d.ellipse([ex - 7, cy - 6, ex + 7, cy + 8], fill=(70, 120, 200, 255))
            d.arc([cx - 24, cy + 4, cx + 24, cy + 34], 20, 160, fill=(70, 70, 110, 255), width=4)
    # Rolling crayon hills.
    for base, color, phase in ((760, (130, 200, 100, 255), 0.3), (860, CRAYON_GREEN, 1.7)):
        pts = [(x, base - 90 * math.sin(x / 520 + phase) - 40 * math.sin(x / 210 + phase * 2)) for x in range(-20, w + 40, 20)]
        poly = pts + [(w + 40, h + 20), (-20, h + 20)]
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for _ in range(9000):
            x, y = r.uniform(-20, w), r.uniform(base - 160, h)
            ld.line([(x, y), (x + 18, y - 9)], fill=shade(color, r.randint(-30, 20))[:3] + (200,), width=5)
        img.paste(layer, (0, 0), Image.fromarray((np.asarray(mask) * (np.asarray(layer.split()[3]) > 0)).astype(np.uint8)))
        ink_line(img, pts, width=4, wobble=1.0, color=shade(color, -80))
    # Two long strips of tape where she joined the page to the book, shown proudly.
    for x0, x1 in ((600, 690), (1300, 1220)):
        strip = [(x0 - 36, -20), (x0 + 36, -20), (x1 + 36, h + 20), (x1 - 36, h + 20)]
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(strip, fill=(250, 240, 200, 120))
        img.alpha_composite(layer)
        ink_line(img, [strip[0], strip[3]], width=1.6, wobble=0.4, color=(210, 190, 130, 255))
        ink_line(img, [strip[1], strip[2]], width=1.6, wobble=0.4, color=(210, 190, 130, 255))
    paper_grain(img, 6).convert("RGB").save(out("backgrounds", "bg_nell_page.png"))


def tiles():
    """The finale tiles, in atlas order: row 5."""
    return [tile_gutter_top, tile_gutter_fill, tile_crayon_top, tile_crayon_fill]


def build():
    build_hairdryer()
    build_warm_beam()
    build_gutter_gate()
    build_drizzle()
    build_gutter()
    build_nell_dryer()
    build_morning_table()
    build_nell_page()
