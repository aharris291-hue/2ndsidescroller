"""Props for Region 2, Lanternfold at full size (Phase 3). Top-down pieces for the
2-3 Lamp Room beam puzzle.

Writes to assets/art/dark/props/:
  beam_mirror.png   a tarnished swivel mirror on an iron pivot, seen from above, its
                    glass running corner to corner like '/' (rotate 90 for '\'), 64 x 64
  wick_cold.png     a great oil wick in a brass dish, cold and sooted, 64 x 64
  wick_lit.png      the same wick burning, 64 x 64
  beam_lens.png     the cracked lamp lens set in the wall, throwing the beam, 64 x 64

Run: python3 tools/art/dark_props_r2.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

from dark_props_prologue import EDGE, BRASS, BRASS_DARK, STEEL, STEEL_DARK, S, canvas, finish, paper_texture

PROPS = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "dark", "props")

IRON = (52, 52, 58, 255)
GLASS = (122, 150, 160, 255)
GLASS_HI = (196, 214, 214, 255)
SOOT = (30, 28, 28, 255)


def mirror():
    w = h = 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    c = w / 2 * S
    # the pivot base: an iron disc with four bolts
    d.ellipse([c - 28 * S, c - 28 * S, c + 28 * S, c + 28 * S], fill=EDGE)
    d.ellipse([c - 25 * S, c - 25 * S, c + 25 * S, c + 25 * S], fill=IRON)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        bx, by = c + math.cos(a) * 20 * S, c + math.sin(a) * 20 * S
        d.ellipse([bx - 2 * S, by - 2 * S, bx + 2 * S, by + 2 * S], fill=STEEL_DARK)
    # the mirror: a long brass-framed pane from bottom-left to top-right ('/')
    def pane(half_len, half_w, fill):
        ax, ay = math.cos(-math.pi / 4), math.sin(-math.pi / 4)
        nx, ny = -ay, ax
        pts = []
        for sl, sw in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            pts.append((c + (ax * half_len * sl + nx * half_w * sw) * S, c + (ay * half_len * sl + ny * half_w * sw) * S))
        d.polygon(pts, fill=fill)
    pane(31, 8, EDGE)
    pane(29, 6, BRASS_DARK)
    pane(27, 4, BRASS)
    pane(25, 2.4, GLASS)
    # a glint along the glass
    d.line([(c - 10 * S, c + 9 * S), (c + 6 * S, c - 7 * S)], fill=GLASS_HI, width=S)
    # the swivel pin
    d.ellipse([c - 5 * S, c - 5 * S, c + 5 * S, c + 5 * S], fill=EDGE)
    d.ellipse([c - 3 * S, c - 3 * S, c + 3 * S, c + 3 * S], fill=STEEL)
    img = paper_texture(img, 201, 0.08, 3)
    return finish(img, w, h)


def wick(lit):
    w = h = 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    c = w / 2 * S
    for r, col in ((29, EDGE), (27, BRASS_DARK), (23, BRASS), (19, (60, 46, 26, 255)), (15, SOOT)):
        d.ellipse([c - r * S, c - r * S, c + r * S, c + r * S], fill=col)
    # three iron feet showing past the rim
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        fx, fy = c + math.cos(a) * 29 * S, c + math.sin(a) * 29 * S
        d.ellipse([fx - 3 * S, fy - 3 * S, fx + 3 * S, fy + 3 * S], fill=EDGE)
    if lit:
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        g = ImageDraw.Draw(glow)
        for r, col in ((16, (210, 120, 40, 200)), (11, (240, 170, 70, 230)), (6, (255, 230, 170, 255))):
            g.ellipse([c - r * S, c - r * S, c + r * S, c + r * S], fill=col)
        glow = glow.filter(ImageFilter.GaussianBlur(2 * S))
        img = Image.alpha_composite(img, glow)
    else:
        # the cold wick: a twist of black cotton
        d.line([(c - 6 * S, c + 4 * S), (c + 2 * S, c - 2 * S), (c + 5 * S, c - 7 * S)], fill=(70, 66, 60, 255), width=3 * S)
    img = paper_texture(img, 211 if lit else 212, 0.08, 3)
    return finish(img, w, h)


def lens():
    w = h = 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    c = w / 2 * S
    d.rectangle([2 * S, 2 * S, (w - 2) * S, (h - 2) * S], fill=EDGE)
    d.rectangle([5 * S, 5 * S, (w - 5) * S, (h - 5) * S], fill=IRON)
    for r, col in ((24, EDGE), (22, BRASS_DARK), (19, BRASS), (16, (190, 150, 80, 255)), (12, (246, 214, 140, 255)), (6, (255, 244, 210, 255))):
        d.ellipse([c - r * S, c - r * S, c + r * S, c + r * S], fill=col)
    # Fresnel rings and a crack
    for r in (9, 14):
        d.ellipse([c - r * S, c - r * S, c + r * S, c + r * S], outline=(150, 112, 50, 255), width=S)
    d.line([(c - 18 * S, c - 6 * S), (c - 4 * S, c + 2 * S), (c + 8 * S, c - 10 * S)], fill=EDGE, width=S)
    img = paper_texture(img, 221, 0.06, 2)
    return finish(img, w, h)


def main():
    mirror().save(os.path.join(PROPS, "beam_mirror.png"))
    wick(False).save(os.path.join(PROPS, "wick_cold.png"))
    wick(True).save(os.path.join(PROPS, "wick_lit.png"))
    lens().save(os.path.join(PROPS, "beam_lens.png"))
    print("wrote beam_mirror, wick_cold, wick_lit and beam_lens")


if __name__ == "__main__":
    main()
