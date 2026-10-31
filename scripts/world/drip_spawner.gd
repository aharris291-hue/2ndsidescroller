class_name DripSpawner
extends Node2D
## Drops runny ink drips from the flap overhead, somewhere along `width`, while Patch
## is nearby. Used under the harbor flap in Chapter 2.

const DRIP_SCENE := preload("res://scenes/enemies/ink_drip.tscn")

@export var width := 640.0
@export var interval := 1.2
@export var floor_y := 896.0
## Only drips while Patch is within this many pixels (horizontally).
@export var active_range := 1100.0

var _left := 0.0


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = interval * randf_range(0.8, 1.2)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or absf(player.global_position.x - (global_position.x + width / 2.0)) > active_range:
		return
	var drip := DRIP_SCENE.instantiate() as Node2D
	drip.position = position + Vector2(randf() * width, 0)
	drip.set("floor_y", floor_y - 20.0)
	get_parent().add_child(drip)
