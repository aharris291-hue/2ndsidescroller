class_name Page
extends Node2D
## Root script for every playable page (level). It tells Patch how the page is viewed,
## places him at the right spawn point, sets camera limits, starts the music, and
## shows the narrator's caption the first time the page is visited.
##
## Expected children: a Patch instance (scenes/player/patch.tscn) and at least one
## Marker2D named "Start" in the "spawn_points" group.

const COMPANION_SCENE := preload("res://scenes/world/dot_companion.tscn")

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


func _ready() -> void:
	add_to_group("page")
	GameState.current_page = scene_file_path
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

	if GameState.get_flag("met_dot") and get_tree().get_first_node_in_group("companion") == null:
		var dot := COMPANION_SCENE.instantiate() as Node2D
		dot.position = player.position + Vector2(-70, -90)
		add_child.call_deferred(dot)

	if music:
		AudioManager.play_music(music)
	HUD.show_hud(true)
	var caption_flag := "caption_seen:" + scene_file_path
	if not opening_caption.is_empty() and not GameState.get_flag(caption_flag):
		GameState.set_flag(caption_flag)
		DialogueUI.narrate(opening_caption)
	EventBus.page_entered.emit(self)


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
