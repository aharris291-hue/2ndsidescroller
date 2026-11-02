"""Dark-rebuild HUD art: health tokens as stitched scraps of soaked paper.

Each token is a ragged, stained paper patch held on with a red cross-stitch:
  crisp   - whole patch, both stitches
  creased - torn in half, one stitch left
  torn    - only the frayed outline and loose thread ends

Run: python3 tools/art/dark_ui.py  (writes assets/art/dark/ui/*.png)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "dark", "ui")
S = 4  # supersample
SIZE = 56

PAPER = (176, 160, 128, 255)
PAPER_DARK = (112, 98, 76, 255)
EDGE = (28, 22, 18, 255)
THREAD = (150, 30, 26, 255)
THREAD_HI = (196, 58, 46, 255)


def ragged(cx, cy, r, seed, jag=0.14, n=26):
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        a = i / n * math.tau
        rr = r * (1.0 + rnd.uniform(-jag, jag)) * (1.0 - 0.12 * abs(math.sin(2 * a)))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def stain(img, seed):
    """Water stains and fibres, clipped to the paper by its alpha."""
    rnd = random.Random(seed)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = img.size[0]
    for _ in range(5):
        x, y, r = rnd.uniform(0, w), rnd.uniform(0, w), rnd.uniform(w * 0.08, w * 0.22)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(60, 48, 36, 70))
    for _ in range(14):
        x, y = rnd.uniform(0, w), rnd.uniform(0, w)
        a = rnd.uniform(0, math.tau)
        L = rnd.uniform(w * 0.05, w * 0.15)
        d.line([x, y, x + math.cos(a) * L, y + math.sin(a) * L], fill=(80, 66, 50, 110), width=S)
    layer = layer.filter(ImageFilter.GaussianBlur(S * 1.2))
    alpha = img.getchannel("A")
    clipped = Image.new("RGBA", img.size, (0, 0, 0, 0))
    clipped.paste(layer, (0, 0), Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), alpha))
    return Image.alpha_composite(img, clipped)


def stitch(d, a, b, width):
    d.line([a, b], fill=EDGE, width=width + 2 * S)
    d.line([a, b], fill=THREAD, width=width)
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    d.line([a, (mx, my)], fill=THREAD_HI, width=max(S, width // 3))


def token(kind):
    w = SIZE * S
    img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = w / 2
    r = w * 0.40
    shape = ragged(c, c, r, seed=7)
    if kind == "torn":
        d.line(shape + [shape[0]], fill=(70, 60, 50, 200), width=2 * S, joint="curve")
        # loose thread ends
        d.line([(c - r * 0.5, c - r * 0.5), (c - r * 0.2, c - r * 0.1), (c - r * 0.35, c + r * 0.1)],
               fill=(110, 26, 22, 220), width=2 * S, joint="curve")
        d.line([(c + r * 0.45, c + r * 0.45), (c + r * 0.15, c + r * 0.25)], fill=(110, 26, 22, 220), width=2 * S)
        return img
    if kind == "creased":
        d.polygon(shape, fill=EDGE)
        inner = [(c + (x - c) * 0.9, c + (y - c) * 0.9) for x, y in shape]
        d.polygon(inner, fill=PAPER_DARK)
        img = stain(img, 11)
        d = ImageDraw.Draw(img)
        stitch(d, (c - r * 0.55, c - r * 0.5), (c - r * 0.02, c + r * 0.4), 3 * S)
        # tear away the right half along a jagged line
        rnd = random.Random(3)
        tear = [(c + rnd.uniform(-r * 0.14, r * 0.14), -S + i * (w + 2 * S) / 12) for i in range(13)]
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).polygon([(0, -S)] + tear + [(0, w + S)], fill=255)
        edge = Image.new("L", img.size, 0)
        ImageDraw.Draw(edge).line(tear, fill=255, width=3 * S)
        img.putalpha(Image.composite(img.getchannel("A"), Image.new("L", img.size, 0), mask))
        dark = Image.new("RGBA", img.size, EDGE)
        img = Image.composite(dark, img, Image.composite(edge, Image.new("L", img.size, 0), img.getchannel("A")))
        return img
    d.polygon(shape, fill=EDGE)
    inner = [(c + (x - c) * 0.9, c + (y - c) * 0.9) for x, y in shape]
    d.polygon(inner, fill=PAPER)
    # fold crease across the patch
    d.line([(c - r * 0.8, c + r * 0.25), (c + r * 0.8, c - r * 0.3)], fill=PAPER_DARK, width=2 * S)
    img = stain(img, 5)
    d = ImageDraw.Draw(img)
    stitch(d, (c - r * 0.5, c - r * 0.5), (c + r * 0.5, c + r * 0.5), 3 * S)
    stitch(d, (c + r * 0.5, c - r * 0.5), (c - r * 0.5, c + r * 0.5), 3 * S)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind in ("crisp", "creased", "torn"):
        token(kind).resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, f"health_{kind}.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
