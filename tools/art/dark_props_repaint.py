"""Painted props for the dark rebuild (docs/ART_STYLE.md), replacing the old bright
flat-colour props in assets/art/props.

Each painted prop comes from an ElevenLabs painting kept in tools/art/source
(prop_<name>_raw.png). It is cut off its background and fitted into the same canvas
and the same box the old prop filled, so every scene, hitbox and offset that used the
old texture still lines up. Small props (pickups, rings, pitons, the water edge) are
painted here in code.

Writes assets/art/dark/props/<same name as the old prop>.png.
Run: python3 tools/art/dark_props_repaint.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from dark_enemies import cut  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
OLD = os.path.join(ROOT, "assets", "art", "props")
OUT = os.path.join(ROOT, "assets", "art", "dark", "props")

INK = (16, 13, 12)

# name: (painting, how it fills the old box). "fit" keeps the painting's shape and
# sits it on the bottom of the old box ("tall": as tall as the box, the windmill, whose
# sails turn on a hub near its top); "fill" stretches it to the whole box (gates and
# doors, whose box is their collision shape); "centre" centres it (things that spin).
PAINTED = {
    "house_gold": ("house_gold", "fit"),
    "house_lilac": ("house_lilac", "fit"),
    "house_red": ("house_red", "fit"),
    "house_teal": ("house_teal", "fit"),
    "lantern_on": ("lantern", "fit"),
    "lantern_off": ("lantern", "fit"),
    "bookmark_on": ("bookmark", "fit"),
    "bookmark_off": ("bookmark", "fit"),
    "campfire": ("campfire", "fit"),
    "moored_boat": ("moored_boat", "fit"),
    "paper_boat": ("paper_boat", "fit"),
    "windmill": ("windmill", "tall"),
    "windmill_sails": ("windmill_sails", "centre"),
    "theater": ("theater", "fit"),
    "hairdryer": ("hairdryer", "fit"),
    "plug": ("plug", "fit"),
    "paperclip": ("paperclip", "centre"),
    "blotter": ("blotter", "fit"),
    "gutter_gate": ("gutter_gate", "fill"),
    "flap_gate": ("flap_gate", "fill"),
    "popup_peak": ("popup_peak", "fill"),
    "page_corner_door": ("page_corner_door", "fill"),
    "spool": ("spool", "fit"),
    "stream_rock": ("stream_rock", "fit"),
    "lost_letter": ("lost_letter", "centre"),
}
# The old lantern box is the unlit one; the lit one's box was its glow.
BOX_FROM = {"lantern_on": "lantern_off"}
# The old hair dryer hangs nozzle-down over the page; the painting points at us.
TURN = {"hairdryer": -62}


def old_canvas(name: str) -> tuple:
    im = Image.open(os.path.join(OLD, name + ".png")).convert("RGBA")
    return im.size, im.getchannel("A").getbbox()


def grade(im: Image.Image) -> Image.Image:
    """Match the game's grade: a touch darker and colder, never pure white."""
    a = np.asarray(im, np.float32).copy()
    rgb = a[..., :3] * 0.86
    rgb = rgb * np.array([0.97, 0.98, 1.03])
    a[..., :3] = np.clip(rgb, 0, 232)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def place(art: Image.Image, size: tuple, box: tuple, how: str) -> Image.Image:
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    out = Image.new("RGBA", size)
    if how == "fill":
        art = art.resize((bw, bh), Image.LANCZOS)
        out.alpha_composite(art, (x0, y0))
        return out
    s = min(bw / art.width, bh / art.height)
    if how == "tall":  # as tall as the old box, however wide that makes it
        s = min(bh / art.height, size[0] / art.width)
    art = art.resize((max(1, round(art.width * s)), max(1, round(art.height * s))), Image.LANCZOS)
    x = x0 + (bw - art.width) // 2
    y = y1 - art.height if how in ("fit", "tall") else y0 + (bh - art.height) // 2
    out.alpha_composite(art, (x, y))
    return out


