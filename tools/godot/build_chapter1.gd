extends "res://tools/godot/build_starter_content.gd"
## One-time bootstrap for Chapter 1 (Thistledown Meadow): the Prologue, Windmill Hills,
## the Ribbon Regatta minigame, the Old Millwheel boss arena, and the first interlude.
## Also adds the boss bar to the HUD, the quest log to the pause menu, and wires
## Thistledown page 1 into the chapter.
##
## Run from the repo root (after `godot --headless --import`):
##   godot --headless --path . --script tools/godot/build_chapter1.gd
##
## Like build_starter_content.gd, re-running overwrites these scenes.

const CH1 := "res://scenes/levels/ch1_thistledown/"
const PAGE_01 := CH1 + "thistledown_page_01.tscn"
const PAGE_02 := CH1 + "thistledown_page_02.tscn"
const RACE := CH1 + "ribbon_regatta.tscn"
const ARENA := CH1 + "millwheel_arena.tscn"
const INTERLUDE := "res://scenes/levels/interludes/interlude_01.tscn"
const PROLOGUE_INTRO := "res://scenes/levels/prologue/prologue_intro.tscn"
const PROLOGUE_FLOOD := "res://scenes/levels/prologue/prologue_flood.tscn"
const MUSIC := "res://assets/audio/music/foldwick_lullaby.wav"


func _build_all() -> void:
	_build_dot_companion()
	_build_ink_drip()
	_build_lost_sheep()
	_build_rising_water()
	_build_narrator_trigger()
	_build_windmills()
	_build_boss()
	_add_boss_bar_to_hud()
	_add_quest_log_to_pause_menu()
	_build_prologue_intro()
	_build_prologue_flood()
	_update_page_01()
	_build_page_02()
	_build_race()
	_build_arena()
	_build_interlude()
	print("Chapter 1 built." if not _failed else "Chapter 1 built WITH ERRORS.")
	quit(1 if _failed else 0)


func _edit_scene(path: String) -> Node:
	var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	return scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)


# --- Reusable pieces ---------------------------------------------------------

func _build_dot_companion() -> void:
	var dot := _node(Node2D, "DotCompanion", null, "res://scripts/world/dot_companion.gd") as Node2D
	_sprite(dot, "characters/dot.png", Vector2.ZERO, 0.8)
	_save_scene(dot, "res://scenes/world/dot_companion.tscn")


func _build_ink_drip() -> void:
	var drip := _area(Area2D, "InkDrip", null, "res://scripts/enemies/ink_drip.gd", L_ENEMY_ATTACKS, 0)
	drip.monitoring = false
	drip.set("knockback", 300.0)
	_sprite(drip, "props/ink_drip.png")
	_shape(drip, _circle(14.0))
	_save_scene(drip, "res://scenes/enemies/ink_drip.tscn")


func _build_lost_sheep() -> void:
	var sheep := _area(Area2D, "LostSheep", null, "res://scripts/world/lost_sheep.gd", L_INTERACTABLES, L_PLAYER)
	sheep.set("prompt_offset", Vector2(0, -150))
	_sprite(sheep, "characters/lost_sheep.png", Vector2(0, -56))
	_shape(sheep, _rect(Vector2(200, 130)), Vector2(0, -60))
	_save_scene(sheep, "res://scenes/world/lost_sheep.tscn")


func _build_rising_water() -> void:
	var water := _area(Area2D, "RisingWater", null, "res://scripts/world/rising_water.gd", L_ENEMY_ATTACKS, 0)
	water.monitoring = false
	water.set("damage", 1)
	water.set("knockback", 900.0)
	water.z_index = 10
	var body := _node(ColorRect, "Body", water) as ColorRect
	body.color = Color(0.32, 0.45, 0.67, 0.9)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := _sprite(water, "props/rising_water.png")
	surface.name = "Surface"
	surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_shape(water, _rect(Vector2(1920, 2400)))
	_save_scene(water, "res://scenes/world/rising_water.tscn")


