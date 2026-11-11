"""Steam store and library art from the key art (tools/art/source/keyart_raw.png).

Writes docs/store/capsules/: every capsule Steam asks for, the library hero (no
text, as Steam requires), and the library logo on a transparent background.
Run from the repo root: python3 tools/art/steam_capsules.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance
import os

SRC = "tools/art/source/keyart_raw.png"
OUT = "docs/store/capsules"
SERIF = "assets/fonts/LiberationSerif-Regular.ttf"
ITALIC = "assets/fonts/LiberationSerif-Italic.ttf"
BONE = (230, 220, 203)
BLOOD = (150, 32, 26)
INK = (14, 11, 10)


def key() -> Image.Image:
    return Image.open(SRC).convert("RGB")


def crop_to(img: Image.Image, w: int, h: int, cx: float, cy: float, zoom: float = 1.0) -> Image.Image:
    """Crop the aspect w:h around (cx, cy) (0-1 of the source), zoomed in by `zoom`, then resize."""
    sw, sh = img.size
    aspect = w / h
    cw = min(sw, sh * aspect) / zoom
    ch = cw / aspect
    x = min(max(cx * sw - cw / 2, 0), sw - cw)
    y = min(max(cy * sh - ch / 2, 0), sh - ch)
    out = img.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((w, h), Image.LANCZOS)
    if out.width > img.width:
        out = out.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    return out


def shade(img: Image.Image, box: tuple, strength: float = 0.75) -> Image.Image:
    """Darken a soft-edged region so the title reads over the painting."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle(box, fill=int(255 * strength))
    mask = mask.filter(ImageFilter.GaussianBlur(max(img.size) * 0.06))
    dark = Image.new("RGB", img.size, INK)
    return Image.composite(dark, img, mask)


def logo(width: int) -> Image.Image:
    """'PATCH' over 'and the Pop-Up Kingdom', with a red stitched rule between them."""
    big = ImageFont.truetype(SERIF, int(width * 0.27))
    small = ImageFont.truetype(ITALIC, int(width * 0.075))
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    tb = probe.textbbox((0, 0), "PATCH", font=big)
    sb = probe.textbbox((0, 0), "and the Pop-Up Kingdom", font=small)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    sw, sh = sb[2] - sb[0], sb[3] - sb[1]
    gap = int(width * 0.04)
    h = th + gap * 2 + sh + int(width * 0.05)
    im = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x0 = (width - tw) // 2 - tb[0]
    # A soft ink shadow behind the letters.
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.text((x0 + 4, -tb[1] + 6), "PATCH", font=big, fill=(0, 0, 0, 220))
    sd.text(((width - sw) // 2 - sb[0] + 3, th + gap * 2 - sb[1] + 4), "and the Pop-Up Kingdom", font=small, fill=(0, 0, 0, 220))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(width * 0.008)))
    d.text((x0, -tb[1]), "PATCH", font=big, fill=BONE + (255,))
    # The stitched rule: a red thread with cross-stitches.
    y = th + gap
    left, right = (width - tw) // 2, (width + tw) // 2
    d.line((left, y, right, y), fill=BLOOD + (255,), width=max(2, width // 260))
    step = max(10, width // 34)
    for x in range(left + step // 2, right, step):
        r = max(3, width // 160)
        d.line((x - r, y - r, x + r, y + r), fill=BLOOD + (255,), width=max(2, width // 400))
        d.line((x - r, y + r, x + r, y - r), fill=BLOOD + (255,), width=max(2, width // 400))
    d.text(((width - sw) // 2 - sb[0], th + gap * 2 - sb[1]), "and the Pop-Up Kingdom", font=small, fill=BONE + (255,))
    return im


def with_logo(img: Image.Image, logo_w: int, cx: float, cy: float, shade_it: bool = True) -> Image.Image:
    lg = logo(logo_w)
    x, y = int(cx * img.width - lg.width / 2), int(cy * img.height - lg.height / 2)
    if shade_it:
        img = shade(img, (x, y, x + lg.width, y + lg.height))
    img = img.convert("RGBA")
    img.alpha_composite(lg, (x, y))
    return img.convert("RGB")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    k = ImageEnhance.Contrast(key()).enhance(1.05)
    # Landscape capsules: Patch lower left, the Sogg right, the title in the dark sky top left.
    with_logo(crop_to(k, 920, 430, 0.5, 0.45), 380, 0.29, 0.25).save(f"{OUT}/header_capsule_920x430.jpg", quality=92)
    with_logo(crop_to(k, 1232, 706, 0.5, 0.5), 500, 0.28, 0.2).save(f"{OUT}/main_capsule_1232x706.jpg", quality=92)
    # The small capsule is mostly title: it shows at 231x87 in lists.
    small = shade(crop_to(k, 462, 174, 0.5, 0.42), (0, 0, 462, 174), 0.45)
    with_logo(small, 300, 0.5, 0.5, False).save(f"{OUT}/small_capsule_462x174.jpg", quality=92)
    # Portrait capsules: Patch in full with the Sogg looming at his shoulder, the title in the sky.
    for w, h, name in ((748, 896, "vertical_capsule_748x896"), (600, 900, "library_capsule_600x900")):
        p = crop_to(k, w, h, 0.405, 0.5)
        with_logo(p, int(w * 0.84), 0.5, 0.17).save(f"{OUT}/{name}.jpg", quality=92)
    # Library hero: no text or logo, by Steam's rules; the logo sits over it in the client.
    crop_to(k, 3840, 1240, 0.5, 0.55).save(f"{OUT}/library_hero_3840x1240.jpg", quality=90)
    logo(1280).save(f"{OUT}/library_logo_1280.png")
    # Store page background (optional): the painting, darkened and soft.
    bg = crop_to(k, 1438, 810, 0.5, 0.5).filter(ImageFilter.GaussianBlur(3))
    ImageEnhance.Brightness(bg).enhance(0.45).save(f"{OUT}/page_background_1438x810.jpg", quality=88)


if __name__ == "__main__":
    main()
