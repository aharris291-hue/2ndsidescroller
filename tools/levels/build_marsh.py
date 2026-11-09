"""Draws Region 3's text maps: Watermark Marsh, where the ink settled (Phase 3: 3-1 to
3-5, the Heronry where the Grey Heron is fought, and the Tally Room, 3-4's sealed back
page).

Writes levels/marsh/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/marsh/*.tscn); the shared characters are:
  #  peat   $  flagstone / stone   -  one-way plank (boardwalks, shelves)
  ~  settled ink   > < ^ v  ink running that way (a current)
  @  start   k  bookmark   s  Soggy   d  drips   i  ink spitter   m  moth   n  Tack Knight
  b  mimic book   o  scrap   1-9  story triggers   E  exit   X  way back
  N  Inked Tack Knight   O  tape ring   R Q  arrival points   W V U J  sluice wheels   D  sealed door   Y  heart patch (a back page's goal)
Ink burns a heart until Patch has the Blot Dive (3-1); with it he swims through ink on
one breath (26 tiles; a current carries him about twice as far, and can't be swum
against).

The wheel puzzles are checked here too: `solve_sluice_house` (3-3) and `solve_weir`
(3-4) try every setting of their wheels and fail the build unless exactly the intended
ones open the way through.

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


def reed_beds() -> Grid:
    """3-4 The Reed Beds: the outflow spits Patch into a marsh of paper reeds. Thickets
    too tall to climb stand in the ink and are dived under; a fight on the bank and a
    bookmark; the Weir (a wheel puzzle: the channel runs against him and the upwelling
    shaft to the high bank must run up); the counting stalls on the high bank, with the
    Tally Room's sealed door; and a long drain under two thickets to the far bank."""
    g = Grid(240, 30)
    F = 22
    g.ground(0, 239, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(6, F - 1, "1")
    g.put(12, F - 1, "s")
    # S2 the thickets: dive under, breathe in the gap, dive again.
    g.put(18, F - 1, "2")
    ink(g, 22, 80, F, 5)
    ink(g, 24, 79, F + 3, 2, ">")
    g.fill(28, 47, F - 8, F, "$")
    g.fill(53, 75, F - 8, F, "$")
    g.put(50, F - 5, "m")
    g.put(78, F - 5, "m")
    # S3 the bank: a fight and a bookmark.
    g.put(83, F - 1, "3")
    g.put(86, F - 1, "s")
    g.put(88, F - 1, "k")
    g.put(92, F - 1, "n")
    g.put(94, F - 1, "o")
    # S4 the Weir. The channel runs back at him; the shaft up to the high bank runs up.
    # Wheel 1 (on the bank) turns both the channel and the shaft; wheel 2 (on the reed
    # mat over the channel) turns only the shaft. Both, and the way is open.
    g.put(95, F - 1, "4")
    g.put(96, F - 1, "W")
    ink(g, 98, 131, F, 4, "<")
    g.fill(100, 121, F - 2, F - 1, "$")
    g.put(104, F - 3, "5")
    g.put(110, F - 3, "J")   # ('V' would read as a gear seat to climb_check)
    top = F - 8
    g.fill(122, 175, top, F - 1, "$")
    g.fill(130, 131, top, F - 1, "^")
    # S5 the counting stalls on the high bank, and the Tally Room's door.
    g.put(136, top - 1, "6")
    g.put(142, top - 1, "s")
    g.put(146, top - 6, "m")
    g.put(150, top - 1, "D")
    g.put(152, top - 1, "Q")
    g.put(158, top - 1, "n")
    g.put(166, top - 1, "s")
    g.put(170, top - 1, "o")
    g.ground(176, 178, F - 5, "$")
    g.ground(179, 181, F - 3, "$")
    # S6 the long drain, under two thickets with one breath of air between.
    g.put(182, F - 1, "7")
    ink(g, 184, 230, F, 4, ">")
    g.fill(188, 207, F - 8, F - 1, "$")
    g.fill(212, 228, F - 8, F - 1, "$")
    g.put(233, F - 1, "R")   # back from the Heron's Reach
    g.put(237, F - 1, "E")
    return g


def solve_weir() -> list:
    """Every wheel setting of the Weir that gets Patch from the bank to the high bank.
    Wheel 1 reverses the channel and the shaft, wheel 2 the shaft alone."""
    wins = []
    rev = {"<": ">", ">": "<", "^": "v", "v": "^"}
    for w1, w2 in itertools.product((False, True), repeat=2):
        rows = [list(r) for r in reed_beds().rows]
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                in_channel = 98 <= x <= 131 and 22 <= y <= 25
                in_shaft = 130 <= x <= 131 and 14 <= y <= 21
                if (in_channel and w1) or (in_shaft and (w1 != w2)):
                    row[x] = rev.get(c, c)
        rows = ["".join(r) for r in rows]
        if (130, 14) in climb_check.swim(rows, (98, 22)) or (131, 14) in climb_check.swim(rows, (98, 22)):
            wins.append((w1, w2))
    return wins


def herons_reach() -> Grid:
    """3-5 The Heron's Reach: the deepest of the marsh. Islands of peat in the ink, a
    wall to dive under, a bookmark, the heron's larder (a hard fight, with Inked), tape
    rings over the black lake, and the far bank where it stands waiting."""
    g = Grid(210, 26)
    F = 18
    g.ground(0, 209, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(6, F - 1, "1")
    # S2 the islands.
    g.put(10, F - 1, "2")
    ink(g, 12, 15, F, 4)
    ink(g, 22, 26, F, 4)
    g.put(24, F - 5, "m")
    g.put(29, F - 1, "s")
    ink(g, 32, 46, F, 5)
    g.fill(39, 40, F - 8, F + 2, "$")
    g.put(44, F - 6, "m")
    g.ground(47, 52, F - 2, "$")
    g.put(50, F - 3, "i")
    ink(g, 53, 58, F, 4)
    # S3 the bookmark.
    g.put(62, F - 1, "3")
    g.put(64, F - 1, "k")
    # S4 the heron's larder.
    g.put(68, F - 1, "4")
    g.put(74, F - 1, "s")
    g.put(80, F - 1, "N")   # Inked
    g.put(88, F - 1, "s")
    g.put(96, F - 1, "n")
    g.ground(100, 106, F - 2, "$")
    g.put(103, F - 3, "i")
    g.put(108, F - 1, "o")
    # S5 the black lake, and tape rings over it.
    g.put(113, F - 1, "5")
    ink(g, 116, 150, F, 5)
    for x, dy in ((121, 5), (128, 6), (135, 5), (142, 6), (148, 5)):
        g.put(x, F - dy, "O")
    # S6 the far bank.
    g.put(158, F - 1, "6")
    g.put(164, F - 6, "m")
    g.put(170, F - 1, "N")  # Inked
    g.put(178, F - 6, "m")
    g.put(196, F - 1, "7")
    g.put(199, F - 1, "R")  # back from the Heronry
    g.put(204, F - 1, "E")
    return g


def heronry() -> Grid:
    """The Heronry, the Grey Heron's arena: one screen of peat between two ink pools,
    deep enough to hide a blot from its wings."""
    g = Grid(30, 17)
    F = 14
    g.ground(0, 29, F)
    ink(g, 4, 8, F, 3)
    ink(g, 21, 25, F, 3)
    g.put(0, F - 1, "X")
    g.put(3, F - 1, "@")
    return g


def tally_room() -> Grid:
    """The Tally Room, 3-4's sealed back page (open once the heron is down): the clerks'
    flooded strongroom, one long dive under four walls with a breath between each, the
    currents mostly against him, and the clerks' last tally at the end: a heart patch
    and 60 Scraps. No bookmark."""
    g = Grid(120, 22)
    F = 14
    g.ground(0, 119, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(6, F - 1, "1")
    ink(g, 8, 110, F, 6)
    # A: two lanes under the wall, the top one against him.
    g.fill(12, 34, F - 8, F + 1, "$")
    g.fill(12, 34, F + 2, F + 3, "<")
    g.fill(12, 34, F + 4, F + 5, ">")
    # B: three rows, the lowest two with him.
    g.fill(38, 62, F - 8, F + 2, "$")
    g.fill(38, 62, F + 3, F + 3, "<")
    g.fill(38, 62, F + 4, F + 5, ">")
    # C: one lane, just wide enough, with him.
    g.fill(66, 90, F - 8, F + 3, "$")
    g.fill(66, 90, F + 4, F + 5, ">")
    # D: still ink, short.
    g.fill(94, 108, F - 8, F + 1, "$")
    g.put(36, F - 5, "m")
    g.put(64, F - 5, "m")
    g.put(114, F - 1, "Y")   # the heart patch: a back page's goal for climb_check
    g.put(117, F - 1, "o")
    return g


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    sump_road().write(os.path.join(OUT, "3_1_the_sump_road.txt"),
        "3-1 The Sump Road (drawn by tools/levels/build_marsh.py; legend in\nscenes/levels/marsh/3_1_the_sump_road.tscn)")
    drowned_ledger().write(os.path.join(OUT, "3_2_the_drowned_ledger.txt"),
        "3-2 The Drowned Ledger (drawn by tools/levels/build_marsh.py; legend in\nscenes/levels/marsh/3_2_the_drowned_ledger.tscn)")
    sluice_house().write(os.path.join(OUT, "3_3_the_sluice_house.txt"),
        "3-3 The Sluice House (drawn by tools/levels/build_marsh.py; legend in\nscenes/levels/marsh/3_3_the_sluice_house.tscn)")
    for build, name, title in ((reed_beds, "3_4_the_reed_beds", "3-4 The Reed Beds"),
                               (herons_reach, "3_5_the_herons_reach", "3-5 The Heron's Reach"),
                               (heronry, "heronry", "The Heronry"),
                               (tally_room, "tally_room", "The Tally Room")):
        build().write(os.path.join(OUT, name + ".txt"),
            "%s (drawn by tools/levels/build_marsh.py; legend in\nscenes/levels/marsh/%s.tscn)" % (title, name))
    import tempfile
    solved = [list(r) for r in reed_beds().rows]
    for y, row in enumerate(solved):
        for x, c in enumerate(row):
            if 98 <= x <= 131 and 22 <= y <= 25 and c == "<":
                row[x] = ">"
    with tempfile.NamedTemporaryFile("w", suffix="_3_4_weir_solved.txt", delete=False) as f:
        f.write("\n".join("".join(r) for r in solved))
    if not climb_check.main(f.name):
        sys.exit(1)
    weir = solve_weir()
    print("weir solutions (wheel 1, wheel 2):", weir)
    if weir != [(True, True)]:
        print("FAIL: the Weir must need both wheels")
        sys.exit(1)
    wins = solve_sluice_house()
    print("sluice house solutions (wheel 1, 2, 3):", wins)
    if not wins or (False, False, False) in wins or any(not (w[0] and w[1]) for w in wins):
        print("FAIL: the sluice house must need wheels 1 and 2, and only them")
        sys.exit(1)


if __name__ == "__main__":
    main()
