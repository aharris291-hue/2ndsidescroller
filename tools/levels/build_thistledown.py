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
    # S5 the awning: a pit with two sheets level with the field, and a wall two tiles up
    # beyond it.
    # Off wet paper Patch can only hop; cut the rope and the dried sheets hold a jump.
    g.put(88, F - 1, "4")
    g.clear(92, 97)
    g.put(93, F - 1, "w")
    g.put(96, F - 1, "w")
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
    g.put(143, F - 2, "J")
    g.plank(142, 144, F - 3)
    g.plank(145, 147, F - 5)
    g.plank(148, 149, F - 7)
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
    g.ground(178, 183, F - 2, "$")
    g.put(181, F - 3, "i")
    g.put(190, F - 1, "s")
    g.clear(196, 231, F, F + 1)
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
    g.put(58, 6, "R")
    return g


def millrace() -> Grid:
    """1-4 The Millrace: wading against the race, three sluices drained one section at a
    time, a turning windmill whose seats carry Patch up to the high bank, Ink Spitters
    on high ledges and an Inkwell Turret over the far bank. Letter W lies in the pit
    under the third section, reachable only once it is drained."""
    g = Grid(252, 28)
    F = 20
    g.ground(0, 251, F)
    # S1 arrival from the chapel's back door.
    g.put(0, F - 1, "X")
    g.put(2, F - 1, "G")
    g.put(4, F - 1, "@")
    g.put(9, F - 1, "1")
    g.put(18, F - 1, "o")
    # S2 shallow water: the current pushes, but Patch can wade it. One Soggy in it.
    g.put(27, F - 1, "2")
    g.put(42, F - 1, "c")
    g.put(49, F - 1, "s")
    g.put(36, 3, "d")
    # S3 the first sluice and the deep race behind it; an Ink Spitter on a ledge over it.
    g.put(60, F - 1, "3")
    g.put(62, F - 1, "S")
    g.put(75, F - 1, "r")
    g.plank(78, 81, F - 6)
    g.put(79, F - 7, "i")
    g.put(84, F - 1, "o")
    g.put(92, F - 1, "k")
    # S4 the windmill: its seats carry Patch up to the high bank (a 6-tile wall).
    g.put(97, F - 1, "4")
    g.put(110, F - 1, "V")
    g.ground(114, 150, F - 6, "$")
    # S5 the high bank: two Soggies, and the second sluice at its end.
    g.put(128, F - 7, "s")
    g.put(136, F - 7, "s")
    g.put(140, F - 7, "o")
    g.put(148, F - 7, "S")
    g.put(163, F - 1, "r")
    # S6 the third sluice; under its section, a pit with Letter W in it.
    g.put(178, F - 1, "S")
    g.put(176, F - 1, "5")
    g.put(191, F - 1, "r")
    g.clear(189, 193, F, 25)
    g.plank(189, 193, 24)
    g.plank(189, 193, 22)
    g.put(191, 25, "L")
    g.ground(206, 214, F - 2, "$")
    g.put(211, F - 3, "q")
    # S7 the mill's foot: Ink Spitters on two ledges, then the mill door.
    g.put(218, F - 1, "6")
    g.plank(224, 227, F - 5)
    g.put(225, F - 6, "i")
    g.plank(235, 238, F - 5)
    g.put(236, F - 6, "i")
    g.put(230, F - 1, "t")
    g.put(242, F - 1, "o")
    g.put(245, F - 1, "7")
    g.put(250, F - 1, "E")
    g.put(247, F - 1, "M")
    return g


STAIR_OFF = 18


def mill_stair() -> Grid:
    """1-5 The Mill Stair (vertical): planks up the inside of the mill under falling
    water, the mill's turning gears carrying seats, soaked flour sacks slung between
    beams that tear if Patch stands on them, a fight on each floor, and the Folded Crane
    with an Inked Soggy at the top. The last Bookmark is by the door to the mill floor.

    Every climb step is at most 2 tiles up with a gap of at most 2 tiles; the sacks are
    only ever crossed level (a jump off a soaked sack is just a hop)."""
    H = 130 - STAIR_OFF
    g = Grid(36, H)

    def r(row: int) -> int:
        return row - STAIR_OFF

    for x in (0, 1, 34, 35):
        g.fill(x, x, 0, H - 1, "$")
    g.fill(0, 35, 0, 1, "$")
    g.ground(0, 35, r(127))

    def floor(row: int) -> None:
        g.plank(2, 33, r(row))

    def zigzag(rows, xs) -> None:
        for row, x0 in zip(rows, xs):
            g.plank(x0, x0 + 5, r(row))

    def sacks(row: int, xs) -> None:
        # a 'w' sits one row above the surface it makes
        for x in xs:
            g.put(x, r(row) - 1, "w")

    A, B, C = 3, 11, 19
    D = 27
    # the mill's foot: Start and the way back out to the race
    g.put(3, r(126), "@")
    g.put(2, r(126), "X")
    g.put(6, r(126), "1")
    zigzag(range(125, 108, -2), [A, B, C, D, C, B, A, B, C])
    for x in (9, 23):
        g.put(x, r(104), "d")
    # floor 1: two Soggies
    floor(107)
    g.put(6, r(106), "2")
    g.put(12, r(106), "s")
    g.put(26, r(106), "s")
    # the first gear: ride its seats up to the planks
    g.put(17, r(106), "V")
    g.plank(21, 26, r(98))
    g.plank(28, 32, r(96))
    sacks(96, [24, 20, 16, 12])
    g.fill(2, 9, r(96), r(97), "$")
    g.put(4, r(95), "o")
    zigzag([94, 92, 90, 88], [10, A, B, C])
    # floor 2: Bookmark, moths and a Soggy
    floor(86)
    g.put(4, r(85), "k")
    g.put(7, r(85), "3")
    g.put(14, r(81), "m")
    g.put(22, r(81), "m")
    g.put(28, r(85), "s")
    # the second gear, then sacks west under the falling water
    g.put(8, r(85), "V")
    g.plank(12, 17, r(77))
    g.plank(20, 25, r(75))
    g.plank(27, 32, r(73))
    sacks(73, [23, 19, 15, 11])
    g.plank(3, 8, r(73))
    for x in (13, 21):
        g.put(x, r(66), "d")
    zigzag([71, 69, 67], [10, 18, 26])
    # floor 3: an Ink Spitter and a Soggy
    floor(65)
    g.put(6, r(64), "i")
    g.put(20, r(64), "s")
    g.put(30, r(64), "t")
    # the third gear, then sacks east
    g.put(26, r(64), "V")
    g.plank(18, 23, r(56))
    g.plank(10, 15, r(54))
    g.plank(3, 8, r(52))
    sacks(52, [11, 15, 19, 23])
    g.plank(27, 32, r(52))
    zigzag([50, 48, 46], [19, B, A])
    # floor 4: moths and Soggies, a breath before the top
    floor(44)
    g.put(6, r(43), "4")
    for x in (12, 20, 28):
        g.put(x, r(39), "m")
    g.put(16, r(43), "s")
    g.put(24, r(43), "s")
    g.put(31, r(43), "o")
    zigzag(range(42, 25, -2), [B, C, D, C, B, A, B, C, D])
    for x in (8, 16, 24):
        g.put(x, r(25), "d")
    # floor 5, the top: the Folded Crane and an Inked Soggy, then the last Bookmark
    floor(24)
    g.put(5, r(23), "5")
    g.put(14, r(23), "n")
    g.put(22, r(23), "e")
    g.put(28, r(23), "k")
    g.put(31, r(23), "6")
    g.put(32, r(23), "E")
    return g


