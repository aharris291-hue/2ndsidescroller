extends "res://tools/godot/build_chapter1.gd"
## One-time bootstrap for Chapter 2 (Lanternfold Harbor): the town, the Margin tape heist,
## the shadow theater minigame, Under the Harbor Flap, the Blotch Kraken arena, and the
## second interlude. Also points the first interlude at the new chapter.
##
## Run from the repo root (after `godot --headless --import`):
##   godot --headless --path . --script tools/godot/build_chapter2.gd
##
## Like the other builders, re-running overwrites these scenes.

const CH2 := "res://scenes/levels/ch2_lanternfold/"
const TOWN := CH2 + "lanternfold_town.tscn"
const THEATER := CH2 + "shadow_theater.tscn"
const FLAP := CH2 + "under_the_flap.tscn"
const KRAKEN_ARENA := CH2 + "kraken_arena.tscn"
const HEIST := "res://scenes/levels/margin/tape_heist.tscn"
const INTERLUDE_2 := "res://scenes/levels/interludes/interlude_02.tscn"
const INTERLUDE_1 := "res://scenes/levels/interludes/interlude_01.tscn"
const MUSIC_TOWN := "res://assets/audio/music/lanternfold_waltz.wav"
const MUSIC_DEEP := "res://assets/audio/music/ink_deep.wav"

const T_COBBLE := Vector2i(0, 2)
const T_BOARDWALK := Vector2i(1, 2)
const T_HARBOR := Vector2i(2, 2)
const T_SEABED := Vector2i(3, 2)
const T_SEABED_FILL := Vector2i(0, 3)
const T_HEDGE := Vector2i(1, 3)


func _build_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CH2))
	_build_grapple_ring()
	_build_lantern()
	_build_tape_strip()
	_build_ch2_npcs()
	_build_kraken()
	_build_town()
	_build_heist()
	_build_theater()
	_build_flap()
	_build_kraken_arena()
	_build_interlude_2()
	_update_interlude_1()
	print("Chapter 2 built." if not _failed else "Chapter 2 built WITH ERRORS.")
	quit(1 if _failed else 0)


# --- Reusable pieces ---------------------------------------------------------

func _build_grapple_ring() -> void:
	var ring := _node(Node2D, "GrappleRing", null, "res://scripts/world/grapple_point.gd") as Node2D
	_sprite(ring, "props/grapple_ring.png")
	_save_scene(ring, "res://scenes/world/grapple_ring.tscn")


func _build_tape_strip() -> void:
	# The Tape Tail pickup: a big strip of real tape (an ability pickup).
	var strip := _area(Area2D, "TapeStrip", null, "res://scripts/world/collectible.gd", 0, L_PLAYER)
	strip.set("kind", 3)
	_sprite(strip, "props/tape.png", Vector2.ZERO, 1.6)
	_shape(strip, _circle(36.0))
	_save_scene(strip, "res://scenes/pickups/tape_strip.tscn")


func _build_lantern() -> void:
	var lantern := _area(Area2D, "Lantern", null, "res://scripts/world/lantern.gd", L_INTERACTABLES, L_PLAYER)
	lantern.set("prompt_offset", Vector2(0, -200))
	_sprite(lantern, "props/lantern_off.png", Vector2(0, -88))
	_shape(lantern, _rect(Vector2(150, 120)), Vector2(0, -40))
	_save_scene(lantern, "res://scenes/world/lantern.tscn")