func _build_narrator_trigger() -> void:
	var trigger := _area(Area2D, "NarratorTrigger", null, "res://scripts/world/narrator_trigger.gd", 0, L_PLAYER)
	_shape(trigger, _rect(Vector2(120, 700)), Vector2(0, -300))
	_save_scene(trigger, "res://scenes/world/narrator_trigger.tscn")


func _build_windmills() -> void:
	for with_wheel in [false, true]:
		var mill := _node(Node2D, "WindmillWheel" if with_wheel else "Windmill", null, "res://scripts/world/windmill.gd") as Node2D
		_sprite(mill, "props/windmill.png", Vector2(0, -200))
		var sails := _node(Node2D, "Sails", mill) as Node2D
		sails.position = Vector2(0, -300)
		_sprite(sails, "props/windmill_sails.png")
		if with_wheel:
			mill.set("gondola_count", 4)
			mill.set("radius", 170.0)
			mill.set("spin_speed", 0.5)
			for i in 4:
				var seat := _node(AnimatableBody2D, "Gondola%d" % i, mill) as AnimatableBody2D
				seat.collision_layer = L_WORLD
				seat.collision_mask = 0
				seat.sync_to_physics = true
				var art := _sprite(seat, "props/cardboard_platform.png")
				art.scale = Vector2(0.6, 1.0)
				var shape := _shape(seat, _rect(Vector2(112, 24)))
				shape.one_way_collision = true
		else:
			mill.set("spinning", true)
			mill.set("spin_speed", 0.25)
			mill.modulate = Color(0.85, 0.85, 0.85, 0.8)
		_save_scene(mill, "res://scenes/world/%s.tscn" % ("windmill_wheel" if with_wheel else "windmill"))


func _build_boss() -> void:
	var boss := _node(Node2D, "OldMillwheel", null, "res://scripts/enemies/boss_millwheel.gd") as Node2D
	_sprite(boss, "characters/millwheel_body.png", Vector2(0, -176), 0.8).name = "Body"
	var sails := _node(Node2D, "Sails", boss) as Node2D
	sails.position = Vector2(0, -300)
	_sprite(sails, "characters/millwheel_sails.png")
	for i in 4:
		var angle := i * PI / 2.0 + 0.2
		var blade := _area(Area2D, "Blade%d" % i, sails, "res://scripts/components/hitbox.gd", L_ENEMY_ATTACKS, 0)
		blade.monitoring = false
		blade.set("knockback", 700.0)
		blade.position = Vector2.from_angle(angle) * 155.0 + Vector2.from_angle(angle + PI / 2.0) * 22.0
		blade.rotation = angle
		_shape(blade, _rect(Vector2(230, 56)))
	var core := _area(Area2D, "Core", boss, "res://scripts/components/hurtbox.gd", 0, L_PLAYER_ATTACKS)
	core.position = Vector2(0, -150)
	_sprite(core, "characters/millwheel_core.png")
	_shape(core, _circle(60.0))
	var health := _node(Node, "HealthComponent", boss, "res://scripts/components/health_component.gd")
	health.set("max_health", 9)
	health.set("invulnerability_time", 0.35)
	_save_scene(boss, "res://scenes/enemies/boss_millwheel.tscn")


func _add_boss_bar_to_hud() -> void:
	var hud := _edit_scene("res://scenes/ui/hud.tscn")
	var root := hud.get_node("Root")
	var bar := _node(VBoxContainer, "BossBar", root) as VBoxContainer
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -460
	bar.offset_right = 460
	bar.offset_top = -120
	bar.offset_bottom = -40
	var label := _node(Label, "BossName", bar) as Label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 36)
	label.add_theme_color_override(&"font_outline_color", Color("fcf6e4"))
	label.add_theme_constant_override(&"outline_size", 8)
	var health := _node(ProgressBar, "BossHealth", bar) as ProgressBar
	health.custom_minimum_size = Vector2(920, 28)
	health.show_percentage = false
	var fill := _paper_box(Color("de583d"), Color("2b2118"), 3)
	var back := _paper_box(Color("fcf6e4"), Color("2b2118"), 3)
	fill.set_content_margin_all(0)
	back.set_content_margin_all(0)
	health.add_theme_stylebox_override(&"fill", fill)
	health.add_theme_stylebox_override(&"background", back)
	_save_scene(hud, "res://scenes/ui/hud.tscn")


