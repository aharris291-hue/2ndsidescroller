"""Chapter 2 art: Lanternfold Harbor, the Margin heist, and the Blotch Kraken.

Built by generate_art.py (same style helpers). To regenerate only this chapter:

    python3 tools/art/generate_art.py chapter2
"""

import math
import random

from PIL import Image, ImageDraw, ImageFilter

from generate_art import (CARDBOARD, CREAM, INK, LILAC, MARIGOLD, SAGE, SKY, TAN, TEAL, TOMATO, WOOD,
                          _sky_gradient, blob, button_eye, crayon_poly, ellipse_points, ink_line, jitter, out,
                          paper_grain, shade)

rng = random.Random(2024)

INKSEA = (34, 46, 96, 255)
BLOTCH = (44, 50, 104, 255)
PINK = (250, 168, 188, 255)
BRASS = (236, 180, 60, 255)
DUSK = (120, 92, 168, 255)


def build_kraken():
    """The Blotch Kraken: a spilled-ink monster with a single furious eye."""
    w, h = 560, 440
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    blob(img, [(280, 250, 170), (160, 300, 110), (400, 300, 110), (280, 150, 120), (110, 380, 70), (450, 380, 70), (280, 360, 130)], BLOTCH, width=7, shade_amount=-40)
    d = ImageDraw.Draw(img)
    for _ in range(18):
        x, y = rng.uniform(120, 440), rng.uniform(140, 400)
        d.ellipse([x - 8, y - 6, x + 8, y + 6], fill=(108, 132, 96, 200))
    for x in (90, 170, 250, 330, 410, 470):
        crayon_poly(img, [(x - 10, 418), (x + 10, 418), (x, 438)], BLOTCH, width=3, wobble=0.4)
    # The empty socket the eye sits in, and a jagged mouth.
    crayon_poly(img, ellipse_points(280, 200, 82, 72, 30), (22, 24, 52, 255), width=6)
    crayon_poly(img, [(200, 320), (360, 320), (340, 360), (220, 360)], (22, 20, 40, 255), width=5)
    for x in range(214, 352, 22):
        crayon_poly(img, [(x, 322), (x + 14, 322), (x + 7, 340)], CREAM, width=2, wobble=0.3)
    ink_line(img, [(170, 120), (232, 150)], width=10, wobble=0.6)
    ink_line(img, [(390, 120), (328, 150)], width=10, wobble=0.6)
    paper_grain(img).save(out("characters", "kraken_body.png"))

    img = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
    crayon_poly(img, ellipse_points(75, 75, 64, 58, 30), CREAM, width=6)
    crayon_poly(img, ellipse_points(80, 78, 30, 30, 24), MARIGOLD, width=4)
    d = ImageDraw.Draw(img)
    d.ellipse([66, 64, 94, 92], fill=INK)
    d.ellipse([70, 66, 80, 76], fill=CREAM)
    for a in (0.6, 1.4, 2.2):
        x, y = 75 + math.cos(a + math.pi) * 54, 75 + math.sin(a + math.pi) * 48
        ink_line(img, [(x, y), (x + math.cos(a + math.pi) * 10, y + math.sin(a + math.pi) * 10)], width=3, color=TOMATO)
    paper_grain(img).save(out("characters", "kraken_eye.png"))

    # One tentacle, hanging straight down with its tip at the bottom.
    w, h = 140, 600
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    left, right = [], []
    for i in range(41):
        y = i / 40 * (h - 30) + 10
        half = 54 * (1 - i / 44) + 6
        sway = math.sin(i / 40 * math.pi * 1.5) * 14
        left.append((70 + sway - half, y))
        right.append((70 + sway + half, y))
    crayon_poly(img, left + right[::-1], BLOTCH, width=6)
    for i in range(4, 38, 4):
        y = i / 40 * (h - 30) + 10
        sway = math.sin(i / 40 * math.pi * 1.5) * 14
        r = 12 * (1 - i / 44) + 4
        crayon_poly(img, ellipse_points(70 + sway + 16 * (1 - i / 44), y, r, r * 0.8, 14), PINK, width=2, shadow=False)
    paper_grain(img).save(out("characters", "kraken_tentacle.png"))


# --------------------------------------------------------------------------- props