func _build_ch2_npcs() -> void:
	var sisters := _area(Area2D, "LamplighterSisters", null, "res://scripts/world/npc.gd", L_INTERACTABLES, L_PLAYER)
	sisters.set("dialogue_id", "lamplighters_intro")
	sisters.set("repeat_dialogue_id", "lamplighters_repeat")
	sisters.set("quest_id", "festival_lanterns")
	sisters.set("quest_progress_dialogue", "lamplighters_progress")
	sisters.set("quest_turn_in_dialogue", "lamplighters_done")
	sisters.set("prompt_offset", Vector2(0, -250))
	_sprite(sisters, "characters/lamplighter_sisters.png", Vector2(0, -106))
	_shape(sisters, _rect(Vector2(300, 140)), Vector2(0, -60))
	_save_scene(sisters, "res://scenes/world/npc_lamplighters.tscn")

	var corrugate := _area(Area2D, "Corrugate", null, "res://scripts/world/npc_corrugate.gd", L_INTERACTABLES, L_PLAYER)
	corrugate.set("quest_id", "lost_cat")
	corrugate.set("idle_bob", 2.0)
	corrugate.set("companion_scene", load("res://scenes/world/corrugate_companion.tscn"))
	corrugate.set("prompt_offset", Vector2(0, -200))
	_sprite(corrugate, "characters/corrugate.png", Vector2(0, -90), 0.8)
	_shape(corrugate, _rect(Vector2(220, 140)), Vector2(0, -60))
	_save_scene(corrugate, "res://scenes/world/npc_corrugate.tscn")

	var cat := _area(Area2D, "Crumple", null, "res://scripts/world/lost_sheep.gd", L_INTERACTABLES, L_PLAYER)
	cat.set("quest_id", "lost_cat")
	cat.set("find_prompt", "Scoop up")
	cat.set("found_caption", "Crumple gave Patch a long, withering look, then let herself be carried. Back to the dock.")
	cat.set("all_found_caption", " Corrugate will want her back.")
	cat.set("leave_offset", Vector2(0, -60))
	cat.set("prompt_offset", Vector2(0, -150))
	_sprite(cat, "characters/crumple.png", Vector2(0, -56))
	_shape(cat, _rect(Vector2(140, 120)), Vector2(0, -50))
	_save_scene(cat, "res://scenes/world/crumple.tscn")


func _build_kraken() -> void:
	var boss := _node(Node2D, "BlotchKraken", null, "res://scripts/enemies/boss_kraken.gd") as Node2D
	_sprite(boss, "characters/kraken_body.png", Vector2(0, -200)).name = "Body"
	var eye := _area(Area2D, "Eye", boss, "res://scripts/components/hurtbox.gd", 0, L_PLAYER_ATTACKS)
	eye.position = Vector2(0, -220)
	_sprite(eye, "characters/kraken_eye.png", Vector2.ZERO, 0.9)
	_shape(eye, _circle(62.0))
	var health := _node(Node, "HealthComponent", boss, "res://scripts/components/health_component.gd")
	health.set("max_health", 9)
	health.set("invulnerability_time", 0.35)
	_save_scene(boss, "res://scenes/enemies/boss_kraken.tscn")


func _ring(parent: Node, ring_name: String, position: Vector2, yank := false) -> Node2D:
	var ring := _instance("res://scenes/world/grapple_ring.tscn", ring_name, parent, position)
	if yank:
		ring.set("mode", 1)
	return ring


func _ink_sea(parent: Node, width: float, top: float) -> void:
	# The sea of ink under everything: it shows through the gaps in the floor.
	var ink := _node(ColorRect, "InkSea", parent) as ColorRect
	ink.position = Vector2(-200, top)
	ink.size = Vector2(width + 400, 1400)
	ink.color = Color("141634")
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.move_child(ink, 1)
	var surface := _sprite(parent, "props/rising_water.png", Vector2(-200, top - 34))
	surface.name = "InkSurface"
	surface.centered = false
	surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	surface.region_enabled = true
	surface.region_rect = Rect2(0, 0, width + 400, 128)
	surface.modulate = Color(0.3, 0.32, 0.6)
	parent.move_child(surface, 2)


# --- Lanternfold town (top-down) ---------------------------------------------

func _house(parent: Node, house_name: String, texture: String, position: Vector2) -> void:
	var house := _node(StaticBody2D, house_name, parent) as StaticBody2D
	house.position = position
	house.collision_layer = L_WORLD
	_sprite(house, "props/" + texture, Vector2(0, -150))
	_shape(house, _rect(Vector2(230, 80)), Vector2(0, -40))


