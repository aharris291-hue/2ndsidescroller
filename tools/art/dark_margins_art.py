"""Art for the optional Blank Margins (the edge of the book, past everything written),
from the painted ElevenLabs renders in tools/art/source/.

Backdrops (assets/art/dark/):
  bg_blank_margins.png   3840x1080, unwritten pages standing like cliffs in a storm
                         (M-1), mirrored strip
  bg_forecast.png        1920x1080, the last blank page under the eye of the storm
                         (the Unwritten Forecast's arena)
Sprites:
  bosses/forecast.png    the Unwritten Forecast, FORECAST_HEIGHT px tall, facing left
  props/rain_ledge.png   a ledge the rain writes on blank paper: a board of wet ink,
                         192 px wide (RainPlatform), its top 10 px down

Run: python3 tools/art/dark_margins_art.py
"""
import os

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "tools", "art", "source")
DARK = os.path.join(ROOT, "assets", "art", "dark")
FORECAST_HEIGHT = 640


def fit(path: str) -> Image.Image:
    return ImageOps.fit(Image.open(path).convert("RGB"), (1920, 1080), Image.LANCZOS)


def strip(img: Image.Image) -> Image.Image:
    out = Image.new("RGB", (3840, 1080))
    out.paste(img, (0, 0))
    out.paste(ImageOps.mirror(img), (1920, 0))
    return out


def cutout(name: str) -> Image.Image:
    from rembg import new_session, remove
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    a = np.array(remove(img, session=new_session("isnet-general-use")))
    alpha = a[:, :, 3]
    alpha[alpha < 24] = 0
    out = Image.fromarray(a)
    return out.crop(out.getbbox())


def rain_ledge() -> Image.Image:
    """A board of wet ink on blank paper, the edges running."""
    w, h = 192, 44
    rng = np.random.default_rng(71)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    top = 10 + rng.normal(0, 0.8, w).cumsum() * 0.15
    top = np.clip(top - top.mean() + 10, 8, 12)
    bottom = 26 + np.abs(rng.normal(0, 2.2, w))
    # drips under the board
    for x in rng.choice(w - 8, 9, replace=False) + 4:
        bottom[x - 1:x + 2] += rng.uniform(6, 16)
    inside = (yy >= top[None, :]) & (yy <= bottom[None, :])
    ink = 0.5 + 0.5 * np.sin(xx * 0.09 + rng.normal(0, 1, (h, w)) * 0.4)
    rgb = np.zeros((h, w, 3), np.float32)
    rgb[...] = np.array([18, 20, 28]) + ink[..., None] * np.array([26, 28, 36])
    lip = (yy >= top[None, :]) & (yy < top[None, :] + 3)
    rgb[lip] = np.array([150, 156, 170])
    alpha = np.where(inside, 235, 0).astype(np.uint8)
    out = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), alpha])
    img = Image.fromarray(out, "RGBA")
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(0.8))
    img.putalpha(a)
    return img


def main() -> None:
    ImageEnhance.Brightness(strip(fit(os.path.join(SRC, "blank_margins_raw.png")))).enhance(0.8).save(os.path.join(DARK, "bg_blank_margins.png"))
    ImageEnhance.Brightness(fit(os.path.join(SRC, "forecast_arena_raw.png"))).enhance(0.8).save(os.path.join(DARK, "bg_forecast.png"))
    boss = cutout("forecast_raw.png")
    boss = boss.resize((round(boss.width * FORECAST_HEIGHT / boss.height), FORECAST_HEIGHT), Image.LANCZOS)
    boss.save(os.path.join(DARK, "bosses", "forecast.png"))
    rain_ledge().save(os.path.join(DARK, "props", "rain_ledge.png"))


if __name__ == "__main__":
    main()
