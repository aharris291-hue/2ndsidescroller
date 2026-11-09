"""Draws Region 5's text maps: Gatefold Fair, the fair that never closed (Phase 3,
part 1: 5-1 to 5-3).

Writes levels/fair/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/fair/*.tscn); the shared characters are:
  #  fair boards   %  stall and tent fronts   $  iron and brick   -  one-way plank
  |  updraft (a column of them is one Updraft: a paper plane rides it up)
  @  start   k  bookmark   s  Soggy   c  carousel horse   m  moth   o  scrap
  1-9  story triggers   E  exit   X  way back   R  arrival point   B  ability page
  Z  the Big Wheel (stands on this cell; see climb_check)
  T U J  pull tabs (5-3: each flips the vent flaps named in its scene's legend)
  A B C  vents under gatefold flaps (5-3: an Updraft each, its height in the legend)

Patch's reach (climb_check): the Frog Fold (4.5 rows up), and from the 'B' in 5-1 the
Paper Plane Glide: gliding, he covers 3 tiles across for each row he drops.

The Gatefold (5-3) is solved here: three vents in the floor and ledges, each under a
gatefold flap, and three pull tabs that flip them (two, two and one). `solve_gatefold` searches
every order of pulls, from wherever Patch can stand, and fails the build unless the
top can be reached and the shortest solution takes at least four pulls.

Run: python3 tools/levels/build_fair.py
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from grid import Grid  # noqa: E402
import climb_check  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "fair")


def draft(g: Grid, x: int, top: int, bottom: int) -> None:
    g.fill(x, x, top, bottom, "|")


def midway() -> Grid:
    """5-1 The Midway: the drowned fair's main street. Soggy fairgoers, the first
    carousel horse, the ticket booth with Gran's paper plane pattern pinned in it; the
    first glide over a hole in the boards; a vent up to the stall roofs, and a long glide
    off them over the dark; a bursting vent over a wall, and the way to the Big Wheel."""
    g = Grid(222, 26)
    F = 22
    g.ground(0, 120, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(7, F - 1, "1")
    g.put(18, F - 1, "s")
    g.put(26, F - 1, "s")
    # S2 the first carousel horse, loose on the boards.
    g.put(34, F - 1, "2")
    g.ground(40, 44, F - 2, "%")
    g.put(52, F - 1, "c")
    g.put(42, F - 3, "o")
    # S3 the ticket booth, raised, and the paper plane.
    g.put(60, F - 1, "3")
    g.ground(62, 75, F - 3, "%")
    g.put(70, F - 4, "B")
    # S4 the first glide: the boards are gone for seventeen tiles.
    g.clear(76, 92, F, 25)
    g.put(84, F - 6, "o")
    g.put(95, F - 1, "4")
    g.put(97, F - 1, "k")
    # S5 a vent up to the stall roofs: a walkway of roofs, a horse and the moths on it.
    draft(g, 101, F - 13, F - 1)
    g.fill(104, 140, F - 11, F - 11, "%")
    g.put(106, F - 12, "5")
    g.put(118, F - 12, "c")
    g.put(126, F - 14, "m")
    g.put(134, F - 14, "m")
    g.put(112, F - 1, "s")
    # S6 off the end of the roofs, over the dark, down to the far side.
    g.clear(121, 150, F, 25)
    g.put(138, F - 12, "6")
    g.ground(151, 165, F - 6, "#")
    # S7 a wall, and a vent that breathes in bursts beside it.
    g.ground(166, 171, F - 17, "$")
    draft(g, 162, F - 19, F - 7)
    g.put(156, F - 7, "7")
    g.ground(172, 221, F - 6, "#")
    g.put(178, F - 7, "s")
    g.put(186, F - 7, "c")
    g.put(194, F - 7, "s")
    g.put(200, F - 7, "8")
    g.put(206, F - 7, "o")
    g.put(212, F - 7, "R")
    g.put(218, F - 7, "E")
    return g


def big_wheel() -> Grid:
    """5-2 The Big Wheel: the ferris wheel still turning over a hole in the fair. Ride
    a gondola up past the moths, and glide off the top to the helter-skelter; from its
    top, down over the dark to the far side. A vent there lifts to a ledge of Scraps."""
    g = Grid(82, 34)
    F = 30
    g.ground(0, 39, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(8, F - 1, "1")
    g.put(14, F - 1, "s")
    g.put(30, F - 1, "Z")
    g.put(22, F - 10, "m")
    g.put(38, F - 14, "m")
    g.put(30, F - 18, "2")
    # The helter-skelter's top, too far to reach from anywhere but the top of the wheel.
    g.ground(44, 60, F - 14, "%")
    g.put(48, F - 15, "3")
    g.put(56, F - 15, "o")
    # Its slide goes down into the dark; the far side.
    g.ground(67, 81, F)
    g.put(70, F - 1, "4")
    g.put(74, F - 1, "c")
    draft(g, 63, F - 18, F - 1)
    g.ground(62, 66, F + 1)
    g.fill(76, 81, F - 17, F - 17, "%")
    g.put(78, F - 18, "o")
    g.put(72, F - 1, "R")
    g.put(80, F - 1, "E")
    return g


# The Gatefold (5-3): vents, as (column, top row, bottom row), each under a flap, and
# the pull tabs: where each stands and which flaps it flips. B and C start open (C
# over the high ledge, B over the middle one, both out of reach from the floor).
VENTS = {"A": (9, 12, 21), "B": (16, 7, 13), "C": (27, 2, 8)}
TABS = {"1": (4, 21), "2": (13, 13), "3": (24, 8)}
CHAIN = {"1": "AB", "2": "BC", "3": "A"}
START_OPEN = "BC"
## The tabs' characters on the drawn map.
TAB_CHARS = {"1": "T", "2": "U", "3": "J"}


def gatefold(open_: str = START_OPEN, draw: bool = True) -> Grid:
    """5-3 The Gatefold: a funhouse made of one huge fold-out page. Three vents with
    hinged flaps over them; three pull tabs that flip them. The way out is the
    top of the page, only a paper plane on the last vent reaches it."""
    g = Grid(40, 25)
    F = 22
    g.ground(0, 39, F)
    g.put(1, F - 1, "X")
    g.put(3, F - 1, "@")
    g.put(6, F - 1, "1")
    g.fill(12, 18, 14, 14, "%")   # the middle ledge (M)
    g.fill(22, 28, 9, 9, "%")     # the high ledge (H), five rows over it
    g.fill(31, 39, 4, 4, "%")     # the top of the page (T), five rows over that
    for c, (x, y) in TABS.items():
        g.put(x, y, TAB_CHARS[c] if draw else c)
    for v, (x, top, bottom) in VENTS.items():
        if draw:
            g.put(x, bottom, v)   # the scene's legend makes each vent and its flap
        elif v in open_:
            draft(g, x, top, bottom)
    g.put(33, 3, "2")
    g.put(36, 3, "o")
    g.put(38, 3, "E")
    return g


def _rows(grid: Grid) -> list:
    return ["".join(r) for r in grid.rows]


def solve_gatefold() -> list:
    """Breadth-first over (which flaps are open, which tab Patch stands at). From a
    state he can walk, drop or ride to any tab the open vents let him reach and pull
    it; solved when he can reach the exit from where he stands."""
    climb_check.UP, climb_check.GLIDE = 4.5, True
    start = ("".join(sorted(START_OPEN)), "@")
    seen = {start: []}
    q = collections.deque([start])
    while q:
        open_, at = q.popleft()
        rows = _rows(gatefold(open_, draw=False))
        here = None if at == "@" else (TABS[at][0], TABS[at][1])
        if climb_check.climbable(rows, start=here)[0]:
            return seen[(open_, at)]
        for t, spot in TABS.items():
            if not climb_check.climbable(rows, start=here, goal=spot)[0]:
                continue
            nxt = ("".join(sorted(set(open_) ^ set(CHAIN[t]))), t)
            if nxt not in seen:
                seen[nxt] = seen[(open_, at)] + [t]
                q.append(nxt)
    return None


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    midway().write(os.path.join(OUT, "5_1_the_midway.txt"),
        "5-1 The Midway (drawn by tools/levels/build_fair.py; legend in\nscenes/levels/fair/5_1_the_midway.tscn)\nabilities: frog glide (the glide is learned at the 'B')")
    big_wheel().write(os.path.join(OUT, "5_2_the_big_wheel.txt"),
        "5-2 The Big Wheel (drawn by tools/levels/build_fair.py; legend in\nscenes/levels/fair/5_2_the_big_wheel.tscn)\nabilities: frog glide")
    gatefold().write(os.path.join(OUT, "5_3_the_gatefold.txt"),
        "5-3 The Gatefold (drawn by tools/levels/build_fair.py; legend in\nscenes/levels/fair/5_3_the_gatefold.tscn); A B C are the vents (B and C start open)")
    ok = True
    climb_check.UP = 4.5
    for name, grid in (("5-1", midway()), ("5-2", big_wheel())):
        rows = _rows(grid)
        climb_check.GLIDE = False
        if name == "5-1":
            b = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "B")
            reach_b = climb_check.climbable(rows, goal=b)[0]
            print("5-1 paper plane reachable without the glide:", reach_b)
            ok &= reach_b
        without = climb_check.climbable(rows)[0]
        print(name, "exit NOT reachable without the glide:", not without)
        ok &= not without
        climb_check.GLIDE = True
        with_ = climb_check.climbable(rows)[0]
        print(name, "climbable with the glide:", with_)
        ok &= with_
    plan = solve_gatefold()
    print("gatefold shortest solution:", plan)
    if plan is None or len(plan) < 4:
        print("FAIL: the Gatefold must be solvable, in no fewer than four pulls")
        ok = False
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
