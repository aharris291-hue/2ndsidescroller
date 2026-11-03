"""Checks the Drowned Chapel's pew puzzles can be solved (and how many pushes it takes).

A room is drawn as text: '$' wall, 'p' the left cell of a 2x1 pew, 'b' a bell stone,
'@' where Patch comes in, anything else floor. Patch takes one cell; he pushes a pew
one cell along a row from either end, or one cell up or down from under or over
either half of it (PushBlock's rules). Solved = every stone has a pew over it.

  python3 tools/levels/pew_solver.py   (checks the rooms in build_thistledown.py)
"""
from collections import deque


def parse(room: list[str]):
    walls, stones, pews, start = set(), set(), [], None
    for y, row in enumerate(room):
        for x, c in enumerate(row):
            if c == "$":
                walls.add((x, y))
            elif c == "b":
                stones.add((x, y))
            elif c == "p":
                pews.append((x, y))
            elif c == "@":
                start = (x, y)
    return walls, stones, tuple(sorted(pews)), start


def cells(pew):
    x, y = pew
    return {(x, y), (x + 1, y)}


def solve(room: list[str], max_states: int = 400_000):
    walls, stones, pews, start = parse(room)
    # Outside the room counts as wall (doorways lead nowhere for the puzzle).
    h, w = len(room), max(len(r) for r in room)
    for x in range(-1, w + 1):
        walls |= {(x, -1), (x, h)}
    for y in range(-1, h + 1):
        walls |= {(-1, y), (w, y)}

    def blocked(pews, skip=None):
        out = set(walls)
        for i, p in enumerate(pews):
            if i != skip:
                out |= cells(p)
        return out

    def reach(pews, frm):
        solid = blocked(pews)
        seen = {frm}
        q = deque([frm])
        while q:
            x, y = q.popleft()
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + d[0], y + d[1])
                if n not in seen and n not in solid:
                    seen.add(n)
                    q.append(n)
        return seen

    def solved(pews):
        covered = set()
        for p in pews:
            covered |= cells(p)
        return stones <= covered

    def norm(pews, player):
        r = reach(pews, player)
        return pews, min(r)

    first = norm(pews, start)
    seen = {first: 0}
    q = deque([(pews, start, 0)])
    while q:
        pews, player, n = q.popleft()
        if solved(pews):
            return n
        if len(seen) > max_states:
            return None
        r = reach(pews, player)
        for i, (x, y) in enumerate(pews):
            others = blocked(pews, skip=i)
            moves = [
                ((x - 1, y), (1, 0)),
                ((x + 2, y), (-1, 0)),
            ]
            for px in (x, x + 1):
                moves.append(((px, y + 1), (0, -1)))
                moves.append(((px, y - 1), (0, 1)))
            for stand, d in moves:
                if stand not in r:
                    continue
                np = (x + d[0], y + d[1])
                if cells(np) & others:
                    continue
                new = list(pews)
                new[i] = np
                new = tuple(sorted(new))
                key = norm(new, stand)
                if key not in seen:
                    seen[key] = n + 1
                    q.append((new, stand, n + 1))
    return None


if __name__ == "__main__":
    import build_thistledown as b

    for name, room in b.CHAPEL_ROOMS.items():
        print(name, "solved in", solve(room), "pushes")
