"""A tiny helper for drawing TextLevel maps (scripts/world/text_level.gd) in code.

A Grid is W x H cells of '.', drawn into with rectangles, columns of ground and single
characters, then written out as a .txt map with a header comment.
"""


class Grid:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.rows = [["."] * w for _ in range(h)]

    def put(self, x: int, y: int, c: str) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.rows[y][x] = c

    def get(self, x: int, y: int) -> str:
        return self.rows[y][x] if 0 <= x < self.w and 0 <= y < self.h else "#"

    def fill(self, x0: int, x1: int, y0: int, y1: int, c: str) -> None:
        """Fills columns x0..x1 and rows y0..y1, inclusive."""
        for y in range(max(y0, 0), min(y1, self.h - 1) + 1):
            for x in range(max(x0, 0), min(x1, self.w - 1) + 1):
                self.rows[y][x] = c

    def ground(self, x0: int, x1: int, top: int, c: str = "#") -> None:
        """Solid ground from row `top` down to the bottom of the map."""
        self.fill(x0, x1, top, self.h - 1, c)

    def clear(self, x0: int, x1: int, y0: int = 0, y1: int = 10_000) -> None:
        self.fill(x0, x1, y0, y1, ".")

    def plank(self, x0: int, x1: int, y: int) -> None:
        self.fill(x0, x1, y, y, "-")

    def floor_at(self, x: int) -> int:
        """The first solid row in column x (the row Patch stands on top of)."""
        for y in range(self.h):
            if self.rows[y][x] in "#%&$":
                return y
        return self.h

    def write(self, path: str, header: str) -> None:
        with open(path, "w") as f:
            for line in header.strip().splitlines():
                f.write("; " + line + "\n")
            for row in self.rows:
                f.write("".join(row) + "\n")
