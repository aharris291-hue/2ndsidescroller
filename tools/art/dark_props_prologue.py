"""Dark-rebuild props and the new Drizzle for the Prologue (P-1 and P-2).

Writes to assets/art/dark/props/ and assets/art/dark/characters/:
  drizzle.png       Drizzle: a small storm cloud of torn grey paper with
                    mismatched button eyes and a red stitch, dripping
  drizzle_pinned.png  the same, squashed flat and crying (pinned under the spine)
  fallen_spine.png  a broken book spine lying across the shelf floor
  pincushion.png    Gran's pincushion with her stork shears driven into it
  nail.png          a bent nail with a scrap of Patch's tail on it
  nail_bare.png     the nail alone (before the tail tears)
  hanging_lamp.png  a small oil lamp on a chain (the light is a PointLight2D)
  book.png          a falling book (P-2 hazard)
  shelf_board.png   a loose shelf board (collapsing platform), 192 x 28
  thread_bridge.png a length of twisted red thread, tiled along the bridge

Run: python3 tools/art/dark_props_prologue.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
PROPS = os.path.join(ROOT, "assets", "art", "dark", "props")
CHARS = os.path.join(ROOT, "assets", "art", "dark", "characters")
S = 4  # supersample

EDGE = (16, 12, 12, 255)
THREAD = (150, 30, 26, 255)
THREAD_HI = (196, 64, 50, 255)
BRASS = (176, 140, 70, 255)
BRASS_DARK = (92, 68, 30, 255)
STEEL = (150, 150, 156, 255)
STEEL_DARK = (60, 60, 66, 255)


def canvas(w, h):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def finish(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def ragged(cx, cy, rx, ry, seed, jag=0.12, n=30):
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        a = i / n * math.tau
        k = 1.0 + rnd.uniform(-jag, jag)
        pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    return pts


def paper_texture(img, seed, strength=0.12, stains=6):
    """Grain, fibres and water stains, kept inside the image's alpha."""
    a = np.asarray(img, np.float32)
    rnd = np.random.default_rng(seed)
    h, w = a.shape[:2]
    n = rnd.normal(0, 1, (h // S + 1, w // S + 1))
    n = np.kron(n, np.ones((S, S)))[:h, :w]
    a[..., :3] *= (1 + strength * n)[..., None]
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    r2 = random.Random(seed)
    for _ in range(stains):
        x, y = r2.uniform(0, w), r2.uniform(0, h)
        r = r2.uniform(w * 0.06, w * 0.2)
        d.ellipse([x - r, y - r, x + r, y + r], outline=150, width=2 * S)
        d.ellipse([x - r * 0.9, y - r * 0.9, x + r * 0.9, y + r * 0.9], fill=40)
    layer = np.asarray(layer.filter(ImageFilter.GaussianBlur(S * 2)), np.float32) / 255.0
    a[..., :3] *= (1 - 0.35 * layer)[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def button(d, cx, cy, r, colour, thread=THREAD):
    d.ellipse([cx - r - 2 * S, cy - r - 2 * S, cx + r + 2 * S, cy + r + 2 * S], fill=EDGE)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
    d.ellipse([cx - r * 0.75, cy - r * 0.75, cx + r * 0.75, cy + r * 0.75], outline=tuple(int(c * 0.6) for c in colour[:3]) + (255,), width=S)
    hole = r * 0.22
    for ox, oy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        hx, hy = cx + ox * r * 0.32, cy + oy * r * 0.32
        d.ellipse([hx - hole, hy - hole, hx + hole, hy + hole], fill=EDGE)
    d.line([(cx - r * 0.32, cy - r * 0.32), (cx + r * 0.32, cy + r * 0.32)], fill=thread, width=2 * S)
    d.line([(cx + r * 0.32, cy - r * 0.32), (cx - r * 0.32, cy + r * 0.32)], fill=thread, width=2 * S)


def drizzle(pinned=False):
    w, h = 220, 200
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, cy = w * S / 2, h * S * (0.5 if not pinned else 0.62)
    sy = 1.0 if not pinned else 0.72
    puffs = [(-52, 8, 46), (0, -18, 60), (54, 6, 48), (-22, 30, 50), (30, 32, 50)]
    for i, (ox, oy, r) in enumerate(puffs):
        pts = ragged(cx + ox * S, cy + oy * S * sy, (r + 5) * S, (r + 5) * S * sy, 11 + i, 0.1)
        d.polygon(pts, fill=EDGE)
    for i, (ox, oy, r) in enumerate(puffs):
        tone = 112 + i * 8
        pts = ragged(cx + ox * S, cy + oy * S * sy, r * S, r * S * sy, 11 + i, 0.1)
        d.polygon(pts, fill=(tone - 14, tone - 6, tone + 8, 255))
        # torn-paper facet lines
        rnd = random.Random(i)
        for _ in range(3):
            a = rnd.uniform(0, math.tau)
            d.line([(cx + ox * S, cy + oy * S * sy),
                    (cx + ox * S + math.cos(a) * r * S * 0.8, cy + oy * S * sy + math.sin(a) * r * S * 0.8 * sy)],
                   fill=(tone - 40, tone - 34, tone - 20, 255), width=S)
    img = paper_texture(img, 3, 0.1, 5)
    d = ImageDraw.Draw(img)
    # stitched seam where Gran mended him once
    sx0, sy0 = cx - 70 * S, cy - 30 * S * sy
    for i in range(6):
        x = sx0 + i * 12 * S
        y = sy0 + math.sin(i * 0.9) * 4 * S
        d.line([(x - 4 * S, y - 6 * S), (x + 4 * S, y + 6 * S)], fill=THREAD, width=2 * S)
    # mismatched buttons: one navy, one bone
    ey = cy + 4 * S * sy
    button(d, cx - 26 * S, ey, 15 * S, (40, 52, 84, 255))
    button(d, cx + 26 * S, ey + 2 * S, 12 * S, (180, 170, 150, 255), THREAD)
    if pinned:
        # tears running out from under the buttons
        for ox in (-26, 26):
            d.line([(cx + ox * S, ey + 16 * S), (cx + ox * S + 2 * S, ey + 46 * S)], fill=(150, 180, 210, 200), width=3 * S)
        d.arc([cx - 14 * S, ey + 22 * S, cx + 14 * S, ey + 38 * S], 200, 340, fill=EDGE, width=2 * S)
    else:
        d.line([(cx - 8 * S, ey + 28 * S), (cx + 8 * S, ey + 28 * S)], fill=EDGE, width=2 * S)
    # rain falling from his underside
    if not pinned:
        rnd = random.Random(5)
        for _ in range(9):
            x = cx + rnd.uniform(-60, 60) * S
            y = cy + rnd.uniform(48, 60) * S
            d.line([(x, y), (x - 3 * S, y + rnd.uniform(14, 26) * S)], fill=(130, 160, 196, 170), width=2 * S)
    return finish(img, w, h)


def fallen_spine():
    w, h = 300, 120
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    # a heavy book spine leaning on its corner, cracked
    poly = [(10, 70), (290, 40), (296, 92), (16, 118)]
    poly = [(x * S, y * S) for x, y in poly]
    d.polygon(poly, fill=EDGE)
    inner = [(16, 74), (286, 46), (290, 86), (20, 112)]
    d.polygon([(x * S, y * S) for x, y in inner], fill=(84, 26, 22, 255))
    for x in (60, 110, 230):
        y0 = 72 - x * 0.1
        d.line([(x * S, (y0 - 2) * S), ((x + 4) * S, (y0 + 40) * S)], fill=(126, 98, 50, 255), width=4 * S)
    d.line([(150 * S, 60 * S), (160 * S, 80 * S), (154 * S, 100 * S)], fill=EDGE, width=3 * S)
    img = paper_texture(img, 21, 0.12, 4)
    return finish(img, w, h)


def shears(d, x, y, angle, length, s=S):
    """Gran's stork shears, closed, pointing along `angle`."""
    ca, sa = math.cos(angle), math.sin(angle)
    def p(u, v):
        return (x + (u * ca - v * sa) * s, y + (u * sa + v * ca) * s)
    blade = [p(0, -5), p(length, -1), p(length, 1), p(0, 5)]
    d.polygon(blade, fill=STEEL_DARK)
    d.polygon([p(0, -4), p(length * 0.95, -0.5), p(0, 0)], fill=STEEL)
    # the stork's body and the two finger loops
    d.ellipse([p(-6, 0)[0] - 7 * s, p(-6, 0)[1] - 7 * s, p(-6, 0)[0] + 7 * s, p(-6, 0)[1] + 7 * s], fill=BRASS_DARK)
    for v in (-11, 11):
        c = p(-26, v)
        d.ellipse([c[0] - 11 * s, c[1] - 11 * s, c[0] + 11 * s, c[1] + 11 * s], outline=BRASS_DARK, width=5 * s)
        d.ellipse([c[0] - 10 * s, c[1] - 10 * s, c[0] + 10 * s, c[1] + 10 * s], outline=BRASS, width=3 * s)
    pivot = p(-2, 0)
    d.ellipse([pivot[0] - 3 * s, pivot[1] - 3 * s, pivot[0] + 3 * s, pivot[1] + 3 * s], fill=BRASS)


def pincushion():
    w, h = 150, 170
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, cy = 75 * S, 128 * S
    # the shears driven point-first into the cushion (drawn first, so the cushion hides the tip)
    shears(d, cx + 4 * S, cy - 64 * S, math.radians(84), 70)
    # tin base
    d.rounded_rectangle([cx - 52 * S, cy, cx + 52 * S, cy + 34 * S], 8 * S, fill=EDGE)
    d.rounded_rectangle([cx - 48 * S, cy + 3 * S, cx + 48 * S, cy + 30 * S], 6 * S, fill=(70, 66, 60, 255))
    # the cushion: a faded red tomato, segmented
    d.ellipse([cx - 56 * S, cy - 42 * S, cx + 56 * S, cy + 16 * S], fill=EDGE)
    d.ellipse([cx - 52 * S, cy - 38 * S, cx + 52 * S, cy + 12 * S], fill=(112, 34, 30, 255))
    for k in (-30, 0, 30):
        d.arc([cx + (k - 26) * S, cy - 38 * S, cx + (k + 26) * S, cy + 12 * S], 250, 290, fill=(60, 16, 14, 255), width=2 * S)
    # pins
    rnd = random.Random(4)
    for _ in range(6):
        px = cx + rnd.uniform(-40, 40) * S
        py = cy + rnd.uniform(-30, -10) * S
        a = rnd.uniform(-2.2, -0.9)
        ex, ey = px + math.cos(a) * 22 * S, py + math.sin(a) * 22 * S
        d.line([(px, py), (ex, ey)], fill=STEEL, width=2 * S)
        d.ellipse([ex - 4 * S, ey - 4 * S, ex + 4 * S, ey + 4 * S], fill=(180, 170, 150, 255))
    img = paper_texture(img, 31, 0.08, 3)
    return finish(img, w, h)


def nail(with_tail):
    w, h = 90, 90
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    # head flush with the shelf side, shaft bent up
    d.line([(10 * S, 50 * S), (44 * S, 50 * S), (58 * S, 34 * S)], fill=EDGE, width=7 * S, joint="curve")
    d.line([(10 * S, 50 * S), (44 * S, 50 * S), (58 * S, 34 * S)], fill=STEEL_DARK, width=4 * S, joint="curve")
    d.rectangle([4 * S, 40 * S, 12 * S, 60 * S], fill=EDGE)
    d.rectangle([5 * S, 42 * S, 11 * S, 58 * S], fill=STEEL)
    if with_tail:
        # a torn strip of orange-brown paper fur, caught on the nail
        tail = [(46, 40), (66, 30), (84, 38), (80, 52), (86, 64), (64, 70), (52, 58), (46, 52)]
        d.polygon([(x * S, y * S) for x, y in tail], fill=EDGE)
        inner = [(50, 42), (66, 34), (80, 40), (76, 52), (80, 62), (64, 66), (54, 56)]
        d.polygon([(x * S, y * S) for x, y in inner], fill=(150, 88, 44, 255))
        d.line([(56 * S, 50 * S), (74 * S, 44 * S)], fill=(196, 170, 130, 255), width=2 * S)
        for x in (60, 70):
            d.line([(x * S, 62 * S), ((x + 2) * S, 80 * S)], fill=(150, 88, 44, 255), width=2 * S)
    img = paper_texture(img, 41, 0.08, 2)
    return finish(img, w, h)


def hanging_lamp():
    w, h = 60, 150
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx = 30 * S
    for i in range(10):
        y = i * 9 * S
        d.ellipse([cx - 3 * S, y, cx + 3 * S, y + 8 * S], outline=(70, 64, 56, 255), width=2 * S)
    d.polygon([(cx - 16 * S, 92 * S), (cx + 16 * S, 92 * S), (cx + 10 * S, 84 * S), (cx - 10 * S, 84 * S)], fill=EDGE)
    d.rounded_rectangle([cx - 15 * S, 92 * S, cx + 15 * S, 134 * S], 6 * S, fill=EDGE)
    d.rounded_rectangle([cx - 12 * S, 95 * S, cx + 12 * S, 131 * S], 5 * S, fill=(240, 196, 120, 255))
    d.ellipse([cx - 6 * S, 104 * S, cx + 6 * S, 122 * S], fill=(255, 238, 190, 255))
    for x in (-12, 12):
        d.line([(cx + x * S, 95 * S), (cx + x * S, 131 * S)], fill=EDGE, width=2 * S)
    d.rectangle([cx - 17 * S, 134 * S, cx + 17 * S, 140 * S], fill=EDGE)
    return finish(img, w, h)


def book():
    w, h = 96, 60
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2 * S, 6 * S, 94 * S, 56 * S], 4 * S, fill=EDGE)
    d.rounded_rectangle([5 * S, 9 * S, 91 * S, 40 * S], 3 * S, fill=(52, 40, 58, 255))
    d.rectangle([7 * S, 40 * S, 89 * S, 52 * S], fill=(176, 162, 132, 255))  # page edges
    for y in range(42, 52, 3):
        d.line([(8 * S, y * S), (88 * S, y * S)], fill=(130, 118, 96, 255), width=S)
    for x in (16, 80):
        d.rectangle([x * S, 9 * S, (x + 3) * S, 40 * S], fill=(126, 98, 50, 255))
    img = paper_texture(img, 51, 0.1, 2)
    return finish(img, w, h)


def shelf_board():
    w, h = 192, 28
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 2 * S, w * S, 26 * S], fill=EDGE)
    d.rectangle([2 * S, 4 * S, (w - 2) * S, 24 * S], fill=(82, 58, 40, 255))
    d.rectangle([2 * S, 4 * S, (w - 2) * S, 8 * S], fill=(196, 184, 160, 255))
    rnd = random.Random(8)
    for _ in range(6):
        y = rnd.uniform(11, 22) * S
        d.line([(4 * S, y), ((w - 4) * S, y + rnd.uniform(-3, 3) * S)], fill=(54, 38, 26, 255), width=S)
    # crack in the middle: it is going to give
    d.line([(96 * S, 4 * S), (90 * S, 14 * S), (100 * S, 24 * S)], fill=EDGE, width=3 * S)
    img = paper_texture(img, 61, 0.1, 3)
    return finish(img, w, h)


