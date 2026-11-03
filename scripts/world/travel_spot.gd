class_name TravelSpot
extends Interactable
## Added to every bookmark: once Patch knows two or more bookmarks, he can open the
## torn map here and travel to any of them.


func _init() -> void:
	prompt_text = "Travel by bookmark"
	prompt_offset = Vector2(0, -190)
	collision_layer = 32
	collision_mask = 2


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(110, 140)
	shape.shape = rect
	shape.position = Vector2(0, -70)
	add_child(shape)
	super._ready()


func can_interact() -> bool:
	return GameState.bookmarks.size() >= 2 and not SceneManager.is_transitioning \
		and not GameState.sandbox and MapPanel.current == null


func interact(_player: Patch) -> void:
	MapPanel.open_panel(get_tree().root, true)