def build_lanterns():
    for name, lit in (("lantern_off", False), ("lantern_on", True)):
        img = Image.new("RGBA", (120, 180), (0, 0, 0, 0))
        if lit:
            glow = Image.new("L", img.size, 0)
            ImageDraw.Draw(glow).ellipse([22, 14, 98, 92], fill=170)
            glow = glow.filter(ImageFilter.GaussianBlur(9))
            img = Image.composite(Image.new("RGBA", img.size, (255, 214, 120, 255)), img, glow)
        crayon_poly(img, [(56, 60), (64, 60), (66, 176), (54, 176)], WOOD, width=3)
        crayon_poly(img, [(40, 170), (80, 170), (82, 178), (38, 178)], shade(WOOD, -30), width=3, smooth=False)
        body = (255, 170, 60, 255) if lit else (150, 156, 176, 255)
        crayon_poly(img, ellipse_points(60, 52, 32, 38, 28), body, width=4)
        for dx in (-16, 0, 16):
            ink_line(img, [(60 + dx, 18), (60 + dx * 1.2, 52), (60 + dx, 86)], width=2, color=shade(body, -60))
        crayon_poly(img, [(46, 10), (74, 10), (72, 18), (48, 18)], INK, outline=False)
        crayon_poly(img, [(46, 86), (74, 86), (72, 94), (48, 94)], INK, outline=False)
        paper_grain(img).save(out("props", name + ".png"))