func _build_town() -> void:
	const COLS := 60
	const ROWS := 34
	var page := _new_page("LanternfoldTown", 1, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"Lanternfold Harbor",
		"Lanternfold Harbor had been getting ready for its festival for three weeks. The damp kept cancelling it.")
	page.set("music", load(MUSIC_TOWN))
	page.y_sort_enabled = true

	var floor_layer := _node(TileMapLayer, "Streets", page) as TileMapLayer
	floor_layer.tile_set = load("res://resources/paper_tiles.tres")
	floor_layer.z_index = -1
	var walls := _node(TileMapLayer, "Walls", page) as TileMapLayer
	walls.tile_set = floor_layer.tile_set
	walls.z_index = -1
	var floor_rows := []
	var wall_rows := []
	for y in ROWS:
		var floor_row := ""
		var wall_row := ""
		for x in COLS:
			var dock := x >= 26 and x <= 31 and y >= 24 and y <= 30
			var island := x >= 38 and x <= 41 and y >= 28 and y <= 31
			var water := y >= 26 and not dock and not island
			floor_row += "B" if dock or island else ("." if not water else " ")
			var hedge := (y == 0 or x == 0 or x == COLS - 1) and not water
			# Planters and hedgerows that shape the streets.
			hedge = hedge or (y == 15 and x >= 2 and x <= 9) or (y == 15 and x >= 44 and x <= 52)
			hedge = hedge or (x == 18 and y >= 9 and y <= 12) or (x == 49 and y >= 20 and y <= 23)
			wall_row += "W" if water else ("H" if hedge else " ")
		floor_rows.append(floor_row)
		wall_rows.append(wall_row)
	_paint(floor_layer, floor_rows, {".": T_COBBLE, "B": T_BOARDWALK})
	_paint(walls, wall_rows, {"W": T_HARBOR, "H": T_HEDGE})

	_spawn_marker(page, "Start", _tile_pos(4, 3))
	_spawn_marker(page, "FromTheater", _tile_pos(12, 13.2))
	_spawn_marker(page, "FromMargin", _tile_pos(21, 23.2))
	_spawn_marker(page, "FromFlap", _tile_pos(28.5, 27))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "ArrivalTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = _tile_pos(7, 4)
	talk.set("dialogue_id", "ch2_town_arrival")
	_shape(talk, _rect(Vector2(120, 500)))
	_narrate_at(story, "FestivalHint", _tile_pos(26, 10), "Festival lanterns dot the town. The Lamplighter Sisters in the square might know what to do.")

	var buildings := _node(Node2D, "Buildings", page) as Node2D
	buildings.y_sort_enabled = true
	_house(buildings, "HouseRed", "house_red.png", _tile_pos(24, 7))
	_house(buildings, "HouseTeal", "house_teal.png", _tile_pos(34, 7))
	_house(buildings, "HouseGold", "house_gold.png", _tile_pos(44, 7))
	_house(buildings, "HouseLilac", "house_lilac.png", _tile_pos(53, 12))
	_house(buildings, "HouseTeal2", "house_teal.png", _tile_pos(22, 18))
	_house(buildings, "HouseRed2", "house_red.png", _tile_pos(40, 19))
	_house(buildings, "HouseGold2", "house_gold.png", _tile_pos(8, 22))
	var theater := _node(StaticBody2D, "Theater", buildings) as StaticBody2D
	theater.position = _tile_pos(12, 11)
	theater.collision_layer = L_WORLD
	_sprite(theater, "props/theater.png", Vector2(0, -170))
	_shape(theater, _rect(Vector2(320, 90)), Vector2(0, -45))
	var boat := _node(Node2D, "MooredBoat", buildings) as Node2D
	boat.position = _tile_pos(34, 27.5)
	_sprite(boat, "props/moored_boat.png", Vector2(0, -70))

	var props := _node(Node2D, "Props", page) as Node2D
	props.y_sort_enabled = true
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, _tile_pos(5, 6))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, _tile_pos(24, 22))
	var show := _instance("res://scenes/world/page_door.tscn", "TheaterDoor", props, _tile_pos(12, 12.4))
	show.set("target_page", THEATER)
	show.set("door_prompt", "See the shadow show")
	var margin := _instance("res://scenes/world/page_door.tscn", "MarginDoor", props, _tile_pos(21, 22))
	margin.set("target_page", HEIST)
	margin.set("target_spawn", &"FromPage")
	margin.set("door_prompt", "Step out onto Gran's table")
	margin.set("requires_flag", "met_corrugate")
	var flap := _instance("res://scenes/world/page_door.tscn", "HarborFlap", props, _tile_pos(28.5, 30))
	flap.set("target_page", FLAP)
	flap.set("target_spawn", &"Start")
	flap.set("door_prompt", "Lift the harbor flap")
	flap.set("requires_flag", "corrugate_joined")
	for spot in [Vector2(6, 9), Vector2(17, 4), Vector2(49, 4), Vector2(56, 21), Vector2(36, 24)]:
		_instance("res://scenes/world/lantern.tscn", "Lantern%d" % props.get_child_count(), props, _tile_pos(spot.x, spot.y))
	var dock_ring := _ring(props, "DockRing", _tile_pos(31.5, 28.2))
	dock_ring.set("land_offset", Vector2(-20, 40))
	var island_ring := _ring(props, "IslandRing", _tile_pos(39.5, 28.2))
	island_ring.set("land_offset", Vector2(0, 40))

	var actors := _node(Node2D, "Actors", page) as Node2D
	actors.y_sort_enabled = true
	_instance("res://scenes/world/npc_lamplighters.tscn", "LamplighterSisters", actors, _tile_pos(30, 13))
	_instance("res://scenes/world/npc_corrugate.tscn", "Corrugate", actors, _tile_pos(25, 25))
	_instance("res://scenes/world/crumple.tscn", "Crumple", actors, _tile_pos(40.5, 31))
	for spot in [Vector2(16, 8), Vector2(36, 14), Vector2(48, 17), Vector2(13, 19)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, _tile_pos(spot.x, spot.y))

	var pickups := _node(Node2D, "Pickups", page) as Node2D
	pickups.y_sort_enabled = true
	var letter_l := _instance("res://scenes/pickups/lost_letter.tscn", "LetterL", pickups, _tile_pos(38.7, 30.5))
	letter_l.set("letter", "L")
	var letter_e := _instance("res://scenes/pickups/lost_letter.tscn", "LetterE", pickups, _tile_pos(12, 8))
	letter_e.set("letter", "E")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, _tile_pos(45, 24))
	for i in 6:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, _tile_pos(28 + i * 1.2, 17))
	for i in 4:
		_instance("res://scenes/pickups/scrap.tscn", "ScrapB%d" % i, pickups, _tile_pos(52, 26 - i * 1.2))

	_instance("res://scenes/player/patch.tscn", "Patch", page, _tile_pos(4, 3))
	_save_scene(page, TOWN)


