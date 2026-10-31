extends "res://tools/godot/build_chapter2.gd"
## One-time bootstrap for Chapter 3 (The Spine Peaks): Frostfold Slopes, the same page
## laid flat, the paperclip heist in the Margin, the climb up the book's spine, the Sogg
## arena, and the third interlude. Also adds the winter tiles to the tileset and points
## the second interlude at the new chapter.
##
## Run from the repo root (after `godot --headless --import`):
##   godot --headless --path . --script tools/godot/build_chapter3.gd
##
## Like the other builders, re-running overwrites these scenes.

const CH3 := "res://scenes/levels/ch3_spine/"
const SLOPES := CH3 + "frostfold_slopes.tscn"
const FLAT := CH3 + "frostfold_flat.tscn"
const SPINE := CH3 + "the_spine.tscn"
const SOGG_ARENA := CH3 + "sogg_arena.tscn"
const CLIP_HEIST := "res://scenes/levels/margin/paperclip_heist.tscn"
const INTERLUDE_3 := "res://scenes/levels/interludes/interlude_03.tscn"
const MUSIC_SPINE := "res://assets/audio/music/spine_peaks.wav"

const T_SNOW_TOP := Vector2i(2, 3)
const T_SNOW_FILL := Vector2i(3, 3)
const T_THREAD := Vector2i(0, 4)
const T_ICE := Vector2i(1, 4)
const T_SNOWFIELD := Vector2i(2, 4)
const T_DRIFT := Vector2i(3, 4)

const SNOW_LEGEND := {"G": T_SNOW_TOP, "#": T_SNOW_FILL, "=": T_THREAD, "I": T_ICE}


func _build_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CH3))
	_add_winter_tiles()
	_build_fold_mark()
	_build_ice_block()
	_build_piton()
	_build_ch3_pickups()
	_build_ch3_npcs()
	_build_sogg()
	_build_slopes()
	_build_flat()
	_build_clip_heist()
	_build_spine()
	_build_sogg_arena()
	_build_interlude_3()
	_update_interlude_2()
	print("Chapter 3 built." if not _failed else "Chapter 3 built WITH ERRORS.")
	quit(1 if _failed else 0)


# --- Tiles and reusable pieces -------------------------------------------------

func _add_winter_tiles() -> void:
	var tileset := load("res://resources/paper_tiles.tres") as TileSet
	var source := tileset.get_source(0) as TileSetAtlasSource
	var h := TILE / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for coords in [T_SNOW_TOP, T_SNOW_FILL, T_THREAD, T_ICE, T_SNOWFIELD, T_DRIFT]:
		if not source.has_tile(coords):
			source.create_tile(coords)
	for coords in [T_SNOW_TOP, T_SNOW_FILL, T_ICE, T_DRIFT]:
		var data := source.get_tile_data(coords, 0)
		if data.get_collision_polygons_count(0) == 0:
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, full)
	# Thread bridges: like planks, Patch can jump up through them.
	var thread := source.get_tile_data(T_THREAD, 0)
	if thread.get_collision_polygons_count(0) == 0:
		thread.add_collision_polygon(0)
		thread.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h + 4), Vector2(h, -h + 4), Vector2(h, -h + 22), Vector2(-h, -h + 22)]))
		thread.set_collision_polygon_one_way(0, 0, true)
	_save_resource(tileset, "res://resources/paper_tiles.tres")


func _build_fold_mark() -> void:
	var mark := _node(Node2D, "FoldMark", null, "res://scripts/world/fold_mark.gd") as Node2D
	var peak := _node(AnimatableBody2D, "Peak", mark) as AnimatableBody2D
	peak.collision_layer = L_WORLD
	peak.collision_mask = 0
	peak.sync_to_physics = true
	var art := _sprite(peak, "props/popup_peak.png", Vector2.ZERO, 0.8)
	art.centered = false
	art.offset = Vector2(-120, 0)
	art.region_enabled = true
	art.region_rect = Rect2(0, 0, 240, 0)
	_shape(peak, _rect(Vector2(132, 256)), Vector2(0, 128))
	var line := _sprite(mark, "props/fold_mark.png", Vector2(0, -16))
	line.name = "Mark"
	line.z_index = 1
	_save_scene(mark, "res://scenes/world/fold_mark.tscn")


