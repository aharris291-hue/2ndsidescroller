class_name GhostTrain
extends Node2D
## The Ghost Train (Gatefold Fair, 5-4): a length of rail over the ink with one car on
## it. The car waits at the left end; Patch climbs in and it sets off on its own, too
## fast to get off and walk, and stops hard at the buffers at the right end. Left there
## empty, it rolls back for another rider. TextLevel lays one for each run of '_' in a
## map: the run's cells are where Patch stands in the car (the top of the row), and the
## rail runs under it. Pop-up ghouls ('g', PopGhoul) wait along the way.
##
## climb_check: a run of '_' is a surface Patch can board only near its left end and
## leave anywhere along it.

const CART := preload("res://assets/art/dark/props/ghost_cart.png")
## The car's floor (where Patch stands) above the sprite's bottom edge.
const SEAT := 54.0
const HALF := 100.0

## How far the rail runs, from the origin (the left end of the run).
@export var length := 1280.0
@export var speed := 470.0
@export var return_speed := 620.0
## Seconds left empty at the buffers before it rolls back.
@export var wait_empty := 1.6

enum State { WAITING, RUNNING, STOPPED, RETURNING }

var state := State.WAITING
var cart: AnimatableBody2D
var _zone: Area2D
var _x := 0.0
var _v := 0.0
var _boarded := 0.0
var _empty := 0.0


func _ready() -> void:
	add_to_group(&"ghost_trains")
	_build_rail()
	cart = AnimatableBody2D.new()
	cart.name = &"Cart"
	cart.collision_mask = 0
	cart.sync_to_physics = true
	var sprite := Sprite2D.new()
	sprite.texture = CART
	sprite.offset = Vector2(0, -CART.get_height() / 2.0)
	sprite.position = Vector2(0, SEAT)
	cart.add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF * 1.7, 16)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	shape.one_way_collision = true
	cart.add_child(shape)
	_zone = Area2D.new()
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	var zshape := CollisionShape2D.new()
	var zrect := RectangleShape2D.new()
	zrect.size = Vector2(HALF * 1.6, 48)
	zshape.shape = zrect
	zshape.position = Vector2(0, -20)
	_zone.add_child(zshape)
	cart.add_child(_zone)
	add_child(cart)
	_x = start_x()
	_place()


func _build_rail() -> void:
	var y := SEAT - 4.0
	var rail := Line2D.new()
	rail.width = 7.0
	rail.default_color = Color(0.4, 0.33, 0.28)
	rail.points = PackedVector2Array([Vector2(0, y), Vector2(length, y)])
	add_child(rail)
	var under := Line2D.new()
	under.width = 10.0
	under.default_color = Color(0.17, 0.13, 0.12)
	under.points = PackedVector2Array([Vector2(0, y + 9), Vector2(length, y + 9)])
	add_child(under)
	# Trestles down into the dark, every two tiles.
	var x := 32.0
	while x < length:
		var leg := Line2D.new()
		leg.width = 8.0
		leg.default_color = Color(0.2, 0.16, 0.14)
		leg.points = PackedVector2Array([Vector2(x, y + 12), Vector2(x - 26, y + 260), Vector2(x + 26, y + 260), Vector2(x, y + 12)])
		add_child(leg)
		x += 128.0
	for end in [0.0, length]:
		var buffer := Polygon2D.new()
		var s := -1.0 if end == 0.0 else 1.0
		buffer.polygon = PackedVector2Array([Vector2(end, y), Vector2(end, y - 46), Vector2(end - s * 14, y - 46), Vector2(end - s * 14, y)])
		buffer.color = Color(0.55, 0.14, 0.11)
		add_child(buffer)


func start_x() -> float:
	return HALF + 8.0


func end_x() -> float:
	return length - HALF - 8.0


func rider() -> Patch:
	for body in _zone.get_overlapping_bodies():
		if body is Patch and (body as Patch).is_on_floor():
			return body as Patch
	return null


func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			_boarded = _boarded + delta if rider() else 0.0
			if _boarded > 0.25:
				state = State.RUNNING
				_v = 0.0
				AudioManager.play_sfx(&"tab_pull", 0.5)
		State.RUNNING:
			_v = move_toward(_v, speed, speed * 2.5 * delta)
			_x += _v * delta
			if _x >= end_x():
				_x = end_x()
				state = State.STOPPED
				_empty = 0.0
				AudioManager.play_sfx(&"slam", 0.7)
				var jolt := create_tween()
				jolt.tween_property(cart, "rotation", 0.06, 0.06)
				jolt.tween_property(cart, "rotation", 0.0, 0.2)
		State.STOPPED:
			_empty = 0.0 if rider() else _empty + delta
			if _empty > wait_empty:
				state = State.RETURNING
		State.RETURNING:
			_x = move_toward(_x, start_x(), return_speed * delta)
			if _x <= start_x():
				state = State.WAITING
				_boarded = 0.0
	_place()


func _place() -> void:
	cart.position = Vector2(_x, 0)
