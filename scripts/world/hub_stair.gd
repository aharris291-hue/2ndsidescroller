class_name HubStair
extends Node2D
## The broken stair up to the Spine's gallery. Its boards are only nailed back once a
## region is mended (`opens_on`); until then a snapped board hangs where they'd be.

const BOARD := preload("res://assets/art/dark/props/shelf_board.png")

## Story flag that puts the boards back.
@export var opens_on := "boss_millwheel_defeated"
## Where each board's top-centre goes, relative to this node.
@export var boards: Array[Vector2] = []

var _built_open := false


func _ready() -> void:
	_build()


func _process(_delta: float) -> void:
	if not _built_open and is_open():
		_build()


func is_open() -> bool:
	return opens_on.is_empty() or GameState.get_flag(opens_on)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_built_open = is_open()
	if not _built_open:
		# One snapped board hanging from a nail, and nothing to stand on.
		var broken := Sprite2D.new()
		broken.texture = BOARD
		broken.position = boards[0] + Vector2(0, 40) if not boards.is_empty() else Vector2.ZERO
		broken.rotation = 1.2
		broken.modulate = Color(0.7, 0.66, 0.66)
		add_child(broken)
		return
	for top in boards:
		var body := StaticBody2D.new()
		body.position = top
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(192, 16)
		shape.shape = rect
		shape.position = Vector2(0, 8)
		shape.one_way_collision = true
		body.add_child(shape)
		var sprite := Sprite2D.new()
		sprite.texture = BOARD
		sprite.position = Vector2(0, 14)
		body.add_child(sprite)
		add_child(body)
