"""Draws the optional Blank Margins' text maps: M-1 The Blank Margins, and the
Unwritten Forecast's arena.

Writes levels/margins/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/margins/*.tscn); the shared characters are:
  #  blank sheets   $  grey slate   @  start   k  bookmark   o  scrap
  u  a rain ledge (RainPlatform): there only while it pours, 3 tiles wide, its top on
     the row below the letter
  O  a grapple ring (the Tape Tail)   g  a gust (its size and push in the legend)
  s  Soggy   p  ink spitter   n  tack knight   m  paper moth
  1-9  story triggers   E  way on   X  way back   R  arrival point

There's no floor under the Margins: the gaps go down to nothing. Everything Patch
crosses between the islands of paper is written by the rain (RainShower), so the
whole level is a walk against the weather: wait under the drizzle, watch the outlines
darken, go when it pours, and be on paper again before it eases. Only the Tape Tail
is needed (the Margins open after Lanternfold).

Run: python3 tools/levels/build_margins.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from grid import Grid  # noqa: E402
import climb_check  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "margins")


def ledge(g: Grid, x: int, top: int) -> None:
    """A rain ledge whose top is row `top`, centred on column x."""
    g.put(x, top - 1, "u")


def blank_margins() -> Grid:
    """M-1 The Blank Margins: past the last written page, the paper goes on, white and
    empty, in islands over nothing.
      S1 a first island, and one gap with one ledge in it: the lesson.
      S2 a stair of ledges up over the void, moths in the rain.
      S3 brass rings someone screwed into the blank paper, and a ledge between them.
      S4 a bookmark, and Soggies that came this far.
      S5 a wind across a row of ledges, with one slate pillar to wait out a shower on.
      S6 down off the far side.
      S7 the last chasm: a ledge, a ring, a ledge. Then the edge of the page."""
    g = Grid(200, 30)
    # S1
    g.ground(0, 13, 20)
    g.put(1, 19, "X")
    g.put(4, 19, "@")
    g.put(7, 19, "1")
    ledge(g, 18, 20)
    g.ground(23, 34, 20)
    g.put(25, 19, "2")
    g.put(30, 14, "m")
    # S2 the stair
    ledge(g, 38, 18)
    ledge(g, 43, 16)
    ledge(g, 48, 14)
    g.put(45, 9, "m")
    g.ground(52, 62, 13)
    g.put(54, 12, "3")
    g.put(58, 12, "s")
    g.put(55, 7, "m")
    # S3 rings
    g.put(67, 8, "O")
    ledge(g, 72, 11)
    g.put(77, 8, "O")
    # S4
    g.ground(81, 96, 12)
    g.put(84, 11, "k")
    g.put(87, 11, "4")
    g.put(90, 11, "s")
    g.put(93, 11, "p")
    g.put(95, 11, "o")
    # S5 the wind
    g.put(97, 12, "g")
    ledge(g, 100, 13)
    ledge(g, 105, 13)
    g.ground(109, 110, 12, "$")
    g.put(110, 11, "5")
    ledge(g, 114, 13)
    ledge(g, 119, 13)
    g.ground(123, 136, 12)
    g.put(126, 11, "n")
    g.put(131, 11, "s")
    g.put(134, 11, "o")
    # S6 down
    ledge(g, 140, 16)
    ledge(g, 145, 19)
    g.put(142, 10, "m")
    g.ground(149, 170, 20)
    g.put(152, 19, "6")
    g.put(158, 19, "s")
    g.put(163, 19, "p")
    g.put(166, 13, "m")
    # S7 the last chasm
    ledge(g, 174, 20)
    g.put(180, 14, "O")
    ledge(g, 185, 19)
    g.ground(189, 199, 20)
    g.put(191, 19, "7")
    g.put(194, 19, "R")
    g.put(198, 19, "E")
    return g


def forecast_arena() -> Grid:
    """The last blank page, where the Unwritten Forecast waits (BossForecast, placed in
    the scene). A floor with a gap in the middle that the boss's own paper covers at
    first, and later doesn't; over the gap, two rain ledges at floor height."""
    g = Grid(30, 17)
    g.ground(0, 10, 14)
    g.ground(20, 29, 14)
    g.put(1, 13, "X")
    g.put(4, 13, "@")
    ledge(g, 13, 14)
    ledge(g, 17, 14)
    return g


def _rows(grid: Grid) -> list:
    return ["".join(r) for r in grid.rows]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    g = blank_margins()
    g.write(os.path.join(OUT, "m_1_the_blank_margins.txt"),
        "M-1 The Blank Margins (drawn by tools/levels/build_margins.py; legend in\nscenes/levels/margins/m_1_the_blank_margins.tscn)\nabilities: rain")
    forecast_arena().write(os.path.join(OUT, "the_forecast.txt"),
        "The Unwritten Forecast's arena (drawn by tools/levels/build_margins.py;\nlegend in scenes/levels/margins/the_forecast.tscn)")
    ok = True
    climb_check.UP, climb_check.GLIDE, climb_check.RAIN = 2.5, False, True
    rows = _rows(g)
    reach = climb_check.climbable(rows)[0]
    print("M-1 climbable in the rain:", reach)
    ok &= reach
    # Without the rain, the first gap can't be crossed: every crossing needs it.
    dry = [r.replace("u", ".") for r in rows]
    crossed = climb_check.climbable(dry, goal=(24, 19))[0]
    print("M-1 the first gap crossed with no rain:", crossed)
    ok &= not crossed
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