func _build_ice_block() -> void:
	var block := _node(StaticBody2D, "IceBlock", null, "res://scripts/world/slam_breakable.gd") as StaticBody2D
	block.collision_layer = L_WORLD
	var art := _sprite(block, "tiles/paper_tiles.png", Vector2.ZERO, 2.0)
	art.region_enabled = true
	art.region_rect = Rect2(T_ICE.x * TILE, T_ICE.y * TILE, TILE, TILE)
	_shape(block, _rect(Vector2(128, 128)))
	_save_scene(block, "res://scenes/world/ice_block.tscn")


func _build_piton() -> void:
	var piton := _node(Node2D, "Piton", null, "res://scripts/world/grapple_point.gd") as Node2D
	_sprite(piton, "props/piton.png")
	_save_scene(piton, "res://scenes/world/piton.tscn")


func _build_ch3_pickups() -> void:
	var clip := _area(Area2D, "Paperclip", null, "res://scripts/world/collectible.gd", 0, L_PLAYER)
	clip.set("kind", 4)
	clip.set("flag", "has_paperclip")
	clip.set("unlock_caption", "A real steel paperclip, as long as Patch. Bindwell can bend this into pitons.")
	_sprite(clip, "props/paperclip.png")
	_shape(clip, _circle(70.0))
	_save_scene(clip, "res://scenes/pickups/paperclip.tscn")

	var spool := _area(Area2D, "Spool", null, "res://scripts/world/lost_sheep.gd", L_INTERACTABLES, L_PLAYER)
	spool.set("quest_id", "restring_spine")
	spool.set("find_prompt", "Pick up")
	spool.set("found_caption", "A spool of Bindwell's bookbinding thread, a bit frozen but still good.")
	spool.set("all_found_caption", " That's all three. Bindwell is waiting near the top.")
	spool.set("leave_offset", Vector2(0, -50))
	spool.set("prompt_offset", Vector2(0, -110))
	_sprite(spool, "props/spool.png", Vector2(0, -40), 0.8)
	_shape(spool, _rect(Vector2(110, 100)), Vector2(0, -40))
	_save_scene(spool, "res://scenes/world/spool.tscn")


func _build_ch3_npcs() -> void:
	var bindwell := _area(Area2D, "Bindwell", null, "res://scripts/world/npc.gd", L_INTERACTABLES, L_PLAYER)
	bindwell.set("dialogue_id", "bindwell_intro")
	bindwell.set("first_talk_flag", "met_bindwell")
	bindwell.set("repeat_dialogue_id", "bindwell_repeat")
	bindwell.set("quest_id", "restring_spine")
	bindwell.set("quest_progress_dialogue", "bindwell_progress")
	bindwell.set("quest_turn_in_dialogue", "bindwell_done")
	bindwell.set("idle_bob", 3.0)
	bindwell.set("prompt_offset", Vector2(0, -250))
	_sprite(bindwell, "characters/bindwell.png", Vector2(0, -105), 0.5)
	_shape(bindwell, _rect(Vector2(180, 140)), Vector2(0, -60))
	_save_scene(bindwell, "res://scenes/world/npc_bindwell.tscn")


func _build_sogg() -> void:
	var boss := _node(Node2D, "TheSogg", null, "res://scripts/enemies/boss_sogg.gd") as Node2D
	_sprite(boss, "characters/sogg_body.png", Vector2(0, -196), 0.7).name = "Body"
	var heart := _area(Area2D, "Heart", boss, "res://scripts/components/hurtbox.gd", 0, L_PLAYER_ATTACKS)
	heart.position = Vector2(0, -200)
	heart.z_index = 1
	_sprite(heart, "characters/drizzle_heart.png", Vector2.ZERO, 0.8)
	_shape(heart, _circle(64.0))
	var contact := _area(Area2D, "ContactHitbox", boss, "res://scripts/components/hitbox.gd", L_ENEMY_ATTACKS, 0)
	contact.monitoring = false
	contact.set("damage", 2)
	contact.set("knockback", 760.0)
	_shape(contact, _rect(Vector2(380, 220)), Vector2(0, -110))
	var health := _node(Node, "HealthComponent", boss, "res://scripts/components/health_component.gd")
	health.set("max_health", 10)
	health.set("invulnerability_time", 0.35)
	_save_scene(boss, "res://scenes/enemies/boss_sogg.tscn")