# --- The Margin heist (top-down, 3D desk) -------------------------------------

func _build_heist() -> void:
	const COLS := 44
	const ROWS := 26
	var page := _new_page("TapeHeist", 1, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"The Margin, at Night",
		"Late at night, the Great Light was low and the table was enormous. Somewhere out there was a roll of real tape.")
	page.set("in_book", false)
	page.set("music", load(MUSIC_TOWN))

	var floor_layer := _node(TileMapLayer, "Table", page) as TileMapLayer
	floor_layer.tile_set = load("res://resources/paper_tiles.tres")
	var walls := _node(TileMapLayer, "Obstacles", page) as TileMapLayer
	walls.tile_set = floor_layer.tile_set
	var floor_rows := []
	var wall_rows := []
	for y in ROWS:
		floor_rows.append(".".repeat(COLS))
		var row := ""
		for x in COLS:
			var border := x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1
			var stacks := (x >= 11 and x <= 13 and y <= 15) or (x >= 23 and x <= 25 and y >= 9) or (y >= 9 and y <= 10 and x >= 30 and x <= 41)
			row += "B" if border or stacks else " "
		wall_rows.append(row)
	_paint(floor_layer, floor_rows, {".": T_WOOD})
	var page_rows := []
	for y in 6:
		page_rows.append("PPPPPPP")
	_paint(floor_layer, page_rows, {"P": T_PAGE_FLOOR}, Vector2i(2, 2))
	_paint(walls, wall_rows, {"B": T_BOOKS})
	_paint(walls, ["II.", "III", ".II"], {"I": T_INK}, Vector2i(16, 18))
	_paint(walls, [".II", "III", "II."], {"I": T_INK}, Vector2i(30, 3))

	_spawn_marker(page, "Start", _tile_pos(5.5, 6))
	_spawn_marker(page, "FromPage", _tile_pos(5.5, 6))

	var props := _node(Node2D, "Props", page)
	var door := _instance("res://scenes/world/page_door.tscn", "BackIntoTheBook", props, _tile_pos(5.5, 4))
	door.set("target_page", TOWN)
	door.set("target_spawn", &"FromMargin")
	door.set("door_prompt", "Climb back into the book")
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, _tile_pos(8, 10))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, _tile_pos(20, 6))
	_instance("res://scenes/world/ink_puddle_hazard.tscn", "InkPuddle1", props, _tile_pos(17.5, 19.5))
	_instance("res://scenes/world/ink_puddle_hazard.tscn", "InkPuddle2", props, _tile_pos(31.5, 4.5))
	var tape_roll := _node(StaticBody2D, "GiantTapeRoll", props) as StaticBody2D
	tape_roll.position = _tile_pos(37, 18)
	tape_roll.collision_layer = L_WORLD
	_sprite(tape_roll, "props/tape.png", Vector2.ZERO, 7.0)
	_shape(tape_roll, _circle(150.0))

	var trigger := _area(Area2D, "ArrivalTalk", page, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	trigger.position = _tile_pos(8, 6)
	trigger.set("dialogue_id", "heist_arrival")
	_shape(trigger, _rect(Vector2(140, 500)))

	var actors := _node(Node2D, "Actors", page)
	for spot in [Vector2(18, 4), Vector2(18, 14), Vector2(30, 16), Vector2(36, 6)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, _tile_pos(spot.x, spot.y))

	var pickups := _node(Node2D, "Pickups", page)
	var strip := _instance("res://scenes/pickups/tape_strip.tscn", "TapeStrip", pickups, _tile_pos(33.5, 18))
	strip.set("ability_id", &"tape_tail")
	strip.set("unlock_caption", "Patch peeled off a strip of real tape and stuck it on where his tail used to be. Press {grapple} to throw the Tape Tail at brass rings!")
	var letter := _instance("res://scenes/pickups/lost_letter.tscn", "LetterA", pickups, _tile_pos(40, 4))
	letter.set("letter", "A")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, _tile_pos(28, 22))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, _tile_pos(15 + i * 1.5, 12))

	_instance("res://scenes/player/patch.tscn", "Patch", page, _tile_pos(5.5, 6))
	_node(Node, "Diorama", page, "res://scripts/world/desk_diorama.gd")
	_save_scene(page, HEIST)


