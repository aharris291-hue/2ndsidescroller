"""Chapter 3 art: the Spine Peaks. The winter page (Frostfold), the book's stitched
spine, the paperclip heist, Old Bindwell, and the Sogg itself.

Same papercraft style as the rest of the book: torn coloured paper with a white
fibre rim, edges in a deep shade of their own colour, folded facets, running
stitches and sewn-on button eyes. Built by generate_art.py; to regenerate only
this chapter:

    python3 tools/art/generate_art.py chapter3
"""

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from character_art import button, organic, part, stitches
from generate_art import (INK, MARIGOLD, TILE, TOMATO, WOOD, blob, crayon_poly, edge_color, ellipse_points, facets, ink_line,
                          out, paper_grain, shade)
from page_art import (TORN_EDGE, _ridge, _ridge_y, _shadowed, deckle, fold_tile, mottle, paper_layer)

rng = random.Random(1203)

SNOW = (244, 248, 255, 255)
SNOW_SHADE = (198, 214, 240, 255)
FROST_ROCK = (124, 140, 176, 255)
ICE = (168, 214, 240, 255)
PINE = (54, 120, 110, 255)
THREAD = (214, 64, 70, 255)
LINEN = (232, 220, 190, 255)
NIGHT = (34, 40, 84, 255)
STEEL = (196, 206, 222, 255)
SOGG = (120, 140, 178, 255)
DRIZZLE = (214, 232, 250, 255)
BRASS = (236, 186, 70, 255)


# ------------------------------------------------------------------------- tiles


def _rock(seed):
    img = mottle(FROST_ROCK, TILE, seed, blur=4, amount=34)
    d = ImageDraw.Draw(img)
    r = random.Random(seed)
    # Folded-paper strata and a few frost flecks, wrapping at the edges.
    for y0, tone in ((16, -24), (38, 18), (54, -14)):
        pts = [(x, y0 + math.sin(x / TILE * math.tau + seed) * 3) for x in range(0, TILE + 1, 4)]
        d.line(pts, fill=shade(FROST_ROCK, tone)[:3] + (120,), width=3)
    for _ in range(5):
        x, y = r.uniform(4, 60), r.uniform(4, 60)
        d.line([(x - 2, y), (x + 2, y)], fill=(236, 244, 255, 200), width=1)
        d.line([(x, y - 2), (x, y + 2)], fill=(236, 244, 255, 200), width=1)
    return fold_tile(img, seed / 100)


def tile_snow_fill():
    return _rock(91)


def tile_snow_top():
    """Frozen rock under a torn strip of white snow paper with a soft blue underside."""
    img = _rock(92)
    edge = [(x, 24 + 2.6 * math.sin(x / TILE * math.tau * 2) + 1.6 * math.sin(x / TILE * math.tau * 5 + 1.0)
             + 0.8 * math.sin(x / TILE * math.tau * 11 + 2.0)) for x in range(0, TILE + 1, 2)]
    snow = [(0, 0), (TILE, 0)] + edge[::-1]
    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).polygon(snow, fill=255)
    shadow = Image.new("L", (TILE, TILE), 0)
    shadow.paste(mask, (0, 3))
    arr = np.asarray(img).astype(np.float32)
    arr[..., :3] *= 1.0 - 0.32 * (np.asarray(shadow.filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32)[..., None] / 255.0)
    img = Image.fromarray(arr.astype(np.uint8))
    under = mask.filter(ImageFilter.MaxFilter(5))
    img.paste(SNOW_SHADE, (0, 0), under)
    img.paste(mottle(SNOW, TILE, 93, blur=3, amount=8, fine=5), (0, 0), mask)
    facets(img, mask, 0.93, cell=18, wrap=True, strength=0.8)
    d = ImageDraw.Draw(img)
    for x, y in ((12, 10), (40, 14), (54, 6)):
        d.line([(x - 2, y), (x + 2, y)], fill=SNOW_SHADE, width=1)
    ink_line(img, [(-4, 1.5), (TILE + 4, 1.5)], width=2.2, wobble=0, color=edge_color(SNOW_SHADE))
    return img


