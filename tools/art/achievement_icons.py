"""Steam achievement icons: 256x256 JPGs, unlocked and locked, one per id in
scripts/autoload/achievements.gd. Each is a piece of the game's own painted art
on an ink-dark torn-paper badge stitched round in Gran's red thread.
Run from the repo root: python3 tools/art/achievement_icons.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageEnhance
import math, os, random, re

ART = "assets/art/dark/"
OUT = "docs/store/achievements"
SIZE = 256
INK = (20, 15, 13)
PAPER = (58, 46, 38)
BLOOD = (150, 32, 26)
BONE = (214, 203, 182)

ICONS = {
    "SHEARS": "patch.png",
    "MILLWHEEL": "bosses/millwheel_body.png",
    "KRAKEN": "bosses/kraken_body.png",
    "HERON": "bosses/heron.png",
    "BINDWELL": "friends/bindwell.png",
    "BARKER": "enemies/barker.png",
    "REDACTOR": "enemies/redactor.png",
    "FORECAST": "bosses/forecast.png",
    "THE_END": "sogg.png",
    "TAIL": "patch_tail_mended.png",
    "HEARTS": "props/spool.png",
    "BESTIARY": "enemies/paper_moth.png",
    "PROOFS": "props/proof_press.png",
    "LAST_MARGIN": "characters/drizzle.png",
    "SECOND_PRINTING": "props/lost_letter.png",
}


def ids() -> list:
    text = open("scripts/autoload/achievements.gd").read()
    block = text[text.index("const LIST := {"):text.index("}", text.index("const LIST := {"))]
    return re.findall(r'^\s*"([A-Z_]+)":', block, re.M)


def badge(seed: int) -> Image.Image:
    rng = random.Random(seed)
    im = Image.new("RGB", (SIZE, SIZE), INK)
    d = ImageDraw.Draw(im)
    # A torn paper disc: a rough circle, lighter than the ink around it.
    c, r = SIZE / 2, SIZE * 0.45
    pts = []
    for i in range(72):
        a = i / 72 * math.tau
        rr = r + rng.uniform(-4, 3)
        pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
    d.polygon(pts, fill=PAPER)
    # Water stains: soft dark blots on the paper.
    stain = Image.new("L", im.size, 0)
    sd = ImageDraw.Draw(stain)
    for _ in range(5):
        x, y, s = rng.uniform(40, 216), rng.uniform(40, 216), rng.uniform(20, 60)
        sd.ellipse((x - s, y - s, x + s, y + s), fill=rng.randint(40, 90))
    im = Image.composite(Image.new("RGB", im.size, INK), im, stain.filter(ImageFilter.GaussianBlur(14)))
    # Vignette, so the art reads in the middle.
    vig = Image.new("L", im.size, 0)
    ImageDraw.Draw(vig).ellipse((20, 20, SIZE - 20, SIZE - 20), fill=255)
    vig = ImageOps.invert(vig.filter(ImageFilter.GaussianBlur(30)))
    return Image.composite(Image.new("RGB", im.size, INK), im, vig.point(lambda v: int(v * 0.8)))


def stitches(im: Image.Image) -> None:
    d = ImageDraw.Draw(im)
    c, r = SIZE / 2, SIZE * 0.465
    for i in range(28):
        a = i / 28 * math.tau
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        t = a + math.pi / 4
        dx, dy = math.cos(t) * 6, math.sin(t) * 6
        d.line((x - dx, y - dy, x + dx, y + dy), fill=BLOOD, width=3)
        d.line((x - dy, y + dx, x + dy, y - dx), fill=BLOOD, width=2)


def art(path: str) -> Image.Image:
    sprite = Image.open(ART + path).convert("RGBA")
    box = sprite.getbbox()
    if box:
        sprite = sprite.crop(box)
    scale = min(170 / sprite.width, 170 / sprite.height)
    return sprite.resize((max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale))), Image.LANCZOS)


def make(achievement: str, n: int) -> tuple:
    base = badge(n * 97 + 13).convert("RGBA")
    sprite = art(ICONS[achievement])
    # A soft shadow under the art.
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    a = sprite.split()[3].point(lambda v: int(v * 0.7))
    shadow.paste((0, 0, 0, 255), ((SIZE - sprite.width) // 2 + 4, (SIZE - sprite.height) // 2 + 6), a)
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)))
    base.alpha_composite(sprite, ((SIZE - sprite.width) // 2, (SIZE - sprite.height) // 2))
    unlocked = base.convert("RGB")
    stitches(unlocked)
    # Locked: the same badge, greyed and sunk in ink, the thread cut loose (no stitches).
    locked = ImageOps.grayscale(base.convert("RGB")).convert("RGB")
    locked = ImageEnhance.Brightness(locked).enhance(0.38)
    return unlocked, locked


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for n, achievement in enumerate(ids()):
        unlocked, locked = make(achievement, n)
        unlocked.save(f"{OUT}/{achievement}.jpg", quality=92)
        locked.save(f"{OUT}/{achievement}_locked.jpg", quality=92)


if __name__ == "__main__":
    main()
