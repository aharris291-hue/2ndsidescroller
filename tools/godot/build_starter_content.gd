extends SceneTree
## One-time bootstrap: generates the starter resources and scenes (theme, tileset, Patch,
## enemies, pickups, props, UI, and the two demo pages) so every .tscn is written by
## Godot itself.
##
## Run from the repo root (after `godot --headless --import`):
##   godot --headless --path . --script tools/godot/build_starter_content.gd
##
## WARNING: re-running overwrites those files. Once you start editing scenes in the
## editor, treat the editor as the source of truth and don't run this again.

const TILE := 64
const ART := "res://assets/art/"

# Collision layer bit values (layer N = 1 << (N - 1)).
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMIES := 4
const L_PLAYER_ATTACKS := 8
const L_ENEMY_ATTACKS := 16
const L_INTERACTABLES := 32

# Atlas coordinates in paper_tiles.png.
const T_GRASS := Vector2i(0, 0)
const T_DIRT := Vector2i(1, 0)
const T_PLANK := Vector2i(2, 0)
const T_SOGGY := Vector2i(3, 0)
const T_WOOD := Vector2i(0, 1)
const T_PAGE_FLOOR := Vector2i(1, 1)
const T_BOOKS := Vector2i(2, 1)
const T_INK := Vector2i(3, 1)

var _failed := false
var _started := false


func _process(_delta: float) -> bool:
	# Build on the first frame, once autoloads are registered (scripts reference them).
	if not _started:
		_started = true
		_build_all()
	return false


func _build_all() -> void:
	_build_theme()
	_build_tileset()
	_build_patch()
	_build_soggy()
	_build_pickups()
	_build_props()
	_build_npcs()
	_build_hud()
	_build_dialogue_ui()
	_build_pause_menu()
	_build_title_screen()
	_build_thistledown_page()
	_build_kitchen_table()
	print("Starter content built." if not _failed else "Starter content built WITH ERRORS.")
	quit(1 if _failed else 0)


# --- Helpers -----------------------------------------------------------------

func _save_scene(root: Node, path: String) -> void:
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err != OK:
		_failed = true
		push_error("Failed to save %s: %s" % [path, error_string(err)])
	else:
		print("  wrote ", path)
	root.free()


func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		# Nodes inside an instanced scene belong to that scene, not this one.
		if child.scene_file_path.is_empty():
			_set_owner(child, owner)


