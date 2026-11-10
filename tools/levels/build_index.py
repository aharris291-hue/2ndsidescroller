"""Draws Region 6's text maps: the Index, the archive at the back of the book where
everything in it is filed (Phase 3, part 1: 6-1 to 6-3).

Writes levels/index/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/index/*.tscn); the shared characters are:
  #  archive floor, shelving and cabinets (the drawer tiles)   $  iron   -  one-way plank
  @  start   k  bookmark   s  Soggy   i  silverfish   m  moth   M  mimic book   o  scrap
  1-9  story triggers   E  exit   X  way back   R  arrival point   B  ability page
  r q  card catalogue drawers (IndexDrawer): 'r' slides out of the wall to its left
       (rightwards), 'q' out of the wall to its right ('d' is TextLevel's ink drip); the cell is the first cell of air in front of
       the cabinet, and out, the drawer's top is that row's top
  P Q A B C  roll shutters (Shutter) standing on this cell's floor, as tall as the
       legend says; the cells above them in the map are drawn as air
  T U W  pull tabs (each flips the shutters named in its scene's legend)

Patch's reach (climb_check): the Frog Fold (4.5 rows up) and the Paper Plane Glide,
and from the 'B' in 6-1 the Bookmark Warp (Gran's ribbon: lay it, go, and come back to
it in an instant). climb_check can't time things, so it treats drawers as out and
shutters as open; what the warp is for is timing: a shutter on a spring ('P' and 'Q')
drops shut again sooner than Patch can run back to it from its tab.

The Reading Room (6-3) is solved here: four rooms in a row under the gallery floor,
the shutters between them, and three tabs that each flip two (or one). Gran's ribbon
goes through a shut shutter. `solve_reading_room` searches every order of pulls, lays
and warps, and fails the build unless it can be solved, can't be without the warp,
and the shortest way takes two warps and four pulls.

Run: python3 tools/levels/build_index.py
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from grid import Grid  # noqa: E402
import climb_check  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "index")


def shutter(g: Grid, x: int, floor: int, rows: int, c: str) -> None:
    """A shutter `rows` tall standing on row `floor`, with solid shelving above it
    up to the top of the map, so nothing goes over it."""
    g.fill(x, x, 0, floor - rows - 1, "#")
    g.fill(x, x, floor - rows, floor - 1, ".")
    g.put(x, floor - 1, c)


def back_pages() -> Grid:
    """6-1 The Back Pages: the way into the Index. Down a long aisle of the archive
    with silverfish in the floor and a mimic on the shelves; Gran's reading desk, where
    her ribbon bookmark is still in the book she never finished; a shaft with scraps at
    the bottom (lay the ribbon, drop, come back); the first spring shutter, its tab up a
    tall stack of shelves; a bookmark; a fight in the stacks; and a second shutter
    with a silverfish waiting by it, which will eat the ribbon if it gets the chance."""
    g = Grid(192, 32)
    F = 20
    g.ground(0, 191, F)
    g.put(1, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(7, F - 1, "1")
    # S2 the first silverfish, and the aisle's mimic.
    g.put(14, F - 1, "2")
    g.put(20, F - 1, "i")
    g.put(28, F - 1, "s")
    g.put(33, F - 1, "i")
    g.put(30, F - 5, "m")
    g.put(40, F - 1, "M")
    # S3 Gran's reading desk, raised, and her ribbon in the open book.
    g.ground(46, 52, F - 2, "#")
    g.put(47, F - 3, "3")
    g.put(50, F - 3, "B")
    # S4 the scrap shaft: twelve rows down, with a slow way back up (shelf planks).
    g.clear(57, 61, F, 30)
    g.fill(56, 56, F, 30, "#")
    g.fill(62, 62, F, 30, "#")
    g.fill(56, 62, 31, 31, "#")
    g.put(55, F - 1, "4")
    for x in (58, 59, 60):
        g.put(x, 30, "o")
    g.plank(57, 58, 27)
    g.plank(60, 61, 23)
    # S5 the first spring shutter 'P': a cabinet over a passage, the tab up a stack.
    g.ground(64, 66, F - 4, "#")
    g.ground(67, 69, F - 8, "#")
    g.ground(64, 65, F - 12, "#")
    g.put(64, F - 13, "T")
    g.put(72, F - 1, "5")
    g.fill(76, 104, 0, F - 7, "#")
    shutter(g, 78, F, 6, "P")
    g.put(84, F - 1, "o")
    # S6 the stacks: a bookmark, then silverfish and moths among the shelves.
    g.put(108, F - 1, "k")
    g.put(110, F - 1, "6")
    g.ground(116, 120, F - 3, "#")
    g.put(118, F - 4, "m")
    g.put(124, F - 1, "i")
    g.put(130, F - 1, "s")
    g.put(134, F - 1, "M")
    g.ground(138, 142, F - 3, "#")
    g.put(140, F - 4, "o")
    g.put(146, F - 1, "i")
    # S7 the second shutter 'Q', its tab up a taller stack, a silverfish by the door.
    g.ground(150, 152, F - 4, "#")
    g.ground(153, 155, F - 8, "#")
    g.ground(150, 151, F - 12, "#")
    g.ground(153, 154, F - 15, "#")
    g.put(153, F - 16, "U")
    g.put(158, F - 1, "7")
    g.put(161, F - 1, "i")
    g.fill(164, 182, 0, F - 7, "#")
    shutter(g, 166, F, 6, "Q")
    g.put(186, F - 1, "8")
    g.put(188, F - 1, "R")
    g.put(190, F - 1, "E")
    return g


def card_catalogue() -> Grid:
    """6-2 The Card Catalogue: up the inside of the great catalogue. A low aisle and a
    fight at the foot; then the canyon between two cabinets, climbed on drawers that
    slide out of the walls and back in on their own clock, in a cascade up the walls
    (a bookmark in a notch half way); on top, a spring shutter over the way on, and
    its tab at the bottom of a drawer shaft, a slow climb back up."""
    g = Grid(36, 50)
    F = 46
    g.ground(0, 35, F)
    g.fill(0, 2, 0, F - 1, "#")
    # Under the shaft and the canyon's left wall: solid down to the low aisle.
    g.fill(3, 12, 22, F - 5, "#")
    # The canyon's walls (left 8-12, right 22-26) and the cabinets right of it.
    g.fill(8, 12, 9, F - 5, "#")
    g.fill(22, 35, 9, F - 1, "#")
    # The top floor, with holes over the shaft (3-7) and the canyon (13-21).
    g.fill(8, 12, 8, 8, "#")
    g.fill(22, 35, 8, 8, "#")
    g.put(3, F - 1, "X")
    g.put(5, F - 1, "@")
    g.put(7, F - 1, "1")
    g.put(10, F - 1, "i")
    g.put(15, F - 1, "s")
    g.put(20, F - 1, "i")
    g.put(14, F - 1, "2")
    # The canyon: drawers every two rows, left and right by turns.
    for row in range(F - 6, 9, -4):
        g.put(13, row, "r")
    for row in range(F - 4, 9, -4):
        g.put(21, row, "q")
    # A filing crate at the foot, up to the first drawer.
    g.fill(17, 18, F - 2, F - 1, "#")
    g.put(17, F - 14, "m")
    g.put(17, F - 30, "m")
    # A notch in the left wall half way up, with a bookmark: its floor is a drawer row.
    g.clear(10, 12, 25, 27)
    g.put(11, 27, "k")
    g.put(12, 27, "3")
    # The top: the passage under the last cabinet, shut by the spring shutter 'P'.
    g.fill(24, 35, 0, 2, "#")
    shutter(g, 26, 8, 5, "P")
    g.put(23, 7, "4")
    g.put(25, 7, "i")
    g.put(29, 7, "M")
    g.put(31, 7, "R")
    g.put(34, 7, "E")
    # The shaft: tab 'T' at the bottom, and drawers both sides for the slow way up.
    g.fill(3, 7, 22, 22, "#")
    g.put(4, 21, "T")
    g.put(6, 21, "o")
    for row in (20, 16, 12):
        g.put(3, row, "r")
    for row in (18, 14, 10):
        g.put(7, row, "q")
    return g


# The Reading Room (6-3): rooms in a row under the gallery floor, left to right.
ROOMS = ["L", "H", "R", "K"]
# Shutter -> the rooms it stands between.
DOORS = {"A": ("L", "H"), "C": ("H", "R"), "B": ("R", "K")}
# Tab -> (its room, the shutters it flips).
TABS = {"T": ("L", "AB"), "W": ("H", "C"), "U": ("R", "AC")}
START_OPEN = ""
START_ROOM = "H"
GOAL_ROOM = "K"


def reading_room() -> Grid:
    """6-3 The Reading Room: Bindwell's index of everything, kept by someone under the
    dome. Four rooms in a row under the gallery floor, roll shutters between them, and
    three tabs: the reading desk's (W) flips the middle shutter; the one in the left
    alcove (T) the left and right; the one in the right alcove (U) the left and middle.
    Every tab but the desk's shuts Patch in. The ribbon gets him out again."""
    g = Grid(52, 24)
    F = 20
    g.ground(0, 51, F)
    # The gallery floor over the rooms, and the walls.
    g.fill(0, 0, 0, F - 1, "#")
    g.fill(1, 33, F - 8, F - 7, "#")
    g.fill(34, 35, 0, F - 7, "#")
    g.fill(51, 51, 0, F - 1, "#")
    # L: x 1-7 | A 8 | H: 9-21 | C 22 | R: 23-33 | B 34 | K: 35-50
    shutter(g, 8, F, 6, "A")
    shutter(g, 22, F, 6, "C")
    shutter(g, 34, F, 6, "B")
    g.fill(8, 8, F - 8, F - 7, "#")
    g.fill(22, 22, F - 8, F - 7, "#")
    g.put(4, F - 1, "T")
    g.put(12, F - 1, "@")
    g.put(10, F - 1, "X")
    g.put(14, F - 1, "1")
    g.put(18, F - 1, "W")
    g.put(26, F - 1, "2")
    g.put(30, F - 1, "U")
    # K: the stair of reading desks up to the dome, and the way on.
    g.put(37, F - 1, "3")
    g.plank(38, 41, F - 3)
    g.plank(44, 47, F - 6)
    g.plank(38, 41, F - 9)
    g.plank(43, 49, F - 12)
    g.put(45, F - 13, "o")
    g.put(46, F - 13, "4")
    g.put(48, F - 13, "E")
    return g


