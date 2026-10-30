extends "res://tools/godot/build_chapter3.gd"
## One-time bootstrap for the Finale (The Gutter): the drowned crease at the middle of
## the book, the Sogg's last stand (played twice, either side of Interlude 4), the
## morning after at Gran's table, Nell's crayon page, and the last page of the book.
## Also adds the finale tiles to the tileset and points the third interlude down into
## the Gutter instead of back to the title.
##
## Run from the repo root (after `godot --headless --import`):
##   godot --headless --path . --script tools/godot/build_finale.gd
##
## Like the other builders, re-running overwrites these scenes.

const FINALE := "res://scenes/levels/finale/"
const GUTTER := FINALE + "the_gutter.tscn"
const SOGG_FINAL := FINALE + "deepest_fold.tscn"
const NELL_PAGE := FINALE + "nell_page.tscn"
const INTERLUDE_4 := "res://scenes/levels/interludes/interlude_04.tscn"
const ENDING_TABLE := "res://scenes/levels/interludes/ending_table.tscn"
const THE_END := "res://scenes/levels/interludes/the_end.tscn"
const MUSIC_WARM := "res://assets/audio/music/warm_air.wav"
const MUSIC_MENDED := "res://assets/audio/music/mended.wav"

const T_GUTTER_TOP := Vector2i(0, 5)
const T_GUTTER_FILL := Vector2i(1, 5)
const T_CRAYON_TOP := Vector2i(2, 5)
const T_CRAYON_FILL := Vector2i(3, 5)

const GUTTER_LEGEND := {"G": T_GUTTER_TOP, "#": T_GUTTER_FILL, "=": T_THREAD}
const CRAYON_LEGEND := {"G": T_CRAYON_TOP, "#": T_CRAYON_FILL}


func _build_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FINALE))
	_add_finale_tiles()
	_build_wave_gate()
	_build_beam()
	_build_drizzle_npc()
	_build_sogg_final()
	_build_gutter()
	_build_deepest_fold()
	_build_interlude_4()
	_build_ending_table()
	_build_nell_page()
	_build_the_end()
	_update_interlude_3()
	print("Finale built." if not _failed else "Finale built WITH ERRORS.")
	quit(1 if _failed else 0)


# --- Tiles and reusable pieces -------------------------------------------------

func _add_finale_tiles() -> void:
	var tileset := load("res://resources/paper_tiles.tres") as TileSet
	var source := tileset.get_source(0) as TileSetAtlasSource
	var h := TILE / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for coords in [T_GUTTER_TOP, T_GUTTER_FILL, T_CRAYON_TOP, T_CRAYON_FILL]:
		if not source.has_tile(coords):
			source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		if data.get_collision_polygons_count(0) == 0:
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, full)
	_save_resource(tileset, "res://resources/paper_tiles.tres")


func _build_wave_gate() -> void:
	var gate := _node(StaticBody2D, "WaveGate", null) as StaticBody2D
	gate.collision_layer = L_WORLD
	var art := _sprite(gate, "props/gutter_gate.png")
	# Anchored at its foot, so it swells up out of the floor.
	art.centered = false
	art.offset = Vector2(-56, -330)
	_shape(gate, _rect(Vector2(96, 330)), Vector2(0, -165))
	_save_scene(gate, "res://scenes/world/wave_gate.tscn")


func _build_beam() -> void:
	var beam := _node(Node2D, "HairdryerBeam", null, "res://scripts/world/hairdryer_beam.gd") as Node2D
	beam.z_index = 3
	var air := _sprite(beam, "props/warm_beam.png", Vector2(0, 812))
	air.name = "Air"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	air.material = add
	var nozzle := _sprite(beam, "props/hairdryer.png", Vector2(0, 148))
	nozzle.name = "Nozzle"
	nozzle.z_index = 2
	_save_scene(beam, "res://scenes/world/hairdryer_beam.tscn")


func _build_drizzle_npc() -> void:
	var drizzle := _area(Area2D, "Drizzle", null, "res://scripts/world/npc.gd", L_INTERACTABLES, L_PLAYER)
	drizzle.set("dialogue_id", "epilogue_drizzle")
	drizzle.set("idle_bob", 10.0)
	drizzle.set("prompt_offset", Vector2(0, -230))
	_sprite(drizzle, "characters/drizzle.png", Vector2(0, -120), 0.5)
	_shape(drizzle, _rect(Vector2(160, 140)), Vector2(0, -70))
	_save_scene(drizzle, "res://scenes/world/npc_drizzle.tscn")