def build_grapple_ring():
    """A brass mooring ring on a nail: the Tape Tail sticks to these."""
    ss = 4
    big = Image.new("RGBA", (80 * ss, 80 * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rectangle([34 * ss, 0, 46 * ss, 28 * ss], fill=INK)
    d.rectangle([37 * ss, 2 * ss, 43 * ss, 26 * ss], fill=shade(BRASS, -50))
    d.ellipse([10 * ss, 22 * ss, 70 * ss, 78 * ss], outline=INK, width=16 * ss)
    d.ellipse([13 * ss, 25 * ss, 67 * ss, 75 * ss], outline=BRASS, width=10 * ss)
    d.arc([16 * ss, 28 * ss, 64 * ss, 72 * ss], 200, 280, fill=shade(BRASS, 70), width=3 * ss)
    img = big.resize((80, 80), Image.LANCZOS)
    paper_grain(img).save(out("props", "grapple_ring.png"))


def build_blotter():
    """A sheet of pink blotting paper on a peg, for soaking up ink."""
    img = Image.new("RGBA", (320, 200), (0, 0, 0, 0))
    crayon_poly(img, [(10, 20), (310, 20), (310, 44), (10, 44)], WOOD, width=5, smooth=False)
    crayon_poly(img, [(24, 40), (296, 40), (290, 188), (30, 192)], PINK, width=5)
    for y in (80, 120, 160):
        ink_line(img, [(40, y), (280, y + 4)], width=2, wobble=0.8, color=shade(PINK, -40))
    crayon_poly(img, ellipse_points(160, 18, 16, 16, 20), BRASS, width=4)
    paper_grain(img).save(out("props", "blotter.png"))


def _house(name, wall, roof, w=280, h=300):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    crayon_poly(img, [(30, 120), (w - 30, 120), (w - 30, h - 6), (30, h - 6)], wall, width=6, smooth=False)
    crayon_poly(img, [(14, 128), (w / 2, 12), (w - 14, 128)], roof, width=6, smooth=False)
    for i in range(1, 4):
        y = 128 - i * 28
        half = (w / 2 - 14) * (1 - i * 28 / 116)
        ink_line(img, [(w / 2 - half, y), (w / 2 + half, y)], width=2, color=shade(roof, -50))
    # Glowing window with a little window box of flowers, and a round door.
    crayon_poly(img, [(56, 160), (116, 160), (116, 214), (56, 214)], (255, 210, 110, 255), width=5, smooth=False)
    ink_line(img, [(86, 160), (86, 214)], width=4)
    ink_line(img, [(56, 187), (116, 187)], width=4)
    crayon_poly(img, [(50, 214), (122, 214), (118, 230), (54, 230)], shade(WOOD, -10), width=3, smooth=False)
    crayon_poly(img, [(w - 112, h - 6), (w - 112, 200), (w - 82, 182), (w - 52, 200), (w - 52, h - 6)], shade(roof, -40), width=5, smooth=False)
    ImageDraw.Draw(img).ellipse([w - 66, 240, w - 58, 248], fill=BRASS)
    # Matchbox side stripe, because every house in Lanternfold started life as one.
    crayon_poly(img, [(30, h - 30), (w - 30, h - 30), (w - 30, h - 20), (30, h - 20)], shade(wall, -30), outline=False, smooth=False)
    paper_grain(img).save(out("props", name + ".png"))


def build_houses():
    _house("house_red", CREAM, TOMATO)
    _house("house_teal", (255, 228, 188, 255), TEAL)
    _house("house_gold", (246, 236, 220, 255), MARIGOLD)
    _house("house_lilac", CREAM, LILAC)


def build_theater():
    w, h = 360, 340
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    crayon_poly(img, [(20, 90), (w - 20, 90), (w - 20, h - 6), (20, h - 6)], (130, 60, 80, 255), width=6, smooth=False)
    # Striped awning.
    for i in range(8):
        x0 = 10 + i * (w - 20) / 8
        x1 = x0 + (w - 20) / 8
        crayon_poly(img, [(x0, 54), (x1, 54), (x1, 104), (x0 + (x1 - x0) / 2, 116), (x0, 104)], TOMATO if i % 2 == 0 else CREAM, width=3, smooth=False)
    crayon_poly(img, [(70, 8), (w - 70, 8), (w - 70, 52), (70, 52)], MARIGOLD, width=5, smooth=False)
    # Lit shadow screen with a fox-shaped shadow on it.
    crayon_poly(img, [(70, 140), (w - 70, 140), (w - 70, 270), (70, 270)], (255, 226, 150, 255), width=5, smooth=False)
    crayon_poly(img, [(150, 250), (160, 200), (190, 196), (200, 170), (210, 196), (222, 172), (228, 204), (236, 250)], (60, 40, 50, 255), outline=False)
    for x in (40, w - 64):
        crayon_poly(img, [(x, 128), (x + 24, 128), (x + 24, h - 6), (x, h - 6)], TOMATO, width=4, smooth=False)
    paper_grain(img).save(out("props", "theater.png"))


def build_flap_gate():
    """A soggy cardboard flap that seals a passage under the harbor."""
    img = Image.new("RGBA", (128, 320), (0, 0, 0, 0))
    crayon_poly(img, [(8, 6), (120, 6), (120, 314), (8, 314)], shade(CARDBOARD, -20), width=6, smooth=False)
    for y in range(30, 300, 24):
        ink_line(img, [(18, y), (110, y + 3)], width=2, wobble=0.6, color=shade(CARDBOARD, -70))
    crayon_poly(img, [(8, 230), (120, 210), (120, 314), (8, 314)], (110, 130, 180, 200), outline=False, smooth=False)
    crayon_poly(img, [(30, 40), (98, 34), (100, 60), (32, 66)], (240, 232, 190, 230), width=3, wobble=0.6)
    paper_grain(img).save(out("props", "flap_gate.png"))


def build_moored_boat():
    """Corrugate's leaky little cardboard steamer, moored at the dock."""
    img = Image.new("RGBA", (320, 200), (0, 0, 0, 0))
    crayon_poly(img, [(10, 100), (310, 100), (270, 180), (50, 180)], CARDBOARD, width=6)
    crayon_poly(img, [(90, 50), (210, 50), (210, 100), (90, 100)], CREAM, width=5, smooth=False)
    crayon_poly(img, [(170, 8), (196, 8), (196, 50), (170, 50)], TOMATO, width=4, smooth=False)
    for x in (110, 150):
        crayon_poly(img, ellipse_points(x, 74, 12, 12, 16), SKY, width=3)
    crayon_poly(img, [(220, 140), (250, 132), (252, 160), (222, 166)], (130, 160, 210, 255), width=3)
    paper_grain(img).save(out("props", "moored_boat.png"))


# ----------------------------------------------------------------------- backgrounds


def build_ink_sea():
    """Under the harbor flap: a deep sea of ink, lit from the flap opening above."""
    w, h = 1920, 1080
    img = _sky_gradient(w, h, (70, 96, 168, 255), (24, 30, 70, 255))
    rays = Image.new("L", (w, h), 0)
    rd = ImageDraw.Draw(rays)
    for x in (260, 760, 1220, 1660):
        rd.polygon([(x - 60, 0), (x + 60, 0), (x + 260, h), (x + 40, h)], fill=60)
    rays = rays.filter(ImageFilter.GaussianBlur(40))
    img = Image.composite(Image.new("RGBA", (w, h), (200, 220, 255, 255)), img, rays)
    # Far reef silhouettes.
    pts = [(x, 760 - math.sin(x / w * math.tau * 3) * 60 - math.sin(x / w * math.tau * 7) * 20) for x in range(-40, w + 41, 20)]
    crayon_poly(img, pts + [(w + 40, h + 40), (-40, h + 40)], (44, 58, 120, 255), width=5, smooth=False, shadow=True)
    ink_line(img, pts, width=5, color=(28, 34, 70, 255))
    # Ribbon seaweed and paper fish.
    for x in range(80, w, 220):
        base = 900
        col = rng.choice([SAGE, TEAL, (246, 134, 150, 255)])
        sway = [(x + math.sin(i / 3.0 + x) * 22, base - i * 34) for i in range(10)]
        ink_line(img, sway, width=18, color=shade(col, -40))
        ink_line(img, sway, width=10, color=col)
    for _ in range(9):
        fx, fy = rng.uniform(100, w - 100), rng.uniform(160, 640)
        col = rng.choice([MARIGOLD, TOMATO, CREAM, PINK])
        crayon_poly(img, [(fx - 40, fy), (fx, fy - 20), (fx + 34, fy), (fx, fy + 20)], col, width=4, smooth=False)
        crayon_poly(img, [(fx - 40, fy), (fx - 62, fy - 16), (fx - 62, fy + 16)], shade(col, -30), width=3, smooth=False)
        button_eye(img, int(fx + 16), int(fy - 4), 4)
    d = ImageDraw.Draw(img)
    for _ in range(70):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h * 0.85), rng.uniform(4, 12)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(190, 210, 255, 200), width=3)
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_ink_sea.png"))


