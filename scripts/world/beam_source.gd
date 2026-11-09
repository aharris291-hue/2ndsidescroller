class_name BeamSource
extends StaticBody2D
## The cracked lamp lens set in a wall of the Lamp Room (2-3, seen from above). It
## throws a beam one way along the grid; the page traces it (see LampRoom).

const TEX := preload("res://assets/art/dark/props/beam_lens.png")

## The grid direction the beam leaves in (y grows downward).
@export var direction := Vector2i(0, 1)


func _ready() -> void:
	add_to_group(&"beam_sources")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 64)
	shape.shape = rect
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = TEX
	add_child(sprite)