def tile_thread_bridge():
    """A rope bridge of bookbinding thread with paper slats: Patch can jump up through it."""
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(4):
        x0 = i * 16 + 1
        tone = shade(LINEN, [6, -10, 2, -16][i])
        d.rectangle([x0, 6, x0 + 13, 22], fill=tone)
        d.line([(x0, 6), (x0 + 13, 6)], fill=shade(tone, 24), width=1)
        d.line([(x0, 22), (x0 + 13, 22)], fill=shade(tone, -50), width=1)
    # Two twisted red threads running through the slats.
    for y in (8, 20):
        for x in range(0, TILE, 6):
            d.line([(x, y - 2), (x + 5, y + 2)], fill=THREAD, width=2)
            d.line([(x + 3, y - 2), (x + 3, y + 2)], fill=shade(THREAD, -60), width=1)
    return fold_tile(img, 0.44, cell=16, strength=0.6)


def tile_ice():
    """A block of glassy ice paper: cracked, glinting, solid."""
    img = mottle(ICE, TILE, 95, blur=6, amount=22, fine=4)
    d = ImageDraw.Draw(img)
    for pts in (((6, 10), (20, 24), (18, 40)), ((40, 4), (34, 22), (52, 36), (50, 58))):
        d.line(pts, fill=(250, 254, 255, 230), width=1)
    d.line([(10, 52), (26, 50)], fill=(255, 255, 255, 220), width=2)
    d.line([(44, 12), (58, 10)], fill=(255, 255, 255, 220), width=2)
    return fold_tile(img, 0.95, cell=22, strength=1.1)


def tile_snowfield():
    """The winter page laid flat: crisp snow with a few footprint dimples."""
    img = mottle(SNOW, TILE, 96, blur=5, amount=10, fine=5)
    d = ImageDraw.Draw(img)
    r = random.Random(96)
    for _ in range(4):
        x, y = r.uniform(6, 58), r.uniform(6, 58)
        d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=SNOW_SHADE)
    return fold_tile(img, 0.96, cell=32, strength=0.7)


def tile_drift():
    """A snowdrift seen from above, with little paper pines poking out: a wall."""
    img = mottle(SNOW_SHADE, TILE, 97, blur=4, amount=16)
    d = ImageDraw.Draw(img)
    for cx, cy, s in ((18, 20, 11), (46, 44, 12), (50, 14, 8), (16, 50, 8)):
        for k, tone in ((1.0, -30), (0.62, 0)):
            pts = [(cx + math.cos(a / 6 * math.tau) * s * k, cy + math.sin(a / 6 * math.tau) * s * k) for a in range(6)]
            d.polygon(pts, fill=shade(PINE, tone))
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=SNOW)
    return fold_tile(img, 0.97, cell=20)


# ------------------------------------------------------------------------- props


