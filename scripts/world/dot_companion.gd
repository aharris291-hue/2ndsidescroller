class_name DotCompanion
extends Node2D
## Dot, the runaway full stop, floating along behind Patch once she has joined him.
## Each Page adds her automatically when the "met_dot" flag is set.

const FOLLOW_OFFSET := Vector2(-70, -90)

@export var follow_speed := 5.0

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
	var target := player.global_position + Vector2(absf(FOLLOW_OFFSET.x) * side, FOLLOW_OFFSET.y)
	target.y += sin(_time * 3.0) * 8.0
	global_position = global_position.lerp(target, clampf(follow_speed * delta, 0.0, 1.0))
	sprite.flip_h = player.global_position.x < global_position.x
