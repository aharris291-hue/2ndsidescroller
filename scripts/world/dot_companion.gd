class_name DotCompanion
extends Node2D
## A friend following Patch: Dot, the runaway full stop, floating behind him once she
## has joined, and Corrugate from Chapter 2. Each Page adds every companion whose
## `companion_flag` is set (see Page.COMPANIONS).
##
## In a fight they help, on their own, every so often:
##   Dot (FULL_STOP)  darts onto the nearest enemy and stops it dead: it can't move or
##                    attack for a moment. She is a full stop; that is what she does.
##   Corrugate (BRACE) shoulders into the nearest enemy and flattens it (a crush,
##                    1 damage and a lot of Hold), then waddles back.

enum Assist { NONE, FULL_STOP, BRACE }

const ASSIST_RANGE := 460.0
const ASSIST_EVERY := {Assist.FULL_STOP: 7.0, Assist.BRACE: 11.0}
const FULL_STOP_TIME := 1.5

@export var follow_speed := 5.0
@export var follow_offset := Vector2(-70, -90)
## The story flag that means this companion has joined.
@export var companion_flag := "met_dot"
## How much the companion bobs up and down (Dot floats; Corrugate waddles).
@export var bob := 8.0
## What it does in a fight (worked out from companion_flag if left at NONE).
@export var assist := Assist.NONE

var _time := 0.0
var _assist_left := 3.0
var _assisting := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("companion")
	z_index = 5
	if assist == Assist.NONE:
		assist = {"met_dot": Assist.FULL_STOP, "corrugate_joined": Assist.BRACE}.get(companion_flag, Assist.NONE)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Patch
	if player == null:
		return
	_time += delta
	if _assisting:
		return
	if assist != Assist.NONE:
		_assist_left -= delta
		if _assist_left <= 0.0:
			var target := nearest_enemy(player)
			if target:
				_help(target)
			else:
				_assist_left = 1.0
	var side := -signf(player.facing.x) if player.facing.x != 0.0 else -1.0
	var target := player.global_position + Vector2(absf(follow_offset.x) * side, follow_offset.y)
	target.y += sin(_time * 3.0) * bob
	global_position = global_position.lerp(target, clampf(follow_speed * delta, 0.0, 1.0))
	sprite.flip_h = player.global_position.x < global_position.x


## The nearest living enemy within reach of Patch, or null.
func nearest_enemy(player: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := ASSIST_RANGE
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var health = enemy.get(&"health")
		if health is HealthComponent and (health as HealthComponent).is_dead():
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Goes to help: flies (or waddles) to the enemy, does its thing, comes back.
func _help(enemy: Node2D) -> void:
	_assisting = true
	_assist_left = ASSIST_EVERY.get(assist, 9.0)
	var tween := create_tween()
	var at := enemy.global_position + Vector2(0, -60 if assist == Assist.FULL_STOP else -20)
	tween.tween_property(self, "global_position", at, 0.22 if assist == Assist.FULL_STOP else 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_strike.bind(enemy))
	tween.tween_interval(0.35)
	tween.tween_callback(func() -> void: _assisting = false)


func _strike(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	match assist:
		Assist.FULL_STOP:
			# Stopped dead: it can't move or attack until the pause is over.
			enemy.set_meta(&"reel_left", maxf(FULL_STOP_TIME, float(enemy.get_meta(&"reel_left", 0.0))))
			if enemy.get(&"_knockback") != null:
				enemy.set(&"_knockback", Vector2.ZERO)
			if enemy is CharacterBody2D:
				(enemy as CharacterBody2D).velocity = Vector2.ZERO
			AudioManager.play_sfx(&"parry", 1.6, -8.0)
			EventBus.companion_assisted.emit(&"full_stop")
		Assist.BRACE:
			var hurtbox := enemy.get_node_or_null(^"Hurtbox")
			var hitbox := Hitbox.new()
			hitbox.collision_layer = 0
			hitbox.monitorable = false
			hitbox.damage = 1
			hitbox.hold_damage = 2.5
			hitbox.knockback = 400.0
			hitbox.reaction = Hitbox.Reaction.CRUSH
			get_parent().add_child(hitbox)
			hitbox.global_position = enemy.global_position + Vector2(0, -80)
			var health = enemy.get(&"health")
			if hurtbox is Hurtbox and health is HealthComponent:
				# Straight into its hurtbox, as if the hitbox had touched it.
				var before: int = (health as HealthComponent).current
				(hurtbox as Hurtbox).hit.emit(hitbox)
				var hold := enemy.get_node_or_null(^"HoldComponent") as HoldComponent
				if hold and (health as HealthComponent).current < before:
					hold.take_hold(hitbox.hold_damage)
			hitbox.queue_free()
			AudioManager.play_sfx(&"slam", 0.8, -4.0)
			EventBus.companion_assisted.emit(&"brace")