func _save_resource(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		_failed = true
		push_error("Failed to save %s: %s" % [path, error_string(err)])
	else:
		print("  wrote ", path)


func _node(type: Object, node_name: String, parent: Node = null, script_path := "") -> Node:
	var node: Node = type.new()
	node.name = node_name
	if not script_path.is_empty():
		node.set_script(load(script_path))
	if parent:
		parent.add_child(node)
	return node


func _instance(path: String, node_name: String, parent: Node, position := Vector2.ZERO) -> Node2D:
	var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var node := scene.instantiate() as Node2D
	node.name = node_name
	node.position = position
	parent.add_child(node)
	return node


func _sprite(parent: Node, texture: String, position := Vector2.ZERO, scale := 1.0) -> Sprite2D:
	var sprite := _node(Sprite2D, "Sprite2D", parent) as Sprite2D
	sprite.texture = load(ART + texture)
	sprite.position = position
	sprite.scale = Vector2.ONE * scale
	return sprite


func _shape(parent: Node, shape: Shape2D, position := Vector2.ZERO, node_name := "CollisionShape2D") -> CollisionShape2D:
	var collision := _node(CollisionShape2D, node_name, parent) as CollisionShape2D
	collision.shape = shape
	collision.position = position
	return collision


func _rect(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape


func _circle(radius: float) -> CircleShape2D:
	var shape := CircleShape2D.new()
	shape.radius = radius
	return shape


func _area(type: Object, node_name: String, parent: Node, script_path: String, layer: int, mask: int) -> Area2D:
	var area := _node(type, node_name, parent, script_path) as Area2D
	area.collision_layer = layer
	area.collision_mask = mask
	return area


func _full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- Theme and tiles ---------------------------------------------------------

func _build_theme() -> void:
	var ink := Color("2b2118")
	var cream := Color("fcf6e4")
	var marigold := Color("f2a93b")
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/PatrickHand-Regular.ttf")
	theme.default_font_size = 32

	theme.set_color(&"font_color", &"Label", ink)
	for state in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		theme.set_color(state, &"Button", ink)
		theme.set_color(state, &"CheckButton", ink)
	theme.set_color(&"default_color", &"RichTextLabel", ink)

	var normal := _paper_box(cream, ink, 3)
	var hover := _paper_box(Color("fbe3b4"), ink, 3)
	var pressed := _paper_box(marigold, ink, 3)
	var focus := _paper_box(Color(0, 0, 0, 0), marigold, 5)
	focus.draw_center = false
	theme.set_stylebox(&"normal", &"Button", normal)
	theme.set_stylebox(&"hover", &"Button", hover)
	theme.set_stylebox(&"pressed", &"Button", pressed)
	theme.set_stylebox(&"focus", &"Button", focus)
	theme.set_stylebox(&"focus", &"CheckButton", focus)
	theme.set_stylebox(&"focus", &"HSlider", focus)

	var paper := _paper_box(cream, ink, 4)
	paper.set_corner_radius_all(16)
	paper.set_content_margin_all(18)
	paper.shadow_color = Color(0.17, 0.13, 0.09, 0.35)
	paper.shadow_size = 6
	paper.shadow_offset = Vector2(4, 6)
	theme.set_stylebox(&"panel", &"PanelContainer", paper)

	# Floating "[E] Talk" prompts above interactables.
	theme.set_type_variation(&"PromptLabel", &"Label")
	theme.set_font_size(&"font_size", &"PromptLabel", 24)
	theme.set_color(&"font_color", &"PromptLabel", ink)
	theme.set_color(&"font_outline_color", &"PromptLabel", cream)
	theme.set_constant(&"outline_size", &"PromptLabel", 8)

	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font_size(&"font_size", &"TitleLabel", 104)
	theme.set_color(&"font_outline_color", &"TitleLabel", cream)
	theme.set_constant(&"outline_size", &"TitleLabel", 18)
	_save_resource(theme, "res://resources/ui_theme.tres")


func _paper_box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(12)
	box.content_margin_left = 24
	box.content_margin_right = 24
	return box


func _build_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, L_WORLD)
	tileset.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(ART + "tiles/paper_tiles.png")
	source.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 0)

	var h := TILE / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for coords in [T_GRASS, T_DIRT, T_PLANK, T_SOGGY, T_WOOD, T_PAGE_FLOOR, T_BOOKS, T_INK]:
		source.create_tile(coords)
	for coords in [T_GRASS, T_DIRT, T_SOGGY, T_BOOKS]:
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, full)
	# Cardboard planks: thin, and Patch can jump up through them.
	var plank := source.get_tile_data(T_PLANK, 0)
	plank.add_collision_polygon(0)
	plank.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h + 2), Vector2(h, -h + 2), Vector2(h, -h + 20), Vector2(-h, -h + 20)]))
	plank.set_collision_polygon_one_way(0, 0, true)
	_save_resource(tileset, "res://resources/paper_tiles.tres")


# --- Characters --------------------------------------------------------------

func _build_patch() -> void:
	var patch := _node(CharacterBody2D, "Patch", null, "res://scripts/player/patch.gd") as CharacterBody2D
	patch.collision_layer = L_PLAYER
	patch.collision_mask = L_WORLD
	patch.floor_snap_length = 12.0
	patch.floor_max_angle = deg_to_rad(50.0)

	var visual := _node(Node2D, "Visual", patch)
	_sprite(visual, "characters/patch.png", Vector2(-8, -10), 0.75)

	var capsule := CapsuleShape2D.new()
	capsule.radius = 28.0
	capsule.height = 84.0
	_shape(patch, capsule)

	var hurtbox := _area(Area2D, "Hurtbox", patch, "res://scripts/components/hurtbox.gd", 0, L_ENEMY_ATTACKS)
	_shape(hurtbox, _rect(Vector2(48, 72)))

	var attack := _area(Area2D, "AttackHitbox", patch, "res://scripts/components/hitbox.gd", L_PLAYER_ATTACKS, 0)
	attack.monitoring = false
	attack.set("knockback", 420.0)
	_shape(attack, _rect(Vector2(76, 96)))

	var interact := _area(Area2D, "InteractArea", patch, "", 0, L_INTERACTABLES)
	interact.monitorable = false
	_shape(interact, _circle(90.0))

	var health := _node(Node, "HealthComponent", patch, "res://scripts/components/health_component.gd")
	health.set("max_health", 6)
	health.set("invulnerability_time", 1.0)

	var camera := _node(Camera2D, "Camera2D", patch) as Camera2D
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.drag_vertical_enabled = true
	camera.drag_top_margin = 0.25
	camera.drag_bottom_margin = 0.15
	_save_scene(patch, "res://scenes/player/patch.tscn")


