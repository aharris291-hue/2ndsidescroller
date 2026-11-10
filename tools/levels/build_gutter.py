"""Draws the finale's text maps: the Gutter, the drowned crease at the middle of the book
where all the flood ran in the end (F-1 The Gutter Descent).

Writes levels/finale/*.txt (F-1, and F-2's arena). Each map's legend is in its scene's TextLevel node
(scenes/levels/finale/*.tscn); the shared characters are:
  #  pulped pages and drowned books   =  frozen run-off (ice)   -  one-way plank
  ~  settled ink   > < ^ v  ink running that way   |  an updraft (a column is one)
  @  start   k  bookmark   s  Soggy   f  a frozen Soggy (only a CRUSH cracks it)
  m  moth   i  silverfish   o  scrap   1-9  story triggers   E  way on   X  way back
  R  arrival point
  G H J  wave locks (GutterLock): standing on the floor at the left gate; the right
       gate and the waves are in the scene's legend. Keep a ceiling over every lock as
       high as its gates, so nothing flies over them.
  P  a spring shutter (Shutter) standing on this cell's floor; T its pull tab

F-1 is the gauntlet: no new ideas, everything Patch has learned on the way down. The
Frog Fold and the Paper Plane Glide are in reach (climb_check); the swim under the low
ceiling needs the Blot Dive, the shutter needs the Bookmark Warp, the updraft needs the
glide, and the frozen Soggies need the Pop-Up Slam.

Run: python3 tools/levels/build_gutter.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from grid import Grid  # noqa: E402
import climb_check  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "finale")

# Each lock's left gate (column) and width in tiles, as the scene's legend has them.
LOCKS = {"G": (40, 22), "H": (123, 22), "J": (201, 18)}


def shutter(g: Grid, x: int, floor: int, rows: int, c: str) -> None:
    g.fill(x, x, 0, floor - rows - 1, "#")
    g.fill(x, x, floor - rows, floor - 1, ".")
    g.put(x, floor - 1, c)


def gutter_descent() -> Grid:
    """F-1 The Gutter Descent: from the top of the spine down into the crease, where the
    flood has nowhere left to go. Drizzle's wet footprints lead the way.
      S1 the summit's edge, and a stair of torn pages down into the dark.
      S2 the first lock: Soggies, a spitter, moths, an inked Tack Knight.
      S3 the sump: the page comes down to meet the ink; under it, a current runs on,
         and only a Blot Dive gets through.
      S4 a bookmark.
      S5 the chasm: no floor at all, and one updraft out of the dark to glide on.
      S6 the second lock: knights, a crane, a mimic, a horse, inked spitters.
      S7 a spring shutter whose tab is down a shaft: lay the ribbon, pull, warp.
      S8 frozen run-off, stepped down, with Soggies frozen into it.
      S9 a bookmark, then the last lock: everything, half of it inked.
    Then the footprints stop, and the way on goes down into the deepest fold."""
    g = Grid(230, 46)
    # S1 the summit's edge.
    g.ground(0, 16, 8)
    g.put(1, 7, "X")
    g.put(4, 7, "@")
    g.put(7, 7, "1")
    g.ground(17, 22, 11)
    g.ground(23, 28, 14)
    g.ground(29, 36, 17)
    g.put(21, 6, "m")
    g.put(25, 13, "2")
    g.put(31, 12, "m")
    g.put(34, 16, "s")
    # S2 the first lock, under a low ceiling.
    g.ground(37, 65, 20)
    g.fill(39, 64, 0, 13, "#")
    x, w = LOCKS["G"]
    g.put(x, 19, "G")
    # S3 the sump: ink six deep, a current through it, the page down to meet it.
    g.put(63, 19, "3")
    g.fill(66, 88, 22, 27, "~")
    g.fill(68, 86, 24, 25, ">")
    g.ground(66, 88, 28)
    g.fill(68, 86, 0, 21, "#")
    g.ground(89, 100, 22)
    # S4 a breath, and a bookmark.
    g.put(92, 21, "k")
    g.put(96, 21, "4")
    # S5 the chasm, and its one updraft.
    g.fill(109, 109, 16, 45, "|")
    g.put(105, 15, "m")
    g.put(114, 13, "m")
    # S6 the second lock.
    g.ground(119, 178, 18)
    g.fill(122, 148, 0, 11, "#")
    x, w = LOCKS["H"]
    g.put(x, 17, "H")
    # S7 the spring shutter, its tab down a shaft (and a slow way back up on planks).
    g.put(147, 17, "5")
    g.clear(150, 155, 18, 28)
    g.fill(149, 149, 18, 29, "#")
    g.fill(156, 156, 18, 29, "#")
    g.fill(149, 156, 29, 29, "#")
    g.put(152, 28, "T")
    g.put(154, 28, "o")
    g.plank(150, 151, 25)
    g.plank(154, 155, 22)
    g.plank(150, 151, 19)
    g.put(162, 17, "i")
    g.fill(170, 190, 0, 11, "#")
    shutter(g, 172, 18, 6, "P")
    g.put(175, 17, "o")
    # S8 frozen run-off, stepped down.
    g.put(177, 17, "6")
    for i, x0 in enumerate(range(179, 195, 4)):
        top = 20 + 2 * i
        g.clear(x0, x0 + 3, 0, top - 1)
        g.fill(x0, x0 + 3, 0, 11, "#")
        g.ground(x0, x0 + 3, top)
        g.fill(x0, x0 + 3, top, top, "=")
    g.put(184, 21, "f")
    g.put(192, 25, "f")
    # S9 a bookmark, the last lock, and the way on.
    g.ground(195, 229, 28)
    g.put(197, 27, "k")
    g.fill(200, 229, 0, 21, "#")
    x, w = LOCKS["J"]
    g.put(x, 27, "J")
    g.put(222, 27, "7")
    g.put(225, 27, "R")
    g.put(228, 27, "E")
    return g


def deepest_fold() -> Grid:
    """F-2 The Deepest Fold: the bottom of the Gutter, where the Sogg stands in the
    water at the right of the page (BossSogg, placed in the scene). A flat floor to
    fight on, the length of the page (the Sogg stands at the right of it, and walls off
    the rest itself), and the way back up behind Patch."""
    g = Grid(32, 17)
    g.ground(0, 31, 14)
    g.put(1, 13, "X")
    g.put(4, 13, "@")
    return g


def _rows(grid: Grid) -> list:
    return ["".join(r) for r in grid.rows]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    g = gutter_descent()
    g.write(os.path.join(OUT, "f_1_the_gutter_descent.txt"),
        "F-1 The Gutter Descent (drawn by tools/levels/build_gutter.py; legend in\nscenes/levels/finale/f_1_the_gutter_descent.tscn)\nabilities: frog glide")
    deepest_fold().write(os.path.join(OUT, "f_2_the_deepest_fold.txt"),
        "F-2 The Deepest Fold, the Sogg's arena (drawn by tools/levels/build_gutter.py;\nlegend in scenes/levels/finale/f_2_the_deepest_fold.tscn)")
    ok = True
    climb_check.UP, climb_check.GLIDE = 4.5, True
    rows = _rows(g)
    reach = climb_check.climbable(rows)[0]
    print("F-1 climbable (shutter open):", reach)
    ok &= reach
    # The shutter's tab can't be reached and run back from before it springs shut:
    # from the tab it's a climb out of the shaft and 20 tiles to the shutter.
    tab = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "T")
    door = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "P")
    back_up = climb_check.climbable(rows, start=tab, goal=(door[0] - 2, door[1]))[0]
    print("F-1 the slow way back up out of the shaft:", back_up, "(%d tiles from the tab to the shutter)" % (door[0] - tab[0]))
    ok &= back_up and door[0] - tab[0] >= 20
    # The chasm can't be crossed without the updraft.
    no_draft = [r.replace("|", ".") for r in rows]
    crossed = climb_check.climbable(no_draft, goal=(121, 17))[0]
    print("F-1 the chasm crossed without the updraft:", crossed)
    ok &= not crossed
    # Every lock has a ceiling over it as tall as its gates, and its letter where the
    # legend's widths expect it.
    for c, (x, w) in LOCKS.items():
        y = next(y for y, r in enumerate(rows) if r[x] == c)
        top = max(yy for yy in range(y) if rows[yy][x + 1] == "#")
        ceiling = all(rows[top][xx] == "#" for xx in range(x, x + w + 1))
        print("F-1 lock", c, "roofed over:", ceiling, "(%d rows)" % (y - top))
        ok &= ceiling and y - top == 6
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
