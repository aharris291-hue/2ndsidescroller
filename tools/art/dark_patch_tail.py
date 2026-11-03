"""Patch's mended tail, for the ending (has_new_tail): Nell makes him a new tail from
a strip of old map, taped on and stitched to the stump with red thread.

Painted in code in the style of docs/ART_STYLE.md, at the same scale as Patch's
painting (assets/art/dark/patch.png) so DarkRig can hang it on his tail bone.

The tail lies along +x from its root (the left middle of the image) and sweeps toward
+y, which on the tail bone turns it up and back behind him.

Writes assets/art/dark/patch_tail_mended.png.
Run: python3 tools/art/dark_patch_tail.py
"""
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "art", "dark", "patch_tail_mended.png")
W, H = 210, 170
ROOT_Y = 40  # where the tail meets the stump, measured from the top
LENGTH = 180.0


def centre(t: np.ndarray) -> tuple:
    """Centre line of the tail at t in [0, 1]: out along x, curling toward +y."""
    x = 6 + t * LENGTH * (1 - 0.18 * t * t)
    y = ROOT_Y + 70 * t ** 2.2
    return x, y


def half_width(t: np.ndarray) -> np.ndarray:
    # thin at the root, bushy past the middle, a ragged point at the tip
    t = np.clip(t, 0, 1)
    bush = 9 + 26 * np.sin(t * math.pi * 0.8) ** 1.3
    return bush * np.clip((1.0 - t) / 0.35, 0, 1) ** 0.7 + 1.0


def main() -> None:
    rng = np.random.default_rng(11)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    ts = np.linspace(0, 1, 400)
    cx, cy = centre(ts)
    hw = half_width(ts)
    # distance to the centre line, and which t is nearest
    best = np.full((H, W), 1e9, np.float32)
    near_t = np.zeros((H, W), np.float32)
    side = np.zeros((H, W), np.float32)
    for i, t in enumerate(ts):
        d2 = (xx - cx[i]) ** 2 + (yy - cy[i]) ** 2
        closer = d2 < best
        best = np.where(closer, d2, best)
        near_t = np.where(closer, t, near_t)
        if i + 1 < len(ts):
            tx, ty = cx[i + 1] - cx[i], cy[i + 1] - cy[i]
            side = np.where(closer, np.sign(tx * (yy - cy[i]) - ty * (xx - cx[i])), side)
    dist = np.sqrt(best)
    # torn, fibrous edge
    ragged = ndimage.gaussian_filter(rng.normal(0, 1, (H, W)), 1.4) * 9
    width = half_width(near_t) + ragged
    inside = dist < width
    alpha = np.clip((width - dist) * 0.9, 0, 1) * inside
    # keep only the tail itself, not loose flecks of torn edge
    labels, n = ndimage.label(alpha > 0.05)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(alpha), labels, range(1, n + 1))
        alpha[labels != 1 + int(np.argmax(sizes))] = 0
    inside = alpha > 0.05

    # map paper: parchment and sepia, stained darker toward the edges
    edge = np.clip(dist / np.maximum(width, 1), 0, 1)
    paper = np.array([200, 178, 136], np.float32)
    sepia = np.array([138, 104, 66], np.float32)
    rgb = paper + (sepia - paper) * (edge ** 1.6)[..., None]
    rgb *= (1 + 0.08 * ndimage.gaussian_filter(rng.normal(0, 1, (H, W)), 2.0))[..., None]
    # light from the upper left: the -y side (above the line) is lit, below falls to shadow
    shade = np.where(side > 0, 1.0 - 0.32 * edge, 1.0 + 0.06 * (1 - edge))
    rgb *= shade[..., None]

    ink = np.array([22, 18, 18], np.float32)
    lines = np.zeros((H, W), np.float32)
    # contour lines of the old map, running along the tail
    for k, off in enumerate((-0.55, -0.2, 0.25, 0.6)):
        target = off * width
        wobble = np.sin(xx * 0.09 + k * 1.7) * 2.2
        signed = dist * side
        lines = np.maximum(lines, np.clip(1.0 - np.abs(signed - target - wobble), 0, 1) * 0.45)
    # a dashed route across the map
    route_y = cy[200] + np.sin((xx - 60) * 0.06) * 10
    route = (np.abs(yy - route_y) < 1.2) & ((xx // 6) % 2 == 0) & (xx > 50) & (xx < 150)
    lines = np.maximum(lines, route * 0.8)
    # a little compass rose near the bushiest part
    rx, ry = cx[230], cy[230] - 6
    r = np.sqrt((xx - rx) ** 2 + (yy - ry) ** 2)
    ang = np.arctan2(yy - ry, xx - rx)
    star = (r < 9 * (0.45 + 0.55 * np.abs(np.cos(ang * 2)) ** 6)) & (r < 9)
    ring = np.abs(r - 10) < 0.8
    lines = np.maximum(lines, star * 0.7 + ring * 0.6)
    rgb = rgb * (1 - lines[..., None]) + ink * lines[..., None]

    # a strip of yellowed tape across the middle, slightly glossy
    tape_c = cx[150]
    tape = np.abs((xx - tape_c) * 0.94 + (yy - cy[150]) * 0.34) < 9
    tape &= inside
    rgb[tape] = rgb[tape] * 0.72 + np.array([196, 170, 96], np.float32) * 0.28
    tape_edge = tape & ~ndimage.binary_erosion(tape, iterations=1)
    rgb[tape_edge] *= 0.7

    # hard black ink outline, broken where the paper frays
    solid = alpha > 0.5
    rim = solid & ~ndimage.binary_erosion(solid, iterations=2)
    broken = ndimage.gaussian_filter(rng.normal(0, 1, (H, W)), 3) > -0.6
    rgb[rim & broken] = ink
    alpha[rim & ~broken] *= 0.85

    # red thread stitches where it is sewn onto the stump
    thread = np.array([150, 40, 32], np.float32)
    for k in range(3):
        t0 = 0.035 + k * 0.03
        x0, y0 = centre(np.array(t0))
        for sgn in (1, -1):
            for s in np.linspace(-1, 1, 20):
                px = x0 + s * 3
                py = y0 + sgn * s * (half_width(np.array(t0)) + 1)
                m = (xx - px) ** 2 + (yy - py) ** 2 < 1.1
                rgb[m] = thread
                alpha[m] = 1.0

    out = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha * 255, 0, 255)]).astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    im.save(OUT)
    print("wrote", OUT, im.size)


if __name__ == "__main__":
    main()
