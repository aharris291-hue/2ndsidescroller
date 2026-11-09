"""Draws Region 3's text maps: Watermark Marsh, where the ink settled (Phase 3, part 1:
3-1 to 3-3).

Writes levels/marsh/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/marsh/*.tscn); the shared characters are:
  #  peat   $  flagstone / stone   -  one-way plank (boardwalks, shelves)
  ~  settled ink   > < ^ v  ink running that way (a current)
  @  start   k  bookmark   s  Soggy   d  drips   i  ink spitter   m  moth   n  Tack Knight
  b  mimic book   o  scrap   1-9  story triggers   E  exit   X  way back
Ink burns a heart until Patch has the Blot Dive (3-1); with it he swims through ink on
one breath (26 tiles; a current carries him about twice as far, and can't be swum
against).

The Sluice House puzzle (3-3) is checked here too: `solve_sluice_house` tries every
setting of its three wheels and fails the build unless exactly the intended ones open
the way through.

Run: python3 tools/levels/build_marsh.py
"""
import itertools
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from grid import Grid  # noqa: E402
import climb_check  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "marsh")


def ink(g: Grid, x0: int, x1: int, top: int, depth: int, c: str = "~") -> None:
    """A pool `depth` rows deep from row `top`, with ground under it."""
    g.fill(x0, x1, top, top + depth - 1, c)


def sump_road() -> Grid:
    """3-1 The Sump Road: boardwalks over black ink, which burns. Halfway, a watermark in
    a paper hill shows Patch the night of the flood, and he learns to let the ink in:
    the Blot Dive ('B'). Then walls to dive under, a bookmark, a fight on the peat, and a
    low tunnel of running ink to the far bank."""
    g = Grid(250, 26)
    F = 18
    g.ground(0, 249, F)
    # S1 the bank: the first ink, a ditch to jump.
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(6, F - 1, "1")
    ink(g, 18, 20, F, 3)
    g.put(26, F - 1, "s")
    # S2 the boardwalk over the sump: planks on posts, gaps to jump, a Soggy and moths.
    g.put(30, F - 1, "2")
    ink(g, 33, 79, F, 5)
    for x0, x1 in ((33, 38), (41, 46), (49, 51), (55, 60), (63, 66), (70, 75)):
        g.plank(x0, x1, F - 1)
    g.ground(52, 53, F - 1)
    g.put(57, F - 2, "s")
    g.put(64, F - 6, "m")
    g.put(72, F - 6, "m")
    g.put(76, F - 2, "o")
    # S3 the watermark hill, and the Blot Dive.
    g.put(84, F - 1, "3")
    g.ground(86, 96, F - 2, "$")
    g.put(92, F - 3, "B")
    g.put(98, F - 1, "4")
    # S4 let it in: a wall down into a pool, dived under.
    ink(g, 100, 112, F, 4)
    g.fill(106, 106, F - 8, F + 1, "$")
    g.put(115, F - 1, "k")
    # S5 the deep trench: two walls, a breath between them.
    g.put(118, F - 1, "5")
    ink(g, 120, 146, F, 6)
    for wx in (128, 140):
        g.fill(wx, wx + 1, F - 8, F + 2, "$")
    g.put(134, F + 4, "o")
    # S6 the peat banks: a fight, with ink between the banks.
    g.put(150, F - 1, "6")
    g.put(156, F - 1, "s")
    g.put(162, F - 1, "s")
    ink(g, 166, 168, F, 4)
    g.ground(171, 178, F - 2, "$")
    g.put(174, F - 3, "i")
    g.put(182, F - 1, "n")
    ink(g, 186, 189, F, 4)
    g.put(193, F - 1, "s")
    g.put(196, F - 6, "m")
    # S7 the culvert: running ink under a stone roof, too long to swim without the current.
    g.put(200, F - 1, "7")
    ink(g, 204, 240, F, 4, ">")
    g.fill(208, 236, F - 3, F - 1, "$")
    g.put(222, F - 4, "o")
    g.put(244, F - 1, "8")
    g.put(247, F - 1, "E")
    g.put(242, F - 1, "R")   # back from the ledger
    return g