def build_fold_mark():
    """A printed dashed fold line on the ground with a little up-arrow: slam here and
    the pop-up behind it springs up."""
    img = Image.new("RGBA", (160, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(8, 152, 18):
        d.rounded_rectangle([x, 36, x + 10, 42], 2, fill=shade(THREAD, -20))
    crayon_poly(img, [(68, 32), (80, 6), (92, 32), (84, 32), (84, 34), (76, 34), (76, 32)], MARIGOLD, width=3, smooth=False)
    paper_grain(img, 4).save(out("props", "fold_mark.png"))


def build_popup_peak():
    """A pop-up paper mountain: a snow-capped peak on a folded cardboard hinge.
    Its flat top is the platform Patch stands on."""
    w, h = 240, 320
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    crayon_poly(img, [(14, 300), (226, 300), (232, 318), (8, 318)], shade(WOOD, -10), width=4, smooth=False)
    body = [(20, 300), (52, 40), (188, 40), (220, 300)]
    crayon_poly(img, body, FROST_ROCK, width=6, smooth=False)
    crayon_poly(img, [(120, 40), (188, 40), (220, 300), (120, 300)], shade(FROST_ROCK, -26), width=0.1, outline=False)
    crayon_poly(img, [(48, 36), (192, 36), (180, 92), (150, 74), (124, 104), (96, 76), (66, 96)], SNOW, width=5, smooth=False)
    stitches(img, [(40, 140), (200, 140)], color=(236, 226, 196, 255), step=12)
    for x, y in ((80, 200), (150, 240), (110, 170)):
        crayon_poly(img, [(x - 14, y + 12), (x, y - 16), (x + 14, y + 12)], PINE, width=2.5, smooth=False)
    paper_grain(img, 5).save(out("props", "popup_peak.png"))


def build_spool():
    """A wooden spool wound with red bookbinding thread (Bindwell's quest)."""
    img = Image.new("RGBA", (96, 104), (0, 0, 0, 0))
    crayon_poly(img, [(14, 10), (82, 10), (82, 24), (14, 24)], shade(WOOD, 20), width=4, smooth=False)
    crayon_poly(img, [(14, 80), (82, 80), (82, 94), (14, 94)], shade(WOOD, 20), width=4, smooth=False)
    crayon_poly(img, [(24, 24), (72, 24), (72, 80), (24, 80)], THREAD, width=4, smooth=False)
    for y in range(30, 78, 7):
        ink_line(img, [(26, y), (70, y + 3)], width=1.4, wobble=0, color=shade(THREAD, -50))
    ink_line(img, [(72, 60), (88, 70), (84, 98)], width=2, wobble=0.5, color=THREAD)
    paper_grain(img, 5).save(out("props", "spool.png"))


def build_paperclip():
    """A real steel paperclip from Gran's table (big, because Patch is small)."""
    ss = 4
    w, h = 220, 90
    big = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)

    def loop(x0, y0, x1, y1, color, width):
        r = (y1 - y0) / 2
        d.arc([x0 * ss, y0 * ss, (x0 + 2 * r) * ss, y1 * ss], 90, 270, fill=color, width=width * ss)
        d.arc([(x1 - 2 * r) * ss, y0 * ss, x1 * ss, y1 * ss], 270, 90, fill=color, width=width * ss)
        d.line([((x0 + r) * ss, y0 * ss), ((x1 - r) * ss, y0 * ss)], fill=color, width=width * ss)

    for color, width in ((INK, 11), (STEEL, 6)):
        loop(10, 10, 210, 80, color, width)
        loop(30, 24, 186, 66, color, width)
    d2 = ImageDraw.Draw(big)
    d2.line([(40 * ss, 14 * ss), (180 * ss, 14 * ss)], fill=(250, 252, 255, 255), width=2 * ss)
    img = big.resize((w, h), Image.LANCZOS)
    paper_grain(img, 3).save(out("props", "paperclip.png"))


def build_piton():
    """A paperclip bent into a hook and pushed into the spine: the Tape Tail sticks to it."""
    ss = 4
    big = Image.new("RGBA", (80 * ss, 96 * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for color, width in ((INK, 13), (STEEL, 7)):
        d.line([(40 * ss, 0), (40 * ss, 30 * ss)], fill=color, width=width * ss)
        d.ellipse([12 * ss, 28 * ss, 68 * ss, 84 * ss], outline=color, width=width * ss)
    d.arc([18 * ss, 34 * ss, 62 * ss, 78 * ss], 200, 280, fill=(255, 255, 255, 255), width=3 * ss)
    img = big.resize((80, 96), Image.LANCZOS)
    paper_grain(img, 3).save(out("props", "piton.png"))


def build_plug():
    """The hairdryer's plug: brass prongs, a white body and a long cord."""
    img = Image.new("RGBA", (180, 120), (0, 0, 0, 0))
    ink_line(img, [(80, 70), (60, 96), (20, 104), (4, 90)], width=7, wobble=0.5, color=(60, 60, 70, 255))
    for y in (34, 62):
        crayon_poly(img, [(140, y), (176, y), (176, y + 12), (140, y + 12)], BRASS, width=3, smooth=False)
    crayon_poly(img, [(70, 20), (144, 22), (144, 92), (70, 94)], (240, 240, 236, 255), width=5)
    for y in (40, 56, 72):
        ink_line(img, [(80, y), (130, y)], width=1.5, wobble=0, color=(190, 190, 196, 255))
    paper_grain(img, 3).save(out("props", "plug.png"))


def build_campfire():
    """A little paper campfire: cut-paper flames on a ring of grey paper stones."""
    img = Image.new("RGBA", (160, 140), (0, 0, 0, 0))
    for i, x in enumerate(range(24, 140, 22)):
        crayon_poly(img, ellipse_points(x, 122, 14, 10, 14), shade(FROST_ROCK, -10 + i * 6), width=3)
    crayon_poly(img, [(40, 110), (80, 10), (120, 110)], TOMATO, width=4, smooth=True)
    crayon_poly(img, [(56, 112), (82, 40), (106, 112)], MARIGOLD, width=3, smooth=True)
    crayon_poly(img, [(70, 112), (82, 74), (94, 112)], (255, 236, 150, 255), width=2, smooth=True)
    paper_grain(img, 4).save(out("props", "campfire.png"))


# ---------------------------------------------------------------------- characters


def build_bindwell():
    """Old Bindwell: the bookbinder's needle who keeps the spine stitched. A tall
    steel needle with a red thread scarf, wire spectacles over button eyes, and a
    thimble hat. Drawn at 2x."""
    w, h = 200, 420
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Thread trailing from the needle's eye down around her like a long scarf.
    ink_line(img, [(118, 70), (150, 120), (140, 220), (164, 330), (140, 404)], width=6, wobble=0.6, color=THREAD)
    # The needle body: a long tapering steel blade with a point at the bottom.
    blade = [(84, 54), (116, 54), (114, 340), (100, 412, 0), (86, 340)]
    part(img, blade, STEEL, width=5, radius=14)
    ink_line(img, [(94, 70), (92, 330)], width=2.2, wobble=0, color=(250, 252, 255, 255))
    # The eye of the needle at the top, with the thread through it.
    part(img, ellipse_points(100, 40, 20, 34, 28), STEEL, width=5, radius=6)
    part(img, ellipse_points(100, 40, 7, 22, 20), (40, 34, 52, 255), width=2, radius=4, shadow=False)
    ink_line(img, [(96, 30), (118, 70)], width=4, wobble=0, color=THREAD)
    # Thimble hat.
    part(img, [(72, 8), (128, 8), (132, 30), (68, 30)], BRASS, width=4, radius=8)
    d = ImageDraw.Draw(img)
    for x in range(80, 124, 8):
        for y in (14, 22):
            d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=shade(BRASS, -60))
    # Face: button eyes behind wire spectacles, a small kind mouth.
    for ex in (88, 112):
        button(img, ex, 126, 10, color=(40, 120, 110, 255))
        ink_line(img, ellipse_points(ex, 126, 15, 14, 24), width=1.6, wobble=0, closed=True, color=(70, 60, 64, 255))
    ink_line(img, [(103, 126), (97, 126)], width=1.6, wobble=0, color=(70, 60, 64, 255))
    ink_line(img, [(92, 156), (100, 161), (108, 156)], width=2, wobble=0, color=(70, 60, 64, 255))
    # Scarf wrap around the "neck".
    part(img, [(76, 176), (124, 172), (128, 196), (72, 200)], THREAD, width=4, radius=8)
    stitches(img, [(80, 186), (120, 184)], color=(250, 230, 200, 255), step=8, size=2.5)
    # Thin wire arms holding a tiny spool.
    for side in (-1, 1):
        ink_line(img, [(100 + side * 14, 210), (100 + side * 46, 250), (100 + side * 40, 280)], width=3, wobble=0, color=(90, 96, 110, 255))
    part(img, [(126, 274), (154, 274), (154, 296), (126, 296)], THREAD, width=3, radius=3)
    paper_grain(img, 4).save(out("characters", "bindwell.png"))


def build_sogg():
    """The Sogg: a swollen storm cloud of soaked, crumpled paper, sagging with water,
    with the torn remains of the Weather Page's printing on it, two glaring eyes and a
    wide ragged mouth. Inside its chest, if you look, is a small pale cloud: Drizzle."""
    w, h = 700, 560
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Dripping skirt of soaked paper tatters hanging under the cloud.
    r = random.Random(77)
    for x in range(110, 600, 44):
        length = r.uniform(80, 150)
        part(img, [(x - 20, 380), (x + 20, 380), (x + 8, 380 + length), (x, 380 + length + 18, 0), (x - 8, 380 + length)],
             shade(SOGG, -40), width=4, radius=8)
    lobes = [(350, 280, 190), (190, 320, 130), (520, 320, 130), (260, 180, 130), (450, 180, 136), (350, 130, 120),
             (110, 380, 80), (600, 380, 80), (350, 390, 150)]
    blob(img, lobes, SOGG, width=8)
    # Smeared printing from the Weather Page: little suns and rain marks, runny.
    d = ImageDraw.Draw(img)
    for x, y in ((180, 250), (520, 230), (420, 400), (240, 400)):
        d.ellipse([x - 18, y - 18, x + 18, y + 18], outline=(220, 190, 110, 120), width=4)
        d.line([(x, y + 18), (x + 4, y + 50)], fill=(220, 190, 110, 90), width=4)
    for x, y in ((300, 120), (420, 110), (560, 300), (150, 340)):
        d.line([(x, y), (x - 8, y + 24)], fill=(80, 100, 150, 160), width=4)
    # Heavy creases.
    for (ax, ay), (bx, by) in (((150, 240), (230, 300)), ((480, 140), (560, 250)), ((300, 430), (380, 470)), ((330, 80), (380, 150))):
        ink_line(img, [(ax, ay), (bx, by)], width=2.2, wobble=1.0, color=shade(SOGG, -60))
        ink_line(img, [(ax + 3, ay - 3), (bx + 3, by - 3)], width=1.4, wobble=1.0, color=shade(SOGG, 40))
    # Brows and glaring eyes (the Sogg's buttons washed away long ago).
    for ex, flip in ((270, 1), (430, -1)):
        crayon_poly(img, ellipse_points(ex, 220, 42, 30, 30), (250, 246, 220, 255), width=5)
        crayon_poly(img, ellipse_points(ex + 8 * flip, 226, 18, 18, 20), (60, 230, 230, 255), width=3)
        crayon_poly(img, ellipse_points(ex + 8 * flip, 226, 8, 8, 16), INK, outline=False, shadow=False)
        part(img, [(ex - 56 * flip, 170), (ex + 46 * flip, 196), (ex + 44 * flip, 212), (ex - 54 * flip, 190)],
             shade(SOGG, -120), width=4, radius=6)
    mouth = [(250, 300), (460, 296), (440, 340), (350, 360), (262, 340)]
    part(img, mouth, (34, 30, 60, 255), width=5, radius=16, shadow=False)
    for tx in range(262, 446, 22):
        crayon_poly(img, [(tx, 300), (tx + 18, 299), (tx + 9, 318)], (236, 236, 226, 255), width=2, smooth=False, shadow=False)
    # Drips running off the bottom.
    for x, y in ((140, 470), (330, 540), (560, 480), (440, 520)):
        part(img, [(x - 9, y), (x, y - 22, 0), (x + 9, y), (x, y + 14)], (150, 196, 240, 255), width=3, radius=6)
    paper_grain(img, 6).save(out("characters", "sogg_body.png"))


def build_drizzle_heart():
    """The Sogg's weak spot: little Drizzle, a pale, worried cloud, showing through a
    torn hole in its chest. Swiping it wrings the Sogg out."""
    w, h = 180, 150
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    crayon_poly(img, deckle(ellipse_points(90, 76, 84, 68, 40), 5, step=8, amount=4), (30, 34, 66, 255), width=4)
    blob(img, [(90, 80, 36), (60, 90, 26), (120, 90, 26), (76, 64, 26), (106, 64, 28)], DRIZZLE, width=4)
    for ex in (78, 102):
        button(img, ex, 80, 7, color=(60, 110, 190, 255))
    ink_line(img, [(82, 100), (90, 96), (98, 100)], width=1.8, wobble=0, color=(60, 70, 110, 255))
    for x in (66, 112):
        part(img, [(x - 4, 116), (x, 108, 0), (x + 4, 116), (x, 122)], (140, 190, 240, 255), width=2, radius=3)
    paper_grain(img, 4).save(out("characters", "drizzle_heart.png"))


# ---------------------------------------------------------------------- backgrounds


def build_frostfold():
    """The winter page: a pale folded sky with paper snowflakes, layered torn-paper
    mountains capped with snow, and paper pines along the nearer ridges."""
    w, h = 1920, 1080
    r = random.Random(1914)
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None] ** 1.2
    rgb = np.broadcast_to(np.array([150, 176, 222], np.float32) * (1 - t) + np.array([236, 232, 244], np.float32) * t, (h, w, 3)).copy()
    img = Image.fromarray(np.concatenate([rgb, np.full((h, w, 1), 255, np.float32)], -1).astype(np.uint8), "RGBA")
    facets(img, Image.new("L", (w, h), 255), 0.71, cell=160, wrap=True, strength=0.4)

    # A pale winter sun behind a paper cloud.
    _shadowed(img, lambda layer: crayon_poly(layer, ellipse_points(420, 220, 80, 80, 40), (252, 236, 196, 255), width=3))
    for cx, cy, sc in ((470, 260, 0.9), (1240, 170, 0.7), (1680, 300, 0.6)):
        lobes = [(cx - 90 * sc, cy, 46 * sc), (cx - 30 * sc, cy - 30 * sc, 60 * sc), (cx + 44 * sc, cy - 16 * sc, 50 * sc), (cx + 98 * sc, cy + 4 * sc, 36 * sc)]
        _shadowed(img, lambda layer, lobes=lobes: blob(layer, lobes, (250, 252, 255, 255), width=3))

    def peaks(base, height, count, phase):
        pts = []
        for i in range(count * 2 + 3):
            x = -120 + i * (w + 240) / (count * 2 + 2)
            y = base - (height * (0.7 + 0.3 * math.sin(i * 1.7 + phase)) if i % 2 == 1 else height * 0.15)
            pts.append((x, y))
        return pts

    for base, height, count, color, seed, phase in ((700, 380, 5, (170, 184, 220, 255), 31, 0.2), (820, 300, 4, (132, 150, 196, 255), 32, 1.4)):
        pts = peaks(base, height, count, phase)
        paper_layer(img, pts + [(w + 120, h + 40), (-120, h + 40)], color, seed, cell=100, strength=0.8)
        for (ax, ay), (bx, by), (cx2, cy2) in zip(pts, pts[1:], pts[2:]):
            if by < ay and by < cy2:
                cap = [(bx + (ax - bx) * 0.28, by + (ay - by) * 0.28), (bx, by), (bx + (cx2 - bx) * 0.28, by + (cy2 - by) * 0.28),
                       (bx + (cx2 - bx) * 0.16, by + (cy2 - by) * 0.34), (bx, by + (ay - by) * 0.22),
                       (bx + (ax - bx) * 0.16, by + (ay - by) * 0.36)]
                paper_layer(img, cap, SNOW, seed + int(bx), cell=40, shadow=(3, 5), strength=0.6)

    near = _ridge(w, 900, ((2, 40), (5, 12)), 2.2)
    paper_layer(img, near + [(w + 40, h + 40), (-40, h + 40)], SNOW, 33, cell=120, shadow=(8, 12), strength=0.7)
    x = 30.0
    while x < w:
        y = _ridge_y(x, w, 900, ((2, 40), (5, 12)), 2.2) + r.uniform(4, 30)
        s = r.uniform(40, 80)
        def tree(layer, x=x, y=y, s=s):
            for k, frac in enumerate((0.0, 0.3, 0.55)):
                ww = s * (0.5 - frac * 0.45)
                top = y - s * (0.75 + frac * 0.6)
                crayon_poly(layer, [(x - ww, y - s * frac * 0.9), (x, top), (x + ww, y - s * frac * 0.9)], shade(PINE, k * 8), width=2.5, smooth=False)
                crayon_poly(layer, [(x - ww * 0.4, top + s * 0.2), (x, top), (x + ww * 0.4, top + s * 0.2)], SNOW, width=1.5, smooth=False, shadow=False)
            crayon_poly(layer, [(x - 4, y), (x + 4, y), (x + 4, y + 10), (x - 4, y + 10)], (120, 80, 60, 255), width=1.5, smooth=False, shadow=False)
        _shadowed(img, tree, offset=(4, 6))
        x += r.uniform(90, 260)

    # Paper snowflakes.
    for _ in range(60):
        fx, fy, s = r.uniform(0, w), r.uniform(0, h * 0.8), r.uniform(5, 12)
        for a in range(3):
            ang = a * math.pi / 3 + 0.3
            ink_line(img, [(fx - math.cos(ang) * s, fy - math.sin(ang) * s), (fx + math.cos(ang) * s, fy + math.sin(ang) * s)],
                     width=1.6, wobble=0, color=(255, 255, 255, 230))
    paper_grain(img, 5).convert("RGB").save(out("backgrounds", "bg_frostfold.png"))


def build_spine():
    """The book's spine seen from inside: a towering wall of folded signatures (page
    bundles) stitched together with huge red thread, against a deep night sky."""
    w, h = 1920, 1080
    r = random.Random(1999)
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    rgb = np.broadcast_to(np.array([24, 28, 64], np.float32) * (1 - t) + np.array([70, 70, 120], np.float32) * t, (h, w, 3)).copy()
    img = Image.fromarray(np.concatenate([rgb, np.full((h, w, 1), 255, np.float32)], -1).astype(np.uint8), "RGBA")
    facets(img, Image.new("L", (w, h), 255), 0.12, cell=180, wrap=True, strength=0.4)
    d = ImageDraw.Draw(img)
    for _ in range(140):
        x, y, s = r.uniform(0, w), r.uniform(0, h * 0.7), r.uniform(1, 3)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(250, 240, 210, 255))
    # Signatures: tall bundles of page edges, each slightly different cream.
    x = -20.0
    k = 0
    while x < w + 20:
        bw = r.uniform(150, 230)
        top = r.uniform(160, 320)
        tone = shade(LINEN, r.randint(-24, 10))
        pts = [(x, h + 20), (x + 6, top + 20), (x + bw * 0.5, top), (x + bw - 6, top + 22), (x + bw, h + 20)]
        paper_layer(img, pts, tone, 40 + k, cell=70, strength=0.7)
        for yy in range(int(top) + 40, h, 14):
            ink_line(img, [(x + 14, yy), (x + bw - 14, yy + r.uniform(-2, 2))], width=0.9, wobble=0, color=shade(tone, -26))
        x += bw - 8
        k += 1
    # Night shadow across the lower wall, so the page in front reads clearly.
    shade_mask = np.clip((np.linspace(0, 1, h, dtype=np.float32) - 0.25) / 0.75, 0, 1)[:, None, None] * 0.45
    arr = np.asarray(img).astype(np.float32)
    arr[..., :3] = arr[..., :3] * (1 - shade_mask) + np.array([40, 46, 96], np.float32) * shade_mask
    img = Image.fromarray(arr.astype(np.uint8))
    # The great binding stitches: thick red thread crossing a few of the seams.
    for sx in range(200, w, 420):
        for sy in range(360 + (sx // 420) % 2 * 90, h, 260):
            for (ax, ay), (bx, by) in (((sx - 46, sy - 50), (sx + 46, sy + 50)), ((sx + 46, sy - 50), (sx - 46, sy + 50))):
                ink_line(img, [(ax, ay), (bx, by)], width=11, wobble=0.6, color=shade(THREAD, -60))
                ink_line(img, [(ax, ay), (bx, by)], width=7, wobble=0.6, color=THREAD)
            for hx, hy in ((sx - 46, sy - 50), (sx + 46, sy - 50), (sx - 46, sy + 50), (sx + 46, sy + 50)):
                d = ImageDraw.Draw(img)
                d.ellipse([hx - 6, hy - 6, hx + 6, hy + 6], fill=(40, 30, 40, 255))
    # Snow drifting down in front.
    for _ in range(80):
        x, y, s = r.uniform(0, w), r.uniform(0, h), r.uniform(2, 5)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(255, 255, 255, 200))
    paper_grain(img, 6).convert("RGB").save(out("backgrounds", "bg_spine.png"))


def build_dad_table_night():
    """Interlude 3: very late. Dad asleep at the table over the torn spine page, the
    lamp still on, and Nell in the lit doorway, watching."""
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), (30, 28, 44, 255))
    # The doorway behind, with warm hall light and Nell's silhouette.
    crayon_poly(img, [(1380, 120), (1660, 120), (1660, 640), (1380, 640)], (255, 214, 150, 255), width=8, smooth=False)
    crayon_poly(img, [(1490, 250), (1550, 250), (1572, 300), (1560, 640), (1478, 640), (1468, 300)], (54, 52, 80, 255), width=4)
    crayon_poly(img, ellipse_points(1520, 220, 34, 40, 24), (54, 52, 80, 255), width=4)
    crayon_poly(img, [(0, 640), (w, 600), (w, h), (0, h)], shade(WOOD, -40), width=8)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([480, 200, 1240, 1000], fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(150))
    img = Image.composite(Image.new("RGBA", (w, h), (255, 206, 140, 255)), img, glow)
    crayon_poly(img, [(840, 0), (860, 0), (860, 150), (840, 150)], INK, outline=False)
    crayon_poly(img, [(740, 150), (960, 150), (1010, 280), (690, 280)], MARIGOLD, width=7)
    # The open book, its spine torn and the winter page creased.
    crayon_poly(img, [(520, 780), (880, 750), (880, 900), (520, 930)], (240, 244, 252, 255), width=6)
    crayon_poly(img, [(900, 750), (1260, 780), (1260, 930), (900, 900)], (236, 238, 248, 255), width=6)
    crayon_poly(img, [(620, 840), (690, 780), (760, 840)], (170, 184, 220, 255), width=4)
    ink_line(img, [(880, 740), (896, 790), (884, 840), (900, 900)], width=4, wobble=1.5, color=(60, 40, 40, 255))
    # Gran sitting up with him.
    from finale_art import SKIN, _person
    _person(img, 1180, 700, 320, (150, 110, 170, 255), (220, 220, 230, 255), hair_style="bun", mouth="flat", glasses=True)
    # Dad asleep, head on folded arms beside the book, in the cast's papercraft style.
    shirt, hair = (110, 120, 150, 255), (96, 70, 56, 255)
    part(img, [(200, 830, 0), (230, 700), (330, 650), (470, 660), (540, 720), (560, 830, 0)], shirt, width=6, radius=40, seed=31)
    stitches(img, [(250, 740), (520, 750)], color=shade(shirt, 40), step=12, size=3)
    part(img, [(240, 790), (300, 740), (520, 740), (560, 800), (520, 830), (260, 830)], shade(shirt, 14), width=5, radius=26, seed=32)
    crayon_poly(img, ellipse_points(520, 800, 26, 22, 18), SKIN, width=4)
    part(img, [(290, 700), (330, 610), (420, 600), (470, 650), (460, 740), (360, 760)], SKIN, width=5, radius=34, seed=33)
    part(img, [(286, 706), (318, 604), (420, 592), (476, 640), (440, 640, 0), (360, 650, 0), (320, 700, 0)], hair, width=4, radius=30, seed=34)
    # Eyes stitched shut in sleep, and a little open mouth.
    for ex, ey in ((372, 682), (424, 676)):
        ink_line(img, [(ex - 12, ey), (ex, ey + 6), (ex + 12, ey)], width=3, wobble=0, color=(40, 40, 70, 255))
    crayon_poly(img, ellipse_points(404, 716, 7, 9, 12), (150, 60, 66, 255), width=2)
    crayon_poly(img, ellipse_points(452, 700, 9, 6, 12), (236, 140, 140, 150), outline=False, shadow=False)
    for k, (zx, zy) in enumerate(((480, 580), (510, 540), (546, 494))):
        ink_line(img, [(zx, zy), (zx + 14 + k * 4, zy), (zx, zy + 14 + k * 4), (zx + 14 + k * 4, zy + 14 + k * 4)], width=3, wobble=0, color=(230, 220, 250, 255))
    # The hairdryer, unplugged, on the table edge.
    crayon_poly(img, [(1360, 860), (1520, 840), (1530, 900), (1370, 920)], (230, 120, 150, 255), width=5)
    crayon_poly(img, [(1400, 900), (1440, 900), (1450, 990), (1410, 990)], (230, 120, 150, 255), width=5)
    ink_line(img, [(1430, 990), (1500, 1040), (1640, 1020), (1700, 1070)], width=4, wobble=1.0, color=(60, 60, 70, 255))
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_dad_table_night.png"))


def tiles():
    """The Chapter 3 tiles, in atlas order: row 3 columns 2-3, then row 4."""
    return [tile_snow_top, tile_snow_fill], [tile_thread_bridge, tile_ice, tile_snowfield, tile_drift]


def build():
    build_fold_mark()
    build_popup_peak()
    build_spool()
    build_paperclip()
    build_piton()
    build_plug()
    build_campfire()
    build_bindwell()
    build_sogg()
    build_drizzle_heart()
    build_frostfold()
    build_spine()
    build_dad_table_night()