# --- The shadow theater (rhythm minigame) --------------------------------------

func _build_theater() -> void:
	var show := _node(Node2D, "ShadowTheater", null, "res://scripts/minigames/shadow_theater.gd") as Node2D
	show.set("return_page", TOWN)
	show.set("music", load(MUSIC_TOWN))
	var bg := _sprite(show, "backgrounds/bg_shadow_theater.png")
	bg.name = "Background"
	bg.centered = false
	bg.show_behind_parent = true
	var ui := _node(CanvasLayer, "UI", show)
	var status := _node(Label, "Status", ui) as Label
	status.position = Vector2(40, 30)
	status.add_theme_font_size_override(&"font_size", 44)
	status.add_theme_color_override(&"font_outline_color", Color("fcf6e4"))
	status.add_theme_constant_override(&"outline_size", 10)
	var hint := _node(Label, "Hint", ui) as Label
	hint.position = Vector2(40, 960)
	hint.text = "Press the matching direction as each shadow reaches the ring."
	hint.add_theme_font_size_override(&"font_size", 34)
	hint.add_theme_color_override(&"font_color", Color("fcf6e4"))
	var big := _node(Label, "BigLabel", ui) as Label
	_full_rect(big)
	big.theme_type_variation = &"TitleLabel"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_scene(show, THEATER)


# --- Under the Harbor Flap (side view) --------------------------------------

