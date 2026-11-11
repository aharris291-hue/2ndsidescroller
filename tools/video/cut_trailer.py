"""Cuts the store trailer from Movie Maker footage.

    python3 tools/video/cut_trailer.py <footage.avi> <trailer_marks.txt> <out.mp4>

The footage and marks come from tools/godot/trailer_capture.gd. Clips are cut from
the mark where each one starts, set between title cards (PIL-rendered in the game's
serif), and laid over the game's own "Drowned" theme with the clips' sound under it.
Needs ffmpeg and Pillow.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, subprocess, sys, tempfile

FPS = 30
W, H = 1920, 1080
SERIF = "assets/fonts/LiberationSerif-Regular.ttf"
ITALIC = "assets/fonts/LiberationSerif-Italic.ttf"
MUSIC = "assets/audio/dark/mus_drowned.ogg"
BONE = (230, 220, 203)
BLOOD = (150, 32, 26)

# (kind, what, seconds): "card" shows text, "clip" cuts footage from that mark.
EDIT = [
    ("card", "On the night of the flood,\nPatch ran.", 3.6),
    ("clip", "SoddenFields", 4.5),
    ("card", "He left Drizzle to drown.", 3.0),
    ("clip", "SpineHub", 2.3),
    ("card", "Now the ink is rising.", 2.6),
    ("clip", "OldMillwheel", 4.0),
    ("clip", "BlotchKraken", 3.6),
    ("clip", "GreyHeron", 3.4),
    ("card", "Take up Gran's shears.", 2.4),
    ("clip", "Bindwell", 3.2),
    ("clip", "Barker", 3.2),
    ("clip", "Redactor", 3.2),
    ("card", "Face what you left behind.", 3.0),
    ("clip", "TheSogg", 5.0),
    ("logo", "", 5.5),
]


def run(*args: str) -> None:
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def card(text: str, path: str) -> None:
    im = Image.new("RGB", (W, H), (10, 8, 7))
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(ITALIC, 76)
    box = d.multiline_textbbox((0, 0), text, font=font, spacing=24, align="center")
    x, y = (W - (box[2] - box[0])) / 2 - box[0], (H - (box[3] - box[1])) / 2 - box[1]
    d.multiline_text((x, y), text, font=font, fill=BONE, spacing=24, align="center")
    im.save(path)


def logo(path: str) -> None:
    sys.path.insert(0, "tools/art")
    from steam_capsules import logo as make_logo, key, crop_to
    bg = crop_to(key(), W, H, 0.5, 0.5).filter(ImageFilter.GaussianBlur(2))
    bg = Image.eval(bg, lambda v: int(v * 0.45))
    lg = make_logo(1100)
    bg = bg.convert("RGBA")
    bg.alpha_composite(lg, ((W - lg.width) // 2, (H - lg.height) // 2 - 60))
    d = ImageDraw.Draw(bg)
    small = ImageFont.truetype(SERIF, 44)
    t = "Wishlist on Steam"
    tw = d.textlength(t, font=small)
    d.text(((W - tw) / 2, (H + lg.height) / 2 + 10), t, font=small, fill=BONE)
    bg.convert("RGB").save(path)


def main() -> None:
    footage, marks_path, out = sys.argv[1:4]
    marks = {}
    for line in open(marks_path).read().split("\n"):
        if line.strip():
            name, frame = line.split()
            marks[name] = int(frame) / FPS
    tmp = tempfile.mkdtemp()
    parts = []
    for i, (kind, what, secs) in enumerate(EDIT):
        part = os.path.join(tmp, f"{i:02d}.mp4")
        fade = f"fade=t=in:st=0:d=0.35,fade=t=out:st={secs - 0.35:.2f}:d=0.35"
        if kind == "clip":
            # Skip the first half second after the mark: the fight is just waking up.
            start = marks[what] + 0.5
            # Never run into the next page turn: stop a few frames before the clip's end mark.
            if what + "_end" in marks:
                secs = min(secs, marks[what + "_end"] - start - 0.1)
                fade = f"fade=t=in:st=0:d=0.35,fade=t=out:st={secs - 0.35:.2f}:d=0.35"
            run("ffmpeg", "-y", "-ss", f"{start:.3f}", "-t", f"{secs}", "-i", footage,
                "-vf", f"scale={W}:{H},{fade}", "-af", f"afade=t=in:d=0.3,afade=t=out:st={secs - 0.3:.2f}:d=0.3",
                "-r", str(FPS), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-ar", "48000", "-ac", "2", part)
        else:
            png = os.path.join(tmp, f"{i:02d}.png")
            card(what, png) if kind == "card" else logo(png)
            run("ffmpeg", "-y", "-loop", "1", "-t", f"{secs}", "-i", png,
                "-f", "lavfi", "-t", f"{secs}", "-i", "anullsrc=r=48000:cl=stereo",
                "-vf", fade, "-r", str(FPS), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", part)
        parts.append(part)
    listing = os.path.join(tmp, "parts.txt")
    open(listing, "w").write("".join(f"file '{p}'\n" for p in parts))
    joined = os.path.join(tmp, "joined.mp4")
    run("ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", joined)
    total = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", joined],
        capture_output=True, text=True).stdout)
    # The theme over everything; the game's own sound (cuts, hits, rain) under it.
    run("ffmpeg", "-y", "-i", joined, "-i", MUSIC, "-filter_complex",
        f"[0:a]volume=0.55[g];[1:a]volume=0.9,afade=t=out:st={total - 3:.2f}:d=3[m];[g][m]amix=inputs=2:duration=first:normalize=0[a]",
        "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out)


if __name__ == "__main__":
    main()
