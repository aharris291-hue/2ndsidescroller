class_name PushBlock
extends StaticBody2D
## Something heavy Patch shoves across a top-down page (a sodden chapel pew). Lean into
## it for a moment and it slides one tile that way, if the way is clear of walls and
## other blocks. Blocks sit on the 64 px grid; `cells` is its size in tiles.
## Where it ends up is remembered per visit only: leaving the page resets the puzzle.

signal moved(block: PushBlock)

const TILE := 64.0
const LEAN_TIME := 0.22
const SLIDE_TIME := 0.18

@export var texture: Texture2D = preload("res://assets/art/dark/props/pew.png")
@export var cells := Vector2i(2, 1)

var _lean := 0.0
var _lean_dir := Vector2.ZERO
var _sliding := false
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(&"push_blocks")
	collision_layer = 1
	collision_mask = 0
	var size := Vector2(cells) * TILE
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = size / texture.get_size()
	add_child(sprite)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size - Vector2(4, 4)
	_shape.shape = rect
	add_child(_shape)


func size_px() -> Vector2:
	return Vector2(cells) * TILE


func _physics_process(delta: float) -> void:
	if _sliding:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Patch
	if player == null or not player.input_enabled:
		_lean = 0.0
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var dir := _leaning_dir(player, input)
	if dir == Vector2.ZERO or dir != _lean_dir:
		_lean_dir = dir
		_lean = 0.0
		return
	_lean += delta
	if _lean >= LEAN_TIME:
		_lean = 0.0
		try_push(dir)


## Which way Patch is leaning on this block (a unit axis), or zero.
func _leaning_dir(player: Node2D, input: Vector2) -> Vector2:
	if input.length() < 0.5:
		return Vector2.ZERO
	var axis := Vector2(signf(input.x), 0) if absf(input.x) >= absf(input.y) else Vector2(0, signf(input.y))
	var half := size_px() / 2.0
	var d := player.global_position - global_position
	# Patch must be pressed against the face he's pushing, and roughly across from it.
	if axis.x != 0.0:
		return axis if absf(d.y) < half.y + 20.0 and signf(-d.x) == axis.x and absf(d.x) < half.x + 52.0 else Vector2.ZERO
	return axis if absf(d.x) < half.x + 20.0 and signf(-d.y) == axis.y and absf(d.y) < half.y + 60.0 else Vector2.ZERO


## Slides one tile in `dir` if nothing is in the way. Returns whether it moved.
func try_push(dir: Vector2) -> bool:
	if _sliding or not _is_clear(global_position + dir * TILE):
		return false
	_sliding = true
	AudioManager.play_sfx(&"tab_pull", 0.6, -4.0)
	var slide := create_tween()
	slide.tween_property(self, "global_position", global_position + dir * TILE, SLIDE_TIME)
	slide.tween_callback(func() -> void:
		_sliding = false
		moved.emit(self))
	return true


func _is_clear(at: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_px() - Vector2(12, 12)
	query.shape = rect
	query.transform = Transform2D(0.0, at)
	query.collision_mask = 1 | 4
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