func _add_quest_log_to_pause_menu() -> void:
	var menu := _edit_scene("res://scenes/ui/pause_menu.tscn")
	var vbox := menu.get_node("Root/Panel/Margin/VBox")
	var log_label := _node(Label, "QuestLog", vbox) as Label
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override(&"font_size", 26)
	vbox.move_child(log_label, vbox.get_node("QuitButton").get_index())
	var panel := menu.get_node("Root/Panel") as Control
	panel.offset_top = -400
	panel.offset_bottom = 400
	_save_scene(menu, "res://scenes/ui/pause_menu.tscn")


# --- Prologue ----------------------------------------------------------------

func _cutscene(scene_name: String, background: String, title: String, conversation: String, next_page: String) -> Control:
	var page := _node(Control, scene_name, null, "res://scripts/world/cutscene_page.gd") as Control
	_full_rect(page)
	page.set("conversation_id", conversation)
	page.set("title_caption", title)
	page.set("next_page", next_page)
	page.set("music", load(MUSIC))
	var bg := _node(TextureRect, "Background", page) as TextureRect
	_full_rect(bg)
	bg.texture = load(ART + "backgrounds/" + background)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var title_label := _node(Label, "TitleLabel", page) as Label
	_full_rect(title_label)
	title_label.theme_type_variation = &"TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return page


func _build_prologue_intro() -> void:
	var page := _cutscene("PrologueIntro", "bg_bookshelf_night.png", "Prologue\nThe Night the River Came", "prologue_intro", PROLOGUE_FLOOD)
	_save_scene(page, PROLOGUE_INTRO)


func _narrate_at(parent: Node, trigger_name: String, position: Vector2, caption: String) -> void:
	var trigger := _instance("res://scenes/world/narrator_trigger.tscn", trigger_name, parent, position)
	trigger.set("caption", caption)


func _build_prologue_flood() -> void:
	const COLS := 30
	const ROWS := 50
	var page := _new_page("PrologueFlood", 0, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"The Title Page",
		"Patch the Magnificent was halfway through a very good boast when the page began to flood.")

	var parallax := _node(Parallax2D, "Background", page) as Parallax2D
	parallax.scroll_scale = Vector2(0.2, 0.2)
	parallax.repeat_size = Vector2(1920, 1080)
	parallax.repeat_times = 3
	_sprite(parallax, "backgrounds/bg_bookshelf_night.png").centered = false

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	# Zigzag of cardboard planks climbing the page, two rows (128 px) apart.
	var rows := []
	for y in ROWS:
		rows.append(".".repeat(COLS))
	rows[ROWS - 2] = "G".repeat(COLS)
	rows[ROWS - 1] = "#".repeat(COLS)
	var step := 0
	var y := ROWS - 4
	while y > 4:
		var x := 4 + (step % 4) * 6 if (step / 4) % 2 == 0 else 22 - (step % 4) * 6
		var row: String = rows[y]
		rows[y] = row.substr(0, x) + "====" + row.substr(x + 4)
		step += 1
		y -= 2
	# The top of the page: solid ground on the left, reached from the last plank on the right.
	rows[4] = "G".repeat(20) + ".".repeat(COLS - 20)
	_paint(tiles, rows, {"G": T_GRASS, "#": T_DIRT, "=": T_PLANK})
	_page_edges(page, 0, COLS * TILE)

	var ground_y := (ROWS - 2) * TILE
	_spawn_marker(page, "Start", Vector2(3 * TILE, ground_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "PatchBoasts", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(3 * TILE, ground_y - 100)
	talk.set("dialogue_id", "prologue_patch")
	_shape(talk, _rect(Vector2(200, 200)))
	_narrate_at(story, "HowToJump", Vector2(7 * TILE, ground_y), "Run with the arrow keys, WASD or the left stick. Press {jump} to jump. Climb! Climb!")
	_narrate_at(story, "HowToSwipe", Vector2(12 * TILE, 30 * TILE), "A Soggy! Patch's paper edge is sharp: press {attack} to swipe.")
	_narrate_at(story, "TailLost", Vector2(5 * TILE, 4 * TILE), "Patch made it off the page. Most of him did. His beautiful tail was gone.")

	var actors := _node(Node2D, "Actors", page)
	_instance("res://scenes/enemies/soggy.tscn", "Soggy1", actors, _first_plank_center(rows, 30) + Vector2(0, -40))
	var props := _node(Node2D, "Props", page)
	var mid_plank := _first_plank_center(rows, 26)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, mid_plank)
	var exit := _instance("res://scenes/world/page_door.tscn", "OffThePage", props, Vector2(4 * TILE, 4 * TILE))
	exit.set("target_page", PAGE_01)
	exit.set("target_spawn", &"Start")
	exit.set("door_prompt", "Leap off the page!")

	var water := _instance("res://scenes/world/rising_water.tscn", "Flood", page, Vector2(0, ROWS * TILE + 120))
	water.set("width", float(COLS * TILE))
	water.set("stop_y", 5.0 * TILE)
	water.set("rise_speed", 34.0)

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(3 * TILE, ground_y - 48))
	_save_scene(page, PROLOGUE_FLOOD)


