"""Character art: Patch and the cast, in the papercraft style of Patch's
turnaround sheet (docs/art/patch_turnaround.png).

Every character is cut and folded from paper: shapes are edged in a deep shade
of their own colour and broken into flat facets that catch the light, with
running stitches on mended seams and sewn-on button eyes. (The Soggies are the
exception: their buttons washed away, so they glare.) Textures are drawn at
twice the size the scenes show them, so they stay sharp.

Run through generate_art.py (it calls build()).
"""

import math
import random

import numpy as np
from PIL import Image, ImageDraw

from generate_art import (
    CARDBOARD,
    CREAM,
    INK,
    _supersample,
    crayon_poly,
    edge_color,
    ellipse_points,
    facets,
    ink_line,
    out,
    paper_grain,
    shade,
)

WOOL = (246, 240, 226, 255)
DAMP_WOOL = (196, 212, 230, 255)
SHEEP_FACE = (64, 52, 50, 255)
SHELL_TOP = (206, 142, 80, 255)
NAVY = (52, 64, 110, 255)
BRASS = (236, 186, 70, 255)
SOGG_PAPER = (196, 210, 230, 255)
LILAC_PAPER = (196, 190, 226, 255)


def organic(points, radius=16.0, steps=8):
    """Rounds every corner by `radius`, except points written (x, y, 0) which stay sharp."""
    n = len(points)
    result = []
    for i in range(n):
        p0, p1, p2 = points[i - 1][:2], points[i][:2], points[(i + 1) % n][:2]
        r_here = 1.5 if len(points[i]) > 2 else radius
        la, lb = math.dist(p0, p1), math.dist(p1, p2)
        if la < 1e-6 or lb < 1e-6:
            continue
        r = min(r_here, la * 0.48, lb * 0.48)
        a = (p1[0] + (p0[0] - p1[0]) * r / la, p1[1] + (p0[1] - p1[1]) * r / la)
        b = (p1[0] + (p2[0] - p1[0]) * r / lb, p1[1] + (p2[1] - p1[1]) * r / lb)
        for k in range(steps + 1):
            t = k / steps
            result.append((
                (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t * t * b[0],
                (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t * t * b[1],
            ))
    return result


def part(img, points, color, width=6, radius=16.0, shadow=True, seed=None):
    """One body part, cut from paper: a rounded shape with a slightly torn edge, edged
    in a darker shade of its colour and folded into flat facets that catch the light."""
    pts = organic(points, radius)
    r = random.Random(seed if seed is not None else int(sum(p[0] * 3.1 + p[1] for p in points[:4])))
    pts = [(x + r.uniform(-0.9, 0.9), y + r.uniform(-0.9, 0.9)) for x, y in pts]
    ss = _supersample(img)
    w, h = img.size
    hp = [(x * ss, y * ss) for x, y in pts]
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ow = max(2.0, width * 0.75) * ss
    edge = edge_color(color)
    d.line(hp + [hp[0], hp[1]], fill=edge, width=int(ow * 2), joint="curve")
    for x, y in hp[:: max(1, len(hp) // 24)]:
        d.ellipse([x - ow, y - ow, x + ow, y + ow], fill=edge)
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).polygon(hp, fill=255)
    layer.paste(color[:3] + (255,), (0, 0), mask)
    img.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    if shadow:
        facets(img, mask.resize((w, h), Image.LANCZOS), r.random())


def stitches(img, points, color=(242, 226, 190, 255), step=9.0, size=3.0):
    """A line of short running stitches along a path, like a mended seam."""
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        length = math.dist((ax, ay), (bx, by))
        n = max(1, int(length / step))
        for i in range(n):
            t = (i + 0.5) / n
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            nx, ny = -(by - ay) / max(1e-6, length), (bx - ax) / max(1e-6, length)
            ink_line(img, [(x - nx * size, y - ny * size), (x + nx * size, y + ny * size)], width=1.5, wobble=0, color=color)


def button(img, cx, cy, r, color=(36, 52, 132, 255), thread=(238, 196, 110, 255)):
    """A sewn-on button eye: a domed button with a rim and an X of thread."""
    crayon_poly(img, ellipse_points(cx, cy, r, r, 32), color, width=max(1.5, r * 0.12), smooth=False, shadow=True)
    crayon_poly(img, ellipse_points(cx, cy, r * 0.72, r * 0.72, 28), shade(color, 18), outline=False, shadow=False)
    ink_line(img, [(cx - r * 0.72, cy), (cx + r * 0.72, cy)], width=0.1, wobble=0, color=shade(color, 18))
    k = r * 0.32
    for sx in (-1, 1):
        ink_line(img, [(cx - k, cy - k * sx), (cx + k, cy + k * sx)], width=max(1.4, r * 0.16), wobble=0, color=thread)
    crayon_poly(img, ellipse_points(cx - r * 0.42, cy - r * 0.48, r * 0.2, r * 0.13, 12), (255, 255, 255, 200), outline=False, shadow=False)


def texture(img, points, strokes, radius=16.0):
    """Draws `strokes` (list of (points, color, width)) clipped inside a shape."""
    ss = _supersample(img)
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for pts, color, lw in strokes:
        d.line([(x * ss, y * ss) for x, y in pts], fill=color, width=max(1, int(lw * ss)), joint="curve")
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).polygon([(x * ss, y * ss) for x, y in organic(points, radius)], fill=255)
    clipped = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    alpha = np.minimum(np.asarray(mask), np.asarray(layer.split()[3])).astype(np.uint8)
    clipped.paste(layer, (0, 0), Image.fromarray(alpha))
    img.alpha_composite(clipped.resize((w, h), Image.LANCZOS))


def fur(img, points, color, count, length, angle, seed, radius=16.0, spread=0.35):
    """Short fur strokes in darker and lighter tones of `color`, flowing along `angle`."""
    r = random.Random(seed)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    strokes = []
    for i in range(count):
        x, y = r.uniform(min(xs), max(xs)), r.uniform(min(ys), max(ys))
        a = angle + r.uniform(-spread, spread)
        ln = length * r.uniform(0.6, 1.2)
        mid = (x + math.cos(a) * ln * 0.5 + r.uniform(-1.5, 1.5), y + math.sin(a) * ln * 0.5)
        end = (x + math.cos(a) * ln, y + math.sin(a) * ln)
        tone = shade(color, -42)[:3] + (120,) if i % 3 else shade(color, 34)[:3] + (110,)
        strokes.append(([(x, y), mid, end], tone, 1.6))
    texture(img, points, strokes, radius)


def ridges(img, points, color, x0, x1, step, angle=1.57, radius=16.0, dark=-40):
    """Parallel fabric ridges (corduroy, cardboard flutes) across a shape."""
    ys = [p[1] for p in points]
    top, bottom = min(ys) - 20, max(ys) + 20
    lean = math.cos(angle) / max(0.1, math.sin(angle))
    strokes = []
    x = x0
    while x < x1:
        strokes.append(([(x, top), (x + (bottom - top) * lean, bottom)], shade(color, dark)[:3] + (150,), 1.8))
        x += step
    texture(img, points, strokes, radius)


def real_eye(img, cx, cy, rx, ry, iris, look=(1.0, 0.0), width=3):
    """An almond eye with white, coloured iris, pupil and highlight (for the Soggies,
    whose button eyes were washed away)."""
    almond = [(cx - rx, cy, 0), (cx - rx * 0.3, cy - ry), (cx + rx * 0.6, cy - ry * 0.9), (cx + rx, cy, 0),
              (cx + rx * 0.4, cy + ry * 0.85), (cx - rx * 0.4, cy + ry * 0.8)]
    part(img, almond, (252, 244, 228, 255), width=width, radius=rx * 0.5, shadow=False)
    ir = ry * 0.92
    ix, iy = cx + look[0] * rx * 0.28, cy + look[1] * ry * 0.2
    crayon_poly(img, ellipse_points(ix, iy, ir, ir, 20), iris, outline=False, shadow=False)
    crayon_poly(img, ellipse_points(ix, iy, ir * 0.5, ir * 0.62, 16), INK, outline=False, shadow=False)
    crayon_poly(img, ellipse_points(ix - ir * 0.38, iy - ir * 0.38, ir * 0.3, ir * 0.3, 12), (255, 255, 255, 255), outline=False, shadow=False)
    ink_line(img, [(cx - rx - 1, cy + 1), (cx - rx * 0.3, cy - ry - 1), (cx + rx * 0.6, cy - ry * 0.9 - 1), (cx + rx + 1, cy)], width=width * 0.8, wobble=0)


# --------------------------------------------------------------------------- Patch


def _rot(points, pivot, angle):
    """Turns points about a pivot (keeps the sharp-corner marker on (x, y, 0) points)."""
    c, s = math.cos(angle), math.sin(angle)
    result = []
    for p in points:
        dx, dy = p[0] - pivot[0], p[1] - pivot[1]
        q = (pivot[0] + dx * c - dy * s, pivot[1] + dx * s + dy * c)
        result.append(q + tuple(p[2:]))
    return result


# Patch's poses, as (near leg, far leg, near arm, far arm) swings in radians
# (negative swings forward), plus how far the body drops so the feet stay planted.
PATCH_POSES = [
    (0.0, 0.0, 0.0, 0.0, 0),        # 0 standing
    (-0.42, 0.36, 0.42, -0.36, 4),  # 1 stride, near leg forward
    (-0.04, 0.04, 0.03, -0.03, 0),  # 2 passing
    (0.36, -0.42, -0.42, 0.36, 4),  # 3 stride, far leg forward
    (-0.6, 0.3, -1.4, -1.1, 0),     # 4 jumping, arms up
]
HIP_NEAR, HIP_FAR = (206, 252), (184, 252)
SHOULDER_NEAR, SHOULDER_FAR = (208, 176), (180, 178)
PATCH_ORANGE = (238, 120, 40, 255)
PATCH_CREAM = (246, 222, 190, 255)
BANDANA = (214, 44, 64, 255)
TORN = (250, 244, 232, 255)


def build_patch():
    """Patch, from his turnaround sheet (docs/art/patch_turnaround.png): a paper fox
    folded from orange paper, big head and ears, stitched-on navy button eyes, a red
    bandana, mitten paws, and a torn stump where his tail used to be. Side view
    facing right.

    Saved as a strip of five frames (see PATCH_POSES) for a simple walk cycle."""
    size = 320
    strip = Image.new("RGBA", (size * len(PATCH_POSES), size), (0, 0, 0, 0))
    for i, pose in enumerate(PATCH_POSES):
        frame = _draw_patch(pose)
        strip.alpha_composite(frame, (i * size, pose[4]))
    paper_grain(strip, 5).save(out("characters", "patch.png"))


def _draw_patch(pose):
    near_leg_a, far_leg_a, near_arm_a, far_arm_a, _ = pose
    img = Image.new("RGBA", (320, 320), (0, 0, 0, 0))
    o = PATCH_ORANGE
    back = shade(o, -26)

    # Far leg and foot.
    L = lambda pts: _rot(pts, HIP_FAR, far_leg_a)
    part(img, L([(170, 244), (200, 244), (198, 284), (204, 298, 0), (166, 298, 0), (168, 280)]), back, width=5, radius=8, seed=1)
    # Far arm.
    A = lambda pts: _rot(pts, SHOULDER_FAR, far_arm_a)
    part(img, A([(172, 172), (192, 170), (194, 214), (188, 232), (170, 232), (166, 210)]), back, width=5, radius=10, seed=2)

    # Torn tail stump with white paper fibres where it ripped.
    stump = [(178, 226), (150, 214), (130, 218), (122, 228, 0), (128, 236), (120, 244, 0), (132, 250), (150, 252), (180, 250)]
    part(img, stump, o, width=5, radius=8, seed=3)
    tear = [(134, 216), (124, 226), (130, 233), (121, 243), (133, 251), (139, 244), (134, 236), (140, 228)]
    crayon_poly(img, tear, TORN, width=1.5, smooth=False, shadow=False)
    for fy in (222, 231, 240, 248):
        ink_line(img, [(126, fy), (118, fy + 2)], width=1.2, wobble=0, color=TORN)

    # Body: a stubby folded-paper torso.
    body = [(172, 164), (230, 160), (240, 206), (236, 256), (176, 258), (166, 208)]
    part(img, body, o, width=6, radius=14, seed=4)
    stitches(img, [(224, 174), (232, 210), (230, 248)])
    stitches(img, [(178, 236), (200, 240)], step=8)

    # Near leg and foot, chunky and folded.
    L = lambda pts: _rot(pts, HIP_NEAR, near_leg_a)
    part(img, L([(192, 244), (226, 244), (228, 282), (244, 288), (246, 299, 0), (190, 299, 0), (192, 280)]), o, width=6, radius=8, seed=5)
    ink_line(img, L([(194, 284), (226, 284)]), width=1.4, wobble=0, color=shade(o, -60))

    # Red bandana: a band round the neck, knot at the back, point at the front.
    part(img, [(174, 150), (236, 146), (240, 166), (176, 170)], BANDANA, width=5, radius=6, seed=6)
    part(img, [(208, 156), (246, 156), (230, 196, 0)], BANDANA, width=5, radius=5, seed=7)
    part(img, [(176, 152), (150, 140, 0), (156, 160), (144, 176, 0), (178, 168)], shade(BANDANA, -16), width=4, radius=4, seed=8)
    crayon_poly(img, ellipse_points(174, 160, 9, 8, 16), shade(BANDANA, -30), width=2, smooth=False)

    # Near arm with a mitten paw.
    A = lambda pts: _rot(pts, SHOULDER_NEAR, near_arm_a)
    part(img, A([(198, 168), (222, 166), (230, 206), (234, 226), (218, 236), (204, 224), (200, 200)]), o, width=5, radius=10, seed=9)
    ink_line(img, A([(220, 226), (226, 232)]), width=1.3, wobble=0, color=shade(o, -60))

    # Head: big and angular, with a pointed snout.
    far_ear = [(150, 66), (160, 4, 0), (196, 50)]
    part(img, far_ear, back, width=6, radius=5, seed=10)
    head = [(132, 96), (142, 56), (174, 34), (220, 34), (252, 54), (270, 82), (300, 106, 0), (282, 122), (250, 140),
            (210, 152), (164, 150), (138, 128)]
    part(img, head, o, width=7, radius=14, seed=11)
    # Cream muzzle under the snout.
    part(img, [(244, 112), (296, 108, 0), (282, 122), (252, 138), (236, 130)], PATCH_CREAM, width=4, radius=8, seed=12)
    # Open, grinning mouth with a little fang.
    part(img, [(262, 118), (288, 116), (276, 132), (256, 136), (250, 126)], (110, 24, 36, 255), width=3.5, radius=6, shadow=False, seed=13)
    crayon_poly(img, organic([(258, 128), (272, 130), (264, 136)], 3), (236, 110, 120, 255), outline=False, shadow=False)
    crayon_poly(img, [(279, 117), (285, 117), (282, 126)], (255, 255, 255, 255), width=1.2, smooth=False, shadow=False)
    # Nose.
    part(img, [(290, 98), (304, 104, 0), (296, 112)], (30, 24, 30, 255), width=2.5, radius=4, shadow=False, seed=14)
    # Near ear with a cream inside.
    near_ear = [(176, 52), (204, 0, 0), (230, 44)]
    part(img, near_ear, o, width=6, radius=5, seed=15)
    part(img, [(188, 48), (204, 14, 0), (220, 44)], PATCH_CREAM, width=3, radius=5, seed=16)
    # Stitched seam over the top of the head, and the button eye.
    stitches(img, [(150, 92), (168, 60), (200, 46)], step=10)
    button(img, 238, 84, 19)
    return img


# --------------------------------------------------------------------- the flock


def cloud(cx, cy, rx, ry, bumps, depth, phase=0.0):
    """A bumpy, fleecy outline: an ellipse with rounded scallops all the way round."""
    pts = []
    n = bumps * 8
    for i in range(n):
        a = i / n * math.tau + phase
        bump = abs(math.sin(i / 8 * math.pi)) * depth
        pts.append((cx + math.cos(a) * (rx + bump), cy + math.sin(a) * (ry + bump)))
    return pts


def wool(img, points, color, count, seed, size=7.0):
    """Little curls of fleece across a shape."""
    r = random.Random(seed)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    strokes = []
    for i in range(count):
        x, y = r.uniform(min(xs), max(xs)), r.uniform(min(ys), max(ys))
        a0 = r.uniform(0, math.tau)
        rad = size * r.uniform(0.7, 1.2)
        arc = [(x + math.cos(a0 + k * 0.5) * rad, y + math.sin(a0 + k * 0.5) * rad) for k in range(8)]
        tone = shade(color, -46)[:3] + (150,) if i % 4 else shade(color, 30)[:3] + (160,)
        strokes.append((arc, tone, 2.0))
    crayon_poly(img, points, color, width=6, smooth=False)
    texture(img, points, strokes, radius=1)


def creases(img, points, color, count, seed, length=40):
    """Straight light and dark fold lines, for paper that has been folded or crumpled."""
    r = random.Random(seed)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    strokes = []
    for i in range(count):
        x, y = r.uniform(min(xs), max(xs)), r.uniform(min(ys), max(ys))
        a = r.uniform(0, math.pi)
        ln = length * r.uniform(0.5, 1.2)
        end = (x + math.cos(a) * ln, y + math.sin(a) * ln)
        strokes.append(([(x, y), end], shade(color, -50)[:3] + (150,), 1.8))
        strokes.append(([(x + 1.5, y + 1.5), (end[0] + 1.5, end[1] + 1.5)], shade(color, 50)[:3] + (140,), 1.4))
    texture(img, points, strokes, radius=4)


def hoof_leg(img, x, top, bottom, color, width=16, facing=1.0):
    """A thin, dark sheep leg with a knobbly knee and a split hoof."""
    knee = top + (bottom - top) * 0.55
    part(img, [(x - width * 0.5, top), (x + width * 0.5, top), (x + width * 0.42, knee), (x + width * 0.34, bottom - 8),
               (x - width * 0.34, bottom - 8), (x - width * 0.42, knee)], color, width=4, radius=5)
    part(img, [(x - width * 0.45, bottom - 12), (x + width * 0.55 * facing + 2, bottom - 12), (x + width * 0.6, bottom),
               (x - width * 0.5, bottom)], shade(color, -30), width=4, radius=3)
    ink_line(img, [(x + 1, bottom - 10), (x + 1, bottom - 1)], width=1.4, wobble=0, color=shade(color, 40))


# --------------------------------------------------------------------- the flock


def build_lost_sheep():
    """A flock sheep, soaked through: drooping blue-grey fleece, dark face, long ears."""
    w, h = 288, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    face = shade(SHEEP_FACE, -6)
    for x in (100, 176):
        hoof_leg(img, x, 160, 240, shade(face, -18))
    # Tail tuft.
    wool(img, cloud(44, 128, 16, 14, 4, 4), shade(DAMP_WOOL, -10), 6, 1)
    body = cloud(140, 134, 94, 58, 11, 9)
    wool(img, body, DAMP_WOOL, 90, 2)
    for x in (120, 196):
        hoof_leg(img, x, 168, 240, face)
    # Drips falling from the soggy fleece.
    for x, y in ((90, 196), (150, 204), (204, 194)):
        part(img, [(x - 5, y), (x, y - 12, 0), (x + 5, y), (x, y + 7)], (140, 186, 232, 255), width=2.5, radius=4)
    # Head: long dark face with a woolly fringe and floppy ears.
    part(img, [(186, 104), (178, 116, 0), (160, 124), (166, 112)], shade(face, 10), width=4, radius=6)
    head = [(198, 82), (230, 80), (262, 98), (272, 120), (262, 138), (238, 142), (208, 128), (196, 108)]
    part(img, head, face, width=6, radius=18)
    part(img, [(224, 104), (246, 96), (240, 112, 0), (230, 116)], shade(face, 18), width=4, radius=5)
    wool(img, cloud(212, 82, 22, 15, 5, 4), DAMP_WOOL, 12, 3, size=5)
    button(img, 236, 102, 9, color=(214, 168, 72, 255), thread=(80, 50, 30, 255))
    ink_line(img, [(262, 112), (266, 118)], width=2, wobble=0, color=shade(face, 60))
    ink_line(img, [(266, 128), (256, 132), (248, 130)], width=2, wobble=0, color=shade(face, 60))
    paper_grain(img, 6).save(out("characters", "lost_sheep.png"))


def build_shepherd_fluff():
    """Shepherd Fluff: an old ewe who stands on two legs, in a knitted shawl and
    round spectacles, leaning on her crook. Faces right."""
    w, h = 240, 300
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    face = SHEEP_FACE
    # Crook (behind her near hand).
    staff = (176, 120, 72, 255)
    part(img, [(198, 70), (208, 70), (206, 292), (196, 292)], staff, width=4, radius=3)
    ink_line(img, [(203, 74), (204, 40), (190, 20), (170, 24), (164, 42), (172, 52)], width=7, wobble=0)
    ink_line(img, [(203, 74), (204, 40), (190, 20), (170, 24), (164, 42), (172, 52)], width=4, wobble=0, color=staff)
    # Legs.
    for x in (96, 132):
        hoof_leg(img, x, 236, 294, shade(face, -10 if x < 110 else 0))
    # Woolly body.
    wool(img, cloud(116, 186, 64, 64, 9, 7), WOOL, 70, 5)
    # Knitted shawl over her shoulders, pinned at the front.
    shawl = [(66, 130), (130, 116), (176, 134), (168, 176), (148, 214, 0), (122, 182), (84, 196, 0), (72, 164)]
    part(img, shawl, (170, 120, 200, 255), width=5, radius=10)
    texture(img, shawl, [([(x, 110), (x - 30, 220)], (130, 84, 160, 150), 2.2) for x in range(70, 210, 9)], radius=10)
    for fx in range(128, 152, 6):
        ink_line(img, [(fx + 18, 212 - (fx - 128) * 0.2), (fx + 16, 224)], width=1.6, wobble=0, color=(150, 100, 180, 255))
    crayon_poly(img, ellipse_points(150, 142, 6, 6, 14), (236, 186, 70, 255), width=2, smooth=False)
    # Near arm reaching to the crook.
    part(img, [(150, 140), (170, 136), (198, 158), (190, 170), (160, 162)], shade(WOOL, -10), width=5, radius=10)
    part(img, [(188, 152), (208, 150), (212, 166), (192, 172)], face, width=4, radius=6)
    # Head: wise long face, woolly cap, floppy ears and spectacles.
    part(img, [(112, 76), (100, 92, 0), (82, 98), (92, 84)], shade(face, 10), width=4, radius=6)
    head = [(110, 56), (142, 50), (176, 68), (190, 92), (180, 112), (154, 116), (124, 104), (110, 82)]
    part(img, head, face, width=6, radius=18)
    part(img, [(144, 80), (164, 72), (160, 88, 0), (150, 92)], shade(face, 18), width=4, radius=5)
    wool(img, cloud(122, 54, 26, 18, 6, 5), WOOL, 16, 6, size=5)
    button(img, 154, 76, 9, color=(214, 168, 72, 255), thread=(80, 50, 30, 255))
    for gx in (154,):
        ink_line(img, [(gx - 13, 76), (gx - 22, 72)], width=1.8, wobble=0, color=(220, 200, 150, 255))
    d = ImageDraw.Draw(img)
    d.ellipse([140, 63, 168, 89], outline=(232, 200, 120, 255), width=3)
    ink_line(img, [(180, 88), (184, 94)], width=2, wobble=0, color=shade(face, 60))
    ink_line(img, [(184, 102), (172, 106), (164, 103)], width=2, wobble=0, color=shade(face, 60))
    paper_grain(img, 6).save(out("characters", "shepherd_fluff.png"))


# --------------------------------------------------------------------------- Dot


def build_dot():
    """Dot, the runaway full stop: a glossy drop of ink with big eyes and stubby limbs."""
    s = 144
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ink = (40, 34, 52, 255)
    for x, end in ((56, 50), (86, 92)):
        ink_line(img, [(x, 110), (end, 128)], width=5, wobble=0, color=ink)
        part(img, [(end - 10, 124), (end + 10, 124), (end + 12, 134), (end - 10, 134)], ink, width=3, radius=5)
    for side in (-1, 1):
        ink_line(img, [(72 + side * 44, 84), (72 + side * 58, 98)], width=4, wobble=0, color=ink)
    part(img, ellipse_points(72, 72, 48, 46, 40), ink, width=4, radius=4)
    # Wet, glossy highlights.
    crayon_poly(img, ellipse_points(52, 46, 14, 8, 20), (130, 126, 170, 255), outline=False, shadow=False)
    crayon_poly(img, ellipse_points(46, 44, 5, 3, 12), (230, 230, 250, 255), outline=False, shadow=False)
    for ex in (60, 90):
        button(img, ex, 70, 12, color=(244, 238, 222, 255), thread=(60, 50, 70, 255))
    ink_line(img, [(64, 96), (76, 101), (88, 96)], width=2.2, wobble=0, color=(200, 196, 220, 255))
    paper_grain(img, 6).save(out("characters", "dot.png"))


# ------------------------------------------------------------------------ Soggy


def build_soggy():
    """A Soggy: a wad of soaked, crumpled paper that came alive, still dripping,
    with faded handwriting on it and a torn, toothy mouth."""
    s = 224
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    for x in (78, 142):
        part(img, [(x - 14, 180), (x + 14, 180), (x + 18, 210), (x - 18, 210)], shade(SOGG_PAPER, -70), width=5, radius=6)
    r = random.Random(9)
    body = []
    for i in range(18):
        a = i / 18 * math.tau + r.uniform(-0.08, 0.08)
        rad = r.choice((90, 84, 76)) + r.uniform(-4, 4)
        pt = (112 + math.cos(a) * rad, 112 + math.sin(a) * rad * 0.86)
        body.append(pt + ((0,) if i % 3 == 0 else ()))
    part(img, body, SOGG_PAPER, width=6, radius=10)
    # Ruled notebook lines and a red margin, run and smeared by the wet.
    lines = [([(x, y + (x - 20) * 0.08) for x in range(20, 206, 30)], (110, 150, 210, 170), 2.2) for y in range(48, 190, 16)]
    lines.append(([(56, 20), (64, 210)], (220, 110, 120, 170), 2.4))
    lines += [([(x, y), (x + 0.1, y)], (130, 150, 196, 90), r.uniform(18, 30)) for x, y in ((70, 70), (150, 150), (160, 60))]
    texture(img, body, lines, radius=10)
    creases(img, body, SOGG_PAPER, 18, 10, 46)
    # A folded-over dog-ear corner.
    part(img, [(150, 40), (186, 52, 0), (166, 76)], shade(SOGG_PAPER, -26), width=4, radius=3)
    # Mildew spots.
    texture(img, body, [([(x, y), (x + 0.1, y)], (120, 150, 104, 170), r.uniform(5, 10))
                        for x, y in ((60, 90), (150, 70), (170, 140), (70, 150), (120, 160))], radius=10)
    # Angry eyes under heavy brows.
    for ex, flip in ((84, 1), (140, -1)):
        real_eye(img, ex, 94, 15, 12, (226, 196, 60, 255), look=(0.0, 0.2), width=3)
        part(img, [(ex - 22 * flip, 70), (ex + 18 * flip, 82), (ex + 16 * flip, 92), (ex - 20 * flip, 80)],
             shade(SOGG_PAPER, -110), width=3, radius=4)
    # Torn mouth with ragged paper teeth.
    mouth = [(72, 132), (152, 128), (146, 156), (112, 166), (80, 156)]
    part(img, mouth, (40, 30, 56, 255), width=4, radius=10, shadow=False)
    for tx in range(80, 150, 12):
        crayon_poly(img, [(tx, 131), (tx + 10, 130), (tx + 5, 142)], CREAM, width=1.5, smooth=False, shadow=False)
    # Drips.
    for x, y in ((50, 176), (112, 196), (176, 172)):
        part(img, [(x - 6, y), (x, y - 14, 0), (x + 6, y), (x, y + 9)], (140, 186, 232, 255), width=2.5, radius=4)
    paper_grain(img, 6).save(out("characters", "soggy.png"))


# ------------------------------------------------------------------- Chapter 2


def scales(img, points, color, seed, size=9):
    """Small overlapping scales for reptile skin."""
    r = random.Random(seed)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    strokes = []
    y = min(ys)
    row = 0
    while y < max(ys):
        x = min(xs) + (size * 0.5 if row % 2 else 0)
        while x < max(xs):
            arc = [(x + math.cos(a) * size * 0.5, y + math.sin(a) * size * 0.45) for a in (0.2, 0.9, 1.6, 2.3, 2.9)]
            strokes.append((arc, shade(color, -40)[:3] + (120,), 1.4))
            x += size
        y += size * 0.7
        row += 1
    texture(img, points, strokes, radius=8)


def build_corrugate():
    """Corrugate: an old tortoise sea captain who stands upright, with a corrugated
    cardboard shell on his back, a navy coat with brass buttons, white whiskers,
    a bottle-cap hat and a spyglass. Faces right."""
    w, h = 280, 320
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    skin = (132, 160, 104, 255)
    # Far leg.
    leg = lambda x, c: part(img, [(x - 20, 252), (x + 20, 252), (x + 24, 300), (x + 28, 312), (x - 24, 312), (x - 20, 296)], c, width=5, radius=8)
    leg(150, shade(skin, -24))
    # The shell on his back: corrugated cardboard, taped where it has been mended.
    shell = [(150, 92), (100, 96), (56, 130), (36, 190), (48, 246), (92, 276), (150, 270)]
    part(img, shell, SHELL_TOP, width=7, radius=30)
    ridges(img, shell, SHELL_TOP, -40, 200, 9, angle=1.2, radius=30, dark=-56)
    part(img, [(150, 260), (88, 268), (56, 250, 0), (62, 240), (150, 248)], shade(SHELL_TOP, -40), width=5, radius=6)
    part(img, [(52, 150), (110, 132), (116, 152), (58, 172)], (242, 232, 190, 230), width=3, radius=3, shadow=False)
    # Near leg.
    leg(192, skin)
    for tx in (178, 192, 206):
        crayon_poly(img, ellipse_points(tx + 12, 308, 5, 4, 10), (240, 228, 200, 255), width=1.5, smooth=False, shadow=False)
    scales(img, [(170, 252), (214, 252), (218, 300), (168, 300)], skin, 3)
    # Navy captain's coat over a cream cardboard belly plate.
    part(img, [(146, 118), (214, 116), (232, 190), (222, 262), (150, 266)], (238, 214, 150, 255), width=6, radius=20)
    coat = [(140, 112), (196, 108), (212, 160, 0), (200, 214), (220, 262, 0), (178, 266), (140, 264)]
    part(img, coat, NAVY, width=6, radius=12)
    fur(img, coat, NAVY, 30, 14, 1.4, 12, radius=12, spread=0.1)
    for by in (150, 182, 214):
        for bx in (188, 202):
            crayon_poly(img, ellipse_points(bx - (214 - by) * 0.05, by, 5, 5, 14), BRASS, width=2, smooth=False)
    # Gold epaulette with a fringe.
    part(img, [(150, 108), (196, 104), (198, 122), (152, 126)], BRASS, width=4, radius=8)
    for fx in range(154, 198, 6):
        ink_line(img, [(fx, 124), (fx, 134)], width=2, wobble=0, color=shade(BRASS, -30))
    # Arm holding a brass spyglass.
    part(img, [(168, 122), (196, 120), (222, 170), (206, 182), (180, 152)], NAVY, width=5, radius=12)
    part(img, [(200, 168), (226, 164), (232, 178), (210, 188)], (230, 200, 120, 255), width=4, radius=4)
    part(img, [(220, 166), (238, 162), (244, 196), (226, 200)], skin, width=5, radius=8)
    part(img, [(206, 186), (266, 152), (272, 164), (212, 198)], BRASS, width=4, radius=4)
    part(img, [(258, 148), (274, 140), (280, 160), (264, 168)], shade(BRASS, -20), width=4, radius=3)
    for t in (0.35, 0.6):
        ink_line(img, [(206 + 60 * t, 186 - 34 * t), (212 + 60 * t, 198 - 34 * t)], width=1.6, wobble=0, color=shade(BRASS, -70))
    # Wrinkly neck and head with a hooked beak, heavy-lidded eye and white whiskers.
    neck = [(170, 110), (190, 70), (214, 64), (210, 112)]
    part(img, neck, skin, width=6, radius=12)
    for wy in (80, 92, 104):
        ink_line(img, [(186, wy), (206, wy - 3)], width=1.6, wobble=0, color=shade(skin, -50))
    head = [(186, 44), (222, 30), (256, 40), (270, 60), (264, 76, 0), (248, 82), (216, 86), (190, 72)]
    part(img, head, skin, width=6, radius=18)
    scales(img, head, skin, 4, size=8)
    part(img, [(250, 58), (272, 60), (266, 78, 0), (248, 74)], (226, 210, 160, 255), width=4, radius=4)
    button(img, 236, 52, 9, color=(120, 76, 44, 255))
    part(img, [(196, 70), (226, 76), (230, 96, 0), (214, 90), (206, 104, 0), (196, 88)], (246, 244, 236, 255), width=4, radius=6)
    # Bottle-cap captain's hat with a crimped rim and a stiff peak.
    cap = []
    for i in range(29):
        a = math.pi + i / 28 * math.pi
        rr = 34 if i % 2 == 0 else 30
        cap.append((222 + math.cos(a) * rr, 34 + math.sin(a) * rr * 0.6, 0))
    part(img, cap, (214, 50, 54, 255), width=5, radius=2)
    part(img, [(186, 30), (268, 28), (282, 38), (186, 40)], (40, 36, 56, 255), width=4, radius=4)
    crayon_poly(img, ellipse_points(222, 20, 7, 5, 14), BRASS, width=2, smooth=False)
    paper_grain(img, 6).save(out("characters", "corrugate.png"))


def build_crumple():
    """Crumple: Corrugate's ship's cat, folded from lilac paper. Sits facing right,
    tail curled round her paws, eyes half shut, deeply unimpressed."""
    w, h = 240, 240
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paper = LILAC_PAPER
    dark = shade(paper, -34)
    # Tail curling round the front.
    tail = [(60, 214), (30, 200), (24, 170), (40, 150, 0), (44, 176), (58, 196), (150, 210), (172, 222, 0), (150, 232), (70, 232)]
    part(img, tail, dark, width=5, radius=10)
    # Haunch and body, folded facets.
    body = [(60, 120), (118, 96), (166, 120), (176, 196), (164, 228, 0), (60, 228, 0), (46, 190)]
    part(img, body, paper, width=6, radius=14)
    creases(img, body, paper, 6, 21, 60)
    haunch = [(56, 160), (104, 150), (122, 200), (110, 228, 0), (56, 228, 0)]
    part(img, haunch, shade(paper, -14), width=5, radius=18)
    # Front legs and neat paws.
    for x, c in ((146, dark), (170, paper)):
        part(img, [(x - 10, 150), (x + 12, 150), (x + 12, 222), (x + 18, 230), (x - 12, 230)], c, width=5, radius=6)
    # Chest bib.
    part(img, [(150, 112), (190, 112), (186, 160), (166, 180, 0), (150, 150)], (246, 244, 250, 255), width=4, radius=8)
    # Head with folded-paper ears, a pink nose and long whiskers.
    head = [(134, 60), (150, 40), (186, 38), (212, 56), (220, 84), (206, 110), (170, 118), (140, 100)]
    part(img, head, paper, width=6, radius=18)
    creases(img, head, paper, 3, 22, 36)
    for ear in ([(142, 58), (144, 8, 0), (172, 42)], [(176, 42), (200, 6, 0), (210, 58)]):
        part(img, ear, paper, width=5, radius=4)
        mid = [(ear[0][0] + 7, ear[0][1] - 4), (ear[1][0] + (2 if ear[1][0] < 160 else 1), ear[1][1] + 14), (ear[2][0] - 8, ear[2][1] - 2)]
        part(img, mid, (240, 196, 214, 255), width=2.5, radius=3, shadow=False)
    part(img, [(198, 82), (226, 80), (222, 104), (200, 104)], (246, 244, 250, 255), width=4, radius=8)
    crayon_poly(img, [(218, 82), (228, 84), (222, 92)], (230, 120, 150, 255), width=2, smooth=False, shadow=False)
    ink_line(img, [(222, 94), (220, 100), (212, 102)], width=1.8, wobble=0)
    button(img, 196, 68, 11, color=(84, 160, 92, 255))
    button(img, 164, 66, 9, color=(70, 140, 80, 255))
    # Half-shut, unimpressed lids folded over the buttons.
    for ex, er in ((196, 11), (164, 9)):
        part(img, [(ex - er - 2, 68 - er - 2), (ex + er + 2, 68 - er - 2), (ex + er + 2, 66), (ex - er - 2, 66)], paper, width=3, radius=3, seed=ex)
    for wy, dy in ((92, -4), (98, 2), (104, 8)):
        ink_line(img, [(214, wy), (238, wy + dy)], width=1.2, wobble=0, color=(250, 248, 250, 255))
    paper_grain(img, 6).save(out("characters", "crumple.png"))


def _doll(img, cx, base, dress, hair, style, skin, seed):
    """One Lamplighter sister, facing the viewer: boots, a dress and apron, a face
    with real eyes and rosy cheeks, and her own hairstyle."""
    for lx in (cx - 16, cx + 16):
        part(img, [(lx - 10, base - 40), (lx + 10, base - 40), (lx + 12, base), (lx - 13, base)], (70, 50, 52, 255), width=4, radius=5)
    dress_pts = [(cx - 30, base - 150), (cx + 30, base - 150), (cx + 56, base - 36, 0), (cx - 56, base - 36, 0)]
    part(img, dress_pts, dress, width=6, radius=12)
    fur(img, dress_pts, dress, 30, 30, 1.57, seed, radius=12, spread=0.05)
    part(img, [(cx - 26, base - 116), (cx + 26, base - 116), (cx + 34, base - 50), (cx - 34, base - 50)], (250, 246, 236, 255), width=4, radius=10)
    part(img, [(cx - 12, base - 92), (cx + 12, base - 92), (cx + 12, base - 74), (cx - 12, base - 74)], shade((250, 246, 236, 255), -24), width=3, radius=4)
    # Collar and neck.
    part(img, [(cx - 8, base - 166), (cx + 8, base - 166), (cx + 8, base - 148), (cx - 8, base - 148)], skin, width=4, radius=4)
    part(img, [(cx - 24, base - 152), (cx, base - 140, 0), (cx + 24, base - 152), (cx + 18, base - 158), (cx - 18, base - 158)], (250, 246, 236, 255), width=3, radius=4)
    # Hair behind the head.
    if style == "braids":
        for side in (-1, 1):
            part(img, [(cx + side * 30, base - 210), (cx + side * 40, base - 150), (cx + side * 30, base - 140), (cx + side * 22, base - 196)], hair, width=4, radius=8)
            crayon_poly(img, ellipse_points(cx + side * 36, base - 140, 6, 5, 12), (214, 62, 66, 255), width=2, smooth=False)
    head = ellipse_points(cx, base - 202, 38, 42, 40)
    part(img, head, skin, width=6, radius=4)
    # Hair on top.
    if style == "bun":
        part(img, ellipse_points(cx, base - 252, 20, 16, 24), hair, width=5, radius=4)
        part(img, [(cx - 40, base - 196), (cx - 36, base - 236), (cx, base - 248), (cx + 36, base - 236), (cx + 40, base - 196), (cx + 26, base - 224), (cx - 26, base - 224)], hair, width=5, radius=14)
    elif style == "bob":
        part(img, [(cx - 44, base - 176), (cx - 42, base - 232), (cx, base - 250), (cx + 42, base - 232), (cx + 44, base - 176), (cx + 30, base - 182), (cx + 28, base - 218), (cx - 6, base - 222, 0), (cx - 28, base - 214), (cx - 30, base - 182)], hair, width=5, radius=12)
    else:
        part(img, [(cx - 40, base - 200), (cx - 34, base - 238), (cx, base - 250), (cx + 34, base - 238), (cx + 40, base - 200), (cx + 20, base - 226), (cx - 20, base - 226)], hair, width=5, radius=14)
    for ex in (cx - 15, cx + 15):
        button(img, ex, base - 200, 9, color=(52, 70, 140, 255))
    for chx in (cx - 22, cx + 22):
        crayon_poly(img, ellipse_points(chx, base - 184, 7, 4.5, 14), (246, 150, 150, 200), outline=False, shadow=False)
    ink_line(img, [(cx - 3, base - 192), (cx, base - 186)], width=1.6, wobble=0, color=shade(skin, -60))
    ink_line(img, [(cx - 10, base - 176), (cx, base - 172), (cx + 10, base - 176)], width=2.2, wobble=0)


def build_lamplighters():
    """The Lamplighter Sisters: three paper-doll sisters cut from one strip of paper,
    still joined at the hands. One carries a lamplighter's pole, one a lantern."""
    w, h = 600, 440
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    base = 424
    # Lamplighter's pole with a hook and a tiny lit wick (behind the left sister).
    part(img, [(146, 30), (154, 30), (156, 410), (144, 410)], (150, 100, 62, 255), width=4, radius=3)
    ink_line(img, [(150, 34), (150, 16), (168, 10), (176, 22)], width=4, wobble=0, color=BRASS)
    part(img, [(170, 22), (178, 8, 0), (186, 22), (178, 30)], (255, 200, 70, 255), width=2.5, radius=4, shadow=False)
    sisters = [
        (170, (214, 62, 66, 255), (120, 70, 44, 255), "bun", (246, 206, 170, 255)),
        (300, (232, 156, 52, 255), (60, 44, 40, 255), "braids", (214, 160, 120, 255)),
        (430, (90, 160, 150, 255), (220, 170, 90, 255), "bob", (250, 214, 184, 255)),
    ]
    # Joined hands: the paper strip they were cut from.
    for x0, x1 in ((206, 264), (336, 394)):
        part(img, [(x0, base - 128), (x1, base - 128), (x1, base - 112), (x0, base - 112)], (250, 236, 210, 255), width=4, radius=6)
    for i, (cx, dress, hair, style, skin) in enumerate(sisters):
        _doll(img, cx, base, dress, hair, style, skin, 50 + i)
    # Outer hands: one holds the pole, the other a paper lantern.
    part(img, [(126, base - 130), (148, base - 136), (152, base - 116), (130, base - 112)], sisters[0][4], width=4, radius=6)
    part(img, [(474, base - 130), (496, base - 120), (492, base - 104), (470, base - 112)], sisters[2][4], width=4, radius=6)
    ink_line(img, [(492, base - 112), (504, base - 92)], width=2, wobble=0)
    lantern = [(484, base - 92), (526, base - 92), (534, base - 60), (526, base - 30), (484, base - 30), (476, base - 60)]
    part(img, lantern, (250, 170, 70, 255), width=5, radius=14)
    for lx in (492, 505, 518):
        ink_line(img, [(lx, base - 90), (lx, base - 32)], width=1.6, wobble=0, color=(210, 110, 40, 255))
    crayon_poly(img, ellipse_points(505, base - 60, 10, 14, 16), (255, 240, 170, 255), outline=False, shadow=False)
    paper_grain(img, 6).save(out("characters", "lamplighter_sisters.png"))


def build():
    build_patch()
    build_lost_sheep()
    build_shepherd_fluff()
    build_dot()
    build_soggy()
    build_corrugate()
    build_crumple()
    build_lamplighters()


if __name__ == "__main__":
    build()
