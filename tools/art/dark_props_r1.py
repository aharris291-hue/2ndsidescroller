"""Props for Region 1, Thistledown at full size (Phase 3).

Writes to assets/art/dark/props/:
  soaked_paper.png   a sodden sheet of paper stretched over two pegs (sags, tears), 192 x 40
  dry_paper.png      the same sheet once an awning has dried it, 192 x 40
  awning_rolled.png  a rolled canvas awning tied up under a rope, 224 x 48
  awning_canvas.png  the awning let down: a stretched, patched canvas, 224 x 70
  sluice_gate.png    a wooden sluice gate with iron bands, 64 x 256
  pew.png            a sodden chapel pew seen from above (top-down push block), 128 x 64
  bell_stone.png     a flagstone with an iron ring and bell rope (top-down plate), 64 x 64
  chapel_bell.png    a cracked bronze bell (top-down, rung by the three ropes), 128 x 128
  hay_bale.png       a sodden hay bale (side view crate), 96 x 72
  gear_wheel.png     the mill's great wooden gear, turning behind the gear seats, 448 x 448
  flour_sack.png     soaked flour sacks slung between two beams (a SoakedPaper look), 192 x 40
  flour_sack_dry.png the same sacks dried stiff, 192 x 40

Run: python3 tools/art/dark_props_r1.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

from dark_props_prologue import EDGE, THREAD, THREAD_HI, BRASS, BRASS_DARK, STEEL, STEEL_DARK, S, canvas, finish, paper_texture

PROPS = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "dark", "props")

WET = (70, 78, 92, 255)
WET_DARK = (40, 44, 56, 255)
DRY = (178, 166, 140, 255)
DRY_DARK = (120, 108, 86, 255)
WOOD = (66, 48, 34, 255)
WOOD_HI = (96, 72, 50, 255)
CANVAS = (98, 90, 76, 255)
CANVAS_STRIPE = (82, 74, 62, 255)  # faded seams, barely there: a tarpaulin, not a fairground
STONE = (84, 84, 88, 255)
STONE_HI = (112, 110, 112, 255)


def paper_sheet(fill, dark, seed, drips):
    w, h = 192, 40
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    # pegs at each end
    for x in (8, w - 16):
        d.rectangle([x * S, 4 * S, (x + 8) * S, 30 * S], fill=EDGE)
        d.rectangle([(x + 2) * S, 6 * S, (x + 6) * S, 30 * S], fill=WOOD_HI)
    # the sheet: a shallow sag, ragged lower edge
    rnd = random.Random(seed)
    top = [(10 * S, 10 * S)]
    for i in range(1, 12):
        x = 10 + (w - 20) * i / 12
        sag = math.sin(i / 12 * math.pi) * (4 if drips else 1)
        top.append((x * S, (10 + sag) * S))
    top.append(((w - 10) * S, 10 * S))
    bottom = []
    for i in range(12, -1, -1):
        x = 10 + (w - 20) * i / 12
        sag = math.sin(i / 12 * math.pi) * (6 if drips else 1.5)
        bottom.append((x * S, (22 + sag + rnd.uniform(-1.5, 1.5)) * S))
    poly = top + bottom
    d.polygon([(px, py + 2 * S) for px, py in poly], fill=EDGE)
    d.polygon(poly, fill=fill)
    # ruled lines and smudged words
    for row in (14, 18):
        d.line([(16 * S, row * S), ((w - 16) * S, (row + (2 if drips else 0)) * S)], fill=dark, width=S)
    for _ in range(14):
        x = rnd.uniform(18, w - 30)
        y = rnd.choice((13, 17))
        d.line([(x * S, y * S), ((x + rnd.uniform(4, 12)) * S, y * S)], fill=(30, 30, 36, 200), width=S)
    if drips:
        for _ in range(5):
            x = rnd.uniform(30, w - 30)
            y = 24 + math.sin((x - 10) / (w - 20) * math.pi) * 6
            ln = rnd.uniform(5, 12)
            d.line([(x * S, y * S), (x * S, (y + ln) * S)], fill=(50, 58, 74, 230), width=2 * S)
            d.ellipse([(x - 1.5) * S, (y + ln - 1) * S, (x + 1.5) * S, (y + ln + 2) * S], fill=(60, 70, 88, 230))
    else:
        # a few stitches where it was mended dry
        # dried stiff, with a brown tide-mark where the water was
        d.line([(14 * S, 20 * S), ((w - 14) * S, 21 * S)], fill=(96, 78, 56, 255), width=2 * S)
    img = paper_texture(img, seed, 0.12, 4)
    return finish(img, w, h)


def awning_rolled():
    w, h = 224, 48
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    # the rope it hangs from, tied to a hook at each end
    d.line([(0, 6 * S), (w * S, 6 * S)], fill=(70, 56, 40, 255), width=3 * S)
    # the roll
    d.rounded_rectangle([12 * S, 12 * S, (w - 12) * S, 40 * S], 13 * S, fill=EDGE)
    d.rounded_rectangle([14 * S, 14 * S, (w - 14) * S, 38 * S], 11 * S, fill=CANVAS)
    for x in range(26, w - 20, 28):
        d.rectangle([x * S, 14 * S, (x + 10) * S, 38 * S], fill=CANVAS_STRIPE)
    # ties
    for x in (40, w - 48):
        d.line([(x * S, 6 * S), (x * S, 40 * S)], fill=(80, 64, 44, 255), width=3 * S)
        d.line([((x + 8) * S, 6 * S), ((x + 8) * S, 40 * S)], fill=(80, 64, 44, 255), width=3 * S)
    img = paper_texture(img, 31, 0.1, 3)
    return finish(img, w, h)


def awning_canvas():
    w, h = 224, 70
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.line([(0, 6 * S), (w * S, 6 * S)], fill=(70, 56, 40, 255), width=3 * S)
    # canvas stretched down at a slant, scalloped edge
    poly = [(6 * S, 8 * S), ((w - 6) * S, 8 * S), ((w - 2) * S, 52 * S)]
    for i in range(8, -1, -1):
        x = 2 + (w - 4) * i / 8
        poly.append((x * S, (56 + (4 if i % 2 else 0)) * S))
    poly.append((2 * S, 52 * S))
    d.polygon([(px, py + 2 * S) for px, py in poly], fill=EDGE)
    d.polygon(poly, fill=CANVAS)
    for x in range(14, w - 10, 28):
        d.polygon([(x * S, 8 * S), ((x + 12) * S, 8 * S), ((x + 13) * S, 56 * S), ((x - 1) * S, 56 * S)], fill=CANVAS_STRIPE)
    # a stitched patch
    d.rectangle([150 * S, 20 * S, 176 * S, 40 * S], fill=(118, 104, 84, 255))
    for x in range(152, 176, 6):
        d.line([(x * S, 20 * S), ((x + 3) * S, 23 * S)], fill=THREAD_HI, width=S)
    img = paper_texture(img, 32, 0.1, 4)
    return finish(img, w, h)


def sluice_gate():
    w, h = 64, 256
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([2 * S, 0, (w - 2) * S, h * S], fill=EDGE)
    for i, x in enumerate(range(5, w - 4, 14)):
        tone = WOOD if i % 2 else WOOD_HI
        d.rectangle([x * S, 2 * S, (x + 12) * S, (h - 2) * S], fill=tone)
    for y in (24, 110, 200):
        d.rectangle([2 * S, y * S, (w - 2) * S, (y + 10) * S], fill=STEEL_DARK)
        for x in (10, w - 14):
            d.ellipse([x * S, (y + 2) * S, (x + 5) * S, (y + 7) * S], fill=STEEL)
    # tide line and weed
    d.rectangle([4 * S, 150 * S, (w - 4) * S, 154 * S], fill=(40, 60, 48, 255))
    img = paper_texture(img, 41, 0.14, 5)
    return finish(img, w, h)


def pew():
    w, h = 128, 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2 * S, 6 * S, (w - 2) * S, (h - 4) * S], 5 * S, fill=EDGE)
    d.rounded_rectangle([5 * S, 9 * S, (w - 5) * S, 40 * S], 4 * S, fill=WOOD_HI)  # seat
    d.rounded_rectangle([5 * S, 42 * S, (w - 5) * S, (h - 7) * S], 3 * S, fill=WOOD)  # back rail
    for x in range(14, w - 10, 18):
        d.line([(x * S, 11 * S), (x * S, 38 * S)], fill=WOOD, width=S)
    # a drowned hymn book left on the seat
    d.rectangle([80 * S, 16 * S, 104 * S, 32 * S], fill=EDGE)
    d.rectangle([82 * S, 18 * S, 102 * S, 30 * S], fill=(90, 30, 28, 255))
    img = paper_texture(img, 51, 0.12, 5)
    return finish(img, w, h)


def bell_stone():
    w, h = 64, 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([1 * S, 1 * S, (w - 1) * S, (h - 1) * S], fill=EDGE)
    d.rectangle([3 * S, 3 * S, (w - 3) * S, (h - 3) * S], fill=STONE)
    d.line([(8 * S, 50 * S), (26 * S, 40 * S)], fill=(50, 50, 54, 255), width=S)
    cx, cy = w / 2 * S, h / 2 * S
    d.ellipse([cx - 14 * S, cy - 14 * S, cx + 14 * S, cy + 14 * S], outline=EDGE, width=5 * S)
    d.ellipse([cx - 13 * S, cy - 13 * S, cx + 13 * S, cy + 13 * S], outline=STEEL, width=3 * S)
    # the bell rope coiled through the ring
    d.line([(cx, cy - 13 * S), (cx + 6 * S, 4 * S)], fill=THREAD, width=4 * S)
    img = paper_texture(img, 61, 0.1, 3)
    return finish(img, w, h)


def chapel_bell():
    w, h = 128, 128
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, cy = w / 2 * S, h / 2 * S
    bronze, bronze_dark, verdigris = (104, 86, 54, 255), (58, 46, 30, 255), (62, 88, 74, 255)
    for r, col in ((58, EDGE), (55, bronze_dark), (46, bronze), (38, verdigris), (30, bronze_dark), (12, EDGE)):
        d.ellipse([cx - r * S, cy - r * S, cx + r * S, cy + r * S], fill=col)
    # the crack
    pts = [(cx + 10 * S, cy - 50 * S), (cx + 4 * S, cy - 30 * S), (cx + 14 * S, cy - 18 * S), (cx + 6 * S, cy - 4 * S)]
    d.line(pts, fill=EDGE, width=2 * S)
    img = paper_texture(img, 71, 0.08, 4)
    return finish(img, w, h)


def hay_bale():
    w, h = 96, 72
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2 * S, 4 * S, (w - 2) * S, (h - 2) * S], 6 * S, fill=EDGE)
    d.rounded_rectangle([5 * S, 7 * S, (w - 5) * S, (h - 5) * S], 5 * S, fill=(118, 102, 62, 255))
    rnd = random.Random(81)
    for _ in range(90):
        x, y = rnd.uniform(8, w - 8), rnd.uniform(10, h - 8)
        d.line([(x * S, y * S), ((x + rnd.uniform(-6, 6)) * S, (y + rnd.uniform(-2, 2)) * S)], fill=(86, 74, 44, 255), width=S)
    for x in (28, w - 30):
        d.rectangle([x * S, 7 * S, (x + 4) * S, (h - 5) * S], fill=(60, 40, 26, 255))
    # the wet half, darker below the tide line
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(over)
    od.rectangle([0, 40 * S, w * S, h * S], fill=(20, 26, 40, 110))
    img = Image.alpha_composite(img, Image.composite(over, Image.new("RGBA", img.size, (0, 0, 0, 0)), img.split()[3]))
    img = paper_texture(img, 82, 0.1, 3)
    return finish(img, w, h)


def gear_wheel():
    w = h = 448
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, cy = w / 2 * S, h / 2 * S
    teeth = 20
    outer, inner = 214, 186
    pts = []
    for i in range(teeth * 4):
        a = i / (teeth * 4) * math.tau
        r = outer if (i % 4) in (1, 2) else inner
        pts.append((cx + math.cos(a) * r * S, cy + math.sin(a) * r * S))
    d.polygon(pts, fill=EDGE)
    pts2 = [(cx + (px - cx) * 0.97, cy + (py - cy) * 0.97) for px, py in pts]
    d.polygon(pts2, fill=WOOD)
    d.ellipse([cx - 170 * S, cy - 170 * S, cx + 170 * S, cy + 170 * S], fill=EDGE)
    d.ellipse([cx - 164 * S, cy - 164 * S, cx + 164 * S, cy + 164 * S], fill=WOOD_HI)
    d.ellipse([cx - 138 * S, cy - 138 * S, cx + 138 * S, cy + 138 * S], fill=EDGE)
    # spokes over a dark well, so the wheel reads as a frame and not a disc
    d.ellipse([cx - 134 * S, cy - 134 * S, cx + 134 * S, cy + 134 * S], fill=(24, 18, 16, 255))
    for k in range(6):
        a = k / 6 * math.tau
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy * 12 * S, dx * 12 * S
        ex, ey = cx + dx * 140 * S, cy + dy * 140 * S
        d.polygon([(cx + nx, cy + ny), (ex + nx, ey + ny), (ex - nx, ey - ny), (cx - nx, cy - ny)], fill=EDGE)
        d.polygon([(cx + nx * 0.7, cy + ny * 0.7), (ex + nx * 0.7, ey + ny * 0.7), (ex - nx * 0.7, ey - ny * 0.7), (cx - nx * 0.7, cy - ny * 0.7)], fill=WOOD)
    d.ellipse([cx - 40 * S, cy - 40 * S, cx + 40 * S, cy + 40 * S], fill=EDGE)
    d.ellipse([cx - 34 * S, cy - 34 * S, cx + 34 * S, cy + 34 * S], fill=STEEL_DARK)
    d.rectangle([cx - 12 * S, cy - 12 * S, cx + 12 * S, cy + 12 * S], fill=EDGE)
    img = paper_texture(img, 91, 0.16, 6)
    return finish(img, w, h)


def flour_sack(wet: bool):
    w, h = 192, 40
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    for x in (4, w - 14):
        d.rectangle([x * S, 2 * S, (x + 10) * S, 34 * S], fill=EDGE)
        d.rectangle([(x + 2) * S, 4 * S, (x + 8) * S, 34 * S], fill=WOOD_HI)
    fill = (92, 90, 84, 255) if wet else (168, 156, 128, 255)
    dark = (54, 54, 56, 255) if wet else (118, 106, 82, 255)
    rnd = random.Random(101 if wet else 102)
    for i, x0 in enumerate(range(14, w - 30, 42)):
        sag = 4 if wet else 1
        d.rounded_rectangle([x0 * S, 8 * S, (x0 + 44) * S, (30 + sag) * S], 9 * S, fill=EDGE)
        d.rounded_rectangle([(x0 + 2) * S, 10 * S, (x0 + 42) * S, (28 + sag) * S], 8 * S, fill=fill)
        d.line([((x0 + 6) * S, 12 * S), ((x0 + 38) * S, 12 * S)], fill=dark, width=2 * S)
        # a stencilled mill mark, half washed off
        d.rectangle([(x0 + 16) * S, 17 * S, (x0 + 28) * S, 23 * S], outline=dark, width=S)
        if wet:
            for _ in range(2):
                x = rnd.uniform(x0 + 8, x0 + 36)
                ln = rnd.uniform(4, 9)
                d.line([(x * S, (28 + sag) * S), (x * S, (28 + sag + ln) * S)], fill=(60, 66, 80, 220), width=2 * S)
    img = paper_texture(img, 103 if wet else 104, 0.12, 4)
    return finish(img, w, h)


def main() -> None:
    os.makedirs(PROPS, exist_ok=True)
    outputs = {
        "soaked_paper.png": paper_sheet(WET, WET_DARK, 11, True),
        "dry_paper.png": paper_sheet(DRY, DRY_DARK, 11, False),
        "awning_rolled.png": awning_rolled(),
        "awning_canvas.png": awning_canvas(),
        "sluice_gate.png": sluice_gate(),
        "pew.png": pew(),
        "bell_stone.png": bell_stone(),
        "chapel_bell.png": chapel_bell(),
        "hay_bale.png": hay_bale(),
        "gear_wheel.png": gear_wheel(),
        "flour_sack.png": flour_sack(True),
        "flour_sack_dry.png": flour_sack(False),
    }
    for name, img in outputs.items():
        img.save(os.path.join(PROPS, name))
        print("wrote", name, img.size)


if __name__ == "__main__":
    main()
