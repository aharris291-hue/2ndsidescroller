"""Checks a TextLevel map can be climbed from '@' to its exit ('E', or 'Y' on a back page) with Patch's real reach.

Surfaces are runs of cells Patch can stand on: a one-way plank '-', the top of solid
ground, a soaked sheet 'w' (its surface is the row below it, ~2.75 tiles wide; soft\nunless an awning above can dry it), and the
seats of a gear or windmill 'V' (sampled round their circle). From a surface Patch can
reach another whose top is at most 2.5 rows higher (1 row from a soaked sheet: a hop)
with a horizontal gap of at most 3 tiles, or any lower surface within 4 tiles. Ceilings
are not modelled: keep solid ground out of the way of the climb.

  python3 tools/levels/climb_check.py levels/thistledown/1_5_the_mill_stair.txt
"""
import math
import sys
from collections import deque

SOLID = set("#%&$")


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
            standable = c == "-" or (c in SOLID and y > 0 and x < len(rows[y - 1]) and rows[y - 1][x] not in SOLID)
            if standable:
                x0 = x
                while x < len(row) and (row[x] == "-" or (row[x] in SOLID and rows[y - 1][x] not in SOLID)):
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
    return out


def reach(a, b):
    ya, a0, a1, soft = a
    yb, b0, b1, _ = b
    gap = max(b0 - a1, a0 - b1, 0)
    up = ya - yb
    if up > 0:
        return up <= (1.0 if soft else 2.5) and gap <= 3
    return gap <= 4


def main(path):
    rows = [ln.rstrip("\n") for ln in open(path) if not ln.startswith(";")]
    surf = surfaces(rows)
    start = goal = None
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "@":
                start = (x, y)
            elif c in "EY" and goal is None:
                goal = (x, y)

    def under(cell):
        x, y = cell
        best = None
        for i, (sy, s0, s1, _) in enumerate(surf):
            if s0 - 0.5 <= x <= s1 + 0.5 and sy > y and (best is None or sy < surf[best][0]):
                best = i
        return best

    s, g = under(start), under(goal)
    seen = {s}
    q = deque([s])
    while q:
        i = q.popleft()
        for j in range(len(surf)):
            if j not in seen and reach(surf[i], surf[j]):
                seen.add(j)
                q.append(j)
    ok = g in seen
    top = min(surf[i][0] for i in seen)
    print("%s: %s (highest surface reached: row %.1f, exit on row %d)" % (path, "climbable" if ok else "NOT climbable", top, surf[g][0]))
    return ok


if __name__ == "__main__":
    sys.exit(0 if all([main(p) for p in sys.argv[1:]]) else 1)