func _snow_background(page: Node, texture: String, height_rows: int) -> void:
	var parallax := _node(Parallax2D, "Background", page) as Parallax2D
	parallax.scroll_scale = Vector2(0.25, 0.1)
	parallax.repeat_size = Vector2(1920, 0)
	parallax.repeat_times = 3
	var art := _sprite(parallax, "backgrounds/" + texture)
	art.centered = false
	# Tall pages: stretch the picture so it covers the whole climb with its slow scroll.
	var needed := 1088.0 + (height_rows * TILE - 1088.0) * 0.1 + 40.0
	if needed > 1080.0:
		art.scale = Vector2(needed / 1080.0, needed / 1080.0)
		parallax.repeat_size = Vector2(1920 * art.scale.x, 0)


func _grid(cols: int, rows: int) -> Array:
	var grid := []
	for y in rows:
		grid.append(".".repeat(cols))
	return grid


## Writes `text` (repeated to `length`) into row y of a grid of strings, from column x.
func _put(grid: Array, x: int, y: int, ch: String, length := 1) -> void:
	var row: String = grid[y]
	grid[y] = row.substr(0, x) + ch.repeat(length) + row.substr(x + length)


## A snowy ledge: a snow top row and `depth` rows of frozen rock under it.
func _ledge(grid: Array, x: int, y: int, length: int, depth := 1) -> void:
	_put(grid, x, y, "G", length)
	for d in depth:
		if y + 1 + d < grid.size():
			_put(grid, x, y + 1 + d, "#", length)


func _fold(parent: Node, fold_name: String, col: float, row: float, rise := 256.0, stay := 0.0) -> Node2D:
	var mark := _instance("res://scenes/world/fold_mark.tscn", fold_name, parent, _tile_pos(col, row))
	mark.set("rise_height", rise)
	mark.set("stay_up_time", stay)
	return mark


func _piton(parent: Node, piton_name: String, position: Vector2, land := Vector2(0, -30)) -> Node2D:
	var piton := _instance("res://scenes/world/piton.tscn", piton_name, parent, position)
	piton.set("land_offset", land)
	return piton


# --- Frostfold Slopes (side view) ----------------------------------------------

