"""Draws Region 4's text maps: the Spine Peaks, the cold top of the book (Phase 3:
4-1 to 4-5, Bindwell's workshop where he is fought, and the cold store, the sealed
back page behind 4-4).

Writes levels/peaks/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/peaks/*.tscn); the shared characters are:
  #  folded slate   $  granite   &  scree   =  black ice (Patch skates on it)
  -  one-way plank
  @  start   k  bookmark   s  Soggy   f  frost-rimed Soggy (only a crushing blow cracks it)
  n  Tack Knight   m  moth   o  scrap   1-9  story triggers   E  exit   X  way back
  R  arrival point   B  ability page   G H  frost gusts (blowing left / right)
  I  ice block (a Pop-Up Slam shatters it; covers this cell, the one right of it and
     the two above)   F  fold mark (a slam springs a 4-tile paper peak)
  N M  clockwork needles (their rail runs through this cell; N's runs 6 tiles each
     way, M's 4)   P T U W  Bindwell's pattern folds (4-3: a slam flips this fold and
     its neighbours)   D  sealed door (opens once Bindwell is beaten)
  Y  heart patch   L  the fire (4-5)

Patch's reach (climb_check): 2.5 rows up, 3 tiles across; with the Frog Fold (learned
at the end of 4-2) 4.5 rows up.

The pattern room's puzzle (4-3) is solved here: `solve_pattern_room` searches every
order of slams, with each raised peak a wall Patch has to get round, and fails the
build unless the exit can be reached and the shortest solution takes at least four
slams.

Run: python3 tools/levels/build_peaks.py
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from grid import Grid  # noqa: E402
import climb_check  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "peaks")


def rime_slopes() -> Grid:
    """4-1 The Rime Slopes: movement on unsafe ground. Black ice that won't let Patch
    stop, ledges of it with a frost gust blowing him back off them, Soggies rimed in
    frost that the shears skid off. Halfway he drops through the snow into a page
    frozen solid, where Gran's pop-up pattern teaches him the Pop-Up Slam, and slams
    his way out. Then a fold mark to climb, an ice wall in a tunnel, and a fight on
    the ice."""
    g = Grid(232, 30)
    F = 22
    g.ground(0, 231, F)
    # S1 the foot of the Peaks.
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(7, F - 1, "1")
    g.ground(18, 29, F - 2, "$")
    g.ground(24, 29, F - 4, "$")
    g.ground(30, 31, F - 2, "$")
    g.put(28, F - 5, "o")
    # S2 the first ice: a long flat run that ends at a crevasse.
    g.put(33, F - 1, "2")
    g.fill(34, 58, F, F, "=")
    g.clear(59, 61, F, F + 3)    # the crevasse: scree four rows down, steps out
    g.fill(59, 61, F + 4, 29, "&")
    g.ground(61, 61, F + 2, "&")
    # S3 ice ledges, and the frost gust that blows him back off them.
    g.put(63, F - 1, "3")
    g.fill(66, 72, F - 2, F - 1, "$")
    g.fill(66, 72, F - 2, F - 2, "=")
    g.fill(75, 81, F - 4, F - 1, "$")
    g.fill(75, 81, F - 4, F - 4, "=")
    g.fill(84, 92, F - 6, F - 1, "$")
    g.fill(84, 92, F - 6, F - 6, "=")
    g.put(83, F - 1, "G")
    g.put(88, F - 7, "o")
    # S4 down again, a bookmark, and the rimed Soggies.
    g.put(97, F - 1, "k")
    g.put(100, F - 1, "4")
    g.put(106, F - 1, "f")
    g.put(114, F - 1, "f")
    # S5 the frozen page: a crack in the snow drops him into a pocket of ice under a
    # cliff he can't climb. The pop-up pattern is in there, and ice blocks the way on.
    g.put(119, F - 1, "5")
    g.clear(124, 151, F, F + 4)
    g.fill(126, 151, F, F + 1, "$")         # the pocket's roof (and the snow on top)
    g.fill(141, 151, F - 9, F + 1, "$")     # the cliff over it, too tall to climb
    g.put(129, F + 4, "6")
    g.put(132, F + 4, "B")
    g.put(139, F + 4, "I")                  # the ice wall: cells 139-140, two rows
    g.clear(152, 156, F, F + 4)
    for i, x in enumerate(range(152, 157, 2)):   # steps up and out of the pocket
        g.ground(x, x + 1, F + 3 - 2 * i, "$")
    g.ground(157, 160, F, "#")
    # S6 a fold mark to climb, then a tunnel with ice in it.
    g.put(160, F - 1, "7")
    g.put(164, F - 1, "F")
    g.ground(166, 171, F - 4, "$")
    g.fill(172, 185, F - 9, F - 7, "$")      # the tunnel's roof
    g.ground(172, 185, F - 4, "#")
    g.put(177, F - 5, "I")                    # ice filling the tunnel (rows F-6..F-5)
    g.fill(177, 178, F - 9, F - 7, "$")
    g.ground(186, 189, F - 2, "$")
    # S7 the ice field: three rimed Soggies, the gust at their backs.
    g.put(190, F - 1, "8")
    g.fill(191, 219, F, F, "=")
    g.put(196, F - 1, "f")
    g.put(204, F - 1, "f")
    g.put(212, F - 1, "f")
    g.put(205, F - 2, "H")
    g.put(216, F - 1, "o")
    g.put(223, F - 1, "R")
    g.put(228, F - 1, "E")
    return g


def fold_works() -> Grid:
    """4-2 The Fold Works: Bindwell's machines, still sewing. Fold marks to slam and
    climb, clockwork needles running their rails overhead and stabbing whatever is
    under them; a fight; a stair of peaks raised one from the top of the last. At the
    top, Bindwell's frog pattern, and the Frog Fold to spring higher than a jump."""
    g = Grid(240, 34)
    F = 30
    g.ground(0, 239, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(7, F - 1, "1")
    # S1 a fold mark under a cliff (the 4-1 lesson again).
    g.put(16, F - 1, "F")
    g.ground(18, 27, F - 4, "$")
    g.ground(28, 67, F - 4, "#")
    # S2 the first needle, running over a flat floor: walk under it between stabs.
    g.put(30, F - 5, "2")
    g.put(46, F - 13, "N")
    g.put(46, F - 5, "o")
    # S3 a fold under a needle: slam, climb, before it comes round.
    g.put(60, F - 5, "3")
    g.put(66, F - 5, "F")
    g.ground(68, 79, F - 8, "$")
    g.put(66, F - 17, "M")
    # S4 down to a bookmark and a fight.
    g.ground(80, 99, F - 4, "#")
    g.put(84, F - 5, "k")
    g.put(90, F - 5, "4")
    g.put(102, F - 1, "n")
    g.put(110, F - 1, "f")
    g.put(116, F - 1, "s")
    # S5 the stair of peaks: each ledge is six rows over the one below; a peak raised
    # from the lower one (four) and a jump (two) gets him up. Needles over both.
    g.put(124, F - 1, "5")
    g.put(130, F - 1, "F")
    g.ground(132, 140, F - 6, "$")
    g.put(138, F - 7, "F")
    g.ground(140, 239, F - 12, "$")
    g.put(134, F - 17, "M")
    g.put(146, F - 21, "N")
    # S6 the top: Bindwell's frog pattern, then ledges only a frog can reach.
    g.put(150, F - 13, "6")
    g.put(160, F - 13, "B")
    g.put(166, F - 13, "7")
    g.ground(172, 239, F - 16, "$")
    g.ground(186, 239, F - 20, "$")
    g.put(180, F - 17, "o")
    g.put(196, F - 21, "m")
    g.put(210, F - 21, "8")
    g.put(232, F - 21, "R")
    g.put(236, F - 21, "E")
    return g


# The pattern room (4-3): four folds in a row, each raised to its own height (rows),
# and what a slam on each flips (itself and its neighbours). Two stand up already.
PATTERN = {"P": (10, 3), "T": (14, 6), "U": (18, 9), "W": (22, 12)}
CHAIN = {"P": "PT", "T": "PTU", "U": "TUW", "W": "UW"}
START_UP = "PW"
ROOM_F = 17


def pattern_room(up: str = START_UP, draw_peaks: bool = False) -> Grid:
    """4-3 Bindwell's Pattern Room: the folds stand in a row, short to tall, and the
    way out is a ledge only the tallest reaches. A slam beside a fold flips it and the
    folds either side; a peak standing is a wall on the floor. Raise all four, in an
    order that lets Patch get to each one, and climb them like stairs."""
    g = Grid(40, 20)
    F = ROOM_F
    g.ground(0, 39, F)
    g.ground(0, 0, 0)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(6, F - 1, "1")
    for c, (x, h) in PATTERN.items():
        if draw_peaks and c in up:
            g.fill(x, x + 1, F - h, F - 1, "%")   # (a peak is about two tiles wide)
        else:
            g.put(x, F - 1, c)
    g.ground(26, 39, F - 14, "$")
    g.put(30, F - 15, "2")
    g.put(33, F - 15, "o")
    g.put(35, F - 15, "R")
    g.put(37, F - 15, "E")
    return g


def _room_rows(up: str) -> list:
    return ["".join(r) for r in pattern_room(up, True).rows]


def solve_pattern_room() -> list:
    """Breadth-first over which folds stand. From each state Patch can slam a fold if
    he can get to the floor beside it (raised peaks are walls); the room is solved when
    he can reach the exit. Returns the shortest list of slams."""
    climb_check.UP = 4.5
    start = "".join(sorted(START_UP))
    seen = {start: []}
    q = collections.deque([start])
    while q:
        up = q.popleft()
        rows = _room_rows(up)
        if climb_check.climbable(rows)[0]:
            return seen[up]
        for c, (x, _h) in PATTERN.items():
            spots = [(x - 1, ROOM_F - 1), (x + 2, ROOM_F - 1)]
            if not any(climb_check.climbable(rows, goal=s)[0] for s in spots if rows[s[1]][s[0]] != "%"):
                continue
            nxt = "".join(sorted(set(up) ^ set(CHAIN[c])))
            if nxt not in seen:
                seen[nxt] = seen[up] + [c]
                q.append(nxt)
    return None


def stitched_ascent() -> Grid:
    """4-4 The Stitched Ascent: the last climb, up the stitched face of the spine to
    Bindwell's workshop. Frog steps; an ice shelf with the wind across it; a chimney
    of planks with a needle running over its top; the black ice at the top with rimed
    Soggies on it; a fold to raise under a cliff and a fight on the far side; a door
    sewn shut (the cold store, open once Bindwell is beaten); the workshop."""
    g = Grid(150, 56)
    F = 52
    g.ground(0, 149, F)
    # S1 the foot of the face: frog steps, four rows each.
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(7, F - 1, "1")
    g.put(11, F - 1, "s")
    g.ground(15, 19, F - 4, "$")
    g.ground(20, 25, F - 8, "$")
    g.put(22, F - 9, "o")
    # S2 an ice shelf, the gust blowing back down it.
    g.ground(26, 57, F - 8, "$")
    g.fill(28, 44, F - 8, F - 8, "=")
    g.put(27, F - 9, "2")
    g.put(38, F - 9, "G")
    # S3 the chimney: planks four rows apart, left and right, a moth in the shaft and
    # a needle running over the top. Walls either side of it.
    g.fill(40, 45, 10, F - 13, "$")
    g.ground(58, 149, 20, "$")
    g.put(48, F - 9, "3")
    for i, y in enumerate(range(F - 12, 23, -4)):
        x0 = 47 if i % 2 == 0 else 52
        g.plank(x0, x0 + 4, y)
    g.fill(53, 57, 20, 20, "$")
    g.put(51, 30, "m")
    g.put(50, F - 13, "o")
    g.put(55, 11, "M")
    # S4 the top: black ice and the rimed Soggies, a bookmark before them.
    g.put(60, 19, "k")
    g.put(63, 19, "4")
    g.fill(66, 82, 20, 20, "=")
    g.put(70, 19, "f")
    g.put(78, 19, "f")
    g.put(76, 18, "H")
    # S5 a needle over a flat, then a fold under a cliff.
    g.put(84, 19, "5")
    g.put(90, 11, "N")
    g.put(90, 19, "o")
    g.put(98, 19, "F")
    g.ground(100, 149, 14, "$")
    # S6 the fight on the cliff, and the door sewn shut.
    g.put(102, 13, "6")
    g.put(110, 13, "n")
    g.put(116, 13, "f")
    g.put(120, 13, "s")
    g.put(124, 13, "7")
    g.put(126, 13, "D")
    g.put(129, 13, "Q")
    # S7 the last step (a frog), the workshop door.
    g.ground(132, 149, 10, "$")
    g.put(135, 9, "8")
    g.put(140, 9, "R")
    g.put(146, 9, "E")
    return g


def workshop() -> Grid:
    """Bindwell's workshop, at the top of the spine: a bare plank floor for the duel."""
    g = Grid(30, 17)
    g.ground(0, 29, 14)
    g.put(1, 13, "X")
    g.put(3, 13, "@")
    return g


def cold_store() -> Grid:
    """The cold store, 4-4's sealed back page: Bindwell's store, where he kept the
    pages he cut out of the spine to make it lighter. A frog climb up shelves of them
    to a heart patch and the store's Scraps, with moths in the dark."""
    g = Grid(60, 22)
    F = 18
    g.ground(0, 59, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(7, F - 1, "1")
    g.ground(14, 19, F - 4, "$")
    g.plank(22, 27, F - 8)
    g.put(25, F - 11, "m")
    g.plank(30, 35, F - 12)
    g.put(36, F - 15, "m")
    g.ground(38, 59, F - 15, "$")
    g.put(40, F - 16, "2")
    g.put(48, F - 16, "Y")
    g.put(52, F - 16, "o")
    return g


def low_point() -> Grid:
    """4-5 The Low Point: over the top of the spine in a blizzard, with the wind
    against him, Soggies coming out of the snow, a needle still running; then a rock
    out of the wind, and a fire, and the thing he has to say. Then up to the top,
    where the Sogg is."""
    g = Grid(140, 26)
    F = 22
    g.ground(0, 139, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(7, F - 1, "1")
    g.put(14, F - 1, "G")
    g.fill(18, 34, F, F, "=")
    g.put(24, F - 1, "f")
    g.put(32, F - 1, "s")
    g.ground(38, 45, F - 4, "$")
    g.ground(46, 55, F - 8, "$")
    g.put(50, F - 9, "o")
    g.ground(56, 139, F - 4, "$")
    g.put(58, F - 5, "2")
    g.put(66, F - 13, "N")
    g.put(72, F - 5, "m")
    g.put(76, F - 5, "n")
    g.put(80, F - 5, "f")
    g.put(84, F - 5, "k")
    # A boulder to put their backs to, out of the wind, and the fire.
    g.ground(92, 93, F - 6, "$")
    g.put(97, F - 5, "3")
    g.put(100, F - 5, "L")
    g.put(110, F - 5, "4")
    g.put(126, F - 5, "R")
    g.put(134, F - 5, "E")
    return g


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    rime_slopes().write(os.path.join(OUT, "4_1_the_rime_slopes.txt"),
        "4-1 The Rime Slopes (drawn by tools/levels/build_peaks.py; legend in\nscenes/levels/peaks/4_1_the_rime_slopes.tscn)")
    fold_works().write(os.path.join(OUT, "4_2_the_fold_works.txt"),
        "4-2 The Fold Works (drawn by tools/levels/build_peaks.py; legend in\nscenes/levels/peaks/4_2_the_fold_works.tscn)\nabilities: frog (learned at the 'B' on the top ledge)")
    pattern_room().write(os.path.join(OUT, "4_3_the_pattern_room.txt"),
        "4-3 Bindwell's Pattern Room (drawn by tools/levels/build_peaks.py; legend in\nscenes/levels/peaks/4_3_the_pattern_room.tscn)\nabilities: frog")
    stitched_ascent().write(os.path.join(OUT, "4_4_the_stitched_ascent.txt"),
        "4-4 The Stitched Ascent (drawn by tools/levels/build_peaks.py; legend in\nscenes/levels/peaks/4_4_the_stitched_ascent.tscn)\nabilities: frog")
    workshop().write(os.path.join(OUT, "bindwell_workshop.txt"),
        "Bindwell's Workshop (drawn by tools/levels/build_peaks.py; legend in\nscenes/levels/peaks/bindwell_workshop.tscn)")
    cold_store().write(os.path.join(OUT, "cold_store.txt"),
        "The Cold Store, 4-4's sealed back page (drawn by tools/levels/build_peaks.py;\nlegend in scenes/levels/peaks/cold_store.tscn)\nabilities: frog")
    low_point().write(os.path.join(OUT, "4_5_the_low_point.txt"),
        "4-5 The Low Point (drawn by tools/levels/build_peaks.py; legend in\nscenes/levels/peaks/4_5_the_low_point.tscn)\nabilities: frog")
    ok = True
    # 4-1 has no frog; 4-2 must reach the frog pattern without it, and the exit with it.
    climb_check.UP = 2.5
    rows = ["".join(r) for r in rime_slopes().rows]
    # (the ice walls are open here: the slam that breaks them is learned in the pocket)
    print("4-1 climbable:", climb_check.climbable(rows)[0])
    ok &= climb_check.climbable(rows)[0]
    rows = ["".join(r) for r in fold_works().rows]
    b = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "B")
    print("4-2 frog pattern reachable without the frog:", climb_check.climbable(rows, goal=b)[0])
    ok &= climb_check.climbable(rows, goal=b)[0]
    climb_check.UP = 4.5
    print("4-2 climbable with the frog:", climb_check.climbable(rows)[0])
    ok &= climb_check.climbable(rows)[0]
    climb_check.UP = 2.5
    print("4-2 exit NOT reachable without the frog:", not climb_check.climbable(rows)[0])
    ok &= not climb_check.climbable(rows)[0]
    climb_check.UP = 4.5
    for name, grid in (("4-4", stitched_ascent()), ("cold store", cold_store()), ("4-5", low_point())):
        rows = ["".join(r) for r in grid.rows]
        if name == "cold store":
            y = next(y for y, r in enumerate(rows) if "Y" in r)
            reach = climb_check.climbable(rows, goal=(rows[y].index("Y"), y))[0]
        else:
            reach = climb_check.climbable(rows)[0]
        print(name, "climbable with the frog:", reach)
        ok &= reach
    climb_check.UP = 2.5
    rows = ["".join(r) for r in stitched_ascent().rows]
    print("4-4 NOT climbable without the frog:", not climb_check.climbable(rows)[0])
    ok &= not climb_check.climbable(rows)[0]
    plan = solve_pattern_room()
    print("pattern room shortest solution:", plan)
    if plan is None or len(plan) < 4:
        print("FAIL: the pattern room must be solvable, in no fewer than four slams")
        ok = False
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