func _build_soggy() -> void:
	var soggy := _node(CharacterBody2D, "Soggy", null, "res://scripts/enemies/soggy.gd") as CharacterBody2D
	soggy.collision_layer = L_ENEMIES
	soggy.collision_mask = L_WORLD
	_sprite(soggy, "characters/soggy.png", Vector2(0, -8), 0.8)
	_shape(soggy, _circle(34.0))
	var hurtbox := _area(Area2D, "Hurtbox", soggy, "res://scripts/components/hurtbox.gd", 0, L_PLAYER_ATTACKS)
	_shape(hurtbox, _circle(42.0))
	var contact := _area(Area2D, "ContactHitbox", soggy, "res://scripts/components/hitbox.gd", L_ENEMY_ATTACKS, 0)
	contact.monitoring = false
	_shape(contact, _circle(30.0))
	var health := _node(Node, "HealthComponent", soggy, "res://scripts/components/health_component.gd")
	health.set("max_health", 2)
	health.set("invulnerability_time", 0.25)
	var ray := _node(RayCast2D, "LedgeCheck", soggy) as RayCast2D
	ray.position = Vector2(-40, 0)
	ray.target_position = Vector2(0, 64)
	ray.collision_mask = L_WORLD
	_save_scene(soggy, "res://scenes/enemies/soggy.tscn")


func _build_npcs() -> void:
	var fluff := _area(Area2D, "ShepherdFluff", null, "res://scripts/world/npc.gd", L_INTERACTABLES, L_PLAYER)
	fluff.set("dialogue_id", "fluff_intro")
	fluff.set("repeat_dialogue_id", "fluff_repeat")
	fluff.set("first_talk_flag", "met_shepherd_fluff")
	fluff.set("prompt_offset", Vector2(0, -150))
	_sprite(fluff, "characters/shepherd_fluff.png", Vector2(0, -50))
	_shape(fluff, _rect(Vector2(200, 140)), Vector2(0, -60))
	_save_scene(fluff, "res://scenes/world/npc_shepherd_fluff.tscn")

	var dot := _area(Area2D, "Dot", null, "res://scripts/world/npc.gd", L_INTERACTABLES, L_PLAYER)
	dot.set("dialogue_id", "dot_meet")
	dot.set("first_talk_flag", "met_dot")
	dot.set("idle_bob", 12.0)
	dot.set("prompt_offset", Vector2(0, -130))
	_sprite(dot, "characters/dot.png", Vector2(0, -60))
	_shape(dot, _rect(Vector2(150, 140)), Vector2(0, -60))
	_save_scene(dot, "res://scenes/world/npc_dot.tscn")


# --- Pickups and props -------------------------------------------------------

func _build_pickups() -> void:
	var specs := [
		["scrap", "props/scrap.png", 0, 20.0],
		["lost_letter", "props/lost_letter.png", 1, 28.0],
		["tape", "props/tape.png", 2, 24.0],
		["ability_page", "props/paper_dart.png", 3, 30.0],
	]
	for spec in specs:
		var pickup := _area(Area2D, spec[0].to_pascal_case(), null, "res://scripts/world/collectible.gd", 0, L_PLAYER)
		pickup.set("kind", spec[2])
		if spec[0] == "tape":
			pickup.set("amount", 2)
		_sprite(pickup, spec[1])
		_shape(pickup, _circle(spec[3]))
		if spec[0] == "lost_letter":
			var label := _node(Label, "Label", pickup) as Label
			label.size = Vector2(56, 56)
			label.position = Vector2(-28, -28)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override(&"font_size", 36)
		_save_scene(pickup, "res://scenes/pickups/%s.tscn" % spec[0])