## Center-top of the first plank found on a row, in pixels.
func _first_plank_center(rows: Array, row: int) -> Vector2:
	var line: String = rows[row]
	var x := line.find("=")
	if x < 0:
		return Vector2(10 * TILE, row * TILE)
	return Vector2((x + 2) * TILE, row * TILE)


# --- Thistledown -------------------------------------------------------------

func _update_page_01() -> void:
	var page := _edit_scene(PAGE_01)
	var fluff := page.get_node("Actors/ShepherdFluff")
	fluff.set("quest_id", "lost_flock")
	fluff.set("quest_progress_dialogue", "fluff_quest_progress")
	fluff.set("quest_turn_in_dialogue", "fluff_quest_done")
	page.get_node("Actors/Dot").set("joins_as_companion", true)
	# Re-link the bridge tab: node-path exports don't survive re-instancing here.
	var bridge_tab := page.get_node("Props/BridgeTab")
	if bridge_tab.get_script() == null:
		bridge_tab.set_script(load("res://scripts/world/pull_tab.gd"))
	bridge_tab.set("target", page.get_node("Props/TabBridge"))
	bridge_tab.set("move_offset", Vector2(0, -3 * TILE))
	var door := _instance("res://scenes/world/page_door.tscn", "OnwardDoor", page.get_node("Props"), Vector2(79 * TILE - 24, 12 * TILE))
	door.set("target_page", PAGE_02)
	door.set("target_spawn", &"Start")
	door.set("door_prompt", "Turn the page")
	_spawn_marker(page, "FromHills", Vector2(76 * TILE, 12 * TILE - 48))
	_save_scene(page, PAGE_01)


