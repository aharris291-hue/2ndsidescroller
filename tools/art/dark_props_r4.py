"""Props for Region 4, the Spine Peaks (Phase 3).

Writes to assets/art/dark/props/:
  clockwork_head.png    one of Bindwell's sewing machines, cut from the ElevenLabs painting:
                        the iron head with gold scrollwork and brass gears that hangs from
                        the rail on two wheels (its top edge is the rail), 75% scale
  clockwork_pin.png     its long frost-rimed steel pin, with dark red thread through the eye
                        (the pin's top is the clamp under the head's left column)
  ice_block.png         a block of frozen page that a Pop-Up Slam shatters, 128 x 128
  needle_rail.png       a length of the iron rail the carriages ride, 128 x 24 (tiles across)

Run: python3 tools/art/dark_props_r4.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

PROPS = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "dark", "props")
S = 4
INK = (14, 12, 12, 255)
# Where things sit in the 1280x720 painting.
RAIL_BOTTOM = 42
PIN_TOP, PIN_X0, PIN_X1 = 262, 488, 720
PIN_SHAFT_X1 = 552   # the pin itself is narrow; the machine's bed arm starts right of it
THREAD_TOP = 470     # below this, only the trailing thread is out to the right
HEAD_BOX = (470, 30, 860, 410)   # the hanger, the iron head, its gears and scrap
PIN_BOX = (488, 262, 720, 700)   # the pin, its clamp and the thread
SCALE = 0.75


def grain(img: Image.Image, amount: int, seed: int) -> Image.Image:
    """Speckle the paint so flat fills read as worn metal, not vector art."""
    rnd = random.Random(seed)
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a:
                n = rnd.randint(-amount, amount)
                px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), a)
    return img


def gear(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, teeth: int, fill, rnd) -> None:
    pts = []
    for i in range(teeth * 2):
        a = i / (teeth * 2) * math.tau + rnd.uniform(-0.03, 0.03)
        rr = r if i % 2 == 0 else r * 0.8
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=fill, outline=INK, width=2 * S)
    d.ellipse((cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3), fill=(40, 34, 28, 255), outline=INK, width=S)


def clockwork_needle() -> None:
    """Cut the painted machine (tools/art/source/sewing_head_raw.png) off its white
    ground, drop the rail it was painted on (the game draws its own), and split the
    long pin from the head so it can plunge on its own."""
    import numpy as np
    from rembg import new_session, remove
    from scipy import ndimage
    img = Image.open(os.path.join(os.path.dirname(__file__), "source", "sewing_head_raw.png")).convert("RGB")
    a = np.array(remove(img, session=new_session("isnet-general-use")))
    alpha = a[:, :, 3].astype(np.float32)
    alpha[alpha < 24] = 0
    a[:, :, 3] = alpha.astype(np.uint8)
    a[:RAIL_BOTTOM, :, 3] = 0  # the painted rail
    # the pin, and the thread trailing from its eye
    take = np.zeros(a.shape[:2], bool)
    take[PIN_TOP:, PIN_X0:PIN_SHAFT_X1] = True
    take[THREAD_TOP:, PIN_X0:PIN_X1] = True
    pin = np.zeros_like(a)
    pin[take] = a[take]
    head = a.copy()
    head[take, 3] = 0
    for arr, box, name in ((head, HEAD_BOX, "clockwork_head.png"), (pin, PIN_BOX, "clockwork_pin.png")):
        piece = Image.fromarray(arr).crop(box)
        piece = piece.resize((round(piece.width * SCALE), round(piece.height * SCALE)), Image.LANCZOS)
        piece.save(os.path.join(PROPS, name))
        print(name, piece.size)


def needle_rail() -> None:
    w, h = 128, 24
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 6 * S, w * S, 18 * S), fill=(40, 38, 40, 255), outline=INK, width=2 * S)
    d.line([(0, 8 * S), (w * S, 8 * S)], fill=(120, 124, 130, 255), width=S)
    for x in range(8, w, 32):
        d.ellipse(((x - 3) * S, 9 * S, (x + 3) * S, 15 * S), fill=(110, 90, 50, 255))
    img = img.resize((w, h), Image.LANCZOS)
    grain(img, 8, 5).save(os.path.join(PROPS, "needle_rail.png"))


def ice_block() -> None:
    """A block of frozen page: grey-blue ice, paper scraps and a torn line of print
    trapped inside, a hard pale rim, and a crack a slam would finish."""
    import numpy as np
    w = h = 128
    rnd = random.Random(19)
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((2 * S, 2 * S, (w - 2) * S, (h - 2) * S), fill=(58, 74, 90, 236))
    # depth: darker towards the bottom, cloudy veils inside
    for i in range(10):
        y0 = rnd.uniform(10, 110) * S
        d.ellipse((rnd.uniform(-20, 80) * S, y0, rnd.uniform(60, 150) * S, y0 + rnd.uniform(14, 40) * S),
                  fill=(150, 176, 196, rnd.randint(30, 70)))
    # trapped scraps of paper, one with a line of print
    for i in range(5):
        cx, cy = rnd.uniform(18, 110) * S, rnd.uniform(20, 108) * S
        r = rnd.uniform(8, 16) * S
        pts = [(cx + math.cos(a) * r * rnd.uniform(0.6, 1.2), cy + math.sin(a) * r * rnd.uniform(0.4, 0.9))
               for a in [k / 6 * math.tau + rnd.uniform(-0.3, 0.3) for k in range(6)]]
        d.polygon(pts, fill=(176, 168, 146, 150))
        if i == 0:
            for k in range(3):
                d.line([(cx - r * 0.7, cy - r * 0.3 + k * 4 * S), (cx + r * 0.5, cy - r * 0.3 + k * 4 * S)],
                       fill=(40, 36, 32, 150), width=S)
    img = img.filter(ImageFilter.GaussianBlur(1.5 * S))
    d = ImageDraw.Draw(img)
    # the crack, and a hard frosted rim (pale on top: standable)
    a = (rnd.uniform(40, 70) * S, 4 * S)
    for k in range(6):
        b = (a[0] + rnd.uniform(-16, 16) * S, a[1] + rnd.uniform(14, 24) * S)
        d.line([a, b], fill=(196, 216, 232, 130), width=2 * S)
        a = b
    d.rectangle((2 * S, 2 * S, (w - 2) * S, (h - 2) * S), outline=INK, width=3 * S)
    d.rectangle((5 * S, 5 * S, (w - 5) * S, 10 * S), fill=(214, 230, 242, 255))
    d.line([(6 * S, 14 * S), (6 * S, (h - 8) * S)], fill=(170, 196, 214, 180), width=2 * S)
    img = img.resize((w, h), Image.LANCZOS)
    arr = np.asarray(img).copy()
    noise = np.random.default_rng(4).integers(-9, 10, arr.shape[:2])
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c].astype(int) + noise, 0, 255)
    Image.fromarray(arr).save(os.path.join(PROPS, "ice_block.png"))


def main() -> None:
    clockwork_needle()
    needle_rail()
    ice_block()
    print("wrote the Peaks props")


if __name__ == "__main__":
    main()
