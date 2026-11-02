class_name CollapsingShelf
extends AnimatableBody2D
## A loose shelf board. It holds for a moment after Patch lands on it, shakes, then
## drops away. It comes back after `return_time` (never, if that is 0).

const BOARD := preload("res://assets/art/dark/props/shelf_board.png")

@export var hold_time := 0.55
@export var return_time := 0.0

var _home := Vector2.ZERO
var _armed := true
var _sprite: Sprite2D


func _ready() -> void:
	_home = position
	sync_to_physics = false
	_sprite = Sprite2D.new()
	_sprite.texture = BOARD
	_sprite.position = Vector2(0, -14)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(184, 20)
	shape.shape = rect
	shape.position = Vector2(0, -16)
	shape.one_way_collision = true
	add_child(shape)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(180, 24)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0, -38)
	sensor.add_child(sensor_shape)
	add_child(sensor)
	sensor.body_entered.connect(_on_stepped)


func _on_stepped(body: Node2D) -> void:
	if not _armed or not body is Patch:
		return
	_armed = false
	AudioManager.play_sfx(&"page_flip", 0.6, -4.0)
	var shake := create_tween()
	for i in 6:
		shake.tween_property(_sprite, "position:x", 3.0 if i % 2 == 0 else -3.0, hold_time / 6.0)
	shake.tween_callback(_drop)


func _drop() -> void:
	_sprite.position.x = 0.0
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	var fall := create_tween().set_parallel()
	fall.tween_property(self, "position:y", position.y + 900.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(self, "rotation", randf_range(-0.4, 0.4), 0.9)
	fall.tween_property(_sprite, "modulate:a", 0.0, 0.9)
	if return_time > 0.0:
		fall.chain().tween_interval(return_time)
		fall.chain().tween_callback(_restore)


func _restore() -> void:
	position = _home
	rotation = 0.0
	_sprite.modulate.a = 1.0
	_armed = true