func _build_page_02() -> void:
	const COLS := 90
	var page := _new_page("ThistledownPage02", 0, Rect2(0, 0, COLS * TILE, 1088),
		"Windmill Hills",
		"On the Windmill Hills the sails hung still and heavy, and somewhere up there three sheep were sulking.")

	var parallax := _node(Parallax2D, "Background", page) as Parallax2D
	parallax.scroll_scale = Vector2(0.25, 0.1)
	parallax.repeat_size = Vector2(1920, 0)
	parallax.repeat_times = 2
	_sprite(parallax, "backgrounds/bg_thistledown.png").centered = false

	var scenery := _node(Node2D, "Scenery", page)
	for col in [10, 22, 52, 80]:
		_instance("res://scenes/world/windmill.tscn", "Windmill%d" % col, scenery, Vector2(col * TILE, 14 * TILE))

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var rows := []
	for y in 17:
		rows.append(".".repeat(COLS))
	var ledge := "G".repeat(12)
	rows[7] = rows[7].substr(0, 37) + ledge + rows[7].substr(49)
	rows[8] = rows[8].substr(0, 37) + "#".repeat(12) + rows[8].substr(49)
	for y in [14, 15, 16]:
		var fill := "G" if y == 14 else "#"
		rows[y] = fill.repeat(64) + ".".repeat(6) + fill.repeat(COLS - 70)
	rows[16] = rows[16].substr(0, 64) + "~~~~~~" + rows[16].substr(70)
	_paint(tiles, rows, {"G": T_GRASS, "#": T_DIRT, "~": T_SOGGY})
	_page_edges(page, 0, COLS * TILE)

	var ground_y := 14 * TILE
	_spawn_marker(page, "Start", Vector2(2 * TILE, ground_y - 48))
	_spawn_marker(page, "FromRace", Vector2(57 * TILE, ground_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "HillsTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(5 * TILE, ground_y - 200)
	talk.set("dialogue_id", "windmill_hills_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	_narrate_at(story, "WheelHint", Vector2(26 * TILE, ground_y), "The big windmill's tab still works. Pull it, then ride the sails up.")
	_narrate_at(story, "DashHint", Vector2(61 * TILE, ground_y), "A soggy gap, too wide to jump. Jump, then Fold Dash across with {dash}!")

	var props := _node(Node2D, "Props", page)
	var wheel := _instance("res://scenes/world/windmill_wheel.tscn", "BigWindmill", props, Vector2(32 * TILE + 32, ground_y))
	var tab := _instance("res://scenes/world/pull_tab.tscn", "WindTab", props, Vector2(28 * TILE, ground_y))
	tab.set("one_shot", true)
	wheel.set("tab", tab)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(51 * TILE, ground_y))
	var race := _instance("res://scenes/world/page_door.tscn", "RegattaDock", props, Vector2(58 * TILE, ground_y))
	race.set("target_page", RACE)
	race.set("door_prompt", "Race the paper boat")
	var exit := _instance("res://scenes/world/page_door.tscn", "ToTheMill", props, Vector2(87 * TILE, ground_y))
	exit.set("target_page", ARENA)
	exit.set("target_spawn", &"Start")
	exit.set("door_prompt", "Head for the old mill")
	var back := _instance("res://scenes/world/page_door.tscn", "BackDoor", props, Vector2(1 * TILE, ground_y))
	back.set("target_page", PAGE_01)
	back.set("target_spawn", &"FromHills")
	back.set("door_prompt", "Turn back a page")

	var actors := _node(Node2D, "Actors", page)
	_instance("res://scenes/world/lost_sheep.tscn", "Sheep1", actors, Vector2(18 * TILE, ground_y))
	_instance("res://scenes/world/lost_sheep.tscn", "Sheep2", actors, Vector2(44 * TILE, 7 * TILE))
	_instance("res://scenes/world/lost_sheep.tscn", "Sheep3", actors, Vector2(75 * TILE, ground_y))
	for col in [14, 22, 42, 72]:
		var y := 7 * TILE if col == 42 else ground_y
		_instance("res://scenes/enemies/soggy.tscn", "Soggy%d" % col, actors, Vector2(col * TILE, y - 40))

	var pickups := _node(Node2D, "Pickups", page)
	var letter := _instance("res://scenes/pickups/lost_letter.tscn", "LetterT", pickups, Vector2(47 * TILE, 7 * TILE - 60))
	letter.set("letter", "T")
	for i in 6:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, Vector2((64.5 + i) * TILE, ground_y - 180))
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, Vector2(53 * TILE, ground_y - 60))

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(2 * TILE, ground_y - 48))
	_save_scene(page, PAGE_02)