func _build_props() -> void:
	var bookmark := _area(Area2D, "Bookmark", null, "res://scripts/world/bookmark.gd", 0, L_PLAYER)
	bookmark.set("respawn_offset", Vector2(0, -48))
	_sprite(bookmark, "props/bookmark_off.png", Vector2(0, -64))
	_shape(bookmark, _rect(Vector2(70, 128)), Vector2(0, -64))
	_save_scene(bookmark, "res://scenes/world/bookmark.tscn")

	var tab := _area(Area2D, "PullTab", null, "res://scripts/world/pull_tab.gd", L_INTERACTABLES, L_PLAYER)
	tab.set("prompt_offset", Vector2(0, -90))
	_sprite(tab, "props/pull_tab.png", Vector2(0, -24))
	_shape(tab, _rect(Vector2(150, 120)), Vector2(0, -40))
	_save_scene(tab, "res://scenes/world/pull_tab.tscn")

	var door := _area(Area2D, "PageDoor", null, "res://scripts/world/page_door.gd", L_INTERACTABLES, L_PLAYER)
	door.set("prompt_offset", Vector2(0, -170))
	_sprite(door, "props/page_corner_door.png", Vector2(0, -64))
	_shape(door, _rect(Vector2(120, 128)), Vector2(0, -64))
	_save_scene(door, "res://scenes/world/page_door.tscn")

	var platform := _node(AnimatableBody2D, "MovingPlatform", null) as AnimatableBody2D
	platform.collision_layer = L_WORLD
	platform.collision_mask = 0
	platform.sync_to_physics = true
	_sprite(platform, "props/cardboard_platform.png")
	var collision := _shape(platform, _rect(Vector2(188, 28)))
	collision.one_way_collision = true
	_save_scene(platform, "res://scenes/world/moving_platform.tscn")

	var hazard := _area(Area2D, "InkPuddleHazard", null, "res://scripts/components/hitbox.gd", L_ENEMY_ATTACKS, 0)
	hazard.monitoring = false
	hazard.set("knockback", 650.0)
	_shape(hazard, _circle(40.0))
	_save_scene(hazard, "res://scenes/world/ink_puddle_hazard.tscn")


# --- UI ----------------------------------------------------------------------

func _build_hud() -> void:
	var hud := _node(CanvasLayer, "HUD", null, "res://scripts/ui/hud.gd") as CanvasLayer
	hud.layer = 10
	var root := _node(Control, "Root", hud) as Control
	_full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _node(HBoxContainer, "Top", root) as HBoxContainer
	top.position = Vector2(32, 24)
	top.add_theme_constant_override(&"separation", 18)
	var tokens := _node(HBoxContainer, "Tokens", top) as HBoxContainer
	tokens.add_theme_constant_override(&"separation", 4)
	var icon := _node(TextureRect, "ScrapIcon", top) as TextureRect
	icon.texture = load(ART + "props/scrap.png")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var scraps := _node(Label, "ScrapsLabel", top) as Label
	scraps.text = "x 0"
	scraps.add_theme_font_size_override(&"font_size", 40)
	var letters := _node(Label, "LettersLabel", top) as Label
	letters.text = "Lost Letters 0/26"
	letters.add_theme_font_size_override(&"font_size", 30)
	_save_scene(hud, "res://scenes/ui/hud.tscn")


func _build_dialogue_ui() -> void:
	var ui := _node(CanvasLayer, "DialogueUI", null, "res://scripts/ui/dialogue_ui.gd") as CanvasLayer
	ui.layer = 20
	var box := _node(PanelContainer, "Box", ui) as PanelContainer
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 180
	box.offset_right = -180
	box.offset_top = -300
	box.offset_bottom = -40
	var margin := _node(MarginContainer, "Margin", box) as MarginContainer
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	var vbox := _node(VBoxContainer, "VBox", margin)
	var speaker := _node(Label, "NameLabel", vbox) as Label
	speaker.add_theme_font_size_override(&"font_size", 38)
	var text := _node(RichTextLabel, "Text", vbox) as RichTextLabel
	text.bbcode_enabled = true
	text.scroll_active = false
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override(&"normal_font_size", 34)
	var hint := _node(Label, "ContinueHint", vbox) as Label
	hint.text = ">>"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var caption := _node(PanelContainer, "Caption", ui) as PanelContainer
	caption.anchor_left = 0.5
	caption.anchor_right = 0.5
	caption.offset_left = -640
	caption.offset_right = 640
	caption.offset_top = 110
	caption.offset_bottom = 220
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cmargin := _node(MarginContainer, "Margin", caption)
	var clabel := _node(Label, "CaptionLabel", cmargin) as Label
	clabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clabel.add_theme_font_size_override(&"font_size", 36)
	clabel.add_theme_color_override(&"font_color", Color("5a3d24"))
	_save_scene(ui, "res://scenes/ui/dialogue_ui.tscn")


