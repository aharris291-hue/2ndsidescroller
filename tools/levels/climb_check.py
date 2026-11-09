"""Checks a TextLevel map can be climbed from '@' to its exit ('E', or 'Y' on a back page) with Patch's real reach.

Surfaces are runs of cells Patch can stand on: a one-way plank '-', the top of solid
ground, a soaked sheet 'w' (its surface is the row below it, ~2.75 tiles wide; soft\nunless an awning above can dry it), and the
seats of a gear or windmill 'V' (sampled round their circle), and brass grapple rings
'O' (the Tape Tail reels Patch up to a ring from any surface within 8 tiles of it, and
he hops off it: a soft surface just under the ring), and shadow ledges 'h' (solid while
their lantern burns: treated as always solid here), and ink ('~', or '<>^v' where it
runs that way): Patch drops into it like any lower surface, Blot Dives through it on one
breath (26 tiles of swimming, a current carries him at about twice that and is nearly
impossible to swim against), and leaps out of any surface cell of it as if from ground
(the floor under ink is not something to stand on). From a surface Patch can
reach another whose top is at most 2.5 rows higher (1 row from a soaked sheet: a hop)
with a horizontal gap of at most 3 tiles, or any lower surface within 4 tiles. Ceilings
are not modelled: keep solid ground out of the way of the climb.

The Spine Peaks add: ice '=' (solid ground with black ice on top: stood on like any
ground), fold marks 'F' (a Pop-Up Slam springs a paper peak 4 tiles tall and about 2
wide: its top is a surface), and the Frog Fold: a map with a comment line
"; abilities: frog" is checked with Patch able to spring 4.5 rows up instead of 2.5.

  python3 tools/levels/climb_check.py levels/thistledown/1_5_the_mill_stair.txt
"""
import math
import sys
from collections import deque

SOLID = set("#%&$=")
INK = set("~<>^v")
CURRENT = {">": (1, 0), "<": (-1, 0), "^": (0, -1), "v": (0, 1)}
BREATH = 26.0


AWNING_HALF = {"A": 224 / 128, "B": 416 / 128, "C": 416 / 128}


def sheltered(rows, x, y):
    """A sheet under an awning ('A', 'B', 'C') dries once its rope is cut."""
    for ay in range(max(0, y - 10), y):
        for ax, c in enumerate(rows[ay]):
            if c in AWNING_HALF and abs(ax - x) <= AWNING_HALF[c] + 40 / 64:
                return True
    return False


def surfaces(rows):
    out = []  # (row, x0, x1, soft)
    h = len(rows)
    for y in range(h):
        x = 0
        row = rows[y]
        while x < len(row):
            c = row[x]
            def ok_top(cx):
                above = rows[y - 1][cx] if cx < len(rows[y - 1]) else "."
                return above not in SOLID and above not in INK
            standable = c == "-" or (c in SOLID and y > 0 and ok_top(x))
            if standable:
                x0 = x
                while x < len(row) and (row[x] == "-" or (row[x] in SOLID and ok_top(x))):
                    x += 1
                out.append((y, x0, x - 1, False))
            else:
                x += 1
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "w":
                out.append((y + 1, x - 0.9, x + 1.9, not sheltered(rows, x, y)))
            elif c == "V":
                # gear_wheel: centre 260 px above its foot, seats on a 200 px circle
                cy = (y + 1) - 260 / 64
                for k in range(16):
                    a = k / 16 * math.tau
                    sx = x + 0.5 + math.cos(a) * 200 / 64
                    sy = cy + math.sin(a) * 200 / 64 - 12 / 64
                    out.append((sy, sx - 0.9, sx + 0.9, False))
            elif c == "h":
                # a lantern's shadow ledge (2-4): 3 tiles wide, its top on the row below
                out.append((y + 1, x - 1, x + 1, False))
            elif c == "F":
                # a fold mark's pop-up peak: 4 tiles tall, 132 px wide
                # (Patch rides it up from the ground it stands on)
                out.append((y + 1 - 4, x - 0.5, x + 0.5, False, "fold", (x, y + 1)))
            elif c == "O":
                out.append((y + 1.25, x + 0.5, x + 0.5, True, "ring"))
            elif c in INK and (y == 0 or (x < len(rows[y - 1]) and rows[y - 1][x] not in INK and rows[y - 1][x] not in SOLID) or x >= len(rows[y - 1])):
                # the skin of a pool: dropped into, and leapt out of, like ground
                out.append((y, x, x, False, "ink", (x, y)))
    return out