def _room_of_column(x: int) -> str:
    return "L" if x <= 7 else "H" if x <= 21 else "R" if x <= 33 else "K"


def check_reading_room_map(g: Grid) -> bool:
    """The map matches the model: each tab is in its room, each shutter stands
    between its rooms and seals floor to gallery, and the goal is in its room."""
    rows = ["".join(r) for r in g.rows]
    ok = True
    for t, (room, _) in TABS.items():
        x = next(x for r in rows for x, c in enumerate(r) if c == t)
        ok &= _room_of_column(x) == room
    for d, (a, b) in DOORS.items():
        x = next(x for r in rows for x, c in enumerate(r) if c == d)
        ok &= _room_of_column(x - 1) == a and _room_of_column(x + 1) == b
        y = next(y for y, r in enumerate(rows) if r[x] == d)
        # Solid from the shutter's top to the top of the map.
        ok &= all(rows[yy][x] == "#" for yy in range(0, y - 5))
    ex = next(x for r in rows for x, c in enumerate(r) if c == "E")
    ok &= _room_of_column(ex) == GOAL_ROOM
    return ok


def _rooms_reached(open_: frozenset, room: str) -> set:
    seen = {room}
    stack = [room]
    while stack:
        r = stack.pop()
        for d, (a, b) in DOORS.items():
            if d in open_:
                for x, y in ((a, b), (b, a)):
                    if x == r and y not in seen:
                        seen.add(y)
                        stack.append(y)
    return seen