func _build_pause_menu() -> void:
	var menu := _node(CanvasLayer, "PauseMenu", null, "res://scripts/ui/pause_menu.gd") as CanvasLayer
	menu.layer = 30
	var root := _node(ColorRect, "Root", menu) as ColorRect
	_full_rect(root)
	root.color = Color(0.17, 0.13, 0.09, 0.5)
	var panel := _node(PanelContainer, "Panel", root) as PanelContainer
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -330
	panel.offset_bottom = 330
	var margin := _node(MarginContainer, "Margin", panel) as MarginContainer
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	var vbox := _node(VBoxContainer, "VBox", margin) as VBoxContainer
	vbox.add_theme_constant_override(&"separation", 16)
	var title := _node(Label, "Title", vbox) as Label
	title.text = "Bookmarked for now"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 52)
	(_node(Button, "ResumeButton", vbox) as Button).text = "Keep reading"
	(_node(Button, "FullscreenButton", vbox) as Button).text = "Toggle fullscreen"
	for row in [["MusicRow", "Music", "MusicSlider"], ["SfxRow", "Sounds", "SfxSlider"]]:
		var hbox := _node(HBoxContainer, row[0], vbox) as HBoxContainer
		var label := _node(Label, "Label", hbox) as Label
		label.text = row[1]
		label.custom_minimum_size = Vector2(140, 0)
		var slider := _node(HSlider, row[2], hbox) as HSlider
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(_node(Button, "QuitButton", vbox) as Button).text = "Save and close the book"
	_save_scene(menu, "res://scenes/ui/pause_menu.tscn")


