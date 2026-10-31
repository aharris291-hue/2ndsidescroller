class_name DotCompanion
extends Node2D
## A friend following Patch: Dot, the runaway full stop, floating behind him once she
## has joined, and Corrugate from Chapter 2. Each Page adds every companion whose
## `companion_flag` is set (see Page.COMPANIONS).

@export var follow_speed := 5.0
@export var follow_offset := Vector2(-70, -90)
## The story flag that means this companion has joined.
@export var companion_flag := "met_dot"
## How much the companion bobs up and down (Dot floats; Corrugate waddles).
@export var bob := 8.0

var _time := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("companion")
	z_index = 5


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Patch
	if player == null:
		return
	_time += delta
	var side := -signf(player.facing.x) if player.facing.x != 0.0 else -1.0
	var target := player.global_position + Vector2(absf(follow_offset.x) * side, follow_offset.y)
	target.y += sin(_time * 3.0) * bob
	global_position = global_position.lerp(target, clampf(follow_speed * delta, 0.0, 1.0))
	sprite.flip_h = player.global_position.x < global_position.x
