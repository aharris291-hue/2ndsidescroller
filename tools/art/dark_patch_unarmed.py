"""Patch's front arm without Gran's shears (assets/art/dark/patch_arm_f_bare.png), for the
Prologue before he finds them. DarkRig swaps it in while he lacks the "crease_swipe" ability.

Everything from the wrist down (the fist, the loops and the blades) is cut away, and the
clenched paw from his back arm is pasted on in its place.
Run: python3 tools/art/dark_patch_unarmed.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter

DARK = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "dark")
SHOULDER = np.array([147.4, 141.4])
HAND = np.array([193.5, 205.6])
PAW = np.array([23.1, 196.5])  # the back arm's fist
PAW_TURN = 20.0


def main() -> None:
    img = Image.open(os.path.join(DARK, "patch_arm_f.png")).convert("RGBA")
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    axis = (HAND - SHOULDER) / np.linalg.norm(HAND - SHOULDER)
    t = (xx - SHOULDER[0]) * axis[0] + (yy - SHOULDER[1]) * axis[1]
    hand_t = float(np.dot(HAND - SHOULDER, axis))
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    brass = (r - b > 55) & (g - b > 25) & (r > 110)
    steel = (np.abs(r - g) < 14) & (np.abs(g - b) < 16) & (r > 95)
    side = np.abs((xx - SHOULDER[0]) * -axis[1] + (yy - SHOULDER[1]) * axis[0])
    cut = (t > hand_t - 14) | ((brass | steel) & (t > hand_t - 40)) | ((t > hand_t - 26) & (side > 13))
    alpha = a[..., 3].copy()
    alpha[cut] = 0
    # soften the new edge
    soft = np.asarray(Image.fromarray(alpha.astype(np.uint8)).filter(ImageFilter.MinFilter(3)), np.float32)
    alpha = np.where(t > hand_t - 20, soft, alpha)
    a[..., 3] = alpha
    out = Image.fromarray(a.astype(np.uint8))
    # the back arm's clenched paw, turned to follow the front forearm
    back = Image.open(os.path.join(DARK, "patch_arm_b.png")).convert("RGBA")
    paw = back.crop((int(PAW[0]) - 24, int(PAW[1]) - 22, int(PAW[0]) + 24, int(PAW[1]) + 26))
    paw = paw.rotate(PAW_TURN, resample=Image.BICUBIC, expand=True)
    at = HAND - axis * 8
    out.alpha_composite(paw, (int(at[0] - paw.width / 2), int(at[1] - paw.height / 2)))
    out.save(os.path.join(DARK, "patch_arm_f_bare.png"))
    print("wrote patch_arm_f_bare.png")


if __name__ == "__main__":
    main()