func _build_title_screen() -> void:
	var screen := _node(Control, "TitleScreen", null, "res://scripts/ui/title_screen.gd") as Control
	_full_rect(screen)
	var bg := _node(TextureRect, "Background", screen) as TextureRect
	_full_rect(bg)
	bg.texture = load(ART + "backgrounds/bg_thistledown.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var center := _node(CenterContainer, "Center", screen) as CenterContainer
	_full_rect(center)
	var vbox := _node(VBoxContainer, "VBox", center) as VBoxContainer
	vbox.add_theme_constant_override(&"separation", 18)
	var title := _node(Label, "Title", vbox) as Label
	title.text = "Patch and the\nPop-Up Kingdom"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.pivot_offset = Vector2(380, 120)
	var subtitle := _node(Label, "Subtitle", vbox) as Label
	subtitle.text = "A storybook adventure, mended with tape"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slots := _node(VBoxContainer, "Slots", vbox) as VBoxContainer
	slots.add_theme_constant_override(&"separation", 12)
	for i in 3:
		var button := _node(Button, "Slot%d" % (i + 1), slots) as Button
		button.custom_minimum_size = Vector2(720, 64)
		button.text = "Book %d" % (i + 1)
	var erase := _node(CheckButton, "EraseToggle", vbox) as CheckButton
	erase.text = "Erase a book"
	erase.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var quit_button := _node(Button, "QuitButton", vbox) as Button
	quit_button.text = "Close the book (quit)"
	_save_scene(screen, "res://scenes/ui/title_screen.tscn")


# --- Levels ------------------------------------------------------------------

func _new_page(page_name: String, mode: int, bounds: Rect2, title: String, caption: String) -> Node2D:
	var page := _node(Node2D, page_name, null, "res://scripts/world/page.gd") as Node2D
	page.set("view_mode", mode)
	page.set("bounds", bounds)
	page.set("page_title", title)
	page.set("opening_caption", caption)
	page.set("music", load("res://assets/audio/music/foldwick_lullaby.wav"))
	return page


## Paints tiles from rows of characters; legend maps a character to atlas coords.
func _paint(layer: TileMapLayer, rows: Array, legend: Dictionary, origin := Vector2i.ZERO) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if legend.has(ch):
				layer.set_cell(origin + Vector2i(x, y), 0, legend[ch])


func _spawn_marker(parent: Node, marker_name: String, position: Vector2) -> void:
	var marker := _node(Marker2D, marker_name, parent) as Marker2D
	marker.position = position
	marker.add_to_group(&"spawn_points", true)


func _page_edges(parent: Node, left: float, right: float) -> void:
	var edges := _node(StaticBody2D, "PageEdges", parent) as StaticBody2D
	edges.collision_layer = L_WORLD
	var left_shape := WorldBoundaryShape2D.new()
	left_shape.normal = Vector2.RIGHT
	_shape(edges, left_shape, Vector2(left, 0), "LeftEdge")
	var right_shape := WorldBoundaryShape2D.new()
	right_shape.normal = Vector2.LEFT
	_shape(edges, right_shape, Vector2(right, 0), "RightEdge")


func _tile_pos(col: float, row: float) -> Vector2:
	return Vector2(col * TILE, row * TILE)


func _build_thistledown_page() -> void:
	const COLS := 80
	var page := _new_page("ThistledownPage01", 0, Rect2(0, 0, COLS * TILE, 1088),
		"Thistledown Meadow",
		"In Thistledown Meadow, the windmills had stopped turning. Something soggy was creeping over the hills.")

	var parallax := _node(Parallax2D, "Background", page) as Parallax2D
	parallax.scroll_scale = Vector2(0.25, 0.1)
	parallax.repeat_size = Vector2(1920, 0)
	parallax.repeat_times = 2
	var bg := _sprite(parallax, "backgrounds/bg_thistledown.png")
	bg.centered = false
	bg.name = "Hills"

	var tiles := _node(TileMapLayer, "Ground", page) as TileMapLayer
	tiles.tile_set = load("res://resources/paper_tiles.tres")
	# 17 rows x 80 columns. G grass top, # dirt, = plank (one-way), ~ soggy ground.
	var rows := [
		"................................................................................",
		"................................................................................",
		"................................................................................",
		"................................................................................",
		"................................................................................",
		"................................................................................",
		"................................................................................",
		"................................................................................",
		"...............................................................===..............",
		"................................................................................",
		".............................................................==.................",
		"................................................................................",
		".........................====......GGGGGGGGGG...........GGGGGGGGGGGGGGGGGGGGGGGG",
		"...................................##########...........########################",
		"GGGGGGGGGGGGGGGGGG...GGGGGGGGGGGGGG##########.=.......=.########################",
		"##################...########################...........########################",
		"##################...########################~~~~~~~~~~~########################",
	]
	_paint(tiles, rows, {"G": T_GRASS, "#": T_DIRT, "=": T_PLANK, "~": T_SOGGY})
	_page_edges(page, 0, COLS * TILE)

	var ground_y := 14 * TILE
	var high_y := 12 * TILE
	_spawn_marker(page, "Start", Vector2(3 * TILE, ground_y - 48))
	_spawn_marker(page, "FromMargin", Vector2(74 * TILE, high_y - 48))

	var actors := _node(Node2D, "Actors", page)
	_instance("res://scenes/world/npc_shepherd_fluff.tscn", "ShepherdFluff", actors, Vector2(9 * TILE, ground_y))
	_instance("res://scenes/enemies/soggy.tscn", "Soggy1", actors, Vector2(31 * TILE, ground_y - 40))
	_instance("res://scenes/enemies/soggy.tscn", "Soggy2", actors, Vector2(50 * TILE, 16 * TILE - 40))
	_instance("res://scenes/enemies/soggy.tscn", "Soggy3", actors, Vector2(68 * TILE, high_y - 40))
	_instance("res://scenes/world/npc_dot.tscn", "Dot", actors, Vector2(60 * TILE, high_y))

	var props := _node(Node2D, "Props", page)
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, Vector2(39 * TILE, high_y))
	var platform := _instance("res://scenes/world/moving_platform.tscn", "TabBridge", props, Vector2(50 * TILE, 15 * TILE + 16))
	var tab := _instance("res://scenes/world/pull_tab.tscn", "BridgeTab", props, Vector2(43 * TILE, high_y))
	tab.set("target", platform)
	tab.set("move_offset", Vector2(0, -3 * TILE))
	var door := _instance("res://scenes/world/page_door.tscn", "MarginDoor", props, Vector2(77 * TILE, high_y))
	door.set("target_page", "res://scenes/levels/margin/kitchen_table.tscn")
	door.set("target_spawn", &"FromPage")
	door.set("door_prompt", "Peek outside the page")

	var pickups := _node(Node2D, "Pickups", page)
	for i in 4:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, Vector2((12 + i * 1.5) * TILE, ground_y - 60))
	for i in 3:
		_instance("res://scenes/pickups/scrap.tscn", "PlankScrap%d" % i, pickups, Vector2((25.5 + i) * TILE, 12 * TILE - 50))
	var letter := _instance("res://scenes/pickups/lost_letter.tscn", "LetterF", pickups, Vector2(64.5 * TILE, 8 * TILE - 60))
	letter.set("letter", "F")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, Vector2(66 * TILE, high_y - 60))
	var dash := _instance("res://scenes/pickups/ability_page.tscn", "FoldDashPage", pickups, Vector2(71 * TILE, high_y - 70))
	dash.set("ability_id", &"fold_dash")
	dash.set("unlock_caption", "Patch remembered how to fold himself into a paper dart! Press {dash} to Fold Dash.")

	_instance("res://scenes/player/patch.tscn", "Patch", page, Vector2(3 * TILE, ground_y - 48))
	_save_scene(page, "res://scenes/levels/ch1_thistledown/thistledown_page_01.tscn")


