class_name Current
extends Area2D
## Shallow floodwater running across the floor: wading through it pushes Patch along
## (`strength` px/s, positive = right), and harder while he's in the air above it. It
## draws itself as a strip of dark water `size` wide, standing on its origin.
## A Sluice can stop it (`flowing = false`).

const SURFACE := preload("res://assets/art/dark/props/rising_water.png")

@export var size := Vector2(640, 96)
@export var strength := 260.0
@export var flowing := true

var _surface: Sprite2D
var _scroll := 0.0


func _ready() -> void:
	add_to_group(&"currents")
	collision_layer = 0
	collision_mask = 2
	z_index = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	var body := ColorRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.color = Color(0.04, 0.05, 0.08, 0.72)
	body.position = Vector2(-size.x / 2.0, -size.y * 0.55)
	body.size = Vector2(size.x, size.y * 0.55)
	add_child(body)
	_surface = Sprite2D.new()
	_surface.texture = SURFACE
	_surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_surface.region_enabled = true
	_surface.region_rect = Rect2(0, 0, size.x, 48)
	_surface.centered = false
	_surface.position = Vector2(-size.x / 2.0, -size.y * 0.55 - 24)
	_surface.modulate = Color(0.3, 0.32, 0.42, 0.9)
	add_child(_surface)


func _physics_process(delta: float) -> void:
	if not flowing:
		return
	_scroll = wrapf(_scroll - strength * delta * 0.5, 0.0, 512.0)
	_surface.region_rect.position.x = _scroll
	for body in get_overlapping_bodies():
		var patch := body as Patch
		if patch:
			patch.push.x += strength * (1.0 if patch.is_on_floor() else 0.6)


## Stops (or restarts) the flow; the water drains away when stopped.
func set_flowing(on: bool) -> void:
	flowing = on
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0 if on else 0.0, 0.8)
	set_deferred("monitoring", on)