func _build_slopes() -> void:
	const COLS := 64
	const ROWS := 34
	var page := _new_page("FrostfoldSlopes", 0, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"Frostfold",
		"Winter had always been Nell's favourite page. Now the snow was grey at the edges, and the mountains sagged.")
	page.set("music", load(MUSIC_SPINE))
	_snow_background(page, "bg_frostfold.png", ROWS)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var g := _grid(COLS, ROWS)
	# The valley floor.
	_ledge(g, 0, 30, 41, 3)
	# First shelf, reached by springing fold mark A, walled off by ice.
	_ledge(g, 18, 26, 18, 1)
	# Upper shelf, reached by fold mark B.
	_ledge(g, 35, 22, 12, 2)
	# The sheer cliff: a wall of frozen rock from the top of the page to the upper shelf.
	for y in range(0, 25):
		_put(g, 47, y, "#", 3)
	_put(g, 47, 0, "G", 3)
	# Beyond the cliff (reached by laying the page flat): a ledge and a thread-bridge climb.
	_ledge(g, 50, 22, 14, 2)
	_put(g, 56, 18, "=", 8)
	_put(g, 50, 16, "=", 6)
	_put(g, 56, 14, "=", 8)
	# A low alcove with a Lost Letter behind ice, at the far end of the valley.
	_ledge(g, 41, 30, 9, 3)
	for y in range(25, 28):
		_put(g, 43, y, "#", 7)
	for y in range(23, ROWS):
		_put(g, 50, y, "#", 14)
	_paint(tiles, g, SNOW_LEGEND)
	_page_edges(page, 0, COLS * TILE)

	var floor_y := 30 * TILE
	_spawn_marker(page, "Start", Vector2(3 * TILE, floor_y - 48))
	_spawn_marker(page, "FromFlatBack", Vector2(44 * TILE, 22 * TILE - 48))
	_spawn_marker(page, "FromFlat", Vector2(52 * TILE, 22 * TILE - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "ArrivalTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(6 * TILE, floor_y - 200)
	talk.set("dialogue_id", "frostfold_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	_narrate_at(story, "FoldHint", Vector2(14 * TILE, floor_y), "A dashed fold line, printed in the snow. Stand on it and Pop-Up Slam with {slam}!")
	_narrate_at(story, "IceHint", Vector2(24 * TILE, 26 * TILE), "A wall of ice paper. A swipe won't scratch it. A slam might.")
	_narrate_at(story, "CliffHint", Vector2(42 * TILE, 22 * TILE), "A cliff as sheer as a page edge. Too high to climb. From above, though, it would only be a line.")

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(2 * TILE, floor_y))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, Vector2(37 * TILE, 22 * TILE))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark3", props, Vector2(51 * TILE, 22 * TILE))
	_fold(props, "FoldA", 16, 30)
	_fold(props, "FoldB", 33, 26)
	_fold(props, "FoldC", 54, 22, 256.0)
	for y in [23, 25]:
		_instance("res://scenes/world/ice_block.tscn", "IceWall%d" % y, props, _tile_pos(28, y))
	_instance("res://scenes/world/ice_block.tscn", "AlcoveIce", props, _tile_pos(46, 29))
	var flip := _instance("res://scenes/world/page_door.tscn", "LayPageFlat", props, Vector2(45 * TILE, 22 * TILE))
	flip.set("target_page", FLAT)
	flip.set("target_spawn", &"FromSlopes")
	flip.set("door_prompt", "Lay the page flat")
	var exit := _instance("res://scenes/world/page_door.tscn", "ToTheSpine", props, Vector2(62 * TILE, 14 * TILE))
	exit.set("target_page", SPINE)
	exit.set("target_spawn", &"Start")
	exit.set("door_prompt", "Climb toward the spine")

	var actors := _node(Node2D, "Actors", page)
	for spot in [Vector2(24, 30), Vector2(34, 30), Vector2(23, 26), Vector2(41, 22), Vector2(59, 22)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, Vector2(spot.x * TILE, spot.y * TILE - 40))

	var pickups := _node(Node2D, "Pickups", page)
	var slam := _instance("res://scenes/pickups/ability_page.tscn", "PopUpSlamPage", pickups, Vector2(10 * TILE, floor_y - 70))
	slam.set("ability_id", &"pop_up_slam")
	slam.set("unlock_caption", "A page folded into a perfect pop-up! Patch stamped on it to see what it would do, and a hill sprang up under his feet. Press {slam} (or attack while holding down in mid-air) to Pop-Up Slam: it springs fold marks, cracks ice and flattens Soggies.")
	var letter_s := _instance("res://scenes/pickups/lost_letter.tscn", "LetterS", pickups, Vector2(48 * TILE, floor_y - 60))
	letter_s.set("letter", "S")
	var letter_p := _instance("res://scenes/pickups/lost_letter.tscn", "LetterP", pickups, Vector2(51 * TILE, 16 * TILE - 60))
	letter_p.set("letter", "P")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, Vector2(30 * TILE, 26 * TILE - 60))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, Vector2(16 * TILE, (25.5 - i) * TILE))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "BridgeScrap%d" % i, pickups, Vector2((57 + i * 1.4) * TILE, 18 * TILE - 50))

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(3 * TILE, floor_y - 48))
	_save_scene(page, SLOPES)


# --- Frostfold, laid flat (top-down) ---------------------------------------------