func _build_kitchen_table() -> void:
	const COLS := 40
	const ROWS := 24
	var page := _new_page("KitchenTable", 1, Rect2(0, 0, COLS * TILE, ROWS * TILE),
		"The Margin",
		"Outside the page, the world was enormous. Gran's kitchen table stretched away under the Great Light.")

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
			var book_stack := (x >= 12 and x <= 14 and y >= 4 and y <= 12) or (x >= 24 and x <= 31 and y >= 15 and y <= 17)
			row += "B" if border or book_stack else " "
		wall_rows.append(row)
	_paint(floor_layer, floor_rows, {".": T_WOOD})
	# The open book lies on the table: a patch of page floor around the way back in.
	var page_rows := []
	for y in 6:
		page_rows.append("PPPPPPP")
	_paint(floor_layer, page_rows, {"P": T_PAGE_FLOOR}, Vector2i(2, 2))
	_paint(walls, wall_rows, {"B": T_BOOKS})
	var ink_rows := ["II.", "III", ".II"]
	_paint(walls, ink_rows, {"I": T_INK}, Vector2i(20, 6))

	_spawn_marker(page, "Start", _tile_pos(5.5, 6))
	_spawn_marker(page, "FromPage", _tile_pos(5.5, 6))

	var props := _node(Node2D, "Props", page)
	var door := _instance("res://scenes/world/page_door.tscn", "BackIntoTheBook", props, _tile_pos(5.5, 4))
	door.set("target_page", "res://scenes/levels/ch1_thistledown/thistledown_page_01.tscn")
	door.set("target_spawn", &"FromMargin")
	door.set("door_prompt", "Climb back into the book")
	_instance("res://scenes/world/bookmark.tscn", "Bookmark1", props, _tile_pos(9, 9))
	_instance("res://scenes/world/ink_puddle_hazard.tscn", "InkPuddle", props, _tile_pos(21.5, 7.5))

	# The giant tape roll: Patch can't carry it yet, but he'll be back (Tape Tail, Chapter 2).
	var tape_roll := _node(StaticBody2D, "GiantTapeRoll", props) as StaticBody2D
	tape_roll.position = _tile_pos(32, 7)
	tape_roll.collision_layer = L_WORLD
	_sprite(tape_roll, "props/tape.png", Vector2.ZERO, 7.0)
	_shape(tape_roll, _circle(150.0))

	var trigger := _area(Area2D, "ArrivalTalk", page, "res://scripts/world/dialogue_trigger.gd", 0, L_PLAYER)
	trigger.position = _tile_pos(18, 8)
	trigger.set("dialogue_id", "margin_arrival")
	_shape(trigger, _rect(Vector2(160, 900)))

	var actors := _node(Node2D, "Actors", page)
	_instance("res://scenes/enemies/soggy.tscn", "Soggy1", actors, _tile_pos(20, 14))
	_instance("res://scenes/enemies/soggy.tscn", "Soggy2", actors, _tile_pos(34, 20))

	var pickups := _node(Node2D, "Pickups", page)
	var letter := _instance("res://scenes/pickups/lost_letter.tscn", "LetterO", pickups, _tile_pos(36, 20))
	letter.set("letter", "O")
	_instance("res://scenes/pickups/tape.tscn", "Tape", pickups, _tile_pos(16, 20))
	for i in 5:
		_instance("res://scenes/pickups/scrap.tscn", "Scrap%d" % i, pickups, _tile_pos(18 + i * 2, 11))

	_instance("res://scenes/player/patch.tscn", "Patch", page, _tile_pos(5.5, 6))
	_save_scene(page, "res://scenes/levels/margin/kitchen_table.tscn")