def build_theater_stage():
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), (36, 24, 40, 255))
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).rectangle([420, 140, 1500, 760], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    img = Image.composite(Image.new("RGBA", (w, h), (255, 196, 110, 255)), img, glow)
    crayon_poly(img, [(470, 170), (1450, 170), (1450, 720), (470, 720)], (255, 232, 170, 255), width=10, smooth=False)
    for x0, x1 in ((0, 420), (1500, w)):
        crayon_poly(img, [(x0, 0), (x1, 0), (x1, h), (x0, h)], (170, 40, 60, 255), width=8, smooth=False)
        for x in range(int(x0) + 40, int(x1), 70):
            ink_line(img, [(x, 0), (x + math.sin(x) * 12, h)], width=6, color=(120, 24, 40, 255))
    crayon_poly(img, [(0, 0), (w, 0), (w, 110), (0, 130)], (190, 50, 70, 255), width=8, smooth=False)
    crayon_poly(img, [(0, 820), (w, 820), (w, h), (0, h)], WOOD, width=8, smooth=False)
    for y in (880, 960, 1040):
        ink_line(img, [(0, y), (w, y)], width=3, color=shade(WOOD, -50))
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_shadow_theater.png"))


def build_dad_table_late():
    """Interlude 2: the same table, later and colder. Nell's chair pushed back."""
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), (40, 36, 52, 255))
    crayon_poly(img, [(0, 640), (w, 600), (w, h), (0, h)], shade(WOOD, -50), width=8, density=0.5)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([620, 160, 1460, 1000], fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(150))
    img = Image.composite(Image.new("RGBA", (w, h), (255, 206, 140, 255)), img, glow)
    crayon_poly(img, [(840, 0), (860, 0), (860, 150), (840, 150)], INK, outline=False)
    crayon_poly(img, [(740, 150), (960, 150), (1010, 280), (690, 280)], MARIGOLD, width=7)
    crayon_poly(img, [(560, 760), (950, 730), (950, 890), (560, 920)], CREAM, width=6)
    crayon_poly(img, [(950, 730), (1340, 760), (1340, 920), (950, 890)], (244, 236, 214, 255), width=6)
    # The harbor page: a little blue sea and a lantern.
    crayon_poly(img, [(990, 840), (1300, 850), (1300, 900), (990, 880)], (90, 130, 200, 255), width=4)
    crayon_poly(img, ellipse_points(1120, 800, 20, 24, 18), MARIGOLD, width=3)
    for x in (620, 1040):
        crayon_poly(img, [(x, 780), (x + 90, 770), (x + 92, 800), (x + 2, 810)], (236, 226, 176, 220), width=3, wobble=0.6)
    # Nell's chair, pushed back from the table and empty.
    chair = (96, 132, 186, 255)
    crayon_poly(img, [(1600, 500), (1780, 500), (1780, 760), (1600, 760)], chair, width=6, smooth=False)
    crayon_poly(img, [(1630, 540), (1750, 540), (1750, 720), (1630, 720)], shade(chair, -30), width=4, smooth=False)
    crayon_poly(img, [(1560, 760), (1800, 760), (1800, 800), (1560, 800)], chair, width=6, smooth=False)
    for x in (1574, 1772):
        crayon_poly(img, [(x, 800), (x + 18, 800), (x + 18, 980), (x, 980)], shade(chair, -20), width=5, smooth=False)
    # Rain on the dark window.
    crayon_poly(img, [(80, 120), (460, 120), (460, 480), (80, 480)], (30, 40, 76, 255), width=10)
    d = ImageDraw.Draw(img)
    for _ in range(60):
        x, y = rng.uniform(90, 450), rng.uniform(130, 470)
        d.line([(x, y), (x - 6, y + 22)], fill=(150, 170, 220, 255), width=2)
    paper_grain(img, 8).convert("RGB").save(out("backgrounds", "bg_dad_table_late.png"))


def build():
    build_kraken()
    build_lanterns()
    build_grapple_ring()
    build_blotter()
    build_houses()
    build_theater()
    build_moored_boat()
    build_flap_gate()
    build_ink_sea()
    build_theater_stage()
    build_dad_table_late()