def _ink_at(rows, x, y):
    return 0 <= y < len(rows) and 0 <= x < len(rows[y]) and rows[y][x] in INK


def swim(rows, start):
    """Ink cells a blot can reach from `start` on one breath (Dijkstra, in tiles of
    swimming: 0.55 with a current, 6 against it, 1 otherwise)."""
    import heapq
    best = {start: 0.0}
    q = [(0.0, start)]
    while q:
        d, (x, y) = heapq.heappop(q)
        if d > best.get((x, y), 1e9):
            continue
        here = rows[y][x]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if ny < 0 or ny >= len(rows) or nx < 0 or nx >= len(rows[ny]) or rows[ny][nx] not in INK:
                continue
            # Patch is two tiles tall: a lane one tile high is too tight for him.
            if not (_ink_at(rows, nx, ny - 1) or _ink_at(rows, nx, ny + 1)):
                continue
            flow = CURRENT.get(here)
            cost = 1.0 if flow is None else (0.55 if flow == (dx, dy) else 6.0 if flow == (-dx, -dy) else 1.0)
            nd = d + cost
            if nd <= BREATH and nd < best.get((nx, ny), 1e9):
                best[(nx, ny)] = nd
                heapq.heappush(q, (nd, (nx, ny)))
    return best


RING_RANGE = 8.0


UP = 2.5


def reach(a, b):
    ya, a0, a1, soft = a[:4]
    yb, b0, b1 = b[:3]
    if len(b) > 4 and b[4] == "fold":
        bx, by = b[5]
        if ya == by and a0 - 0.5 <= bx <= a1 + 0.5:
            return True
        b = b[:4]
    if len(b) > 4:
        # zip to a ring: Patch stands about 0.7 rows above the surface he throws from
        nx = min(max(b0, a0), a1)
        return math.hypot(b0 - nx, (ya - 0.7) - (yb - 1.25)) <= RING_RANGE
    gap = max(b0 - a1, a0 - b1, 0)
    up = ya - yb
    if up > 0:
        return up <= (1.0 if soft else UP) and gap <= 3
    return gap <= 4


def main(path):
    global UP
    lines = open(path).read().splitlines()
    UP = 4.5 if any(ln.startswith(";") and "abilities:" in ln and "frog" in ln for ln in lines) else 2.5
    rows = [ln for ln in lines if not ln.startswith(";")]
    ok, top, goal_row = climbable(rows)
    print("%s: %s (highest surface reached: row %.1f, exit on row %d)" % (path, "climbable" if ok else "NOT climbable", top, goal_row))
    return ok


def climbable(rows, start=None, goal=None):
    """Can Patch get from `start` (default '@') to `goal` (default the exit)? Returns
    (ok, the highest surface row reached, the goal's surface row)."""
    surf = surfaces(rows)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "@" and start is None:
                start = (x, y)
            elif c in "EY" and goal is None:
                goal = (x, y)

    def under(cell):
        x, y = cell
        best = None
        for i, (sy, s0, s1) in enumerate(t[:3] for t in surf):
            if s0 - 0.5 <= x <= s1 + 0.5 and sy > y and (best is None or sy < surf[best][0]):
                best = i
        return best

    s, g = under(start), under(goal)
    swims = {}
    seen = {s}
    q = deque([s])
    while q:
        i = q.popleft()
        if len(surf[i]) > 4 and surf[i][4] == "ink":
            swims[i] = swim(rows, surf[i][5])
        for j in range(len(surf)):
            if j in seen:
                continue
            a_ink = len(surf[i]) > 4 and surf[i][4] == "ink"
            b_ink = len(surf[j]) > 4 and surf[j][4] == "ink"
            if a_ink and b_ink and surf[j][5] in swims[i]:
                seen.add(j)
                q.append(j)
            elif reach(surf[i][:4], surf[j]) if not b_ink else reach(surf[i][:4], surf[j][:4]):
                seen.add(j)
                q.append(j)
    ok = g in seen
    top = min(surf[i][0] for i in seen)
    return ok, top, surf[g][0]


if __name__ == "__main__":
    sys.exit(0 if all([main(p) for p in sys.argv[1:]]) else 1)
