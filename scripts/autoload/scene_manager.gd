extends CanvasLayer
## Moves between pages with a page-turn wipe, and remembers where Patch should appear
## on the next page (a named spawn marker, or an exact checkpoint position).

const TITLE_SCREEN := "res://scenes/ui/title_screen.tscn"
const PAPER_COLOR := Color("f7eed6")
const INK_COLOR := Color("2b2118")
const TURN_TIME := 0.35

var is_transitioning := false
var _spawn_name: StringName = &""
var _spawn_position: Variant = null
var _sheet: ColorRect
var _edge: ColorRect


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sheet = ColorRect.new()
	_sheet.color = PAPER_COLOR
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	# A thin ink line on the leading edge sells the "page" look.
	_edge = ColorRect.new()
	_edge.color = INK_COLOR
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_edge)
	_sheet.visible = false


## Turns to another page. Patch appears at the Marker2D named spawn_name,
## or at the page's "Start" marker when no name is given.
func change_page(scene_path: String, spawn_name: StringName = &"") -> void:
	_spawn_name = spawn_name
	_spawn_position = null
	await _turn_to(scene_path)


## Turns to a page and places Patch at an exact position (used by checkpoints and loading).
func change_page_at(scene_path: String, position: Vector2) -> void:
	_spawn_name = &""
	_spawn_position = position
	await _turn_to(scene_path)


func respawn_at_checkpoint() -> void:
	GameState.health = GameState.max_health
	await change_page_at(GameState.checkpoint_page, GameState.checkpoint_position)


func go_to_title() -> void:
	GameState.in_gameplay = false
	await _turn_to(TITLE_SCREEN)


## Called by a Page when it loads. Returns {"name": StringName, "position": Vector2 or null}.
func consume_spawn() -> Dictionary:
	var result := {"name": _spawn_name, "position": _spawn_position}
	_spawn_name = &""
	_spawn_position = null
	return result


func _turn_to(scene_path: String) -> void:
	if is_transitioning:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("Page not found: %s" % scene_path)
		return
	is_transitioning = true
	var size := get_viewport().get_visible_rect().size
	_sheet.size = size
	_edge.size = Vector2(6, size.y)
	_edge.position = Vector2.ZERO
	_sheet.position = Vector2(size.x, 0)
	_sheet.visible = true
	AudioManager.play_sfx(&"page_flip", randf_range(0.9, 1.1))

	var cover := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cover.tween_property(_sheet, "position:x", 0.0, TURN_TIME)
	await cover.finished

	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
	# The new scene is added at the end of this frame; wait for it to finish _ready.
	await get_tree().process_frame
	await get_tree().process_frame

	_edge.position = Vector2(size.x - 6, 0)
	var reveal := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_property(_sheet, "position:x", -size.x, TURN_TIME)
	await reveal.finished
	_sheet.visible = false
	is_transitioning = false