func _build_sogg_final() -> void:
	var boss := _node(Node2D, "TheSogg", null, "res://scripts/enemies/boss_sogg_final.gd") as Node2D
	_sprite(boss, "characters/sogg_body.png", Vector2(0, -196), 0.8).name = "Body"
	var heart := _area(Area2D, "Heart", boss, "res://scripts/components/hurtbox.gd", 0, L_PLAYER_ATTACKS)
	heart.position = Vector2(0, -200)
	heart.z_index = 1
	_sprite(heart, "characters/drizzle_heart.png", Vector2.ZERO, 0.8)
	_shape(heart, _circle(64.0))
	var contact := _area(Area2D, "ContactHitbox", boss, "res://scripts/components/hitbox.gd", L_ENEMY_ATTACKS, 0)
	contact.monitoring = false
	contact.set("damage", 2)
	contact.set("knockback", 760.0)
	_shape(contact, _rect(Vector2(400, 230)), Vector2(0, -115))
	var health := _node(Node, "HealthComponent", boss, "res://scripts/components/health_component.gd")
	health.set("max_health", 16)
	health.set("invulnerability_time", 0.3)
	_save_scene(boss, "res://scenes/enemies/boss_sogg_final.tscn")


# --- The Gutter (side view, the gauntlet) --------------------------------------

func _build_gutter() -> void:
	const COLS := 76
	const ROWS := 20
	var page := _new_page("TheGutter", 0, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"The Gutter",
		"Down, down, into the crease at the middle of the book, where the pages meet and the flood had nowhere left to go.")
	page.set("music", load(MUSIC_DEEP))
	page.set("no_companions", true)
	_snow_background(page, "bg_gutter.png", ROWS)
	_ink_sea(page, COLS * TILE, 18.6 * TILE)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var g := _grid(COLS, ROWS)
	# The near floor, up to the drowned gap.
	_ledge(g, 0, 16, 31, 3)
	# A swollen bundle of pages standing up out of the water: reach it with the Tape Tail.
	_ledge(g, 39, 13, 9, 6)
	# The far floor, with the second lock on it.
	_ledge(g, 48, 16, 28, 3)
	# The high ledge at the very end, reached by springing a peak.
	_ledge(g, 69, 12, 7, 7)
	_paint(tiles, g, GUTTER_LEGEND)
	_page_edges(page, 0, COLS * TILE)

	var floor_y := 16 * TILE
	_spawn_marker(page, "Start", Vector2(3 * TILE, floor_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "ArrivalTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(5 * TILE, floor_y - 200)
	talk.set("dialogue_id", "gutter_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	var echoes := _area(Area2D, "EchoesTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	echoes.position = Vector2(11 * TILE, floor_y - 200)
	echoes.set("dialogue_id", "gutter_echoes")
	_shape(echoes, _rect(Vector2(120, 600)))
	_narrate_at(story, "GapHint", Vector2(28 * TILE, floor_y), "The floor drowns here. A ring hangs over the water, near the bundle of pages. Tape Tail with {grapple}.")
	_narrate_at(story, "FoldHint", Vector2(65 * TILE, floor_y), "One last fold mark, before the deep part. Spring it with {slam}.")

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(2 * TILE, floor_y))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark2", props, Vector2(30 * TILE, floor_y))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark3", props, Vector2(40 * TILE, 13 * TILE))
	_instance("res://scenes/world/bookmark.tscn", "Bookmark4", props, Vector2(66 * TILE, floor_y))
	var ring := _ring(props, "GapRing", Vector2(37.5 * TILE, 11.5 * TILE))
	ring.set("land_offset", Vector2(140, -40))
	_fold(props, "LastFold", 67, 16)
	var exit := _instance("res://scenes/world/page_door.tscn", "IntoTheDeep", props, Vector2(74 * TILE, 12 * TILE))
	exit.set("target_page", SOGG_FINAL)
	exit.set("target_spawn", &"Start")
	exit.set("door_prompt", "Go down into the deepest fold")

	# The two locks: the gauntlet.
	_wave_lock(page, props, "LockOne", 13.5, 29.5, 16, 15, 28, [2, 3, 3],
		"The soaked pages swelled shut behind Patch, and ahead. Shapes rose out of the water.",
		"The last one fell back into the water. The pages sagged open again.")
	_wave_lock(page, props, "LockTwo", 49.5, 64.5, 53, 51, 63, [3, 3, 4],
		"Shut in again. More of them this time, and the ceiling dripping.",
		"Quiet. Just the drip, drip of the Gutter, and Patch breathing hard.")

	var hazards := _node(Node2D, "Hazards", page)
	var drips := _node(Node2D, "Drips", hazards, "res://scripts/world/drip_spawner.gd") as Node2D
	drips.position = Vector2(51 * TILE, 3 * TILE)
	drips.set("width", 12.0 * TILE)
	drips.set("interval", 1.4)
	drips.set("floor_y", float(floor_y))

	var actors := _node(Node2D, "Actors", page)
	for spot in [Vector2(9, 16), Vector2(45, 13)]:
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % actors.get_child_count(), actors, Vector2(spot.x * TILE, spot.y * TILE - 40))

	var pickups := _node(Node2D, "Pickups", page)
	var letter_g := _instance("res://scenes/pickups/lost_letter.tscn", "LetterG", pickups, Vector2(46 * TILE, 13 * TILE - 60))
	letter_g.set("letter", "G")
	var letter_u := _instance("res://scenes/pickups/lost_letter.tscn", "LetterU", pickups, Vector2(58 * TILE, floor_y - 60))
	letter_u.set("letter", "U")
	var letter_d := _instance("res://scenes/pickups/lost_letter.tscn", "LetterD", pickups, Vector2(71 * TILE, 12 * TILE - 60))
	letter_d.set("letter", "D")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, Vector2(31 * TILE, floor_y - 60))
	_instance("res://scenes/pickups/tape.tscn", "Tape2", pickups, Vector2(43 * TILE, 13 * TILE - 60))
	_instance("res://scenes/pickups/tape.tscn", "Tape3", pickups, Vector2(66 * TILE, floor_y - 60))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, Vector2((33 + i * 1.2) * TILE, (10.5 + absf(i - 2) * 0.4) * TILE))

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(3 * TILE, floor_y - 48))
	_save_scene(page, GUTTER)