func _build_flap() -> void:
	const COLS := 110
	var page := _new_page("UnderTheFlap", 0, Rect2(0, 0, COLS * TILE, 1088),
		"Under the Harbor Flap",
		"Under the harbor flap, the sea had turned to ink. It dripped from the paper sky and pooled in every gap.")
	page.set("music", load(MUSIC_DEEP))

	var parallax := _node(Parallax2D, "Background", page) as Parallax2D
	parallax.scroll_scale = Vector2(0.25, 0.1)
	parallax.repeat_size = Vector2(1920, 0)
	parallax.repeat_times = 4
	_sprite(parallax, "backgrounds/bg_ink_sea.png").centered = false
	_ink_sea(page, COLS * TILE, 15.4 * TILE)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var rows := []
	for y in 17:
		rows.append(".".repeat(COLS))
	var gaps := [[17, 25], [63, 73]]
	for x in COLS:
		var in_gap := false
		for gap in gaps:
			if x >= gap[0] and x < gap[1]:
				in_gap = true
		if in_gap:
			continue
		for y in [14, 15, 16]:
			var row: String = rows[y]
			rows[y] = row.substr(0, x) + ("S" if y == 14 else "F") + row.substr(x + 1)
	# The wall the flap gate seals, hanging from the top of the page.
	for y in 9:
		var row: String = rows[y]
		rows[y] = row.substr(0, 46) + "FF" + row.substr(48)
	# A high ledge with a Lost Letter, reached by zipping up.
	rows[6] = rows[6].substr(0, 56) + "SSSSS" + rows[6].substr(61)
	rows[7] = rows[7].substr(0, 56) + "FFFFF" + rows[7].substr(61)
	# A low shelf to hop over the Soggies.
	rows[11] = rows[11].substr(0, 30) + "===" + rows[11].substr(33)
	rows[11] = rows[11].substr(0, 80) + "====" + rows[11].substr(84)
	_paint(tiles, rows, {"S": T_SEABED, "F": T_SEABED_FILL, "=": T_PLANK})
	_page_edges(page, 0, COLS * TILE)

	var ground_y := 14 * TILE
	_spawn_marker(page, "Start", Vector2(3 * TILE, ground_y - 48))
	_spawn_marker(page, "FromArena", Vector2(105 * TILE, ground_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "ArrivalTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(6 * TILE, ground_y - 200)
	talk.set("dialogue_id", "flap_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	_narrate_at(story, "ZipHint", Vector2(14 * TILE, ground_y), "A gap full of ink. Jump, then press {grapple} near the brass ring to zip across!")
	_narrate_at(story, "GateHint", Vector2(41 * TILE, ground_y), "A soggy flap blocks the way, too heavy to push. That ring on it, though...")
	_narrate_at(story, "ChainHint", Vector2(60 * TILE, ground_y), "Two rings over a wide gap. Zip to the first, then throw the tape again in mid-air.")

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(2 * TILE, ground_y))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, Vector2(50 * TILE, ground_y))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark3", props, Vector2(76 * TILE, ground_y))
	_ring(props, "GapRing", Vector2(21 * TILE, 9 * TILE))
	var gate := _node(AnimatableBody2D, "FlapGate", props) as AnimatableBody2D
	gate.position = Vector2(47 * TILE, 9 * TILE + 160)
	gate.collision_layer = L_WORLD
	gate.collision_mask = 0
	gate.sync_to_physics = true
	_sprite(gate, "props/flap_gate.png")
	_shape(gate, _rect(Vector2(128, 320)))
	var gate_ring := _ring(props, "GateRing", Vector2(45.6 * TILE, 10 * TILE), true)
	gate_ring.set("target", gate)
	gate_ring.set("move_offset", Vector2(0, -330))
	_ring(props, "LedgeRing", Vector2(55 * TILE, 4.5 * TILE))
	_ring(props, "WideRing1", Vector2(66 * TILE, 9 * TILE))
	_ring(props, "WideRing2", Vector2(70.5 * TILE, 9 * TILE))
	var exit := _instance("res://scenes/world/page_door.tscn", "ToTheKraken", props, Vector2(107 * TILE, ground_y))
	exit.set("target_page", KRAKEN_ARENA)
	exit.set("target_spawn", &"Start")
	exit.set("door_prompt", "Swim toward the eye")
	var back := _instance("res://scenes/world/page_door.tscn", "BackUp", props, Vector2(1 * TILE, ground_y))
	back.set("target_page", TOWN)
	back.set("target_spawn", &"FromFlap")
	back.set("door_prompt", "Climb back up to the harbor")

	var hazards := _node(Node2D, "Hazards", page)
	for spot in [Vector2(27, 13), Vector2(77, 13)]:
		var spawner := _node(Node2D, "Drips%d" % hazards.get_child_count(), hazards, "res://scripts/world/drip_spawner.gd") as Node2D
		spawner.position = Vector2(spot.x * TILE, 0)
		spawner.set("width", spot.y * TILE)
		spawner.set("floor_y", float(ground_y))

	var actors := _node(Node2D, "Actors", page)
	for spot in [Vector2(30, 14), Vector2(37, 14), Vector2(53, 14), Vector2(81, 14), Vector2(88, 14), Vector2(96, 14)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, Vector2(spot.x * TILE, spot.y * TILE - 40))

	var pickups := _node(Node2D, "Pickups", page)
	var letter := _instance("res://scenes/pickups/lost_letter.tscn", "LetterN", pickups, Vector2(59.5 * TILE, 6 * TILE - 60))
	letter.set("letter", "N")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, Vector2(89 * TILE, ground_y - 60))
	_instance("res://scenes/pickups/tape.tscn", "Tape2", pickups, Vector2(48.5 * TILE, ground_y - 60))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "GapScrap%d" % i, pickups, Vector2((19 + i * 1.5) * TILE, 11 * TILE))
	for i in 6:
		_instance("res://scenes/pickups/scrap.tscn", "WideScrap%d" % i, pickups, Vector2((64 + i * 1.5) * TILE, 11 * TILE))
	for i in 4:
		_instance("res://scenes/pickups/scrap.tscn", "LedgeScrap%d" % i, pickups, Vector2((56.5 + i) * TILE, 6 * TILE - 50))

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(3 * TILE, ground_y - 48))
	_save_scene(page, FLAP)


