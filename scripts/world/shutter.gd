class_name Shutter
extends Node2D
## A roll shutter over an alcove of the Index: oak slats on a brass rail, solid while
## down. A PullTab whose `flips` names this shutter's `tag` rolls it up (or down). With
## `open_time` above 0 it's on a spring: a pull rolls it up for that long, ticking, and
## then it drops on its own, faster than anyone can run to it. That's what Gran's
## ribbon is for (Bookmark Warp): lay it by the shutter, pull, and come back.
##
## It fills `size`, standing on its origin (the floor under its letter in the map).
## Joins the PullTab's "vent_flaps" group, so the tabs that flip vents flip these too.

const ART := preload("res://assets/art/dark/props/index_shutter.png")
const RISE := 0.35

@export var size := Vector2(96, 256)
@export var tag := ""
@export var open := false
## Seconds a pull holds it open (0: each pull just toggles it).
@export var open_time := 0.0

var body: StaticBody2D
var _shape: CollisionShape2D
var _sprite: Sprite2D
var _shut_in := 0.0
## 0 shut, 1 rolled all the way up.
var _roll := 0.0


func _ready() -> void:
	add_to_group(&"vent_flaps")
	add_to_group(&"shutters")
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x * 0.8, size.y)
	_shape.shape = rect
	_shape.position = Vector2(0, -size.y / 2.0)
	body.add_child(_shape)
	add_child(body)
	# The frame stays; the slats roll up into the housing at the top.
	var housing := Polygon2D.new()
	housing.color = Color(0.16, 0.11, 0.09)
	housing.polygon = PackedVector2Array([Vector2(-size.x / 2 - 6, -size.y - 22), Vector2(size.x / 2 + 6, -size.y - 22),
		Vector2(size.x / 2 + 6, -size.y + 6), Vector2(-size.x / 2 - 6, -size.y + 6)])
	_sprite = Sprite2D.new()
	_sprite.texture = ART
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.scale = Vector2(size.x / ART.get_width(), size.y / ART.get_height())
	_sprite.position = Vector2(-size.x / 2.0, -size.y)
	add_child(_sprite)
	add_child(housing)
	_roll = 1.0 if open else 0.0
	_apply()


func flip() -> void:
	if open_time > 0.0:
		_set_open(true)
		_shut_in = open_time
	else:
		_set_open(not open)


func _set_open(value: bool) -> void:
	if value == open:
		return
	open = value
	AudioManager.play_sfx(&"tab_pull", 0.6 if open else 0.45, -2.0)
	if not open:
		_shove_out()


func _physics_process(delta: float) -> void:
	if _shut_in > 0.0:
		var before := _shut_in
		_shut_in -= delta
		# It ticks as the spring runs down, faster at the end.
		var step := 0.5 if _shut_in > 1.5 else 0.25
		if floorf(before / step) != floorf(_shut_in / step) and _shut_in > 0.0:
			AudioManager.play_sfx(&"voice_blip", 2.2, -12.0)
		if _shut_in <= 0.0:
			_set_open(false)
	var goal := 1.0 if open else 0.0
	if _roll != goal:
		_roll = move_toward(_roll, goal, delta / RISE)
		_apply()


func _apply() -> void:
	var h := ART.get_height() * (1.0 - _roll)
	_sprite.region_rect = Rect2(0, ART.get_height() - h, ART.get_width(), maxf(h, 0.01))
	_sprite.visible = h > 1.0
	# Solid until it's most of the way up, and from the moment it starts down.
	var solid := (_roll < 0.85) if open else true
	_shape.set_deferred("disabled", not solid)


## Coming down on Patch: he's pushed out to the nearer side, not shut inside.
func _shove_out() -> void:
	for patch in get_tree().get_nodes_in_group(&"player"):
		var p := patch as Node2D
		var d := p.global_position - global_position
		if absf(d.x) < size.x / 2.0 + 28.0 and d.y < 50.0 and d.y > -size.y - 40.0:
			p.global_position.x = global_position.x + signf(d.x if d.x != 0.0 else -1.0) * (size.x / 2.0 + 32.0)
