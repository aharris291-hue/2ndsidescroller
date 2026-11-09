"""Draws Region 2's text maps: Lanternfold, the harbour that went dark (Phase 3, Level
Design Bible, "Lanternfold at full size", part 1: 2-1 to 2-3).

Writes levels/lanternfold/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/lanternfold/*.tscn); the shared characters are:
  #  ground   $  stone   -  one-way plank (jetties, the lighthouse stair)
  @  start   k  bookmark   s  Soggy   d  drips   n  Tack Knight   o  scrap   t  tape
  P  lantern post, burning   p  cold lantern post (Patch lights it for good)
  u  short-trimmed lantern: cold, and gutters out a few seconds after Patch leaves it
  O  brass grapple ring (Tape Tail)   1-9  story triggers   E  exit
Lantern light reaches 4.5 tiles either side of its post; Soggies won't come into it.

The Lamp Room's mirror puzzle is checked here too: `solve_lamp_room` tries every
setting of every room's mirrors and fails the build if a room can't be solved, or is
solved before Patch touches a mirror.

Run: python3 tools/levels/build_lanternfold.py
"""
import itertools
import os
import sys

from grid import Grid

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "lanternfold")


def drowned_quay() -> Grid:
    """2-1 The Drowned Quay: lantern posts are the only safe ground; the hand lantern from
    a drowned lamplighter's cart; jetties over black water; a street of short-trimmed
    lamps that go dark behind Patch; rooftops to Letter L; Corrugate's empty boat
    (Letter E); Tack Knights, who don't care about light; the Margin's folded corner;
    the mole out to the lighthouse."""
    g = Grid(332, 28)
    F = 20
    g.ground(0, 331, F)
    # S1 the quay's end: one lamp still burning, and the opening line.
    g.put(3, F - 1, "@")
    g.put(6, F - 1, "P")
    g.put(9, F - 1, "1")
    # S2 the lamp-to-lamp walk: two Soggies in the dark stretch between burning lamps.
    g.put(14, F - 1, "2")
    g.put(24, F - 1, "s")
    g.put(30, F - 1, "s")
    g.put(38, F - 1, "P")
    g.put(12, 4, "d")
    # S3 the lamplighter's cart: the hand lantern, then the first cold post to light.
    g.clear(43, 45)
    g.put(48, F - 1, "3")
    g.put(51, F - 1, "H")
    g.put(56, F - 1, "s")
    g.put(60, F - 1, "p")
    g.put(63, F - 1, "k")
    # S4 the jetties: planks over the black water, a cold post halfway, a Soggy on each.
    g.clear(66, 99)
    g.plank(66, 73, F)
    g.put(70, F - 1, "s")
    g.plank(77, 86, F)
    g.put(81, F - 1, "p")
    g.put(85, F - 1, "o")
    g.plank(90, 99, F)
    g.put(95, F - 1, "s")
    g.plank(94, 97, F - 2)
    g.put(95, F - 3, "o")
    # S5 Corrugate's boat, tied up and empty: its deck is a plank two up, Letter E aboard.
    g.put(103, F - 1, "4")
    g.put(108, F - 1, "b")
    g.plank(105, 111, F - 2)
    g.plank(107, 109, F - 4)
    g.put(108, F - 5, "L")
    # S6 the street of short-trimmed lamps: light each one, and it gutters out behind you.
    g.put(116, F - 1, "5")
    for x in (120, 132, 144, 156, 168):
        g.put(x, F - 1 - (2 if 140 <= x <= 160 else 0), "u")
    for x in (126, 138, 150, 162):
        g.put(x, F - 1 - (2 if 140 <= x <= 160 else 0), "s")
    g.ground(140, 160, F - 2)
    g.put(150, 3, "d")
    # S7 a burning lamp and a Bookmark; then the first Tack Knight, who walks into light.
    g.put(176, F - 1, "k")
    g.put(178, F - 1, "P")
    g.put(181, F - 1, "6")
    g.put(190, F - 1, "n")
    g.put(197, F - 1, "s")
    g.put(199, F - 1, "t")
    # S8 the rooftops: steps of two up the fronts of drowned houses; Letter L on a
    # chimney plank above the last roof; a Soggy on the middle roof.
    g.ground(205, 210, F - 2, "$")
    g.ground(213, 218, F - 4, "$")
    g.ground(221, 227, F - 6, "$")
    g.put(216, F - 5, "s")
    g.plank(229, 231, F - 8)
    g.put(230, F - 9, "l")
    g.ground(228, 228, F - 6, "$")
    g.put(224, F - 7, "o")
    # S9 the harbour mouth: two cold posts and a Tack Knight with two Soggies.
    g.put(240, F - 1, "7")
    g.put(246, F - 1, "p")
    g.put(254, F - 1, "s")
    g.put(262, F - 1, "n")
    g.put(268, F - 1, "s")
    g.put(274, F - 1, "p")
    g.put(258, F - 1, "o")
    # S10 the Margin's folded corner.
    g.put(284, F - 1, "M")
    g.put(286, F - 1, "G")
    g.put(282, F - 1, "8")
    # S11 the mole out to the lighthouse: rocks over the water, the last cold post.
    g.clear(292, 293)
    g.ground(295, 298, F - 2, "$")
    g.clear(299, 301)
    g.ground(302, 331, F, "$")
    g.put(305, F - 1, "p")
    g.put(312, F - 1, "9")
    g.put(326, F - 1, "R")
    g.put(328, F - 1, "E")
    return g