# --- The Blotch Kraken arena ---------------------------------------------------

func _build_kraken_arena() -> void:
	const COLS := 30
	var page := _new_page("KrakenArena", 0, Rect2(0, 0, COLS * TILE, 1088), "The Ink Deep", "")
	page.set("music", load(MUSIC_DEEP))

	var parallax := _node(Parallax2D, "Background", page) as Parallax2D
	parallax.scroll_scale = Vector2(0.25, 0.1)
	_sprite(parallax, "backgrounds/bg_ink_sea.png").centered = false
	_ink_sea(page, COLS * TILE, 15.4 * TILE)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var rows := []
	for y in 17:
		rows.append(".".repeat(COLS))
	rows[10] = "...." + "====" + "......" + "====" + ".".repeat(12)
	for y in [14, 15, 16]:
		rows[y] = ("S" if y == 14 else "F").repeat(24) + ".".repeat(COLS - 24)
	_paint(tiles, rows, {"S": T_SEABED, "F": T_SEABED_FILL, "=": T_PLANK})
	_page_edges(page, 0, 23.5 * TILE)

	var ground_y := 14 * TILE
	_spawn_marker(page, "Start", Vector2(2 * TILE, ground_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "KrakenTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(4 * TILE, ground_y - 200)
	talk.set("dialogue_id", "kraken_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	var start_zone := _area(Area2D, "FightStart", story, "", 0, L_PLAYER)
	start_zone.position = Vector2(8 * TILE, ground_y - 200)
	_shape(start_zone, _rect(Vector2(120, 600)))

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(1 * TILE + 16, ground_y))
	var ring_a := _ring(props, "BlotterRing1", Vector2(6 * TILE, 4.5 * TILE), true)
	var ring_b := _ring(props, "BlotterRing2", Vector2(16 * TILE, 4.5 * TILE), true)
	var blotters: Array[Node2D] = []
	for i in 2:
		var blotter := _node(Node2D, "Blotter%d" % (i + 1), props) as Node2D
		blotter.position = Vector2((21.5 + i * 4.5) * TILE, 20)
		_sprite(blotter, "props/blotter.png")
		blotters.append(blotter)
	var exit := _instance("res://scenes/world/page_door.tscn", "ToGransTable", props, Vector2(21 * TILE, ground_y))
	exit.set("target_page", INTERLUDE_2)
	exit.set("door_prompt", "Close Chapter 2")

	var boss := _instance("res://scenes/enemies/boss_kraken.tscn", "BlotchKraken", page, Vector2(26 * TILE, ground_y))
	var rings: Array[Node] = [ring_a, ring_b]
	boss.set("rings", rings)
	boss.set("blotters", blotters)
	boss.set("exit_door", exit)
	boss.set("start_zone", start_zone)
	boss.set("floor_y", float(ground_y))
	boss.set("arena_left", 2.0 * TILE)
	boss.set("arena_right", 22.5 * TILE)
	# Blotters hang in front of the Kraken.
	page.move_child(boss, props.get_index())

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(2 * TILE, ground_y - 48))
	_save_scene(page, KRAKEN_ARENA)


# --- Interludes --------------------------------------------------------------

func _build_interlude_2() -> void:
	var page := _cutscene("Interlude02", "bg_dad_table_late.png", "Later that night, at Gran's kitchen table...", "interlude_2", "")
	page.set("sets_flag", "chapter2_complete")
	page.set("save_on_finish", true)
	_save_scene(page, INTERLUDE_2)


func _update_interlude_1() -> void:
	var page := _edit_scene(INTERLUDE_1)
	page.set("next_page", TOWN)
	_save_scene(page, INTERLUDE_1)