func _build_race() -> void:
	var race := _node(Node2D, "RibbonRegatta", null, "res://scripts/minigames/boat_race.gd") as Node2D
	race.set("return_page", PAGE_02)
	race.set("music", load(MUSIC))
	var parallax := _node(Parallax2D, "Background", race) as Parallax2D
	parallax.repeat_size = Vector2(1920, 0)
	parallax.repeat_times = 3
	_sprite(parallax, "backgrounds/bg_ribbon_stream.png").centered = false
	_node(Node2D, "Course", race)
	var boat := _node(Node2D, "Boat", race) as Node2D
	_sprite(boat, "props/paper_boat.png")
	_node(Camera2D, "Camera2D", race)
	var ui := _node(CanvasLayer, "UI", race)
	var status := _node(Label, "Status", ui) as Label
	status.position = Vector2(40, 30)
	status.add_theme_font_size_override(&"font_size", 44)
	status.add_theme_color_override(&"font_outline_color", Color("fcf6e4"))
	status.add_theme_constant_override(&"outline_size", 10)
	var big := _node(Label, "BigLabel", ui) as Label
	_full_rect(big)
	big.theme_type_variation = &"TitleLabel"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_scene(race, RACE)


func _build_arena() -> void:
	const COLS := 30
	var page := _new_page("MillwheelArena", 0, Rect2(0, 0, COLS * TILE, 1088),
		"The Old Mill", "")

	var parallax := _node(Parallax2D, "Background", page) as Parallax2D
	parallax.scroll_scale = Vector2(0.25, 0.1)
	_sprite(parallax, "backgrounds/bg_thistledown.png").centered = false

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	var rows := []
	for y in 17:
		rows.append(".".repeat(COLS))
	rows[12] = ".".repeat(15) + "=====" + ".".repeat(10)
	for y in [14, 15, 16]:
		rows[y] = ("G" if y == 14 else "#").repeat(COLS)
	_paint(tiles, rows, {"G": T_GRASS, "#": T_DIRT, "=": T_PLANK})
	_page_edges(page, 0, COLS * TILE)

	var ground_y := 14 * TILE
	_spawn_marker(page, "Start", Vector2(2 * TILE, ground_y - 48))

	var story := _node(Node2D, "Story", page)
	var talk := _area(Area2D, "MillTalk", story, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	talk.position = Vector2(4 * TILE, ground_y - 200)
	talk.set("dialogue_id", "millwheel_arrival")
	_shape(talk, _rect(Vector2(120, 600)))
	var start_zone := _area(Area2D, "FightStart", story, "", 0, L_PLAYER)
	start_zone.position = Vector2(8 * TILE, ground_y - 200)
	_shape(start_zone, _rect(Vector2(120, 600)))

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(1 * TILE + 16, ground_y))
	var tabs: Array[Node] = []
	for spot in [Vector2(5 * TILE, ground_y), Vector2(11 * TILE, ground_y), Vector2(17 * TILE + 32, 12 * TILE)]:
		var tab := _instance("res://scenes/world/pull_tab.tscn", "MooringTab%d" % (tabs.size() + 1), props, spot)
		tab.set("one_shot", true)
		tabs.append(tab)
	var exit := _instance("res://scenes/world/page_door.tscn", "ToGransTable", props, Vector2(27 * TILE, ground_y))
	exit.set("target_page", INTERLUDE)
	exit.set("door_prompt", "Close Chapter 1")

	var boss := _instance("res://scenes/enemies/boss_millwheel.tscn", "OldMillwheel", page, Vector2(24 * TILE, ground_y))
	boss.set("tabs", tabs)
	boss.set("exit_door", exit)
	boss.set("start_zone", start_zone)
	boss.set("floor_y", float(ground_y))
	boss.set("arena_left", 2.0 * TILE)
	boss.set("arena_right", 20.0 * TILE)

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(2 * TILE, ground_y - 48))
	_save_scene(page, ARENA)


func _build_interlude() -> void:
	var page := _cutscene("Interlude01", "bg_dad_table.png", "Meanwhile, at Gran's kitchen table...", "interlude_1", "")
	page.set("sets_flag", "chapter1_complete")
	page.set("save_on_finish", true)
	_save_scene(page, INTERLUDE)
