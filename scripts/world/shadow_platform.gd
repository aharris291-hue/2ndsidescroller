class_name ShadowPlatform
extends StaticBody2D
## A shadow thrown on the wharf's walls by a burning lantern (Region 2, Lanternfold):
## the silhouette of a net, a crate on a rope, a hanging board. While the nearest lantern
## burns, the shadow is solid enough to stand on (a one-way ledge); when the lamp goes
## out, so does the ledge. With short-trimmed lamps that makes a climb against the clock.
##
## Its top is at its origin (like a plank on the row below the map cell it is drawn in).

const TEX := preload("res://assets/art/dark/props/shadow_ledge.png")
## The board in the art is this wide, with its top this far down the image.
const ART_BOARD := 192.0
const ART_TOP := 14.0

@export var width := 192.0
## How far it looks for the lantern that casts it, in px.
@export var link_range := 1200.0

var solid := false
var lamp: Node2D
var _shape: CollisionShape2D
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group(&"shadow_platforms")
	# Never respawn Patch onto a shadow: its lamp may be out by then.
	add_to_group(&"unsafe_floor")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 16)
	_shape.shape = rect
	_shape.position = Vector2(0, 8)
	_shape.one_way_collision = true
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.scale = Vector2(width / ART_BOARD, 1.0)
	_sprite.position = Vector2(0, TEX.get_height() * 0.5 - ART_TOP)
	add_child(_sprite)
	_find_lamp.call_deferred()


func _find_lamp() -> void:
	var best := link_range
	for node in get_tree().get_nodes_in_group(&"light_zones"):
		var d := (node as Node2D).global_position.distance_to(global_position)
		if d < best:
			best = d
			lamp = node
	_set_solid(lamp != null and lamp.get("lit"), true)


func _physics_process(_delta: float) -> void:
	if lamp == null:
		return
	var on: bool = lamp.get("lit")
	if on != solid:
		_set_solid(on)


func _set_solid(on: bool, instant := false) -> void:
	solid = on
	_shape.set_deferred("disabled", not on)
	var target := 1.0 if on else 0.14
	if instant:
		_sprite.modulate.a = target
		return
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate:a", target, 0.25 if on else 0.4)