STAIR_ROWS = 70


def lamplighters_climb() -> Grid:
    """2-2 The Lamplighter's Climb (vertical): the spiral stair inside the drowned
    lighthouse. Landings with cold posts to light and a fight each; halfway up, the
    lamplighter's things and the Tape Tail; above that the stair is broken and the way up
    is by brass rings. Letter R on a ledge off a ring. At the top, the Lamp Room door.

    Every stair step is 2 tiles up with a 2-tile gap, like the Mill Stair; the ring
    pitches leave a plank within reach of each ring."""
    H = STAIR_ROWS
    g = Grid(36, H)
    for x in (0, 1, 34, 35):
        g.fill(x, x, 0, H - 1, "$")
    g.fill(0, 35, 0, 1, "$")
    g.ground(0, 35, H - 2)
    A, B, C, D = 3, 11, 19, 27

    def floor(row: int) -> None:
        g.plank(2, 33, row)

    def zigzag(rows, xs) -> None:
        for row, x0 in zip(rows, xs):
            g.plank(x0, x0 + 5, row)

    base = H - 2
    # the foot of the tower: Start, the way back out to the quay, a burning post
    g.put(3, base - 1, "@")
    g.put(2, base - 1, "X")
    g.put(7, base - 1, "1")
    g.put(10, base - 1, "P")
    g.put(24, base - 1, "s")
    zigzag(range(base - 2, base - 15, -2), [D, C, B, A, B, C, D])
    for x in (9, 25):
        g.put(x, base - 26, "d")
    # landing 1: two cold posts and three Soggies between them
    f1 = base - 16
    floor(f1)
    g.put(5, f1 - 1, "2")
    g.put(8, f1 - 1, "p")
    g.put(14, f1 - 1, "s")
    g.put(18, f1 - 1, "s")
    g.put(22, f1 - 1, "s")
    g.put(28, f1 - 1, "p")
    g.put(31, f1 - 1, "o")
    zigzag(range(f1 - 2, f1 - 13, -2), [D, C, B, A, B, C])
    # landing 2: the lamplighter's things and the Tape Tail; a Bookmark; a Tack Knight
    f2 = f1 - 14
    floor(f2)
    g.put(4, f2 - 1, "k")
    g.put(7, f2 - 1, "P")
    g.put(16, f2 - 1, "n")
    g.put(26, f2 - 1, "3")
    g.put(30, f2 - 1, "T")
    # above landing 2 the stair is gone: rings up the hollow middle of the tower
    g.put(22, f2 - 6, "O")
    g.plank(24, 29, f2 - 5)
    g.put(19, f2 - 11, "O")
    g.plank(12, 17, f2 - 10)
    # Letter R: a ring off to the side, over a ledge in a window
    g.put(7, f2 - 15, "O")
    g.plank(2, 5, f2 - 14)
    g.put(3, f2 - 15, "r")
    zigzag([f2 - 12, f2 - 14], [C, D])
    # landing 3: moths in the dark over a cold post, an Inked Soggy
    f3 = f2 - 16
    floor(f3)
    g.put(6, f3 - 1, "4")
    g.put(10, f3 - 1, "p")
    g.put(20, f3 - 1, "e")
    for x in (14, 24):
        g.put(x, f3 - 5, "m")
    g.put(30, f3 - 1, "t")
    # one more ring pitch, then the last of the stair
    g.put(26, f3 - 7, "O")
    g.plank(28, 33, f3 - 6)
    zigzag(range(f3 - 8, f3 - 17, -2), [D, C, B, A, B])
    # the top: the sisters' lights far below, a Bookmark, the Lamp Room door
    top = f3 - 18
    floor(top)
    g.put(8, top - 1, "5")
    g.put(14, top - 1, "k")
    g.put(18, top - 1, "P")
    g.put(28, top - 1, "6")
    g.put(30, top - 1, "G")
    g.put(32, top - 1, "E")
    assert top >= 4, top
    return g


# The Lamp Room: three rooms of 20 columns; walls at each room's edges, grilles 'D' in
# the doorways at row 7. Lenses 'B' (in the wall, with their beam direction in the
# scene's legend: 'B' down), mirrors 'm' (start '/') and 'n' (start '\'), wicks 'w'.

