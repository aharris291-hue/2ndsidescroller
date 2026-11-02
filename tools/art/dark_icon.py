"""Dark-rebuild game icon: Patch's head and shears in lantern light over the drowned kingdom.

Writes icon.png (512x512) and icon.ico (16-256). Run: python3 tools/art/dark_icon.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
DARK = os.path.join(ROOT, "assets", "art", "dark")
N = 512
S = 4  # supersample for the frame


def backdrop() -> Image.Image:
    bg = Image.open(os.path.join(DARK, "bg_drowned.png")).convert("RGB")
    side = bg.height
    left = (bg.width - side) // 2
    bg = bg.crop((left, 0, left + side, side)).resize((N, N), Image.LANCZOS)
    bg = ImageEnhance.Color(bg).enhance(0.55)
    a = np.asarray(bg, np.float32) * np.array([0.42, 0.46, 0.56], np.float32)
    # warm lantern glow behind the head
    yy, xx = np.mgrid[0:N, 0:N]
    d = np.sqrt((xx - N * 0.52) ** 2 + (yy - N * 0.42) ** 2) / N
    glow = np.exp(-(d / 0.26) ** 2)[..., None]
    a = a + glow * np.array([120, 62, 26], np.float32)
    vign = np.clip(1.15 - d * 1.5, 0.25, 1.0)[..., None]
    a *= vign
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))


def patch_bust() -> Image.Image:
    p = Image.open(os.path.join(DARK, "patch.png")).convert("RGBA")
    # head, bandana and the raised shears
    bust = p.crop((20, 0, 296, 300))
    scale = 470 / bust.width
    bust = bust.resize((round(bust.width * scale), round(bust.height * scale)), Image.LANCZOS)
    bust = bust.filter(ImageFilter.UnsharpMask(radius=2, percent=90, threshold=2))
    return bust


def rim(img: Image.Image) -> Image.Image:
    """Dark backlit outline so the silhouette reads at 16 px."""
    a = img.getchannel("A")
    halo = a.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(3))
    out = Image.new("RGBA", img.size, (12, 8, 8, 0))
    out.putalpha(halo)
    return Image.alpha_composite(out, img)


def frame(img: Image.Image) -> Image.Image:
    w = N * S
    mask = Image.new("L", (w, w), 0)
    ImageDraw.Draw(mask).rounded_rectangle([6 * S, 6 * S, w - 6 * S, w - 6 * S], radius=92 * S, fill=255)
    mask = mask.resize((N, N), Image.LANCZOS)
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    ring = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    d.rounded_rectangle([6 * S, 6 * S, w - 6 * S, w - 6 * S], radius=92 * S, outline=(18, 12, 10, 255), width=10 * S)
    # red running stitch just inside the edge
    inset, r = 26 * S, 74 * S
    x0, y0, x1, y1 = inset, inset, w - inset, w - inset
    path = []
    steps = 400
    per = 2 * (x1 - x0 - 2 * r) + 2 * (y1 - y0 - 2 * r) + 2 * math.pi * r
    for i in range(steps):
        t = i / steps * per
        path.append(_on_rrect(t, x0, y0, x1, y1, r))
    for i in range(0, steps, 8):
        d.line([path[i], path[i + 4]], fill=(20, 10, 8, 255), width=9 * S)
        d.line([path[i], path[i + 4]], fill=(150, 30, 26, 255), width=5 * S)
    ring = ring.resize((N, N), Image.LANCZOS)
    return Image.alpha_composite(out, ring)


def _on_rrect(t, x0, y0, x1, y1, r):
    segs = []
    segs.append(("l", (x0 + r, y0), (x1 - r, y0)))
    segs.append(("a", (x1 - r, y0 + r), -90))
    segs.append(("l", (x1, y0 + r), (x1, y1 - r)))
    segs.append(("a", (x1 - r, y1 - r), 0))
    segs.append(("l", (x1 - r, y1), (x0 + r, y1)))
    segs.append(("a", (x0 + r, y1 - r), 90))
    segs.append(("l", (x0, y1 - r), (x0, y0 + r)))
    segs.append(("a", (x0 + r, y0 + r), 180))
    for kind, a, b in segs:
        if kind == "l":
            L = math.dist(a, b)
            if t <= L:
                f = t / L
                return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
            t -= L
        else:
            L = math.pi * r / 2
            if t <= L:
                ang = math.radians(b + 90 * t / L)
                return (a[0] + math.cos(ang) * r, a[1] + math.sin(ang) * r)
            t -= L
    return (x0 + r, y0)


def main() -> None:
    img = backdrop().convert("RGBA")
    bust = rim(patch_bust())
    img.alpha_composite(bust, ((N - bust.width) // 2 + 6, 44))
    icon = frame(img)
    icon.save(os.path.join(ROOT, "icon.png"))
    icon.save(os.path.join(ROOT, "icon.ico"), sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("wrote icon.png and icon.ico")


if __name__ == "__main__":
    main()
