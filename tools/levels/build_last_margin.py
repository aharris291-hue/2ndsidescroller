"""Draws the Last Margin (the true ending): the inside margin of the book's very last
page, the blank one at the back that Nell drew on, where the ink from the Gutter came
up through the paper and wrote Patch's worst night back into the book.

Writes levels/postgame/the_last_margin.txt. Its legend is in the scene's TextLevel node
(scenes/levels/postgame/the_last_margin.tscn); the characters are:
  #  blank sheets   $  grey slate   -  a ruled line (one-way)   @  start   k  bookmark
  o  scrap   O  a grapple ring (the Tape Tail)
  s  Soggy   p  ink spitter   n  tack knight   m  paper moth (all of them inked)
  1-6  pencil notes in the margin (story triggers)   X  way back   Y  the arena's
     far wall (the goal for the climb check: the Runaway is placed in the scene)

  S1 the back cover's inside, and the first note.
  S2 ruled lines up a torn stair of paper, moths in the dark.
  S3 rings over a tear right through the page.
  S4 Nell's crayon, and things that came up out of the ink to stand on it.
  S5 a long drop off the end of the drawing, glided.
  S6 a bookmark, and the last note before the bottom of the margin.
  Arena: a flat floor 40 tiles wide, walled at the far end, where he waits.

Needs everything Patch has by the end of the book (the Tape Tail and the glide).

Run: python3 tools/levels/build_last_margin.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from grid import Grid  # noqa: E402
import climb_check  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "postgame")
ARENA = 136


def last_margin() -> Grid:
    g = Grid(180, 22)
    # S1
    g.ground(0, 18, 18)
    g.put(1, 17, "X")
    g.put(4, 17, "@")
    g.put(8, 17, "1")
    g.put(15, 17, "o")
    # S2 a torn stair of ruled lines
    g.ground(19, 24, 16)
    g.plank(26, 29, 14)
    g.plank(31, 34, 12)
    g.ground(36, 48, 11)
    g.put(28, 9, "m")
    g.put(38, 10, "2")
    g.put(42, 10, "s")
    g.put(46, 10, "o")
    g.put(44, 6, "m")
    # S3 rings over the tear
    g.put(53, 7, "O")
    g.ground(57, 58, 12, "$")
    g.put(62, 7, "O")
    g.ground(65, 92, 12)
    # S4 Nell's drawing
    g.put(67, 11, "3")
    g.put(72, 11, "n")
    g.put(78, 11, "p")
    g.put(82, 11, "s")
    g.put(86, 11, "s")
    g.put(88, 7, "m")
    g.put(90, 11, "o")
    g.ground(91, 92, 10, "$")
    g.put(92, 9, "4")
    # S5 the long drop, glided
    g.ground(110, 134, 18)
    g.put(112, 17, "k")
    # S6
    g.put(116, 17, "5")
    g.put(121, 17, "n")
    g.put(126, 17, "p")
    g.put(127, 12, "m")
    g.put(131, 17, "o")
    # The arena
    g.ground(135, 179, 18)
    g.put(ARENA + 4, 17, "6")
    g.fill(178, 179, 0, 17, "$")
    g.put(176, 17, "Y")
    return g


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    g = last_margin()
    g.write(os.path.join(OUT, "the_last_margin.txt"),
        "The Last Margin (drawn by tools/levels/build_last_margin.py; legend in\nscenes/levels/postgame/the_last_margin.tscn)\nabilities: glide")
    climb_check.UP, climb_check.GLIDE = 2.5, True
    ok = climb_check.climbable(["".join(r) for r in g.rows])[0]
    print("The Last Margin climbable:", ok)
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
