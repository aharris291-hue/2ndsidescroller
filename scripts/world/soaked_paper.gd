class_name SoakedPaper
extends AnimatableBody2D
## A sheet of sodden paper stretched between two pegs (Thistledown's new idea). It
## holds Patch, but it sags while he stands on it and tears if he stays too long; it
## knits back together after `return_time`. Stepping off lets it recover. It is too
## soft to jump from properly: a jump off it is only a hop (Patch.SOFT_JUMP).
##
## Once dried (an Awning dropped over it, see Awning), it is sturdy paper and holds
## for good. A sheet that starts `dry` never tears.

const WET_TEX := preload("res://assets/art/dark/props/soaked_paper.png")
const DRY_TEX := preload("res://assets/art/dark/props/dry_paper.png")
const SAG := 12.0

## Seconds of standing before it tears.
@export var tear_time := 0.9
@export var return_time := 3.0
@export var dry := false

var _load := 0.0
var _torn := false
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _sensor: Area2D


func _ready() -> void:
	add_to_group(&"soaked_paper")
	sync_to_physics = false
	_sprite = Sprite2D.new()
	_sprite.texture = DRY_TEX if dry else WET_TEX
	_sprite.position = Vector2(0, -16)
	add_child(_sprite)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(176, 18)
	_shape.shape = rect
	_shape.position = Vector2(0, -20)
	_shape.one_way_collision = true
	add_child(_shape)
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(176, 24)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0, -40)
	_sensor.add_child(sensor_shape)
	add_child(_sensor)


func is_torn() -> bool:
	return _torn


## How close it is to tearing, 0..1.
func strain() -> float:
	return clampf(_load / tear_time, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _torn or dry:
		return
	var standing := false
	for body in _sensor.get_overlapping_bodies():
		if body is Patch and (body as Patch).is_on_floor():
			standing = true
			(body as Patch).soft_ground_left = 0.12
	if standing:
		_load += delta
		if _load >= tear_time:
			tear()
			return
	else:
		_load = maxf(_load - delta * 1.5, 0.0)
	var k := strain()
	_sprite.position = Vector2(randf_range(-1.5, 1.5) * k, -16 + SAG * k)
	_sprite.scale = Vector2(1.0, 1.0 + 0.25 * k)


func tear() -> void:
	if _torn or dry:
		return
	_torn = true
	_load = 0.0
	_shape.set_deferred("disabled", true)
	AudioManager.play_sfx(&"page_flip", 0.5, -2.0)
	var fall := create_tween().set_parallel()
	fall.tween_property(_sprite, "position:y", _sprite.position.y + 140.0, 0.6).set_ease(Tween.EASE_IN)
	fall.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	fall.tween_property(_sprite, "rotation", randf_range(-0.3, 0.3), 0.6)
	if return_time > 0.0:
		fall.chain().tween_interval(return_time)
		fall.chain().tween_callback(_mend)


func _mend() -> void:
	_torn = false
	_sprite.position = Vector2(0, -16)
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE
	_shape.set_deferred("disabled", false)
	create_tween().tween_property(_sprite, "modulate:a", 1.0, 0.3)


## Dries the sheet: it stops sagging and holds for good.
func dry_out(duration := 1.2) -> void:
	if dry:
		return
	dry = true
	if _torn:
		_mend()
	_sprite.position = Vector2(0, -16)
	_sprite.scale = Vector2.ONE
	var swap := create_tween()
	swap.tween_property(_sprite, "modulate", Color(1.3, 1.25, 1.1), duration * 0.5)
	swap.tween_callback(func() -> void: _sprite.texture = DRY_TEX)
	swap.tween_property(_sprite, "modulate", Color.WHITE, duration * 0.5)