def unlit(im: Image.Image) -> Image.Image:
    """Put the lantern out: its warm, bright glass goes cold and dark."""
    a = np.asarray(im, np.float32).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    warm = np.clip((r - b) / 90.0, 0, 1) * np.clip((r + g) / 300.0, 0, 1)
    grey = (r + g + b) / 3 * 0.45
    for i, tint in enumerate((0.92, 0.96, 1.08)):
        a[..., i] = a[..., i] * (1 - warm) + grey * tint * warm
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def lit(im: Image.Image) -> Image.Image:
    """A faint warm halo round the lantern's glass, so it reads as a light at night."""
    a = np.asarray(im, np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    hot = ((r > 150) & (r - b > 60) & (a[..., 3] > 200)).astype(np.float32)
    halo = ndimage.gaussian_filter(hot, 12)
    halo = np.clip(halo / (halo.max() + 1e-6), 0, 1) * 0.55
    glow = np.zeros_like(a)
    glow[..., 0], glow[..., 1], glow[..., 2] = 236, 168, 82
    glow[..., 3] = halo * 255
    base = Image.fromarray(glow.astype(np.uint8), "RGBA")
    base.alpha_composite(im)
    return base


def faded(im: Image.Image) -> Image.Image:
    """The bookmark's ribbon before Patch rests there: drained of its red."""
    a = np.asarray(im, np.float32).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    red = np.clip((r - (g + b) / 2) / 50.0, 0, 1)
    grey = (r + g + b) / 3 * 0.8
    for i in range(3):
        a[..., i] = a[..., i] * (1 - red) + grey * red
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


# --- small props painted in code ----------------------------------------------

def supersample(w: int, h: int, draw_fn, k: int = 4) -> Image.Image:
    big = Image.new("RGBA", (w * k, h * k))
    draw_fn(ImageDraw.Draw(big), k)
    return big.resize((w, h), Image.LANCZOS)


def paper_texture(im: Image.Image, seed: int, amount: float = 0.12) -> Image.Image:
    a = np.asarray(im, np.float32).copy()
    n = ndimage.gaussian_filter(np.random.default_rng(seed).normal(0, 1, a.shape[:2]), 1.2)
    n /= np.abs(n).max() + 1e-6
    a[..., :3] *= (1 + amount * n)[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def scrap() -> Image.Image:
    """The currency pickup: a torn scrap of old page with a line of red stitching."""
    rng = np.random.default_rng(3)

    def draw(d, k):
        pts = []
        for i in range(14):
            ang = i / 14 * math.tau + 0.3
            r = (17 + rng.uniform(-3.5, 3.5)) * k
            pts.append((24 * k + math.cos(ang) * r * 1.05, 24 * k + math.sin(ang) * r * 0.9))
        d.polygon(pts, fill=(176, 156, 120, 255), outline=INK + (255,), width=2 * k)
        for i in range(3):
            y = (17 + i * 6) * k
            d.line([(13 * k, y), (35 * k, y - 2 * k)], fill=(70, 58, 48, 200), width=k)
        for i in range(4):
            x = (14 + i * 6) * k
            d.line([(x, 34 * k), (x + 3 * k, 30 * k)], fill=(150, 36, 30, 255), width=2 * k)
    return paper_texture(supersample(48, 48, draw), 3)


def tape() -> Image.Image:
    """A roll of yellowed masking tape, the edge of its last strip curling loose."""
    def draw(d, k):
        c = 24 * k
        d.ellipse([c - 22 * k, c - 22 * k, c + 22 * k, c + 22 * k], fill=(150, 128, 82, 255), outline=INK + (255,), width=2 * k)
        d.ellipse([c - 16 * k, c - 16 * k, c + 16 * k, c + 16 * k], outline=(108, 90, 58, 255), width=k)
        d.ellipse([c - 11 * k, c - 11 * k, c + 11 * k, c + 11 * k], fill=(54, 42, 32, 255), outline=INK + (255,), width=2 * k)
        d.polygon([(c + 14 * k, c + 14 * k), (c + 23 * k, c + 22 * k), (c + 18 * k, c + 24 * k), (c + 10 * k, c + 18 * k)],
                  fill=(166, 144, 96, 255), outline=INK + (255,))
    return paper_texture(supersample(48, 48, draw), 5, 0.08)


def fold_mark() -> Image.Image:
    """Where the page folds: a dashed line of dark red thread and a small iron notch."""
    def draw(d, k):
        for i in range(9):
            x = (12 + i * 15) * k
            d.line([(x, 42 * k), (x + 9 * k, 42 * k)], fill=(122, 30, 26, 255), width=3 * k)
        d.polygon([(70 * k, 38 * k), (80 * k, 4 * k), (90 * k, 38 * k)], fill=(78, 70, 64, 255), outline=INK + (255,), width=2 * k)
        d.line([(80 * k, 10 * k), (80 * k, 34 * k)], fill=(150, 136, 118, 255), width=k)
    return supersample(160, 48, draw)


def ring(fill: tuple, rim: tuple, w: int, h: int, cx: float, cy: float, r: float, stem: bool) -> Image.Image:
    def draw(d, k):
        if stem:
            d.rectangle([(cx - 4) * k, 0, (cx + 4) * k, (cy - r + 4) * k], fill=fill + (255,), outline=INK + (255,), width=2 * k)
        d.ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], outline=INK + (255,), width=13 * k)
        d.ellipse([(cx - r + 2) * k, (cy - r + 2) * k, (cx + r - 2) * k, (cy + r - 2) * k], outline=fill + (255,), width=9 * k)
        d.arc([(cx - r + 3) * k, (cy - r + 3) * k, (cx + r - 3) * k, (cy + r - 3) * k], 200, 260, fill=rim + (255,), width=3 * k)
    return supersample(w, h, draw)


