class_name PageExit
extends Area2D
## Walking (or falling) into this area turns to another page, with no button press.
## Used where the way on is a drop, a collapse or the edge of a page.

@export_file("*.tscn") var target_page := ""
@export var target_spawn: StringName = &""
## Story flag that must be set first (empty = always open).
@export var requires_flag := ""
@export var size := Vector2(128, 256)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Patch or target_page.is_empty() or SceneManager.is_transitioning:
		return
	if not requires_flag.is_empty() and not GameState.get_flag(requires_flag):
		return
	SceneManager.change_page(target_page, target_spawn)