func _build_flat() -> void:
	const COLS := 44
	const ROWS := 26
	var page := _new_page("FrostfoldFlat", 1, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"Frostfold, Laid Flat",
		"Patch laid the page down flat, and the mountains folded away into lines on a snowfield.")
	page.set("music", load(MUSIC_SPINE))
	page.y_sort_enabled = true

	var floor_layer := _node(TileMapLayer, "Snowfield", page) as TileMapLayer
	floor_layer.tile_set = load("res://resources/paper_tiles.tres")
	floor_layer.z_index = -1
	var walls := _node(TileMapLayer, "Drifts", page) as TileMapLayer
	walls.tile_set = floor_layer.tile_set
	walls.z_index = -1
	var floor_rows := []
	var wall_rows := []
	for y in ROWS:
		floor_rows.append(".".repeat(COLS))
		var row := ""
		for x in COLS:
			var border := x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1
			# The cliff, seen from above: a long drift line, with a gap at the south end
			# that ice has sealed.
			var cliff := x >= 20 and x <= 21 and y <= 18
			var pond := x >= 8 and x <= 13 and y >= 15 and y <= 19
			var copse := (x >= 28 and x <= 31 and y >= 3 and y <= 5) or (x >= 34 and x <= 38 and y >= 18 and y <= 20)
			row += "I" if pond else ("D" if border or cliff or copse else " ")
		wall_rows.append(row)
	_paint(floor_layer, floor_rows, {".": T_SNOWFIELD})
	_paint(walls, wall_rows, {"D": T_DRIFT, "I": T_ICE})
	# The spine's edge along the right side of the page: a row of thread stitches.
	var stitch_rows := []
	for y in ROWS - 2:
		stitch_rows.append("=")
	_paint(floor_layer, stitch_rows, {"=": T_THREAD}, Vector2i(COLS - 2, 1))

	_spawn_marker(page, "Start", _tile_pos(4, 6))
	_spawn_marker(page, "FromSlopes", _tile_pos(4, 6))
	_spawn_marker(page, "FromMargin", _tile_pos(37, 11))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "ArrivalTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = _tile_pos(7, 6)
	talk.set("dialogue_id", "flat_arrival")
	_shape(talk, _rect(Vector2(120, 500)))
	_narrate_at(story, "IceGapHint", _tile_pos(17, 21), "Ice has sealed the way round the cliff. Slam it with {slam}.")

	var props := _node(Node2D, "Props", page) as Node2D
	props.y_sort_enabled = true
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, _tile_pos(5, 9))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, _tile_pos(26, 12))
	for y in [19.5, 21.5, 23.5]:
		_instance("res://scenes/world/ice_block.tscn", "GapIce%d" % int(y * 2), props, _tile_pos(21, y))
	var back := _instance("res://scenes/world/page_door.tscn", "StandBackUp", props, _tile_pos(2.5, 4))
	back.set("target_page", SLOPES)
	back.set("target_spawn", &"FromFlatBack")
	back.set("door_prompt", "Stand the page back up")
	var margin := _instance("res://scenes/world/page_door.tscn", "MarginDoor", props, _tile_pos(39, 13))
	margin.set("target_page", CLIP_HEIST)
	margin.set("target_spawn", &"FromPage")
	margin.set("door_prompt", "Step out onto Gran's table")
	margin.set("requires_flag", "met_bindwell")
	var stand := _instance("res://scenes/world/page_door.tscn", "StandUpBeyond", props, _tile_pos(33, 22.5))
	stand.set("target_page", SLOPES)
	stand.set("target_spawn", &"FromFlat")
	stand.set("door_prompt", "Stand the page up here")
	stand.set("requires_flag", "has_paperclip")

	var actors := _node(Node2D, "Actors", page) as Node2D
	actors.y_sort_enabled = true
	_instance("res://scenes/world/npc_bindwell.tscn", "Bindwell", actors, _tile_pos(37, 8))
	for spot in [Vector2(14, 6), Vector2(16, 12), Vector2(28, 16), Vector2(30, 9)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, _tile_pos(spot.x, spot.y))

	var pickups := _node(Node2D, "Pickups", page) as Node2D
	pickups.y_sort_enabled = true
	var letter := _instance("res://scenes/pickups/lost_letter.tscn", "LetterI", pickups, _tile_pos(10.5, 22))
	letter.set("letter", "I")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, _tile_pos(25, 4))
	for i in 6:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, _tile_pos(24 + i * 1.3, 22.5))

	_instance("res://scenes/player/patch.tscn", "Patch", page, _tile_pos(4, 6))
	_save_scene(page, FLAT)


# --- The Margin: the paperclip heist (top-down, 3D desk) ------------------------

