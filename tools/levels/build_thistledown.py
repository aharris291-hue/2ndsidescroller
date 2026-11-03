"""Draws Region 1's text maps: Thistledown, Drowned (Phase 3, Level Design Bible).

Writes levels/thistledown/*.txt. Each map's legend is in its scene's TextLevel node
(scenes/levels/thistledown/*.tscn); the shared characters are:
  #  ground (sodden meadow)   $  stone   -  one-way plank
  @  start   k  bookmark   s  Soggy   d  ink drips
  w  soaked paper (sags, tears, too soft to jump from)   W  dry paper
  A  awning (224 px)   B  wide awning (416 px)   C  high awning tied off on the ground
  1-9  story triggers   E  exit   o  scrap   t  tape
Spacing follows the Bible's construction rules: jumps of 3 tiles up at most, gaps of
3 (easy) or 4 (committed), fights on flat ground 12+ tiles wide.

Run: python3 tools/levels/build_thistledown.py
"""
import os

from grid import Grid

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "thistledown")


def sodden_fields() -> Grid:
    """1-1 The Sodden Fields: first fights one at a time, soaked paper, awnings, and the
    drowned sheep's bell in the lane under the field."""
    g = Grid(266, 28)
    F = 20
    g.ground(0, 265, F)
    # S1 the lane: start, the opening line, Dot by the stall lamp.
    g.put(3, F - 1, "@")
    g.put(10, F - 1, "1")
    g.put(12, 3, "d")
    g.put(21, 3, "d")
    g.put(23, F - 1, "D")
    # S2 the first Soggy, alone, on 20 tiles of flat ground.
    g.put(32, F - 1, "2")
    g.put(44, F - 1, "s")
    # S3 a shallow ditch with a soaked sheet over it: safe to fall through.
    g.put(48, F - 1, "3")
    g.clear(51, 53, F, F + 1)
    g.put(52, F - 1, "w")
    # S4 three sheets over open pits, one-tile posts between: keep moving.
    for x0 in (65, 69, 73):
        g.clear(x0, x0 + 2)
        g.put(x0 + 1, F - 1, "w")
    # S5 the awning: a pit with two sheets, a wall two tiles above the field beyond it.
    # Off wet paper Patch can only hop; cut the rope and the dried sheets hold a jump.
    g.put(88, F - 1, "4")
    g.clear(92, 97)
    g.put(93, F, "w")
    g.put(96, F, "w")
    g.put(95, F - 3, "B")
    g.ground(98, 112, F - 2)
    g.put(105, F - 3, "o")
    # S6 bookmark, then two Soggies at once.
    g.put(115, F - 1, "k")
    g.put(124, F - 1, "s")
    g.put(129, F - 1, "s")
    # S7 the bell: a shaft down into the drowned lane under the field, wading against
    # the current to Letter F and a lost sheep, planks back up at the far end.
    g.put(134, F - 1, "5")
    g.clear(136, 138, F, 25)
    g.clear(139, 170, 22, 25)
    g.put(150, 25, "s")
    g.put(155, 25, "c")
    g.put(160, 25, "L")
    g.put(166, 25, "h")
    g.put(145, 22, "d")
    g.clear(171, 173, F, 25)
    g.plank(171, 173, 23)
    g.plank(171, 173, F)
    # S8 three sheets over a pit with a Soggy waiting on the landing, then steps up.
    g.clear(180, 188)
    for x in (181, 184, 187):
        g.put(x, F - 1, "w")
    g.put(184, F - 4, "A")
    g.put(193, F - 1, "s")
    g.ground(197, 200, F - 2)
    g.ground(201, 216, F - 4)
    g.put(208, F - 5, "o")
    # S9 down into the moths' field.
    g.put(220, F - 1, "t")
    g.put(226, F - 1, "6")
    for x in (232, 235, 238):
        g.put(x, F - 6, "m")
    g.put(242, F - 1, "o")
    # S10 the Margin's folded corner, and the hedge gap on to the Sheepfold.
    g.put(250, F - 1, "M")
    g.put(248, F - 1, "F")
    g.put(258, F - 1, "G")
    g.put(255, F - 1, "7")
    g.put(262, F - 1, "E")
    return g