def thread_tile():
    w, h = 64, 16
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 5 * S, w * S, 11 * S], fill=EDGE)
    d.rectangle([0, 6 * S, w * S, 10 * S], fill=THREAD)
    for x in range(0, w, 8):
        d.line([(x * S, 6 * S), ((x + 6) * S, 10 * S)], fill=THREAD_HI, width=S * 2)
    return finish(img, w, h)


def main():
    os.makedirs(PROPS, exist_ok=True)
    os.makedirs(CHARS, exist_ok=True)
    drizzle().save(os.path.join(CHARS, "drizzle.png"))
    drizzle(pinned=True).save(os.path.join(CHARS, "drizzle_pinned.png"))
    fallen_spine().save(os.path.join(PROPS, "fallen_spine.png"))
    pincushion().save(os.path.join(PROPS, "pincushion.png"))
    nail(True).save(os.path.join(PROPS, "nail.png"))
    nail(False).save(os.path.join(PROPS, "nail_bare.png"))
    hanging_lamp().save(os.path.join(PROPS, "hanging_lamp.png"))
    book().save(os.path.join(PROPS, "book.png"))
    shelf_board().save(os.path.join(PROPS, "shelf_board.png"))
    thread_tile().save(os.path.join(PROPS, "thread_bridge.png"))
    print("wrote prologue props")


if __name__ == "__main__":
    main()