ROOMS = [
    # (room, lens, mirrors {(x, y): start}, wicks, pillars)
    (0, (5, 0), {(5, 10): "/"}, [(14, 10)], [(10, 3), (10, 4), (14, 4)]),
    (1, (3, 0), {(3, 4): "/", (10, 4): "/", (10, 11): "/", (16, 11): "\\", (16, 2): "/", (3, 11): "\\"},
     [(7, 4), (16, 7)], [(7, 8), (13, 8)]),
    (2, (10, 0), {(10, 5): "\\", (3, 5): "\\", (3, 12): "/", (16, 12): "\\", (16, 5): "/", (10, 9): "/", (6, 9): "\\"},
     [(3, 9), (10, 12), (16, 8)], [(7, 2), (13, 2), (6, 13)]),
]


def lamp_room() -> Grid:
    """2-3 The Lamp Room, top-down: three rooms round the great lamp. In each, swivel
    mirrors carry the lamp's beam from a lens in the wall through every cold wick."""
    g = Grid(60, 15)
    g.fill(0, 59, 0, 0, "$")
    g.fill(0, 59, 14, 14, "$")
    for x in (0, 19, 20, 39, 40, 59):
        g.fill(x, x, 0, 14, "$")
    for x in (19, 20, 39, 40):
        g.put(x, 6, ".")
        g.put(x, 7, ".")
    g.put(0, 6, ".")
    g.put(0, 7, "X")
    g.put(2, 7, "@")
    g.put(19, 7, "D")
    g.put(39, 7, "D")
    g.put(59, 6, ".")
    g.put(58, 7, "D")
    g.put(59, 7, "E")
    for room, lens, mirrors, wicks, pillars in ROOMS:
        ox = room * 20
        g.put(ox + lens[0], lens[1], "B")
        for (x, y), start in mirrors.items():
            g.put(ox + x, y, "m" if start == "/" else "n")
        for x, y in wicks:
            g.put(ox + x, y, "w")
        for x, y in pillars:
            g.put(ox + x, y, "$")
    g.put(4, 7, "1")
    g.put(23, 7, "2")
    g.put(43, 7, "3")
    g.put(37, 1, "o")
    g.put(57, 13, "o")
    return g


def trace(g: Grid, lens, settings, gates):
    """The cells the beam lights, following LampRoom.trace in the game."""
    x, y = lens
    dx, dy = 0, 1
    lit = set()
    seen = set()
    for _ in range(600):
        nx, ny = x + dx, y + dy
        c = g.get(nx, ny)
        if c == "$" or c == "B" or (nx, ny) in gates or not (0 <= nx < g.w and 0 <= ny < g.h):
            break
        x, y = nx, ny
        if (x, y, dx, dy) in seen:
            break
        seen.add((x, y, dx, dy))
        lit.add((x, y))
        if (x, y) in settings:
            if settings[(x, y)] == "/":
                dx, dy = -dy, -dx
            else:
                dx, dy = dy, dx
    return lit


def solve_lamp_room(g: Grid) -> bool:
    gates = set()
    for y in range(g.h):
        for x in range(g.w):
            if g.get(x, y) == "D":
                gates.add((x, y))
                gates.add((x, y - 1))
    ok = True
    for room, lens, mirrors, wicks, _ in ROOMS:
        ox = room * 20
        cells = [(ox + x, y) for x, y in mirrors]
        targets = {(ox + x, y) for x, y in wicks}
        start = {(ox + x, y): s for (x, y), s in mirrors.items()}
        solutions = []
        for combo in itertools.product("/\\", repeat=len(cells)):
            settings = dict(zip(cells, combo))
            if targets <= trace(g, (ox + lens[0], lens[1]), settings, gates):
                flips = sum(1 for c in cells if settings[c] != start[c])
                solutions.append(flips)
        solved_at_start = targets <= trace(g, (ox + lens[0], lens[1]), start, gates)
        print("Lamp Room %d: %d of %d mirror settings light every wick; fewest turns %s%s" % (
            room + 1, len(solutions), 2 ** len(cells), min(solutions) if solutions else "-",
            " (SOLVED AT START)" if solved_at_start else ""))
        ok = ok and bool(solutions) and not solved_at_start
    return ok


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    drowned_quay().write(os.path.join(OUT, "2_1_the_drowned_quay.txt"),
        "2-1 The Drowned Quay (drawn by tools/levels/build_lanternfold.py; legend in\nscenes/levels/lanternfold/2_1_the_drowned_quay.tscn)")
    lamplighters_climb().write(os.path.join(OUT, "2_2_the_lamplighters_climb.txt"),
        "2-2 The Lamplighter's Climb, vertical (drawn by tools/levels/build_lanternfold.py;\nlegend in scenes/levels/lanternfold/2_2_the_lamplighters_climb.tscn)")
    room = lamp_room()
    room.write(os.path.join(OUT, "2_3_the_lamp_room.txt"),
        "2-3 The Lamp Room, top-down (drawn by tools/levels/build_lanternfold.py; legend\nin scenes/levels/lanternfold/2_3_the_lamp_room.tscn)")
    print("wrote Lanternfold maps")
    if not solve_lamp_room(room):
        sys.exit("a Lamp Room can't be solved, or starts solved")


if __name__ == "__main__":
    main()