def drowned_ledger() -> Grid:
    """3-2 The Drowned Ledger: the marsh's sunken archive. A two-layer channel (the top
    runs against Patch, the bottom with him), stacks of ledgers to climb and fight on,
    an upwelling shaft that throws him to the high shelves, and a drain to the exit."""
    g = Grid(230, 34)
    F = 24
    g.ground(0, 229, F, "$")
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(6, F - 1, "1")
    # S2 the two-layer channel under a roof of shelving.
    g.put(14, F - 1, "2")
    ink(g, 18, 62, F, 2, "<")
    ink(g, 18, 62, F + 2, 2, ">")
    g.fill(22, 58, F - 3, F - 1, "$")
    g.put(40, F + 3, "o")
    # S3 the stacks: ledgers piled in steps, a fight.
    g.put(68, F - 1, "3")
    for x0, x1, top in ((72, 76, F - 2), (78, 81, F - 4), (84, 88, F - 6)):
        g.ground(x0, x1, top, "$")
    g.put(74, F - 3, "b")
    g.put(86, F - 7, "i")
    g.put(80, F - 9, "m")
    g.put(92, F - 1, "s")
    g.put(95, F - 1, "k")
    # S4 the upwelling: a channel along the floor feeds a shaft that rises to the
    # high shelves.
    g.put(97, F - 1, "4")
    ink(g, 99, 112, F, 3, ">")
    ink(g, 113, 116, 9, F + 3 - 9, "^")
    g.ground(117, 120, F - 5, "$")  # a wall: no walking past the shaft at floor level
    g.ground(105, 112, 9, "$")
    g.clear(105, 112, F, F + 2)
    ink(g, 105, 112, F, 3, ">")
    g.fill(105, 112, F - 1, F - 1, "$")
    g.ground(117, 122, 9, "$")
    # S5 the high shelves: a walk along the tops of the stacks.
    g.put(119, 8, "5")
    for x0, x1 in ((126, 130), (134, 137), (141, 146), (150, 153)):
        g.plank(x0, x1, 9)
    g.put(128, 8, "o")
    g.put(144, 4, "m")
    g.put(158, 8, "k")
    g.ground(156, 164, 9, "$")
    g.put(162, 8, "i")
    # down the far side, stair-stepped
    for x0, x1, top in ((166, 169, 12), (172, 175, 15), (178, 181, 18), (184, 187, 21)):
        g.ground(x0, x1, top, "$")
    g.put(190, F - 1, "6")
    g.put(194, F - 1, "b")
    g.put(198, F - 1, "s")
    # S6 the drain: running ink under the floor of the archive, out to the exit.
    ink(g, 202, 224, F, 3, ">")
    g.fill(205, 222, F - 3, F - 1, "$")
    g.put(226, F - 1, "7")
    g.put(228, F - 1, "E")
    g.put(225, F - 1, "R")   # back from the sluice house
    return g


SLUICE_W, SLUICE_H = 40, 20


def sluice_house(flip=(False, False, False)) -> Grid:
    """3-3 The Sluice House: a basin of three channels, split down the middle by a wall
    with one gap. Every channel runs against Patch. Three wheels each turn a channel
    round: one on the left middle channel, one on the right middle channel, one (a
    decoy) on the left bottom and right top together. Only the middle way, both halves
    turned, carries him through on one breath to the outflow at the foot of the right
    shaft (the exit)."""
    g = Grid(SLUICE_W, SLUICE_H)
    top = 10
    g.ground(0, 39, top, "$")
    g.clear(4, 36, top, 17)
    # dividers and the middle wall
    g.fill(6, 34, 12, 12, "$")
    g.fill(6, 34, 15, 15, "$")
    g.fill(20, 20, 10, 17, "$")
    g.clear(20, 20, 13, 14)
    # the roof over the channels and the right shaft: no surfacing past the left shaft
    g.fill(6, 36, 8, 9, "$")
    g.ground(37, 39, 2, "$")

    def chan(x0, x1, y0, c, flipped):
        rev = {"<": ">", ">": "<"}
        g.fill(x0, x1, y0, y0 + 1, rev[c] if flipped else c)

    a, b, c3 = flip
    chan(6, 19, 10, "<", c3 and False)   # A_L
    chan(6, 19, 13, "<", a)              # B_L (wheel 1)
    chan(6, 19, 16, "<", c3)             # C_L (wheel 3)
    chan(21, 34, 10, "<", c3)            # A_R (wheel 3)
    chan(21, 34, 13, "<", b)             # B_R (wheel 2)
    chan(21, 34, 16, "<", False)         # C_R
    g.fill(4, 5, 10, 17, "~")             # left shaft
    g.fill(20, 20, 13, 14, "~")           # the gap
    g.fill(35, 36, 10, 17, "~")           # right shaft
    # the entry ledge and the roof, with the wheels
    g.put(0, top - 1, "X")
    g.put(1, top - 1, "1")
    g.put(2, top - 1, "W")   # wheel 1: B_L, by the door
    g.put(3, top - 1, "@")
    g.put(26, 7, "V")        # wheel 2: B_R, out along the roof
    g.put(12, 7, "U")        # wheel 3: A_R + C_L
    g.put(16, 7, "2")
    # the way out is down: the outflow at the foot of the right shaft
    g.put(36, 17, "E")
    return g


def solve_sluice_house() -> list:
    """Every wheel setting that gets Patch from the entry to the exit ledge."""
    wins = []
    for flip in itertools.product((False, True), repeat=3):
        rows = ["".join(r) for r in sluice_house(flip).rows]
        best = climb_check.swim(rows, (4, 10))
        if (35, 17) in best or (36, 17) in best:
            wins.append(flip)
    return wins


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    sump_road().write(os.path.join(OUT, "3_1_the_sump_road.txt"),
        "3-1 The Sump Road (drawn by tools/levels/build_marsh.py; legend in\nscenes/levels/marsh/3_1_the_sump_road.tscn)")
    drowned_ledger().write(os.path.join(OUT, "3_2_the_drowned_ledger.txt"),
        "3-2 The Drowned Ledger (drawn by tools/levels/build_marsh.py; legend in\nscenes/levels/marsh/3_2_the_drowned_ledger.tscn)")
    sluice_house().write(os.path.join(OUT, "3_3_the_sluice_house.txt"),
        "3-3 The Sluice House (drawn by tools/levels/build_marsh.py; legend in\nscenes/levels/marsh/3_3_the_sluice_house.tscn)")
    wins = solve_sluice_house()
    print("sluice house solutions (wheel 1, 2, 3):", wins)
    if not wins or (False, False, False) in wins or any(not (w[0] and w[1]) for w in wins):
        print("FAIL: the sluice house must need wheels 1 and 2, and only them")
        sys.exit(1)


if __name__ == "__main__":
    main()