def hayloft() -> Grid:
    """The Hayloft, 1-2's sealed back page: a gauntlet of soaked paper and awnings in the
    rafters, with no Bookmark. The reward at the far end is a heart patch and 60 Scraps."""
    g = Grid(120, 24)
    F = 18
    g.ground(0, 119, F)
    g.put(1, F - 1, "X")
    g.put(2, F - 1, "G")
    g.put(4, F - 1, "@")
    g.put(8, F - 1, "1")
    # S1 five sheets over the long drop through the loft floor: keep moving
    g.clear(16, 38)
    for x in (18, 22, 26, 30, 34):
        g.put(x, F - 1, "w")
    g.put(37, 3, "d")
    # S2 two sheets in a pit under an awning, and a Soggy on the wall above them
    g.clear(42, 49)
    g.put(44, F - 1, "w")
    g.put(47, F - 1, "w")
    g.put(45, F - 3, "B")
    g.ground(50, 60, F - 2)
    g.put(56, F - 3, "s")
    # S3 sheets over the drop again, with moths over them
    g.clear(62, 84)
    for x in (64, 68, 72, 76, 80):
        g.put(x, F - 3, "w")
    g.ground(61, 61, F - 2)
    g.ground(85, 87, F - 2)
    for x in (68, 76):
        g.put(x, F - 7, "m")
    # S4 up into the rafters, then a last run of sheets under an awning tied off below
    g.plank(89, 92, F - 4)
    g.plank(94, 96, F - 6)
    g.clear(97, 104)
    g.ground(88, 96, F)
    g.put(99, F - 7, "w")
    g.put(103, F - 7, "w")
    g.put(101, F - 10, "C")
    g.ground(105, 119, F - 6, "$")
    # the reward: a heart patch and the shepherds' tin of Scraps
    g.put(110, F - 7, "P")
    g.put(113, F - 7, "o")
    g.put(116, F - 7, "2")
    g.put(118, F - 7, "Y")
    return g


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    sodden_fields().write(os.path.join(OUT, "1_1_sodden_fields.txt"),
        "1-1 The Sodden Fields (drawn by tools/levels/build_thistledown.py; legend in\nscenes/levels/thistledown/1_1_sodden_fields.tscn)")
    the_sheepfold().write(os.path.join(OUT, "1_2_the_sheepfold.txt"),
        "1-2 The Sheepfold (drawn by tools/levels/build_thistledown.py; legend in\nscenes/levels/thistledown/1_2_the_sheepfold.tscn)")
    drowned_chapel().write(os.path.join(OUT, "1_3_drowned_chapel.txt"),
        "1-3 The Drowned Chapel, top-down (drawn by tools/levels/build_thistledown.py;\nlegend in scenes/levels/thistledown/1_3_drowned_chapel.tscn)")
    millrace().write(os.path.join(OUT, "1_4_the_millrace.txt"),
        "1-4 The Millrace (drawn by tools/levels/build_thistledown.py; legend in\nscenes/levels/thistledown/1_4_the_millrace.tscn)")
    mill_stair().write(os.path.join(OUT, "1_5_the_mill_stair.txt"),
        "1-5 The Mill Stair, vertical (drawn by tools/levels/build_thistledown.py; legend\nin scenes/levels/thistledown/1_5_the_mill_stair.tscn)")
    hayloft().write(os.path.join(OUT, "hayloft.txt"),
        "The Hayloft, 1-2's sealed back page (drawn by tools/levels/build_thistledown.py;\nlegend in scenes/levels/thistledown/hayloft.tscn)")
    print("wrote Thistledown maps")


if __name__ == "__main__":
    main()