def rust(im: Image.Image, seed: int) -> Image.Image:
    a = np.asarray(im, np.float32).copy()
    n = ndimage.gaussian_filter(np.random.default_rng(seed).normal(0, 1, a.shape[:2]), 1.5)
    spots = np.clip((n - 0.15) * 4, 0, 1)[..., None]
    a[..., :3] = a[..., :3] * (1 - spots * 0.6) + np.array([110, 58, 32]) * spots * 0.6
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def grapple_ring() -> Image.Image:
    return rust(ring((92, 84, 78), (170, 160, 148), 80, 80, 40, 46, 30, True), 7)


def piton() -> Image.Image:
    """An iron piton hammered into the rock, with its ring."""
    def draw(d, k):
        d.polygon([(32 * k, 46 * k), (48 * k, 46 * k), (42 * k, 88 * k), (38 * k, 88 * k)], fill=(72, 66, 62, 255), outline=INK + (255,), width=2 * k)
        d.ellipse([18 * k, 4 * k, 62 * k, 48 * k], outline=INK + (255,), width=12 * k)
        d.ellipse([20 * k, 6 * k, 60 * k, 46 * k], outline=(96, 88, 82, 255), width=8 * k)
        d.arc([22 * k, 8 * k, 58 * k, 44 * k], 200, 260, fill=(168, 158, 146, 255), width=3 * k)
    return rust(supersample(80, 96, draw), 9)


def paper_dart() -> Image.Image:
    """An ability page folded into a dart: old print, stained, ink on its folds."""
    def draw(d, k):
        d.polygon([(64 * k, 8 * k), (2 * k, 2 * k), (24 * k, 24 * k)], fill=(184, 166, 132, 255), outline=INK + (255,), width=2 * k)
        d.polygon([(64 * k, 8 * k), (24 * k, 24 * k), (8 * k, 46 * k)], fill=(138, 122, 96, 255), outline=INK + (255,), width=2 * k)
        for i in range(3):
            d.line([((14 + i * 9) * k, (6 + i * 3) * k), ((40 + i * 5) * k, (10 + i * 2) * k)], fill=(80, 70, 60, 180), width=k)
    return paper_texture(supersample(64, 48, draw), 11)