def solve_reading_room(warp: bool = True):
    """Breadth-first over (open shutters, Patch's room, the ribbon's room or None).
    From a room he can walk to any room the open shutters join it to; there he can
    pull a tab, or lay the ribbon (if it isn't down); and from anywhere he can warp
    back to the ribbon. Returns the shortest list of moves, or None."""
    start = (frozenset(START_OPEN), START_ROOM, None)
    seen = {start: []}
    q = collections.deque([start])
    while q:
        state = q.popleft()
        open_, room, ribbon = state
        reach = _rooms_reached(open_, room)
        if GOAL_ROOM in reach:
            return seen[state]
        moves = []
        for t, (tab_room, flips) in TABS.items():
            if tab_room in reach:
                moves.append(((open_ ^ frozenset(flips), tab_room, ribbon), "pull " + t))
        if warp and ribbon is None:
            for r in sorted(reach):
                moves.append(((open_, r, r), "lay in " + r))
        if warp and ribbon is not None:
            moves.append(((open_, ribbon, None), "warp to " + ribbon))
        for nxt, move in moves:
            if nxt not in seen:
                seen[nxt] = seen[state] + [move]
                q.append(nxt)
    return None


def _rows(grid: Grid) -> list:
    return ["".join(r) for r in grid.rows]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    back_pages().write(os.path.join(OUT, "6_1_the_back_pages.txt"),
        "6-1 The Back Pages (drawn by tools/levels/build_index.py; legend in\nscenes/levels/index/6_1_the_back_pages.tscn)\nabilities: frog glide")
    card_catalogue().write(os.path.join(OUT, "6_2_the_card_catalogue.txt"),
        "6-2 The Card Catalogue (drawn by tools/levels/build_index.py; legend in\nscenes/levels/index/6_2_the_card_catalogue.tscn)\nabilities: frog glide drawers")
    reading_room().write(os.path.join(OUT, "6_3_the_reading_room.txt"),
        "6-3 The Reading Room (drawn by tools/levels/build_index.py; legend in\nscenes/levels/index/6_3_the_reading_room.tscn); A B C are the shutters (all start shut)")
    ok = True
    climb_check.UP, climb_check.GLIDE = 4.5, True
    for name, grid, drawers in (("6-1", back_pages(), False), ("6-2", card_catalogue(), True)):
        climb_check.DRAWERS = drawers
        rows = _rows(grid)
        reach = climb_check.climbable(rows)[0]
        print(name, "climbable (drawers out, shutters open):", reach)
        ok &= reach
    # 6-1: the tab of each spring shutter is reachable from the near side of it.
    climb_check.DRAWERS = False
    rows = _rows(back_pages())
    for tab, door in (("T", "P"), ("U", "Q")):
        spot = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == tab)
        sealed = [r.replace(door, "#") for r in rows]
        reach = climb_check.climbable(sealed, goal=spot)[0]
        print("6-1 tab", tab, "reachable with shutter", door, "shut:", reach)
        ok &= reach
    # 6-2: the shaft's tab, and the way back up out of the shaft without the ribbon.
    climb_check.DRAWERS = True
    rows = _rows(card_catalogue())
    tab = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "T")
    door = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "P")
    out_of_shaft = climb_check.climbable(rows, start=tab, goal=(door[0] - 2, door[1]))[0]
    print("6-2 the slow way back up out of the shaft:", out_of_shaft)
    ok &= out_of_shaft
    ok_map = check_reading_room_map(reading_room())
    print("6-3 map matches the room model:", ok_map)
    ok &= ok_map
    plan = solve_reading_room()
    print("6-3 shortest solution:", plan)
    no_warp = solve_reading_room(warp=False)
    print("6-3 solvable without the warp:", no_warp is not None)
    if plan is None or no_warp is not None or sum(m.startswith("warp") for m in plan) < 2 \
            or sum(m.startswith("pull") for m in plan) < 4:
        print("FAIL: the Reading Room must need the warp twice and four pulls")
        ok = False
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
