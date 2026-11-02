"""Props for the Spine hub: region doors, the mending table and the stove.

  region_door.png   a tall doorway cut through layered pages, a red ribbon bookmark
                    hanging in it (the Bookmark that leads to a region)
  mending_table.png Gran's mending table: thread, needles, a pinned scrap of paper
  stove.png         a small cast-iron stove (its glow is a PointLight2D)

Run: python3 tools/art/dark_props_hub.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

from dark_props_prologue import EDGE, THREAD, THREAD_HI, BRASS, BRASS_DARK, STEEL, S, canvas, finish, paper_texture

PROPS = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "dark", "props")


def region_door():
    w, h = 170, 260
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    # layered page edges around an arched opening
    rnd = random.Random(2)
    for i in range(7):
        inset = i * 7
        tone = 150 - i * 14
        box = [(10 + inset) * S, (10 + inset) * S, (w - 10 - inset) * S, (h + 60) * S]
        d.rounded_rectangle(box, (70 - inset) * S, fill=EDGE)
        box2 = [box[0] + 3 * S, box[1] + 3 * S, box[2] - 3 * S, box[3]]
        d.rounded_rectangle(box2, (68 - inset) * S, fill=(tone, tone - 8, tone - 22, 255))
    # the dark opening
    d.rounded_rectangle([62 * S, 62 * S, (w - 62) * S, (h + 60) * S], 30 * S, fill=(8, 8, 12, 255))
    # ribbon bookmark hanging through it, notched at the end
    cx = w / 2 * S
    d.polygon([(cx - 12 * S, 62 * S), (cx + 12 * S, 62 * S), (cx + 12 * S, 220 * S), (cx, 206 * S), (cx - 12 * S, 220 * S)], fill=(120, 22, 20, 255))
    d.line([(cx - 8 * S, 62 * S), (cx - 8 * S, 210 * S)], fill=(160, 40, 34, 255), width=2 * S)
    # brass plaque above
    d.rounded_rectangle([cx - 30 * S, 22 * S, cx + 30 * S, 44 * S], 4 * S, fill=BRASS_DARK)
    d.rounded_rectangle([cx - 27 * S, 25 * S, cx + 27 * S, 41 * S], 3 * S, fill=BRASS)
    # stitches up the jambs
    for y in range(80, h, 26):
        for x in (32, w - 32):
            d.line([((x - 5) * S, y * S), ((x + 5) * S, (y + 10) * S)], fill=THREAD, width=2 * S)
            d.line([((x + 5) * S, y * S), ((x - 5) * S, (y + 10) * S)], fill=THREAD, width=2 * S)
    img = paper_texture(img, 71, 0.1, 6)
    return finish(img, w, h)


def mending_table():
    w, h = 300, 150
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    # legs and top
    for x in (24, w - 36):
        d.rectangle([x * S, 60 * S, (x + 12) * S, h * S], fill=EDGE)
        d.rectangle([(x + 2) * S, 62 * S, (x + 10) * S, h * S], fill=(62, 44, 30, 255))
    d.rectangle([6 * S, 48 * S, (w - 6) * S, 66 * S], fill=EDGE)
    d.rectangle([9 * S, 50 * S, (w - 9) * S, 63 * S], fill=(92, 66, 44, 255))
    d.rectangle([9 * S, 50 * S, (w - 9) * S, 53 * S], fill=(196, 184, 160, 255))
    # pinned scrap of paper and a spool
    d.polygon([(70 * S, 48 * S), (150 * S, 46 * S), (156 * S, 22 * S), (82 * S, 26 * S)], fill=EDGE)
    d.polygon([(74 * S, 46 * S), (148 * S, 44 * S), (152 * S, 25 * S), (85 * S, 29 * S)], fill=(176, 162, 132, 255))
    d.line([(90 * S, 34 * S), (140 * S, 32 * S)], fill=(120, 108, 88, 255), width=S)
    d.line([(112 * S, 30 * S), (112 * S, 14 * S)], fill=STEEL, width=2 * S)
    d.ellipse([108 * S, 10 * S, 116 * S, 18 * S], fill=THREAD_HI)
    d.rectangle([200 * S, 18 * S, 232 * S, 48 * S], fill=EDGE)
    d.rectangle([203 * S, 22 * S, 229 * S, 44 * S], fill=THREAD)
    for y in range(24, 44, 4):
        d.line([(203 * S, y * S), (229 * S, (y + 2) * S)], fill=THREAD_HI, width=S)
    d.rectangle([198 * S, 14 * S, 234 * S, 20 * S], fill=(92, 66, 44, 255))
    d.rectangle([198 * S, 44 * S, 234 * S, 50 * S], fill=(92, 66, 44, 255))
    # loose thread trailing off the edge
    d.line([(216 * S, 48 * S), (250 * S, 70 * S), (244 * S, 100 * S)], fill=THREAD, width=2 * S, joint="curve")
    img = paper_texture(img, 81, 0.08, 4)
    return finish(img, w, h)


def stove():
    w, h = 130, 200
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([52 * S, 0, 72 * S, 70 * S], fill=EDGE)
    d.rectangle([55 * S, 0, 69 * S, 70 * S], fill=(46, 44, 46, 255))
    d.rounded_rectangle([14 * S, 66 * S, 116 * S, 180 * S], 14 * S, fill=EDGE)
    d.rounded_rectangle([18 * S, 70 * S, 112 * S, 176 * S], 12 * S, fill=(52, 48, 50, 255))
    d.rounded_rectangle([36 * S, 106 * S, 94 * S, 150 * S], 6 * S, fill=EDGE)
    d.rounded_rectangle([40 * S, 110 * S, 90 * S, 146 * S], 5 * S, fill=(200, 92, 34, 255))
    d.rounded_rectangle([48 * S, 124 * S, 82 * S, 146 * S], 4 * S, fill=(250, 180, 80, 255))
    for x in (46, 58, 70, 82):
        d.line([(x * S, 110 * S), (x * S, 146 * S)], fill=EDGE, width=3 * S)
    for x in (24, 98):
        d.rectangle([x * S, 176 * S, (x + 10) * S, 198 * S], fill=EDGE)
    img = paper_texture(img, 91, 0.06, 3)
    return finish(img, w, h)


def main():
    region_door().save(os.path.join(PROPS, "region_door.png"))
    mending_table().save(os.path.join(PROPS, "mending_table.png"))
    stove().save(os.path.join(PROPS, "stove.png"))
    print("wrote hub props")


if __name__ == "__main__":
    main()
