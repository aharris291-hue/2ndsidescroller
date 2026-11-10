class_name Page
extends Node2D
## Root script for every playable page (level). It tells Patch how the page is viewed,
## places him at the right spawn point, sets camera limits, starts the music, and
## shows the narrator's caption the first time the page is visited.
##
## Expected children: a Patch instance (scenes/player/patch.tscn) and at least one
## Marker2D named "Start" in the "spawn_points" group.

## Story flag -> the companion that follows Patch once it is set.
const WEATHERED := preload("res://resources/shaders/weathered.gdshader")
## Art already painted for the dark rebuild; the weathering pass leaves it alone.
const DARK_ART_DIR := "res://assets/art/dark/"

const COMPANIONS := {
	"met_dot": preload("res://scenes/world/dot_companion.tscn"),
	"corrugate_joined": preload("res://scenes/world/corrugate_companion.tscn"),
}

@export var view_mode: PageView.Mode = PageView.Mode.SIDE
@export var page_title := ""
## Dad's handwritten caption, shown once on the first visit.
@export_multiline var opening_caption := ""
@export var music: AudioStream
## The playable area, in pixels. The camera never shows outside it.
@export var bounds := Rect2(0, 0, 3840, 1080)
## False for pages in the real world (the Margin): they fill the screen instead of
## being drawn inside the open book (see BookFrame).
@export var in_book := true
## Dark rebuild: book pages are played in the drowned world itself, under rain, fog
## and a cold grade (DarkAtmosphere), filling the screen instead of sitting in the
## open book. Real-world pages (in_book = false) keep their own look.
@export var weather := true
## Overrides for this page's weather: the cold tint and how hard it rains.
@export var weather_tint := Color(0.6, 0.65, 0.78)
@export var rain_amount := 420
## Indoor pages (the Spine) turn the lightning off.
@export var lightning := true
## The Spine Peaks: the rain falls as snow (slow, drifting flakes, and no rain sound).
@export var snow := false
## No companions follow Patch here, even if they've joined (he's alone in the Gutter).
@export var no_companions := false


# Joins "page" before any child's _ready, so enemies can read the page's view mode.
func _enter_tree() -> void:
	add_to_group("page")


func _ready() -> void:
	if weather and in_book:
		in_book = false
		var atmosphere := DarkAtmosphere.new()
		atmosphere.ambient = weather_tint
		atmosphere.rain_amount = rain_amount
		atmosphere.lightning = lightning
		atmosphere.snow = snow
		add_child(atmosphere)
		_weathered = ShaderMaterial.new()
		_weathered.shader = WEATHERED
		_weather_art(self)
		get_tree().node_added.connect(_on_node_added)
	GameState.current_page = scene_file_path
	Rematch.page_loaded(scene_file_path)
	if GameState.printing > 0 and not GameState.get_flag("printing_noted"):
		GameState.set_flag("printing_noted")
		DialogueUI.narrate.call_deferred("The %s Printing. The same pages, set again in heavier type, and the ink not quite dry. Patch remembered all of it. So did the book." % SecondPrinting.ordinal(GameState.printing))
	GameState.mark_visited(scene_file_path)
	GameState.in_gameplay = true

	var player := get_tree().get_first_node_in_group("player") as Patch
	if player == null:
		push_error("Page %s has no Patch instance." % name)
		return
	player.view_mode = view_mode
	_place_player(player)
	_configure_camera(player.camera)
	if view_mode == PageView.Mode.SIDE:
		player.fall_limit = bounds.end.y + 200.0

	# A page with no checkpoint yet (fresh game) uses its start point.
	if GameState.checkpoint_page.is_empty():
		GameState.set_checkpoint(scene_file_path, player.global_position)

	for flag in COMPANIONS:
		if no_companions:
			break
		if GameState.get_flag(flag) and not _has_companion(flag):
			var friend := (COMPANIONS[flag] as PackedScene).instantiate() as Node2D
			friend.position = player.position + friend.get("follow_offset")
			add_child.call_deferred(friend)

	if music:
		AudioManager.play_music(music)
	HUD.show_hud(true)
	var caption_flag := "caption_seen:" + scene_file_path
	if not opening_caption.is_empty() and not GameState.get_flag(caption_flag):
		GameState.set_flag(caption_flag)
		DialogueUI.narrate(opening_caption)
	TitleCard.on_page(self)
	EventBus.page_entered.emit(self)


var _weathered: ShaderMaterial


## Drains the colour from the old bright art under this page (until each piece is
## repainted). Skips Patch, pickups (they must stay easy to spot), the backdrop,
## the tiles, art from the dark kit and anything that already has its own material.
func _weather_art(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node is Patch or node is Collectible or node is TileMapLayer or node is Parallax2D:
		return
	if node is CanvasLayer or node is Control:
		return
	# Combat effects and enemy tells keep their colour: it's what tells the player
	# to parry (white), dodge (red), or that a Mend (green) or perfect dodge (gold) worked.
	if node.is_in_group(&"vfx"):
		return
	if node is CanvasItem and _wants_weathering(node):
		(node as CanvasItem).material = _weathered
		(node as CanvasItem).use_parent_material = false
	for child in node.get_children():
		_weather_art(child)


func _wants_weathering(item: CanvasItem) -> bool:
	if item.material != null:
		return false
	if not (item is Sprite2D or item is AnimatedSprite2D or item is Polygon2D or item is Line2D):
		return false
	var texture: Texture2D = item.get(&"texture")
	return texture == null or not texture.resource_path.begins_with(DARK_ART_DIR)


func _on_node_added(node: Node) -> void:
	if not is_ancestor_of(node):
		return
	# Only the top of a newly added branch; skip anything inside Patch or a pickup.
	var up := node.get_parent()
	while up != self:
		if up is Patch or up is Collectible:
			return
		up = up.get_parent()
	# Deferred, and the branch may be freed before then (a hit spark, a dropped scrap).
	var weak: WeakRef = weakref(node)
	(func() -> void:
		var still: Node = weak.get_ref()
		if still:
			_weather_art(still)).call_deferred()


func _has_companion(flag: String) -> bool:
	for friend in get_tree().get_nodes_in_group("companion"):
		if friend.get("companion_flag") == flag:
			return true
	return false


func _place_player(player: Patch) -> void:
	var spawn := SceneManager.consume_spawn()
	if spawn.position != null:
		player.global_position = spawn.position
		return
	var wanted: StringName = spawn.name if spawn.name != &"" else &"Start"
	for marker in get_tree().get_nodes_in_group("spawn_points"):
		if marker.name == wanted:
			player.global_position = marker.global_position
			return
	if spawn.name != &"":
		push_warning("Spawn point '%s' not found on %s." % [spawn.name, name])


func _configure_camera(camera: Camera2D) -> void:
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.reset_smoothing()