func _build_clip_heist() -> void:
	const COLS := 42
	const ROWS := 26
	var page := _new_page("PaperclipHeist", 1, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"The Margin, Very Late",
		"Very late now. The Great Light hummed. Out on the table lay a pot of paperclips, and the hairdryer, unplugged.")
	page.set("in_book", false)
	page.set("music", load(MUSIC_SPINE))

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
			var stacks := (x >= 14 and x <= 16 and y >= 6) or (y >= 6 and y <= 7 and x >= 22 and x <= 34) or (x >= 26 and x <= 28 and y >= 15)
			row += "B" if border or stacks else " "
		wall_rows.append(row)
	_paint(floor_layer, floor_rows, {".": T_WOOD})
	var page_rows := []
	for y in 6:
		page_rows.append("PPPPPPP")
	_paint(floor_layer, page_rows, {"P": T_PAGE_FLOOR}, Vector2i(2, 2))
	_paint(walls, wall_rows, {"B": T_BOOKS})
	_paint(walls, ["III", ".II"], {"I": T_INK}, Vector2i(19, 14))
	_paint(walls, ["II.", "III"], {"I": T_INK}, Vector2i(35, 3))

	_spawn_marker(page, "Start", _tile_pos(5.5, 6))
	_spawn_marker(page, "FromPage", _tile_pos(5.5, 6))

	var props := _node(Node2D, "Props", page)
	var door := _instance("res://scenes/world/page_door.tscn", "BackIntoTheBook", props, _tile_pos(5.5, 4))
	door.set("target_page", FLAT)
	door.set("target_spawn", &"FromMargin")
	door.set("door_prompt", "Climb back into the book")
	door.set("requires_flag", "has_paperclip")
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, _tile_pos(9, 10))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, _tile_pos(20, 3))
	_instance("res://scenes/world/ink_puddle_hazard.tscn", "InkPuddle1", props, _tile_pos(20.5, 15))
	_instance("res://scenes/world/ink_puddle_hazard.tscn", "InkPuddle2", props, _tile_pos(36.5, 4))
	# The hairdryer plug, lying out on the table. Yank its ring to haul it over by the book.
	var plug := _node(Node2D, "HairdryerPlug", props) as Node2D
	plug.position = _tile_pos(23, 20)
	_sprite(plug, "props/plug.png", Vector2.ZERO, 1.6)
	var plug_ring := _ring(props, "PlugRing", _tile_pos(21.5, 19.2), true)
	plug_ring.set("target", plug)
	plug_ring.set("move_offset", Vector2(-13 * TILE, -11 * TILE))
	plug_ring.set("duration", 1.2)
	plug_ring.set("sets_flag", "plug_moved")
	plug_ring.set("yank_caption", "Patch hauled the hairdryer's plug across the table until it lay right beside the book. Dot looked very pleased about something.")

	var trigger := _area(Area2D, "ArrivalTalk", page, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	trigger.position = _tile_pos(8, 6)
	trigger.set("dialogue_id", "clip_heist_arrival")
	_shape(trigger, _rect(Vector2(140, 500)))

	var actors := _node(Node2D, "Actors", page)
	for spot in [Vector2(19, 4), Vector2(20, 11), Vector2(31, 11), Vector2(35, 20), Vector2(10, 18)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, _tile_pos(spot.x, spot.y))

	var pickups := _node(Node2D, "Pickups", page)
	_instance("res://scenes/pickups/paperclip.tscn", "Paperclip", pickups, _tile_pos(37, 12))
	var letter := _instance("res://scenes/pickups/lost_letter.tscn", "LetterC", pickups, _tile_pos(38, 23))
	letter.set("letter", "C")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, _tile_pos(10, 21))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, _tile_pos(29 + i * 1.5, 10))

	_instance("res://scenes/player/patch.tscn", "Patch", page, _tile_pos(5.5, 6))
	_node(Node, "Diorama", page, "res://scripts/world/desk_diorama.gd")
	_save_scene(page, CLIP_HEIST)


# --- The Spine (side view, a tall climb) ------------------------------------------

