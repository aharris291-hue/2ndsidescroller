"""Builds the Dark Rebuild art kit from the concept paintings.

Inputs live in the shared project folder (concepts/dark), made with the ElevenLabs
image models. Background removal uses rembg (isnet-general-use).
Run:  python3 tools/art/dark_assets.py [concept_dir]
Outputs go to assets/art/dark/.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageEnhance

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/concepts/dark")
OUT = Path(__file__).resolve().parents[2] / "assets/art/dark"
OUT.mkdir(parents=True, exist_ok=True)

_session = None


def cutout(name: str) -> Image.Image:
    global _session
    from rembg import new_session, remove
    if _session is None:
        _session = new_session("isnet-general-use")
    im = Image.open(SRC / f"{name}.png").convert("RGB")
    out = remove(im, session=_session)
    a = np.array(out)
    # Drop faint matte noise so the bounding box hugs the figure.
    alpha = a[:, :, 3]
    alpha[alpha < 24] = 0
    a[:, :, 3] = alpha
    img = Image.fromarray(a)
    # Joints are measured on the first cutout, cropped to rembg's raw bounding box.
    img.info["raw_origin"] = out.getbbox()[:2]
    return img


def bbox(im: Image.Image):
    return im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()


# --- Patch -------------------------------------------------------------------
# Joints measured on the concept painting (he faces LEFT there).
PATCH_JOINTS = {
    "hips": (392, 372), "chest": (372, 262), "neck": (332, 218), "head": (282, 140), "head_tip": (250, 40),
    "shoulder_f": (300, 282), "elbow_f": (242, 334), "hand_f": (208, 410), "shears_tip": (18, 560),
    "shoulder_b": (452, 232), "elbow_b": (510, 302), "hand_b": (548, 392),
    "hip_f": (345, 410), "knee_f": (300, 535), "foot_f": (245, 655),
    "hip_b": (430, 410), "knee_b": (468, 530), "foot_b": (535, 680),
    "tail": (478, 392), "tail_tip": (575, 515),
}
PATCH_HEIGHT = 360


def build_patch():
    im = cutout("hero_patch")
    ox, oy = im.info["raw_origin"]
    x0, y0, x1, y1 = bbox(im)
    pad = 6
    x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)
    crop = im.crop((x0, y0, x1, y1)).transpose(Image.FLIP_LEFT_RIGHT)
    s = PATCH_HEIGHT / crop.height
    final = crop.resize((round(crop.width * s), PATCH_HEIGHT), Image.LANCZOS)
    final.save(OUT / "patch.png")
    w = x1 - x0
    joints = {k: [round((w - (x + ox - x0)) * s, 1), round((y + oy - y0) * s, 1)] for k, (x, y) in PATCH_JOINTS.items()}
    (OUT / "patch_rig.json").write_text(json.dumps({"size": final.size, "joints": joints}, indent=1))
    split_patch_layers(final, joints)
    print("patch", final.size)


def _seg_dist(xs, ys, a, b):
    a = np.array(a, np.float32)
    b = np.array(b, np.float32)
    ab = b - a
    t = np.clip(((xs - a[0]) * ab[0] + (ys - a[1]) * ab[1]) / max(float(ab @ ab), 1e-3), 0, 1)
    return np.hypot(xs - (a[0] + ab[0] * t), ys - (a[1] + ab[1] * t))


def split_patch_layers(final: Image.Image, j: dict):
    """Cuts the painting into three puppet layers: back arm, body, front (shears) arm.
    The body layer gets the hidden bits under the front arm painted back in, so the
    arm can swing away without leaving a hole."""
    import cv2
    from scipy import ndimage
    rgba = np.array(final)
    h, w = rgba.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    alpha = rgba[:, :, 3] > 20
    body_bones = [("hips", "chest"), ("chest", "neck"), ("neck", "head_tip"), ("hip_f", "knee_f"), ("knee_f", "foot_f"),
                  ("hip_b", "knee_b"), ("knee_b", "foot_b"), ("tail", "tail_tip")]
    d_body = np.min([_seg_dist(xs, ys, j[a], j[b]) for a, b in body_bones], axis=0)
    d_upper = _seg_dist(xs, ys, j["shoulder_f"], j["elbow_f"])
    d_lower = _seg_dist(xs, ys, j["elbow_f"], j["hand_f"])
    d_blade = _seg_dist(xs, ys, j["hand_f"], j["shears_tip"])
    d_rings = np.hypot(xs - j["hand_f"][0], ys - j["hand_f"][1])
    front = alpha & (((d_upper < 12) & (d_upper < d_body - 2)) | ((d_lower < 13) & (d_lower < d_body + 3))
                     | ((d_blade < 15) & (d_body > 12)) | (d_rings < 32))
    d_back = np.min([_seg_dist(xs, ys, j["shoulder_b"], j["elbow_b"]), _seg_dist(xs, ys, j["elbow_b"], j["hand_b"])], axis=0)
    back = alpha & ~front & (d_back < 19) & (d_back < d_body + 2)
    body = alpha & ~front & ~back
    # Drop stray scraps cut off from the main body (bits of arm and blade edges).
    labels, n = ndimage.label(ndimage.binary_dilation(body, iterations=1))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
        body &= labels == (1 + int(np.argmax(sizes)))
    # Fill the body where the front arm covered it: holes inside the body, plus a closing.
    filled = ndimage.binary_fill_holes(ndimage.binary_closing(body | (front & (d_body < 22)), iterations=3))
    filled &= ~(front & (d_body >= 22))
    hole = filled & ~body
    rgb = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2BGR)
    rgb = cv2.inpaint(rgb, (hole | (~alpha & filled)).astype(np.uint8) * 255, 5, cv2.INPAINT_TELEA)
    body_rgba = np.dstack([cv2.cvtColor(rgb, cv2.COLOR_BGR2RGB), (filled * 255).astype(np.uint8)])
    body_rgba[:, :, 3] = np.where(body, rgba[:, :, 3], body_rgba[:, :, 3])
    def layer(mask):
        out = rgba.copy()
        out[:, :, 3] = np.where(mask, rgba[:, :, 3], 0)
        return out
    Image.fromarray(body_rgba).save(OUT / "patch_body.png")
    Image.fromarray(layer(front)).save(OUT / "patch_arm_f.png")
    Image.fromarray(layer(back)).save(OUT / "patch_arm_b.png")


# --- The Sogg / Sodden grunt ------------------------------------------------------
def build_sogg():
    im = cutout("boss_the_sogg")
    crop = im.crop(bbox(im))
    # Kept facing left: Soggy flips its sprite when it turns right.
    s = 420 / crop.height
    crop.resize((round(crop.width * s), 420), Image.LANCZOS).save(OUT / "sogg.png")
    print("sogg", crop.size)


# --- Backdrop ----------------------------------------------------------------
def build_backdrop():
    import cv2
    im = cv2.imread(str(SRC / "world_drowned_kingdom.png"))
    # Paint out the little fox silhouette on the left ledge.
    mask = np.zeros(im.shape[:2], np.uint8)
    cv2.rectangle(mask, (182, 455), (292, 540), 255, -1)
    region = im[455:540, 182:292]
    dark = (region.max(axis=2) < 60).astype(np.uint8) * 255
    mask[:] = 0
    mask[455:540, 182:292] = cv2.dilate(dark, np.ones((7, 7), np.uint8))
    im = cv2.inpaint(im, mask, 9, cv2.INPAINT_TELEA)
    rgb = Image.fromarray(cv2.cvtColor(im, cv2.COLOR_BGR2RGB))
    big = rgb.resize((2400, round(2400 * rgb.height / rgb.width)), Image.LANCZOS)
    big = big.filter(ImageFilter.GaussianBlur(1.2))
    big = ImageEnhance.Brightness(big).enhance(0.8)
    big.save(OUT / "bg_drowned.png")
    print("backdrop", big.size)


# --- Ground: a slab of soaked, stacked pages -----------------------------------------
def noise(w, h, scale, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((h // scale + 2, w // scale + 2))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((w + 2 * scale, h + 2 * scale), Image.BICUBIC)
    return np.array(img, dtype=np.float32)[scale:scale + h, scale:scale + w] / 255.0


def tileable(arr):
    # Blend the left and right halves so the strip repeats without a seam.
    w = arr.shape[1]
    ramp = np.linspace(0, 1, w)[None, :, None] if arr.ndim == 3 else np.linspace(0, 1, w)[None, :]
    return arr * (1 - ramp) + np.roll(arr, w // 2, axis=1) * ramp


def build_ground():
    w, h = 512, 256
    rng = np.random.default_rng(7)
    base = np.zeros((h, w, 3), np.float32)
    y = 0
    rows = []
    while y < h:
        th = int(rng.integers(5, 14))
        rows.append((y, th))
        y += th
    for (y, th) in rows:
        tone = rng.uniform(0.17, 0.32)
        tint = np.array([0.92, 0.95, 1.0]) * tone + np.array([0.06, 0.05, 0.03]) * rng.uniform(0, 1)
        wobble = (noise(w, 1, 32, int(rng.integers(1e6)))[0] * 6).astype(int)
        edge_mask = noise(w, 1, 20, int(rng.integers(1e6)))[0] > 0.55
        for x in range(w):
            y0 = min(h, y + wobble[x])
            base[y0:min(h, y0 + th), x] = tint
            if y0 < h and edge_mask[x]:
                base[y0, x] = tint * 1.35  # wet sheen along parts of each page edge
    grain = noise(w, h, 3, 1)[:, :, None] * 0.12 + noise(w, h, 24, 2)[:, :, None] * 0.18
    stains = (noise(w, h, 40, 3) > 0.62)[:, :, None] * np.array([0.05, 0.04, 0.02])
    img = base * (0.8 + grain) - stains
    # Darker deeper down, and a soaked black lip at the very top.
    img *= np.linspace(1.15, 0.45, h)[:, None, None]
    img[:6] *= 0.35
    img = tileable(np.clip(img, 0, 1))
    alpha = np.ones((h, w, 1), np.float32)
    # Ragged torn top edge.
    edge = (noise(w, 1, 9, 5)[0] * 7 + noise(w, 1, 2, 6)[0] * 3).astype(int)
    edge = tileable(edge[None, :].astype(np.float32))[0].astype(int)
    for x in range(w):
        alpha[:edge[x], x] = 0
    out = np.concatenate([img, alpha], axis=2)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(OUT / "ground.png")
    print("ground", (w, h))


if __name__ == "__main__":
    build_patch()
    build_sogg()
    build_backdrop()
    build_ground()