def the_sheepfold() -> Grid:
    """1-2 The Sheepfold: Fluff's pen behind its barricade, three waves, wool-wearing
    Soggies among the sheep, the hayloft (Letter M, the sealed back page's door) and the
    hill path down toward the chapel."""
    g = Grid(232, 28)
    F = 20
    g.ground(0, 231, F)
    # S1 arrival through the hedge; the way back to the fields is behind Patch.
    g.put(0, F - 1, "X")
    g.put(4, F - 1, "@")
    g.put(10, F - 1, "1")
    # S2 dry-stone walls to hop, and a stone tower with a lost sheep on top: two soaked
    # sheets up its face, too soft to climb from until the wide awning dries them.
    for x in (18, 27):
        g.fill(x, x + 1, F - 2, F - 1, "$")
    g.ground(44, 47, F - 6, "$")
    g.put(39, F - 3, "w")
    g.put(42, F - 5, "w")
    g.put(41, F - 8, "C")
    g.put(46, F - 7, "h")
    # S3 Fluff outside the pen, the west gate, and the pen itself (50 tiles of flat).
    g.put(58, F - 1, "k")
    g.put(64, F - 1, "2")
    g.put(72, F - 1, "f")
    g.put(80, F - 1, "g")
    g.put(84, F - 1, "K")
    for x in (95, 112, 121):
        g.put(x, F - 1, "u")
    # the barn roof on posts, where Ink Spitters come up in the second wave
    g.plank(100, 110, F - 5)
    g.put(130, F - 1, "g")
    g.put(134, F - 1, "k")
    # S4 the barn and its hayloft: planks up the outside to the roof (Letter M behind
    # the chimney), and the hayloft's sealed door.
    g.ground(138, 156, F - 1, "$")
    g.put(141, F - 2, "H")
    g.plank(144, 146, F - 4)
    g.plank(148, 150, F - 7)
    g.ground(150, 156, F - 9, "$")
    g.put(155, F - 10, "L")
    g.put(152, F - 10, "o")
    # S5 the hill path down: a pit with three soaked sheets under drips, an Ink Spitter
    # on a ledge, two Soggies on the way down.
    g.put(162, F - 1, "3")
    g.clear(166, 174)
    for x in (167, 170, 173):
        g.put(x, F - 1, "w")
    g.put(170, 3, "d")
    g.ground(178, 183, F - 4, "$")
    g.put(181, F - 5, "i")
    g.put(190, F - 1, "s")
    g.ground(196, 231, F + 2)
    g.put(205, F + 1, "s")
    g.put(214, F + 1, "o")
    g.put(222, F + 1, "4")
    g.put(228, F + 1, "E")
    g.put(225, F + 1, "G")
    return g


# 1-3's three rooms, left to right, each 20 x 15 with doorways in rows 6-7. 'p' is the
# left cell of a 2-cell pew, 'b' a bell stone. tools/levels/pew_solver.py checks each
# can be solved: the nave in 6 pushes, the aisles in 25, the crypt in 15.
CHAPEL_ROOMS = {
    "nave": [
        "$$$$$$$$$$$$$$$$$$$$",
        "$..................$",
        "$..................$",
        "$.....$$....$$.....$",
        "$.....$$.b..$$.....$",
        "$..................$",
        "@..................$",
        "...................$",
        "$..................$",
        "$.....$$....$$.....$",
        "$.....$$.p..$$.....$",
        "$..................$",
        "$..................$",
        "$..................$",
        "$$$$$$$$$$$$$$$$$$$$",
    ],
    "aisles": [
        "$$$$$$$$$$$$$$$$$$$$",
        "$..................$",
        "$..........$$......$",
        "$.b$...............$",
        "$..$....p...$$$$...$",
        "$..$...........$...$",
        "@..............$....",
        "....................",
        "$...........$$.....$",
        "$..................$",
        "$......$$$$........$",
        "$.....$$$.b......p.$",
        "$..................$",
        "$..................$",
        "$$$$$$$$$$$$$$$$$$$$",
    ],
    "crypt": [
        "$$$$$$$$$$$$$$$$$$$$",
        "$..................$",
        "$.$$...$$$$$$...$$.$",
        "$.$$.....b......$$.$",
        "$......p...........$",
        "$...$$.......$$....$",
        "@...$$...$$..$$..b.$",
        "........$$$$.......$",
        "$...b....$$..p.....$",
        "$...$$.......$$....$",
        "$.........p........$",
        "$.$$............$$.$",
        "$.$$...$$$$$$...$$.$",
        "$..................$",
        "$$$$$$$$$$$$$$$$$$$$",
    ],
}


def drowned_chapel() -> Grid:
    """1-3 The Drowned Chapel (top-down): the nave, the flooded aisles, the crypt.
    Each room's bell stones open the next door; the crypt's three ring the bell."""
    g = Grid(60, 15)
    for i, room in enumerate(CHAPEL_ROOMS.values()):
        for y, row in enumerate(room):
            for x, c in enumerate(row):
                g.put(i * 20 + x, y, "." if c == "@" else c)
    # the doorways between rooms are both walls' gaps; a gate sits in the far one
    for x in (19, 39, 59):
        g.put(x, 6, ".")
        g.put(x, 7, ".")
    g.put(19, 7, "D")
    g.put(39, 7, "D")
    g.put(58, 7, "D")
    g.put(0, 7, "X")
    g.put(2, 7, "@")
    g.put(1, 6, "G")
    # the aisles' Soggies and a sheep hiding behind the stone
    for x, y in ((27, 9), (33, 3), (36, 12)):
        g.put(x, y, "s")
    g.put(21, 2, "h")
    g.put(41, 13, "L")
    g.put(57, 1, "o")
    g.put(4, 3, "1")
    g.put(22, 7, "2")
    g.put(42, 7, "3")
    g.put(59, 7, "E")
    return g


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    sodden_fields().write(os.path.join(OUT, "1_1_sodden_fields.txt"),
        "1-1 The Sodden Fields (drawn by tools/levels/build_thistledown.py; legend in\nscenes/levels/thistledown/1_1_sodden_fields.tscn)")
    the_sheepfold().write(os.path.join(OUT, "1_2_the_sheepfold.txt"),
        "1-2 The Sheepfold (drawn by tools/levels/build_thistledown.py; legend in\nscenes/levels/thistledown/1_2_the_sheepfold.tscn)")
    drowned_chapel().write(os.path.join(OUT, "1_3_drowned_chapel.txt"),
        "1-3 The Drowned Chapel, top-down (drawn by tools/levels/build_thistledown.py;\nlegend in scenes/levels/thistledown/1_3_drowned_chapel.tscn)")
    print("wrote Thistledown maps")


if __name__ == "__main__":
    main()