def pull_tab() -> Image.Image:
    """A worn card pull tab with an inked arrow, its end frayed from pulling."""
    def draw(d, k):
        d.polygon([(2 * k, 6 * k), (78 * k, 6 * k), (94 * k, 24 * k), (78 * k, 42 * k), (2 * k, 42 * k)],
                  fill=(112, 86, 60, 255), outline=INK + (255,), width=2 * k)
        d.line([(12 * k, 24 * k), (70 * k, 24 * k)], fill=(28, 22, 20, 255), width=4 * k)
        d.polygon([(58 * k, 14 * k), (76 * k, 24 * k), (58 * k, 34 * k)], fill=(28, 22, 20, 255))
        d.line([(4 * k, 10 * k), (4 * k, 38 * k)], fill=(150, 120, 86, 255), width=2 * k)
    return paper_texture(supersample(96, 48, draw), 13, 0.15)


def cardboard_platform() -> Image.Image:
    """A swollen, water-stained strip of corrugated board."""
    w, h = 192, 32
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rng = np.random.default_rng(17)
    base = np.array([92, 72, 52], np.float32)
    flutes = 0.5 + 0.5 * np.sin(xx * 0.9)
    rgb = base * (0.82 + 0.18 * flutes)[..., None]
    stain = ndimage.gaussian_filter(rng.normal(0, 1, (h, w)), (3, 10))
    stain = np.clip(stain / np.abs(stain).max(), -1, 1)
    rgb *= (1 - 0.25 * np.clip(stain, 0, 1) - 0.25 * (yy / h))[..., None]
    rgb[0:2] = INK
    rgb[2:5] = np.array([170, 150, 118])  # the pale top edge you stand on
    rgb[-2:] = INK
    rgb[:, :2] = INK
    rgb[:, -2:] = INK
    a = np.dstack([np.clip(rgb, 0, 255), np.full((h, w), 255)]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def rising_water() -> Image.Image:
    """The flood's surface: black ink water with a cold grey sheen on each swell. Tiles
    left to right."""
    w, h = 256, 128
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    crest = 22 + 6 * np.sin(xx / w * math.tau * 2) + 3 * np.sin(xx / w * math.tau * 5 + 1.0)
    below = yy - crest
    alpha = np.clip(below + 1, 0, 1)
    depth = np.clip(below / 90, 0, 1)
    rgb = np.array([30, 34, 40], np.float32) * (1 - depth[..., None]) + np.array([8, 9, 12], np.float32) * depth[..., None]
    sheen = np.exp(-((below - 3) / 2.2) ** 2)
    rgb += sheen[..., None] * np.array([96, 104, 112])
    n = np.random.default_rng(19).normal(0, 1, (h, w))
    n = ndimage.gaussian_filter(n, (1.0, 6.0), mode="wrap")
    streak = np.clip(n / np.abs(n).max(), 0, 1) * np.clip(1 - depth * 1.5, 0, 1)
    rgb += streak[..., None] * 26
    a = np.dstack([np.clip(rgb, 0, 255), alpha * 235]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


CODED = {
    "scrap": scrap,
    "tape": tape,
    "fold_mark": fold_mark,
    "grapple_ring": grapple_ring,
    "piton": piton,
    "paper_dart": paper_dart,
    "pull_tab": pull_tab,
    "cardboard_platform": cardboard_platform,
    "rising_water": rising_water,
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    cuts = {}
    for name, (src, how) in PAINTED.items():
        if src not in cuts:
            art = cut(os.path.join(SRC, "prop_" + src + "_raw.png"))
            if src in TURN:
                art = art.rotate(TURN[src], resample=Image.BICUBIC, expand=True)
                art = art.crop(art.getbbox())
            cuts[src] = grade(art)
        size, _ = old_canvas(name)
        _, box = old_canvas(BOX_FROM.get(name, name))
        im = place(cuts[src], size, box, how)
        if name == "lantern_on":
            im = lit(im)
        elif name == "lantern_off":
            im = unlit(im)
        elif name == "bookmark_off":
            im = faded(im)
        im.save(os.path.join(OUT, name + ".png"))
        print(name, im.size)
    for name, fn in CODED.items():
        im = fn()
        assert im.size == old_canvas(name)[0], name
        im.save(os.path.join(OUT, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    main()
