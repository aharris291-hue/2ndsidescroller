class_name IndexDrawer
extends Node2D
## A card catalogue drawer (the Index, 6-2): it slides out of the cabinet wall into the
## air, stays out a while, and slides back in, on its own clock. Stand on it while it's
## out; when it goes back in, the wall stops Patch and the drawer goes out from under
## him. A ribbon laid on a drawer (Bookmark Warp) rides in and out with it.
##
## Its letter in a map ('r' opens to the right, 'q' to the left; `dir` in the legend)
## is the first cell of air in front of the cabinet: out, the drawer's top is the top
## of that row and it reaches `reach` tiles out into the air from there.

const ART := preload("res://assets/art/dark/props/index_drawer.png")
const TILE := 64.0
const LENGTH := 256.0

@export var dir := 1.0
@export var reach := 3
@export var out_time := 2.4
@export var in_time := 1.4
@export var slide_time := 0.45
## Where in its cycle it starts, in seconds.
@export var phase := 0.0
## Seconds each row up a drawer lags the one below, so a stack of them (one map
## character, one legend) opens in a cascade up the wall instead of all at once.
@export var cascade := 0.0

var drawer: AnimatableBody2D
var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"index_drawers")
	drawer = AnimatableBody2D.new()
	drawer.name = &"Drawer"
	drawer.sync_to_physics = true
	drawer.collision_layer = 1
	drawer.collision_mask = 0
	_sprite = Sprite2D.new()
	_sprite.texture = ART
	_sprite.flip_h = dir < 0.0
	_sprite.centered = false
	_sprite.region_enabled = true
	drawer.add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LENGTH - 8.0, 16)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	shape.one_way_collision = true
	drawer.add_child(shape)
	add_child(drawer)
	_t = phase + position.y / TILE * cascade
	_place(_openness())


func cycle() -> float:
	return out_time + in_time + slide_time * 2.0


## 0 shut, 1 all the way out, at this point in the cycle.
func _openness() -> float:
	var t := fposmod(_t, cycle())
	if t < slide_time:
		return t / slide_time
	t -= slide_time
	if t < out_time:
		return 1.0
	t -= out_time
	if t < slide_time:
		return 1.0 - t / slide_time
	return 0.0


func is_out() -> bool:
	return _openness() >= 0.99


func _at(openness: float) -> Vector2:
	# The cabinet face is the near edge of the cell; the drawer's top is the row's top.
	var face := -TILE / 2.0 * dir
	var shut_centre := face - LENGTH / 2.0 * dir
	var out_centre := face + (reach * TILE - LENGTH / 2.0) * dir
	return Vector2(lerpf(shut_centre, out_centre, ease(openness, -1.8)), -TILE)


func _physics_process(delta: float) -> void:
	var before := _openness()
	_t += delta
	var now := _openness()
	if (before < 1.0 and now >= 1.0) or (before > 0.0 and now <= 0.0):
		_thunk()
	_place(now)


## Moves the drawer, and shows only the part of it that's out of the cabinet.
func _place(openness: float) -> void:
	drawer.position = _at(openness)
	var face := -TILE / 2.0 * dir
	var front := drawer.position.x + LENGTH / 2.0 * dir
	var shown := clampf((front - face) * dir + 10.0, 0.0, LENGTH)
	_sprite.visible = shown > 1.0
	_sprite.region_rect = Rect2(ART.get_width() - shown, 0, maxf(shown, 0.01), ART.get_height())
	var left := front - shown if dir > 0.0 else front
	_sprite.position = Vector2(left - drawer.position.x, -8.0)


func _thunk() -> void:
	var patch := get_tree().get_first_node_in_group(&"player") as Node2D
	if patch and patch.global_position.distance_to(global_position) < 900.0:
		AudioManager.play_sfx(&"slam", 1.8, -14.0)