func _build_spine() -> void:
	const COLS := 40
	const ROWS := 50
	var page := _new_page("TheSpine", 0, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"The Spine",
		"Above Frostfold rose the spine of the book itself: page bundles stacked like cliffs, and holding them together, thread.")
	page.set("music", load(MUSIC_SPINE))
	_snow_background(page, "bg_spine.png", ROWS)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var g := _grid(COLS, ROWS)
	# Bottom: the foot of the spine, and a stair of thread bridges up to the right.
	_ledge(g, 0, 47, COLS, 2)
	_put(g, 10, 45, "=", 6)
	_put(g, 17, 43, "=", 6)
	_put(g, 24, 41, "=", 6)
	_ledge(g, 30, 39, 10, 1)
	# A big shelf on the left, reached with the Tape Tail from a piton.
	_ledge(g, 0, 33, 27, 3)
	# A thread bridge across the middle, reached by springing a peak from the shelf.
	_put(g, 10, 29, "=", 11)
	# The long ledge on the right with the drip zone, and an ice-sealed nook.
	_ledge(g, 22, 25, 18, 4)
	# Thread bridges zig-zagging back left to the upper shelf.
	_put(g, 12, 21, "=", 17)
	_put(g, 12, 19, "=", 5)
	_ledge(g, 0, 17, 12, 1)
	# The top: the campfire ledge on the right, across a gap of nothing.
	_ledge(g, 24, 13, 16, 1)
	_paint(tiles, g, SNOW_LEGEND)
	_page_edges(page, 0, COLS * TILE)

	var floor_y := 47 * TILE
	_spawn_marker(page, "Start", Vector2(3 * TILE, floor_y - 48))
	_spawn_marker(page, "FromArena", Vector2(36 * TILE, 13 * TILE - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "ArrivalTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(6 * TILE, floor_y - 200)
	talk.set("dialogue_id", "spine_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	_narrate_at(story, "PitonHint", Vector2(33 * TILE, 39 * TILE), "Bindwell's pitons: bent paperclips pushed into the spine. Throw the Tape Tail at one with {grapple}.")
	_narrate_at(story, "ChainHint", Vector2(9 * TILE, 17 * TILE), "Two pitons over the gap. Zip to the first, then throw the tape again in mid-air.")
	var low := _area(Area2D, "LowPoint", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	low.position = Vector2(28 * TILE, 13 * TILE - 200)
	low.set("dialogue_id", "spine_lowpoint")
	low.set("once_flag", "patch_told_truth")
	_shape(low, _rect(Vector2(120, 500)))

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(2 * TILE, floor_y))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, Vector2(2 * TILE, 33 * TILE))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark3", props, Vector2(24 * TILE, 25 * TILE))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark4", props, Vector2(26 * TILE, 13 * TILE))
	_piton(props, "ShelfPiton", Vector2(27.5 * TILE, 31.5 * TILE), Vector2(-80, -40))
	_fold(props, "ShelfFold", 8, 33)
	_piton(props, "LedgePiton", Vector2(22.5 * TILE, 23 * TILE), Vector2(20, -30))
	_fold(props, "LedgeFold", 30, 25)
	_piton(props, "GapPiton1", Vector2(16 * TILE, 13 * TILE), Vector2(0, 40))
	_piton(props, "GapPiton2", Vector2(24.5 * TILE, 11.5 * TILE), Vector2(40, -10))
	for y in [22, 24]:
		_instance("res://scenes/world/ice_block.tscn", "NookIce%d" % y, props, _tile_pos(35, y))
	var fire := _node(Node2D, "Campfire", props) as Node2D
	fire.position = Vector2(31 * TILE, 13 * TILE)
	_sprite(fire, "props/campfire.png", Vector2(0, -60))
	var exit := _instance("res://scenes/world/page_door.tscn", "ToTheSummit", props, Vector2(38 * TILE, 13 * TILE))
	exit.set("target_page", SOGG_ARENA)
	exit.set("target_spawn", &"Start")
	exit.set("door_prompt", "Climb to the summit")
	exit.set("requires_flag", "patch_told_truth")

	var hazards := _node(Node2D, "Hazards", page)
	var drips := _node(Node2D, "Meltwater", hazards, "res://scripts/world/drip_spawner.gd") as Node2D
	drips.position = Vector2(25 * TILE, 15 * TILE)
	drips.set("width", 12.0 * TILE)
	drips.set("floor_y", 25.0 * TILE)

	var actors := _node(Node2D, "Actors", page)
	_instance("res://scenes/world/npc_bindwell.tscn", "Bindwell", actors, Vector2(34 * TILE, 13 * TILE))
	for spot in [Vector2(20, 47), Vector2(34, 39), Vector2(14, 33), Vector2(21, 33), Vector2(27, 25), Vector2(16, 21)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, Vector2(spot.x * TILE, spot.y * TILE - 40))
	_instance("res://scenes/world/spool.tscn", "Spool1", actors, Vector2(28 * TILE, 41 * TILE))
	_instance("res://scenes/world/spool.tscn", "Spool2", actors, Vector2(3 * TILE, 33 * TILE))
	_instance("res://scenes/world/spool.tscn", "Spool3", actors, Vector2(38 * TILE, 25 * TILE))

	var pickups := _node(Node2D, "Pickups", page)
	var letter_t := _instance("res://scenes/pickups/lost_letter.tscn", "LetterB", pickups, Vector2(2 * TILE, 17 * TILE - 60))
	letter_t.set("letter", "B")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, Vector2(36 * TILE, 39 * TILE - 60))
	_instance("res://scenes/pickups/tape.tscn", "Tape2", pickups, Vector2(33 * TILE, 13 * TILE - 60))
	for i in 6:
		_instance("res://scenes/pickups/scrap.tscn", "BridgeScrap%d" % i, pickups, Vector2((12 + i * 1.5) * TILE, 29 * TILE - 50))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "GapScrap%d" % i, pickups, Vector2((14 + i * 2) * TILE, 15 * TILE))

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(3 * TILE, floor_y - 48))
	_save_scene(page, SPINE)