func _wave_lock(page: Node, props: Node, lock_name: String, gate_a: float, gate_b: float, trigger_col: float,
		spawn_from: float, spawn_to: float, waves: Array, start: String, clear: String) -> void:
	var floor_y := 16 * TILE
	var gates: Array[Node2D] = []
	for col in [gate_a, gate_b]:
		gates.append(_instance("res://scenes/world/wave_gate.tscn", "%sGate%d" % [lock_name, gates.size() + 1], props, Vector2(col * TILE, floor_y)))
	var lock := _area(Area2D, lock_name, page.get_node("Story"), "res://scripts/world/wave_lock.gd", 0, L_PLAYER)
	lock.position = Vector2(trigger_col * TILE, floor_y - 200)
	_shape(lock, _rect(Vector2(120, 600)))
	lock.set("gates", gates)
	var counts: Array[int] = []
	counts.assign(waves)
	lock.set("waves", counts)
	lock.set("spawn_left", spawn_from * TILE)
	lock.set("spawn_right", spawn_to * TILE)
	lock.set("spawn_y", float(floor_y))
	lock.set("start_caption", start)
	lock.set("clear_caption", clear)


# --- The deepest fold: the Sogg's last stand ---------------------------------------

func _build_deepest_fold() -> void:
	const COLS := 30
	var page := _new_page("DeepestFold", 0, Rect2(0, 0, COLS * TILE, 1088), "The Deepest Fold", "")
	page.set("music", load(MUSIC_DEEP))
	page.set("no_companions", true)
	_snow_background(page, "bg_gutter.png", 17)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var g := _grid(COLS, 17)
	_ledge(g, 0, 14, COLS, 2)
	_paint(tiles, g, GUTTER_LEGEND)
	_page_edges(page, 0, COLS * TILE)

	var floor_y := 14 * TILE
	_spawn_marker(page, "Start", Vector2(2 * TILE, floor_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "SoggTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(4 * TILE, floor_y - 200)
	talk.set("dialogue_id", "gutter_sogg_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	var start_zone := _area(Area2D, "FightStart", story, "", 0, L_PLAYER)
	start_zone.position = Vector2(7 * TILE, floor_y - 200)
	_shape(start_zone, _rect(Vector2(120, 600)))

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(1 * TILE + 16, floor_y))
	var marks: Array[Node] = []
	for col in [8, 15, 22]:
		marks.append(_fold(props, "Fold%d" % (marks.size() + 1), col, 14, 180.0, 2.4))

	var beam := _instance("res://scenes/world/hairdryer_beam.tscn", "HairdryerBeam", page, Vector2(15 * TILE, 0))
	beam.set("left_limit", 3.0 * TILE)
	beam.set("right_limit", 27.0 * TILE)

	var boss := _instance("res://scenes/enemies/boss_sogg_final.tscn", "TheSogg", page, Vector2(18 * TILE, floor_y))
	boss.set("boss_name", "The Sogg")
	boss.set("fold_marks", marks)
	boss.set("start_zone", start_zone)
	boss.set("floor_y", float(floor_y))
	boss.set("arena_left", 2.0 * TILE)
	boss.set("arena_right", 28.0 * TILE)
	boss.set("hover_height", 500.0)
	boss.set("dive_intervals", [2.6, 2.6] as Array[float])
	boss.set("rain_intervals", [0.55, 0.55] as Array[float])
	boss.set("soak_time", 2.6)
	boss.set("stun_time", 4.0)
	boss.set("defeated_flag", "sogg_dried")
	boss.set("defeat_dialogue", "drizzle_dried")
	boss.set("next_page", ENDING_TABLE)
	boss.set("lose_page", INTERLUDE_4)
	boss.set("beam", beam)
	boss.set("warm_music", load(MUSIC_WARM))
	boss.set("section_lines", [
		"Steam rolled off the Sogg. A whole side of it puckered, dried and shrank away.",
		"Another piece of it dried out and flaked off. It was getting smaller.",
		"Half its water gone. Under the grey, something white was showing through.",
		"Nearly dry. It wasn't roaring any more. It sounded almost scared.",
	] as Array[String])

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(2 * TILE, floor_y - 48))
	_save_scene(page, SOGG_FINAL)


# --- Nell's page (side view, the epilogue) -----------------------------------------

func _build_nell_page() -> void:
	const COLS := 48
	const ROWS := 17
	var page := _new_page("NellsPage", 0, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"Nell's Page",
		"This page wasn't in the book before. Nell drew it this morning. The crayon was still warm.")
	page.set("music", load(MUSIC_MENDED))
	_snow_background(page, "bg_nell_page.png", ROWS)

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var g := _grid(COLS, ROWS)
	# Gentle crayon hills.
	_ledge(g, 0, 14, 12, 2)
	_ledge(g, 12, 13, 8, 3)
	_ledge(g, 20, 12, 10, 4)
	_ledge(g, 30, 13, 8, 3)
	_ledge(g, 38, 14, 10, 2)
	_paint(tiles, g, CRAYON_LEGEND)
	_page_edges(page, 0, COLS * TILE)

	_spawn_marker(page, "Start", Vector2(3 * TILE, 14 * TILE - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "ArrivalTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(6 * TILE, 14 * TILE - 200)
	talk.set("dialogue_id", "epilogue_arrival")
	_shape(talk, _rect(Vector2(120, 600)))

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(2 * TILE, 14 * TILE))
	var exit := _instance("res://scenes/world/page_door.tscn", "CloseTheBook", props, Vector2(46 * TILE, 14 * TILE))
	exit.set("target_page", THE_END)
	exit.set("door_prompt", "Turn to the last page")

	var actors := _node(Node2D, "Actors", page)
	_instance("res://scenes/world/npc_drizzle.tscn", "Drizzle", actors, Vector2(15 * TILE, 13 * TILE))
	for spec in [["npc_shepherd_fluff", "ShepherdFluff", 23, 12, "epilogue_fluff"],
			["npc_lamplighters", "Lamplighters", 32, 13, "epilogue_lamplighters"],
			["npc_bindwell", "Bindwell", 41, 14, "epilogue_bindwell"]]:
		var npc := _instance("res://scenes/world/%s.tscn" % spec[0], spec[1], actors, Vector2(spec[2] * TILE, spec[3] * TILE))
		npc.set("dialogue_id", spec[4])
		npc.set("repeat_dialogue_id", "")
		npc.set("first_talk_flag", "")
		npc.set("quest_id", "")

	var pickups := _node(Node2D, "Pickups", page)
	for i in 8:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, Vector2((24 + i * 0.9) * TILE, 10 * TILE - absf(i - 3.5) * 20))

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(3 * TILE, 14 * TILE - 48))
	_save_scene(page, NELL_PAGE)


# --- Interludes and the ending ---------------------------------------------------

func _build_interlude_4() -> void:
	var page := _cutscene("Interlude04", "bg_nell_dryer.png", "Meanwhile, at Gran's kitchen table...", "interlude_4", SOGG_FINAL)
	page.set("sets_flag", "nell_has_dryer")
	page.set("save_on_finish", true)
	_save_scene(page, INTERLUDE_4)


func _build_ending_table() -> void:
	var page := _cutscene("EndingTable", "bg_morning_table.png", "The next morning...", "ending_table", NELL_PAGE)
	page.set("sets_flag", "has_new_tail")
	page.set("save_on_finish", true)
	page.set("music", load(MUSIC_MENDED))
	_save_scene(page, ENDING_TABLE)


func _build_the_end() -> void:
	var page := _cutscene("TheEnd", "bg_morning_table.png", "", "the_end", "")
	page.set("sets_flag", "game_complete")
	page.set("save_on_finish", true)
	page.set("music", load(MUSIC_MENDED))
	_save_scene(page, THE_END)


func _update_interlude_3() -> void:
	var page := _edit_scene(INTERLUDE_3)
	page.set("next_page", GUTTER)
	_save_scene(page, INTERLUDE_3)