# --- The Sogg arena ---------------------------------------------------------------

func _build_sogg_arena() -> void:
	const COLS := 30
	var page := _new_page("SoggArena", 0, Rect2(0, 0, COLS * TILE, 1088), "The Summit", "")
	page.set("music", load(MUSIC_DEEP))
	_snow_background(page, "bg_spine.png", 17)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var g := _grid(COLS, 17)
	_ledge(g, 0, 14, COLS, 2)
	_paint(tiles, g, SNOW_LEGEND)
	_page_edges(page, 0, COLS * TILE)

	var floor_y := 14 * TILE
	_spawn_marker(page, "Start", Vector2(2 * TILE, floor_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "SoggTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(4 * TILE, floor_y - 200)
	talk.set("dialogue_id", "sogg_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	var start_zone := _area(Area2D, "FightStart", story, "", 0, L_PLAYER)
	start_zone.position = Vector2(7 * TILE, floor_y - 200)
	_shape(start_zone, _rect(Vector2(120, 600)))

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(1 * TILE + 16, floor_y))
	var marks: Array[Node] = []
	for col in [8, 15, 22]:
		marks.append(_fold(props, "Fold%d" % (marks.size() + 1), col, 14, 180.0, 2.4))
	var exit := _instance("res://scenes/world/page_door.tscn", "IntoTheGutter", props, Vector2(27 * TILE, floor_y))
	exit.set("target_page", INTERLUDE_3)
	exit.set("door_prompt", "Fall into the Gutter")

	var boss := _instance("res://scenes/enemies/boss_sogg.tscn", "TheSogg", page, Vector2(18 * TILE, floor_y))
	boss.set("fold_marks", marks)
	boss.set("exit_door", exit)
	boss.set("start_zone", start_zone)
	boss.set("floor_y", float(floor_y))
	boss.set("arena_left", 2.0 * TILE)
	boss.set("arena_right", 28.0 * TILE)
	boss.set("next_page", INTERLUDE_3)

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(2 * TILE, floor_y - 48))
	_save_scene(page, SOGG_ARENA)


# --- Interludes ---------------------------------------------------------------

func _build_interlude_3() -> void:
	var page := _cutscene("Interlude03", "bg_dad_table_night.png", "Much later, at Gran's kitchen table...", "interlude_3", "")
	page.set("sets_flag", "chapter3_complete")
	page.set("save_on_finish", true)
	_save_scene(page, INTERLUDE_3)


func _update_interlude_2() -> void:
	var page := _edit_scene(INTERLUDE_2)
	page.set("next_page", SLOPES)
	_save_scene(page, INTERLUDE_2)
